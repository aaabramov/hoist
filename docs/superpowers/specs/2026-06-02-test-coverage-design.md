# Test Coverage — Design

Date: 2026-06-02

## Goal

Give Hoist a real, automated unit-test suite so the configuration "brain" of the
app is protected against silent regressions, and wire it into CI. Hoist currently
has **zero** automated tests.

## Scope

### In scope (pure, deterministic logic)

- **`HoistConfig.mm` config logic**
  - JSON dictionary → `parameters` type coercion (bool / int / float / array → string)
  - `validateParameters` defaults + clamping + `warpMouse` computation
  - CLI-argument override precedence over file values
- **Pure helpers**
  - `is_pwa(NSString*)` bundle-id matching

### Out of scope (not unit-testable without a live GUI session, Accessibility
permission, and the SkyLight private framework)

- Window detection / raising / activation (`get_mousewindow`, `raiseAndActivate`, …)
- Cursor scaling, event taps, screen geometry, space/app-activation callbacks

These are thin glue over OS APIs and belong to manual / integration testing, not a
headless unit suite. We explicitly do **not** mock the Accessibility or SkyLight
APIs — that would be brittle and low-value.

## Approach

A **dependency-free assertion harness** compiled with the project's existing
`g++ -fobjc-arc` toolchain, exposed through a new `make test` target. This matches
Hoist's minimalist, zero-dependency, Makefile-only ethos (no `.xcodeproj`, so XCTest
adds ceremony; GoogleTest adds an external dependency).

### Components

- **`tests/test_harness.h`** — tiny header with `RUN_TEST`, `ASSERT_TRUE`,
  `ASSERT_EQ_INT`, `ASSERT_EQ_STR`, `ASSERT_EQ_FLOAT` macros that record
  pass/fail counts and print a summary. Exit code non-zero on any failure.
- **`tests/test_main.mm`** — registers and runs all test functions.
- **`tests/test_config.mm`** — config-coercion, validation, and CLI-override tests.
- **`tests/test_helpers.mm`** — `is_pwa` tests.

### Build wiring

A `make test` target compiles the test objects plus only the production objects
they need — `HoistGlobals.o` + `HoistConfig.o` (+ `HoistHelpers.o` for `is_pwa`) —
and links a `hoist_tests` binary. It deliberately excludes `HoistMain.o`
(which owns `main()`) and the GUI objects. Objective-C message sends to
`PreferencesWindowController` inside `saveConfig` resolve dynamically, so the UI
object file is not required to link.

### Testability refactors (small, low-risk, behavior-preserving)

Three seams were extracted so logic is testable without filesystem / GUI:

- `- (void) applyConfigDictionary:(NSDictionary *)json` — the JSON→`parameters`
  coercion loop, pulled out of `readHiddenConfig` (which now calls it).
- `- (void) applyCLIOverrides:(NSDictionary *)arguments` — the CLI-override loop,
  pulled out of `readConfig` (which now calls it with `NSArgumentDomain`). This
  avoids needing to manipulate the read-only `NSArgumentDomain` in tests.
- `+ (NSMutableDictionary *) buildConfigDictionary` — the global-state→config-dict
  serialization, pulled out of `saveConfig` (which now calls it, then writes).
  Lets the serialization branches be tested without writing to disk or needing
  the GUI controller.

Additionally, the `savedDelayCount` global was moved from `HoistUI.mm` to
`HoistGlobals.mm` (where its sibling state globals live) so the config logic
links without pulling in the GUI translation unit.

## Test cases

**Config coercion (`applyConfigDictionary:`)**
- JSON `true`/`false` (NSNumber BOOL) → `"true"`/`"false"`
- JSON integer → its string form
- JSON float → its string form
- JSON array → comma-joined string
- JSON string → passed through
- Keys not in `parametersDictionary` are ignored

**`validateParameters`**
- Empty parameters → all documented defaults applied (`delay=1`, `pollMillis=50`,
  `scale=2.0`, `disableKey=control`, `scaleDuration=600`, `warpX/Y=0.5`, …)
- `pollMillis` below 20 clamped to 50; valid value preserved
- Negative `mouseDelta` clamped to 0
- `scale` below 1 reset to 2.0
- `scaleDuration` below 200 reset to 600
- `warpMouse` true only when warpX/warpY both in (0, 1]

**CLI override (`applyCLIOverrides:`)**
- A CLI-supplied value overrides the existing value for that key
- Keys absent from the CLI arguments are left untouched

**Serialization (`buildConfigDictionary`)**
- `disableKey` int → `"control"` / `"option"` / `"disabled"` mapping
- `delay` falls back to `savedDelayCount` when no active menu delay
- `mouseDelta` omitted when 0, included when > 0
- `verbose` omitted when false

**`is_pwa`**
- Chrome-style PWA id (`com.google.Chrome.app.<hash>`) → true
- Pake id (`com.pake.<x>`) → true
- Regular app id (`com.apple.finder`) → false

## CI

Extend `.github/workflows/ci.yml` to run `make test` after the build, so every PR
to `master` runs the suite on `macos-latest`.

## Success criteria

- `make test` builds and runs headlessly, exits 0 when green, non-zero on failure.
- All listed test cases pass.
- CI runs the suite on every PR.
- `make` / `make all` still build the app unchanged.
