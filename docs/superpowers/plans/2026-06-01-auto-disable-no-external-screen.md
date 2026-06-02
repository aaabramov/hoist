# Auto-disable Without External Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in option that automatically disables Hoist's raise/focus when no external display is connected, and restores it when one is reconnected.

**Architecture:** A new boolean config option `disableWhenNoExternalScreen` drives a reconciliation function `applyScreenAutoDisable()` that mirrors the menu-bar icon toggle (`delayCount`/`savedDelayCount`). External displays are detected via `CGDisplayIsBuiltin`. The function runs at startup and whenever `NSApplicationDidChangeScreenParametersNotification` fires. The option is exposed in the right-click menu and the Preferences window.

**Tech Stack:** Objective-C++ (ARC), AppKit, ApplicationServices, Makefile (`g++`) build.

---

## Testing approach

This project has **no unit-test harness** — it is a Makefile-built macOS app verified by compiling and by manual runtime checks. So the "verify" step for each task is a successful build (`make build`), and end-to-end behavior is checked once in the final manual-verification task.

`make build` does a clean build with the experimental flags (`EXPERIMENTAL_FOCUS_FIRST`, `OLD_ACTIVATION_METHOD`), producing the `Hoist` binary and `Hoist.app`. Building with those flags exercises the `FOCUS_FIRST` code paths and both `parametersDictionary` variants, so it is the right command to catch compile errors across `#ifdef`s.

## File structure

- `Hoist.h` — add extern globals, config-key extern, function prototypes, and the new Preferences property.
- `HoistGlobals.mm` — define the new globals, the config-key constant, and add the key to both `parametersDictionary` arrays.
- `HoistHelpers.mm` — define `hasExternalScreen()` and `applyScreenAutoDisable()` (screen logic lives next to `findScreen`).
- `HoistConfig.mm` — persist the new option in `saveConfig`.
- `HoistMain.mm` — parse the option, print it in the startup summary, and call `applyScreenAutoDisable()` at startup.
- `HoistWatcher.mm` — observe `NSApplicationDidChangeScreenParametersNotification` and react.
- `HoistUI.mm` — menu toggle + Preferences checkbox.
- `README.md` — document the option.

Each task below leaves the build green and is committed independently. Task 1 bundles the cross-cutting core (globals, helpers, parsing, persistence, startup call) because the app links all `.mm` files together — splitting a declaration from its definition across commits would leave an unlinkable intermediate commit.

---

### Task 1: Core — option, detection, apply logic, parsing, persistence, startup

**Files:**
- Modify: `HoistGlobals.mm` (globals + key + `parametersDictionary`)
- Modify: `Hoist.h` (externs + prototypes)
- Modify: `HoistHelpers.mm` (after `findScreen`, line 435)
- Modify: `HoistMain.mm` (parse + print + startup call)
- Modify: `HoistConfig.mm` (`saveConfig`)

- [ ] **Step 1: Define the new globals in `HoistGlobals.mm`**

Find (line 101):

```objc
bool showIcon = true;
```

Replace with:

```objc
bool showIcon = true;
bool disableWhenNoExternalScreen = false;
bool autoDisabledForScreen = false;
```

- [ ] **Step 2: Define the config-key constant in `HoistGlobals.mm`**

Find (line 122):

```objc
const NSString *kShowIcon = @"showIcon";
```

Replace with:

```objc
const NSString *kShowIcon = @"showIcon";
const NSString *kDisableWhenNoExternalScreen = @"disableWhenNoExternalScreen";
```

- [ ] **Step 3: Add the key to both `parametersDictionary` arrays in `HoistGlobals.mm`**

Find the `FOCUS_FIRST` variant:

```objc
NSArray *parametersDictionary = @[kDelay, kWarpX, kWarpY, kScale, kVerbose, kAltTaskSwitcher,
    kFocusDelay, kRequireMouseStop, kIgnoreSpaceChanged, kInvertDisableKey, kInvertIgnoreApps,
    kIgnoreApps, kIgnoreTitles, kStayFocusedBundleIds, kDisableKey, kMouseDelta, kPollMillis,
    kScaleDuration, kShowIcon];
```

Replace with:

```objc
NSArray *parametersDictionary = @[kDelay, kWarpX, kWarpY, kScale, kVerbose, kAltTaskSwitcher,
    kFocusDelay, kRequireMouseStop, kIgnoreSpaceChanged, kInvertDisableKey, kInvertIgnoreApps,
    kIgnoreApps, kIgnoreTitles, kStayFocusedBundleIds, kDisableKey, kMouseDelta, kPollMillis,
    kScaleDuration, kShowIcon, kDisableWhenNoExternalScreen];
```

Then find the non-`FOCUS_FIRST` variant:

```objc
NSArray *parametersDictionary = @[kDelay, kWarpX, kWarpY, kScale, kVerbose, kAltTaskSwitcher,
    kRequireMouseStop, kIgnoreSpaceChanged, kInvertDisableKey, kInvertIgnoreApps, kIgnoreApps,
    kIgnoreTitles, kStayFocusedBundleIds, kDisableKey, kMouseDelta, kPollMillis, kScaleDuration,
    kShowIcon];
```

Replace with:

```objc
NSArray *parametersDictionary = @[kDelay, kWarpX, kWarpY, kScale, kVerbose, kAltTaskSwitcher,
    kRequireMouseStop, kIgnoreSpaceChanged, kInvertDisableKey, kInvertIgnoreApps, kIgnoreApps,
    kIgnoreTitles, kStayFocusedBundleIds, kDisableKey, kMouseDelta, kPollMillis, kScaleDuration,
    kShowIcon, kDisableWhenNoExternalScreen];
```

- [ ] **Step 4: Add extern globals in `Hoist.h`**

Find (line 137):

```objc
extern bool showIcon;
```

Replace with:

```objc
extern bool showIcon;
extern bool disableWhenNoExternalScreen;
extern bool autoDisabledForScreen;
```

- [ ] **Step 5: Add the extern config-key in `Hoist.h`**

Find (line 158):

```objc
extern const NSString *kShowIcon;
```

Replace with:

```objc
extern const NSString *kShowIcon;
extern const NSString *kDisableWhenNoExternalScreen;
```

- [ ] **Step 6: Add function prototypes in `Hoist.h`**

Find (line 241):

```objc
NSScreen * findScreen(CGPoint point);
```

Replace with:

```objc
NSScreen * findScreen(CGPoint point);
bool hasExternalScreen();
void applyScreenAutoDisable();
```

- [ ] **Step 7: Implement `hasExternalScreen()` and `applyScreenAutoDisable()` in `HoistHelpers.mm`**

Find the end of `findScreen` (lines 433-435) followed by `is_desktop_window`:

```objc
    return NULL;
}

bool is_desktop_window(AXUIElementRef _window) {
```

Replace with:

```objc
    return NULL;
}

bool hasExternalScreen() {
    for (NSScreen * screen in [NSScreen screens]) {
        CGDirectDisplayID did =
            (CGDirectDisplayID) [screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
        if (!CGDisplayIsBuiltin(did)) { return true; }
    }
    return false;
}

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
        // No external screen and Hoist is currently enabled -> disable like the icon toggle.
        savedDelayCount = delayCount;
        delayCount = 0;
        autoDisabledForScreen = true;
        if (verbose) { NSLog(@"No external screen: auto-disabling"); }
        if (statusBarController) { [statusBarController updateIconState]; }
    } else if (external && autoDisabledForScreen) {
        // External display reconnected -> restore.
        delayCount = savedDelayCount ? savedDelayCount : 1;
        autoDisabledForScreen = false;
        if (verbose) { NSLog(@"External screen connected: restoring"); }
        if (statusBarController) { [statusBarController updateIconState]; }
    }
}

bool is_desktop_window(AXUIElementRef _window) {
```

- [ ] **Step 8: Parse the option in `HoistMain.mm`**

Find (lines 452-454):

```objc
        if (parameters[kShowIcon]) {
            showIcon = [parameters[kShowIcon] boolValue];
        }
```

Replace with:

```objc
        if (parameters[kShowIcon]) {
            showIcon = [parameters[kShowIcon] boolValue];
        }
        disableWhenNoExternalScreen = [parameters[kDisableWhenNoExternalScreen] boolValue];
```

- [ ] **Step 9: Print the option in the startup summary in `HoistMain.mm`**

Find (line 501):

```objc
        printf("  * invertIgnoreApps: %s\n", invertIgnoreApps ? "true" : "false");
```

Replace with:

```objc
        printf("  * invertIgnoreApps: %s\n", invertIgnoreApps ? "true" : "false");
        printf("  * disableWhenNoExternalScreen: %s\n", disableWhenNoExternalScreen ? "true" : "false");
```

- [ ] **Step 10: Call `applyScreenAutoDisable()` at startup in `HoistMain.mm`**

Find (lines 605-608):

```objc
        if (showIcon) {
            statusBarController = [[StatusBarController alloc] init];
        }
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
```

Replace with:

```objc
        if (showIcon) {
            statusBarController = [[StatusBarController alloc] init];
        }
        applyScreenAutoDisable();
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
```

- [ ] **Step 11: Persist the option in `HoistConfig.mm` `saveConfig`**

Find (line 153):

```objc
    config[@"showIcon"] = @(showIcon);
```

Replace with:

```objc
    config[@"showIcon"] = @(showIcon);
    config[@"disableWhenNoExternalScreen"] = @(disableWhenNoExternalScreen);
```

- [ ] **Step 12: Build to verify it compiles and links**

Run: `make build`
Expected: build completes without errors and produces `Hoist.app` (last lines show the codesign / bundle steps, no `error:` lines).

- [ ] **Step 13: Commit**

```bash
git add Hoist.h HoistGlobals.mm HoistHelpers.mm HoistMain.mm HoistConfig.mm
git commit -m "feat: auto-disable core for no-external-screen option"
```

---

### Task 2: React to display changes (notification observer)

**Files:**
- Modify: `HoistWatcher.mm` (`MDWorkspaceWatcher` init, dealloc, new handler)

- [ ] **Step 1: Register the screen-parameters observer in `init`**

In `HoistWatcher.mm`, find (lines 32-36):

```objc
        [center
            addObserver: self
            selector: @selector(spaceChanged:)
            name: NSWorkspaceActiveSpaceDidChangeNotification
            object: nil];
```

Replace with:

```objc
        [center
            addObserver: self
            selector: @selector(spaceChanged:)
            name: NSWorkspaceActiveSpaceDidChangeNotification
            object: nil];
        [[NSNotificationCenter defaultCenter]
            addObserver: self
            selector: @selector(screenParametersChanged:)
            name: NSApplicationDidChangeScreenParametersNotification
            object: nil];
```

- [ ] **Step 2: Remove the observer in `dealloc`**

Find (lines 61-63):

```objc
- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self];
}
```

Replace with:

```objc
- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}
```

- [ ] **Step 3: Add the handler method**

Find (lines 65-68):

```objc
- (void)spaceChanged:(NSNotification *)notification {
    if (verbose) { NSLog(@"Space changed"); }
    spaceChanged();
}
```

Replace with:

```objc
- (void)spaceChanged:(NSNotification *)notification {
    if (verbose) { NSLog(@"Space changed"); }
    spaceChanged();
}

- (void)screenParametersChanged:(NSNotification *)notification {
    if (verbose) { NSLog(@"Screen parameters changed"); }
    applyScreenAutoDisable();
}
```

- [ ] **Step 4: Build to verify it compiles**

Run: `make build`
Expected: build completes without errors.

- [ ] **Step 5: Commit**

```bash
git add HoistWatcher.mm
git commit -m "feat: react to display config changes for auto-disable"
```

---

### Task 3: Menu toggle

**Files:**
- Modify: `HoistUI.mm` (`menuNeedsUpdate` + new action)

- [ ] **Step 1: Add the menu item after the Alt Task Switcher item**

In `HoistUI.mm`, find (lines 485-489):

```objc
    NSMenuItem *altTsItem = [[NSMenuItem alloc] initWithTitle:@"Alt Task Switcher (e.g. AltTab)"
        action:@selector(toggleAltTaskSwitcher:) keyEquivalent:@""];
    altTsItem.target = self;
    altTsItem.state = altTaskSwitcher ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:altTsItem];
```

Replace with:

```objc
    NSMenuItem *altTsItem = [[NSMenuItem alloc] initWithTitle:@"Alt Task Switcher (e.g. AltTab)"
        action:@selector(toggleAltTaskSwitcher:) keyEquivalent:@""];
    altTsItem.target = self;
    altTsItem.state = altTaskSwitcher ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:altTsItem];

    NSMenuItem *autoDisableScreenItem = [[NSMenuItem alloc] initWithTitle:@"Disable Without External Display"
        action:@selector(toggleDisableWhenNoExternalScreen:) keyEquivalent:@""];
    autoDisableScreenItem.target = self;
    autoDisableScreenItem.state = disableWhenNoExternalScreen ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:autoDisableScreenItem];
```

- [ ] **Step 2: Add the action method after `toggleAltTaskSwitcher:`**

Find (lines 586-589):

```objc
- (void) toggleAltTaskSwitcher:(id)sender {
    altTaskSwitcher = !altTaskSwitcher;
    [self saveConfig];
}
```

Replace with:

```objc
- (void) toggleAltTaskSwitcher:(id)sender {
    altTaskSwitcher = !altTaskSwitcher;
    [self saveConfig];
}

- (void) toggleDisableWhenNoExternalScreen:(id)sender {
    disableWhenNoExternalScreen = !disableWhenNoExternalScreen;
    applyScreenAutoDisable();
    [self saveConfig];
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `make build`
Expected: build completes without errors.

- [ ] **Step 4: Commit**

```bash
git add HoistUI.mm
git commit -m "feat: menu toggle for auto-disable without external display"
```

---

### Task 4: Preferences checkbox

**Files:**
- Modify: `Hoist.h` (`PreferencesWindowController` property)
- Modify: `HoistUI.mm` (`buildPanel`, `showWindow`, new action)

- [ ] **Step 1: Add the checkbox property in `Hoist.h`**

Find (line 208):

```objc
@property (strong, nonatomic) NSButton *showIconCheckbox;
```

Replace with:

```objc
@property (strong, nonatomic) NSButton *showIconCheckbox;
@property (strong, nonatomic) NSButton *autoDisableScreenCheckbox;
```

- [ ] **Step 2: Add the checkbox in `buildPanel`**

In `HoistUI.mm`, find (lines 191-195):

```objc
    // Show Menu Bar Icon checkbox
    _showIconCheckbox = [NSButton checkboxWithTitle:@"Show Menu Bar Icon" target:self
        action:@selector(showIconChanged:)];
    _showIconCheckbox.state = showIcon ? NSControlStateValueOn : NSControlStateValueOff;
    [stack addArrangedSubview:_showIconCheckbox];
```

Replace with:

```objc
    // Show Menu Bar Icon checkbox
    _showIconCheckbox = [NSButton checkboxWithTitle:@"Show Menu Bar Icon" target:self
        action:@selector(showIconChanged:)];
    _showIconCheckbox.state = showIcon ? NSControlStateValueOn : NSControlStateValueOff;
    [stack addArrangedSubview:_showIconCheckbox];

    // Disable Without External Display checkbox
    _autoDisableScreenCheckbox = [NSButton checkboxWithTitle:@"Disable when no external display is connected" target:self
        action:@selector(autoDisableScreenChanged:)];
    _autoDisableScreenCheckbox.state = disableWhenNoExternalScreen ? NSControlStateValueOn : NSControlStateValueOff;
    [stack addArrangedSubview:_autoDisableScreenCheckbox];
```

- [ ] **Step 3: Refresh the checkbox in `showWindow`**

Find (line 256):

```objc
    _showIconCheckbox.state = showIcon ? NSControlStateValueOn : NSControlStateValueOff;
```

Replace with:

```objc
    _showIconCheckbox.state = showIcon ? NSControlStateValueOn : NSControlStateValueOff;
    _autoDisableScreenCheckbox.state = disableWhenNoExternalScreen ? NSControlStateValueOn : NSControlStateValueOff;
```

- [ ] **Step 4: Add the action method after `showIconChanged:`**

Find (lines 337-354):

```objc
- (void)showIconChanged:(NSButton *)sender {
    if (sender.state == NSControlStateValueOff) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Hide Menu Bar Icon?";
        alert.informativeText = @"The menu bar icon will be hidden after restarting Hoist. "
            @"To re-enable it, edit ~/.config/hoist/config.json and set \"showIcon\" to true, then restart the app.";
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"Hide Icon"];
        [alert addButtonWithTitle:@"Cancel"];
        NSModalResponse response = [alert runModal];
        if (response != NSAlertFirstButtonReturn) {
            sender.state = NSControlStateValueOn;
            return;
        }
    }
    showIcon = (sender.state == NSControlStateValueOn);
    [statusBarController saveConfig];
}
```

Replace with (append the new method after it):

```objc
- (void)showIconChanged:(NSButton *)sender {
    if (sender.state == NSControlStateValueOff) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Hide Menu Bar Icon?";
        alert.informativeText = @"The menu bar icon will be hidden after restarting Hoist. "
            @"To re-enable it, edit ~/.config/hoist/config.json and set \"showIcon\" to true, then restart the app.";
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"Hide Icon"];
        [alert addButtonWithTitle:@"Cancel"];
        NSModalResponse response = [alert runModal];
        if (response != NSAlertFirstButtonReturn) {
            sender.state = NSControlStateValueOn;
            return;
        }
    }
    showIcon = (sender.state == NSControlStateValueOn);
    [statusBarController saveConfig];
}

- (void)autoDisableScreenChanged:(NSButton *)sender {
    disableWhenNoExternalScreen = (sender.state == NSControlStateValueOn);
    applyScreenAutoDisable();
    [statusBarController saveConfig];
}
```

- [ ] **Step 5: Build to verify it compiles**

Run: `make build`
Expected: build completes without errors.

- [ ] **Step 6: Commit**

```bash
git add Hoist.h HoistUI.mm
git commit -m "feat: preferences checkbox for auto-disable without external display"
```

---

### Task 5: Document the option in README

**Files:**
- Modify: `README.md` (Behavior table)

- [ ] **Step 1: Add the row to the Behavior table**

Find (line 117):

```
| `altTaskSwitcher` | `false` | Set to `true` if you use a third-party task switcher (e.g., AltTab). |
```

Replace with:

```
| `altTaskSwitcher` | `false` | Set to `true` if you use a third-party task switcher (e.g., AltTab). |
| `disableWhenNoExternalScreen` | `false` | Automatically disable raise/focus when no external display is connected (e.g. laptop on its built-in screen only). Restores when an external display is reconnected. Clamshell mode (lid closed + one external monitor) stays enabled. |
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: document disableWhenNoExternalScreen option"
```

---

### Task 6: Manual verification

No automated tests exist, so verify behavior by hand. Requires a Mac with a detachable external display.

- [ ] **Step 1: Build and run the dev app**

Run: `make run`
Expected: app launches, menu bar icon appears.

- [ ] **Step 2: Enable the option and test detach/attach**

- Right-click the menu bar icon → enable "Disable Without External Display".
- On a 2-display setup, unplug the external display.
- Expected: icon greys out; hovering windows no longer raises them.
- Replug the external display.
- Expected: icon un-greys; hover-to-raise works again.

- [ ] **Step 3: Verify the two UIs stay in sync**

- Open Preferences (right-click → Preferences…). Confirm "Disable when no external display is connected" reflects the menu state.
- Toggle it in Preferences; reopen the menu and confirm the menu item matches.

- [ ] **Step 4: Verify startup-on-single-screen**

- With the option enabled and saved, quit and relaunch on the laptop's built-in display only (`make run`).
- Expected: app starts with the icon greyed and raising disabled.

- [ ] **Step 5: Verify clamshell stays enabled**

- Close the laptop lid while driving a single external monitor.
- Expected: Hoist stays enabled (the one screen is external).

- [ ] **Step 6: Verify manual-off is not force-enabled**

- On a single screen, manually turn Hoist off (left-click the icon).
- Attach then detach an external display.
- Expected: Hoist remains off — it is not auto-enabled on reconnect, because it was off by user choice.

- [ ] **Step 7: Verify config persistence**

Run: `cat ~/.config/hoist/config.json`
Expected: contains `"disableWhenNoExternalScreen": true`, and `"delay"` still holds the user's chosen delay (not `0`) even while auto-disabled.
