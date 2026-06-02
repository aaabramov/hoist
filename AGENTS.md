# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Project Overview

Hoist is a macOS utility that automatically raises and focuses windows on mouse hover. It's an Objective-C++ project split across multiple files with a Makefile build system. The .app bundle includes a menu bar status icon for runtime configuration and a preferences window.

## Build Commands

```bash
make            # Build both CLI binary and .app bundle (default target: all)
make test       # Build and run the headless unit-test suite (tests/)
make clean      # Remove binaries, object files, and .app directories
make install    # Install Hoist.app to /Applications
make build      # Clean build with experimental flags (EXPERIMENTAL_FOCUS_FIRST, OLD_ACTIVATION_METHOD)
make dev        # Clean build of HoistDev.app with experimental flags (separate bundle ID for parallel dev testing)
make run        # Dev build and execute
make debug      # Dev build with verbose logging and execute
make update     # Build and install to /Applications
```

Compiler: `g++` with `-fobjc-arc -O2`. Requires Xcode Command Line Tools.

## Architecture

The codebase is split into these files, all sharing `Hoist.h`:

- **`Hoist.h`** — Shared header: includes, constants, `extern` globals, `@interface` blocks, function prototypes
- **`HoistGlobals.mm`** — Global variable definitions, config key constants, `parametersDictionary`/`parameters`
- **`HoistHelpers.mm`** — Window detection (`get_mousewindow`, `get_raisable_window`, `topwindow`, `fallback`), activation (`activate`, `raiseAndActivate`), mouse warping (`get_mousepoint`), environment checks (`dock_active`, `mc_active`, `findScreen`), yabai focus methods
- **`HoistWatcher.mm`** — `MDWorkspaceWatcher`: space changes, app activation, cursor scaling, polling timer
- **`HoistConfig.mm`** — `ConfigClass`: CLI args and JSON config file parsing (`~/.config/hoist/config.json`)
- **`HoistUI.mm`** — `PreferencesWindowController` + `StatusBarController`: menu bar icon, context menu, preferences panel, live config persistence
- **`HoistMain.mm`** — `spaceChanged()`, `appActivated()`, `onTick()` polling loop, `eventTapHandler()`, `main()`
- **`tests/`** — Headless unit tests (`make test`). A dependency-free assertion harness (`test_harness.h` + `test_main.mm`) plus `test_config.mm` (config parsing/validation/CLI overrides/serialization), `test_helpers.mm` (`is_pwa`), and `test_screen.mm` (the no-external-screen auto-disable/re-enable state machine). `test_stubs.mm` supplies link stubs for GUI/main symbols so only pure-logic translation units (`HoistGlobals`, `HoistConfig`, `HoistHelpers`) are linked — no GUI session, Accessibility permission, or private frameworks required. Window/screen/event-tap logic depends on a live GUI and is out of unit-test scope.

## Key Compilation Flags

- `EXPERIMENTAL_FOCUS_FIRST` — Enables focus-without-raise via private SkyLight API
- `OLD_ACTIVATION_METHOD` — Uses deprecated ProcessSerialNumber API for problematic apps
- `ALTERNATIVE_TASK_SWITCHER` — Compatibility for third-party task switchers (e.g., AltTab)

## macOS Frameworks

AppKit, ApplicationServices, CoreFoundation, Carbon (legacy), SkyLight (optional private framework auto-detected at build time).

## Key Design Patterns

- **Polling loop**: Timer fires every `pollMillis` ms, checks mouse position against windows
- **Event tap**: Global CGEventTap monitors modifier keys and cmd-tab for disable/task-switch detection
- **Fallback chain**: Multiple window detection methods (`get_mousewindow` → `fallback`) for reliability across apps
- **Hard-coded app quirk lists**: Special handling for apps like Finder desktop, IntelliJ (raises on focus), PWAs (Chrome/Brave), and apps without window titles (System Settings, Calculator)
- **Menu bar status icon**: Left-click toggles raise on/off, right-click shows context menu. App runs as accessory (`NSApplicationActivationPolicyAccessory`)
- **Live config persistence**: Changes made via menu/preferences are saved immediately to `~/.config/hoist/config.json` (JSON format)
- **Config layering**: Config file is always read first as base; CLI arguments override file values
