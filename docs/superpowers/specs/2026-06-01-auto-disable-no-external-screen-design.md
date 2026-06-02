# Auto-disable Hoist without an external display

**Date:** 2026-06-01
**Status:** Approved

## Problem

Hoist's raise-on-hover behavior is most useful with multiple/large screens. On a
laptop's built-in display alone, automatically raising windows on hover is often
unwanted. Users want Hoist to disable itself automatically when no external display
is attached, and re-enable when one is reconnected — without manually toggling the
menu bar icon each time.

## Goals

- Add an opt-in config option that disables Hoist's raise/focus behavior when no
  external display is connected, and restores it when one is reconnected.
- The disabled effect must match clicking the menu bar icon: raise/focus stops and
  the icon greys out. Cursor warp and cursor scaling are unaffected (consistent with
  the manual toggle).
- Correctly handle clamshell mode (laptop lid closed, driving a single external
  monitor): that one screen is external, so Hoist stays enabled.
- Expose the option via both the right-click menu and the Preferences window.
- Default off — no behavior change for existing users.

## Non-goals

- Per-display configuration (e.g. enable only on specific monitors).
- Disabling warp / cursor scaling based on screen count.
- Any test harness (the project has none; verification is manual).

## Design

### Config option

New key `disableWhenNoExternalScreen` (bool, default `false`), wired through the
existing config pipeline exactly like other boolean options:

- `HoistGlobals.mm`: add `bool disableWhenNoExternalScreen = false;`, the
  `kDisableWhenNoExternalScreen` key constant, and include it in both
  `parametersDictionary` arrays (the `FOCUS_FIRST` and non-`FOCUS_FIRST` variants).
- `Hoist.h`: matching `extern` declarations.
- `HoistMain.mm` `main()`: parse with
  `disableWhenNoExternalScreen = [parameters[kDisableWhenNoExternalScreen] boolValue];`
  and print it in the startup summary alongside the other behavior flags.
- `HoistConfig.mm` `saveConfig`: persist with
  `config[@"disableWhenNoExternalScreen"] = @(disableWhenNoExternalScreen);`.

### External-display detection (`HoistHelpers.mm`)

```objc
bool hasExternalScreen() {
    for (NSScreen *screen in [NSScreen screens]) {
        CGDirectDisplayID did =
            (CGDirectDisplayID)[screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
        if (!CGDisplayIsBuiltin(did)) { return true; }
    }
    return false;
}
```

Returns `true` if any connected display is external. Clamshell (external-only) → `true`.

### Apply logic (`applyScreenAutoDisable()`, `HoistHelpers.mm`)

A single reconciliation function reusing the icon-toggle semantics
(`delayCount` / `savedDelayCount`). A runtime flag
`bool autoDisabledForScreen = false;` (global) records whether the current
disabled state was applied automatically.

```objc
void applyScreenAutoDisable() {
    if (!disableWhenNoExternalScreen) {
        // Option off: undo any auto-disable we previously applied.
        if (autoDisabledForScreen) {
            delayCount = savedDelayCount ? savedDelayCount : 1;
            autoDisabledForScreen = false;
            if (statusBarController) { [statusBarController updateIconState]; }
        }
        return;
    }

    bool external = hasExternalScreen();
    if (!external && !autoDisabledForScreen && delayCount) {
        // No external screen and Hoist is currently enabled → disable like the icon toggle.
        savedDelayCount = delayCount;
        delayCount = 0;
        autoDisabledForScreen = true;
        if (statusBarController) { [statusBarController updateIconState]; }
    } else if (external && autoDisabledForScreen) {
        // External reconnected → restore.
        delayCount = savedDelayCount ? savedDelayCount : 1;
        autoDisabledForScreen = false;
        if (statusBarController) { [statusBarController updateIconState]; }
    }
}
```

Key decisions encoded here:

- The `&& delayCount` guard means an already-manually-disabled Hoist is **not**
  force-enabled when an external screen reconnects — we only restore what we
  ourselves turned off.
- `statusBarController` may be `nil` when `showIcon` is false, so icon updates are
  guarded.
- The function never calls `saveConfig`: auto-disable is transient screen-derived
  state, not a saved preference. Because `saveConfig` derives the persisted `delay`
  from `savedDelayCount` whenever `delayCount == 0`, the user's chosen delay in
  `config.json` is preserved while auto-disabled.

### Triggering

- **Startup:** call `applyScreenAutoDisable()` once near the end of `main()`, after
  the `StatusBarController` is created, so launching on a lone screen starts disabled
  (and the icon reflects it).
- **Display change:** `MDWorkspaceWatcher` observes
  `NSApplicationDidChangeScreenParametersNotification` on
  `[NSNotificationCenter defaultCenter]` (not the workspace notification center) and
  calls `applyScreenAutoDisable()`. The observer is removed in `dealloc`.

### UI

- **Menu** (`HoistUI.mm` `menuNeedsUpdate`): add a "Disable Without External Display"
  checkbox item near the other boolean toggles. Handler
  `toggleDisableWhenNoExternalScreen:` flips the option, calls
  `applyScreenAutoDisable()` for immediate effect, then `saveConfig`.
- **Preferences** (`HoistUI.mm` `buildPanel` + `showWindow`): add a matching checkbox
  with a new `autoDisableScreenCheckbox` property on `PreferencesWindowController`
  (declared in `Hoist.h`). Handler `autoDisableScreenChanged:` mirrors the menu
  handler.

### Prototypes (`Hoist.h`)

- `bool hasExternalScreen();`
- `void applyScreenAutoDisable();`
- `extern bool disableWhenNoExternalScreen;`
- `extern bool autoDisabledForScreen;`
- `extern const NSString *kDisableWhenNoExternalScreen;`
- `@property (strong, nonatomic) NSButton *autoDisableScreenCheckbox;` on
  `PreferencesWindowController`.

## Edge cases

- **Already off, then unplug:** `&& delayCount` guard skips it; on replug Hoist is not
  force-enabled.
- **Manual toggle while auto-disabled:** the menu-bar icon toggle (`toggleEnabled:`)
  clears `autoDisabledForScreen`, so a manual click surrenders auto-ownership — a later
  display reconnect will not override the user's explicit choice. (Changing the delay via
  the Delay submenu/slider does not clear the flag; that path keeps the best-effort
  behavior, which is acceptable for the "same as the icon" model.)
- **`showIcon` false:** icon updates are guarded; the disable/enable still takes effect.
- **Clamshell:** single external display → `hasExternalScreen()` returns true → enabled.

## Testing (manual)

1. `make build`; run on a 2-display setup, unplug external → icon greys, hover stops
   raising; replug → restores.
2. Toggle the option via the menu and via Preferences while on a single screen →
   disables/enables immediately and the two UIs stay in sync.
3. Launch with the option on while on laptop-only → starts disabled.
4. Clamshell: lid closed + single external → stays enabled.
5. Manually disable, then unplug, then replug → stays off (not force-enabled).

## Documentation

Add `disableWhenNoExternalScreen` to the **Behavior** table in `README.md`.
