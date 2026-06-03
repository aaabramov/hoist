/*
 * Hoist - Copyright (C) 2026 aaabramov
 * Some pieces of the code are based on
 * https://github.com/sbmpost/AutoRaise by sbmpost
 * metamove by jmgao as part of XFree86
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include "Hoist.h"

//------------------------------------------status bar controller--------------------------------------------

StatusBarController *statusBarController = nil;

//---------------------------------------preferences window controller---------------------------------------

@implementation PreferencesWindowController

+ (instancetype)shared {
    static PreferencesWindowController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PreferencesWindowController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self buildPanel];
    }
    return self;
}

- (void)buildPanel {
    _panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 420, 600)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
        backing:NSBackingStoreBuffered defer:YES];
    _panel.title = @"Hoist Preferences";
    _panel.level = NSFloatingWindowLevel;
    _panel.hidesOnDeactivate = NO;
    [_panel center];

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSMakeRect(20, 20, 380, 560)];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 12;

    // Delay row
    [stack addArrangedSubview:[self labelWithString:@"Delay:"]];
    NSStackView *delayRow = [[NSStackView alloc] init];
    delayRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    delayRow.spacing = 8;
    _delaySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
    _delaySlider.minValue = 0;
    _delaySlider.maxValue = 10;
    _delaySlider.intValue = delayCount;
    _delaySlider.numberOfTickMarks = 11;
    _delaySlider.allowsTickMarkValuesOnly = YES;
    _delaySlider.target = self;
    _delaySlider.action = @selector(delaySliderChanged:);
    _delayLabel = [self valueLabelWithString:[self delayString]];
    [delayRow addArrangedSubview:_delaySlider];
    [delayRow addArrangedSubview:_delayLabel];
    [stack addArrangedSubview:delayRow];

    // Scale Duration row
    [stack addArrangedSubview:[self labelWithString:@"Scale Duration:"]];
    NSStackView *sdRow = [[NSStackView alloc] init];
    sdRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    sdRow.spacing = 8;
    _scaleDurationSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
    _scaleDurationSlider.minValue = 200;
    _scaleDurationSlider.maxValue = 2000;
    _scaleDurationSlider.intValue = scaleDurationMs;
    _scaleDurationSlider.numberOfTickMarks = 19;
    _scaleDurationSlider.allowsTickMarkValuesOnly = YES;
    _scaleDurationSlider.target = self;
    _scaleDurationSlider.action = @selector(scaleDurationSliderChanged:);
    _scaleDurationLabel = [self valueLabelWithString:[NSString stringWithFormat:@"%dms", scaleDurationMs]];
    [sdRow addArrangedSubview:_scaleDurationSlider];
    [sdRow addArrangedSubview:_scaleDurationLabel];
    [stack addArrangedSubview:sdRow];

    // Warp X row
    [stack addArrangedSubview:[self labelWithString:@"Warp X:"]];
    NSStackView *wxRow = [[NSStackView alloc] init];
    wxRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    wxRow.spacing = 8;
    _warpXSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
    _warpXSlider.minValue = 0;
    _warpXSlider.maxValue = 1.0;
    _warpXSlider.floatValue = warpX;
    _warpXSlider.numberOfTickMarks = 5;
    _warpXSlider.target = self;
    _warpXSlider.action = @selector(warpXSliderChanged:);
    _warpXLabel = [self valueLabelWithString:[NSString stringWithFormat:@"%.2f", warpX]];
    [wxRow addArrangedSubview:_warpXSlider];
    [wxRow addArrangedSubview:_warpXLabel];
    [stack addArrangedSubview:wxRow];

    // Warp Y row
    [stack addArrangedSubview:[self labelWithString:@"Warp Y:"]];
    NSStackView *wyRow = [[NSStackView alloc] init];
    wyRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    wyRow.spacing = 8;
    _warpYSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
    _warpYSlider.minValue = 0;
    _warpYSlider.maxValue = 1.0;
    _warpYSlider.floatValue = warpY;
    _warpYSlider.numberOfTickMarks = 5;
    _warpYSlider.target = self;
    _warpYSlider.action = @selector(warpYSliderChanged:);
    _warpYLabel = [self valueLabelWithString:[NSString stringWithFormat:@"%.2f", warpY]];
    [wyRow addArrangedSubview:_warpYSlider];
    [wyRow addArrangedSubview:_warpYLabel];
    [stack addArrangedSubview:wyRow];

    // Disable Key row
    [stack addArrangedSubview:[self labelWithString:@"Disable Key:"]];
    _disableKeyPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 24) pullsDown:NO];
    [_disableKeyPopUp addItemsWithTitles:@[@"Control", @"Option", @"Disabled"]];
    if (disableKey == (int)kCGEventFlagMaskControl) { [_disableKeyPopUp selectItemAtIndex:0]; }
    else if (disableKey == (int)kCGEventFlagMaskAlternate) { [_disableKeyPopUp selectItemAtIndex:1]; }
    else { [_disableKeyPopUp selectItemAtIndex:2]; }
    _disableKeyPopUp.target = self;
    _disableKeyPopUp.action = @selector(disableKeyChanged:);
    [stack addArrangedSubview:_disableKeyPopUp];

    // Ignore Apps row
    [stack addArrangedSubview:[self labelWithString:@"Ignore Apps (comma-separated):"]];
    _ignoreAppsField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 360, 24)];
    _ignoreAppsField.stringValue = [self ignoreAppsString] ?: @"";
    _ignoreAppsField.delegate = self;
    [stack addArrangedSubview:_ignoreAppsField];

    // Ignore Titles row
    [stack addArrangedSubview:[self labelWithString:@"Ignore Titles (comma-separated regex):"]];
    _ignoreTitlesField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 360, 24)];
    _ignoreTitlesField.stringValue = [ignoreTitles componentsJoinedByString:@","] ?: @"";
    _ignoreTitlesField.delegate = self;
    [stack addArrangedSubview:_ignoreTitlesField];

    // Poll Interval row
    [stack addArrangedSubview:[self labelWithString:@"Poll Interval:"]];
    NSTextField *pollHint = [NSTextField wrappingLabelWithString:@"How often to check mouse position. Lower = more responsive, higher CPU."];
    pollHint.font = [NSFont systemFontOfSize:11];
    pollHint.textColor = [NSColor secondaryLabelColor];
    pollHint.preferredMaxLayoutWidth = 380;
    [stack addArrangedSubview:pollHint];
    NSStackView *pollRow = [[NSStackView alloc] init];
    pollRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    pollRow.spacing = 8;
    _pollMillisSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
    _pollMillisSlider.minValue = 20;
    _pollMillisSlider.maxValue = 200;
    _pollMillisSlider.intValue = pollMillis;
    _pollMillisSlider.numberOfTickMarks = 19;
    _pollMillisSlider.allowsTickMarkValuesOnly = YES;
    _pollMillisSlider.target = self;
    _pollMillisSlider.action = @selector(pollMillisSliderChanged:);
    _pollMillisLabel = [self valueLabelWithString:[NSString stringWithFormat:@"%dms", pollMillis]];
    [pollRow addArrangedSubview:_pollMillisSlider];
    [pollRow addArrangedSubview:_pollMillisLabel];
    [stack addArrangedSubview:pollRow];

    // Launch at Login row
    if (@available(macOS 13.0, *)) {
        _launchAtLoginCheckbox = [NSButton checkboxWithTitle:@"Launch at Login" target:self
            action:@selector(launchAtLoginChanged:)];
        SMAppService *service = [SMAppService mainAppService];
        _launchAtLoginCheckbox.state = (service.status == SMAppServiceStatusEnabled) ? NSControlStateValueOn : NSControlStateValueOff;
        [stack addArrangedSubview:_launchAtLoginCheckbox];
    }

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

    // Open Config Folder button
    NSButton *openConfigButton = [NSButton buttonWithTitle:@"Open Config Folder" target:self
        action:@selector(openConfigFolder:)];
    [stack addArrangedSubview:openConfigButton];

    [_panel.contentView addSubview:stack];
}

- (NSTextField *)labelWithString:(NSString *)string {
    NSTextField *label = [NSTextField labelWithString:string];
    label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    return label;
}

- (NSTextField *)valueLabelWithString:(NSString *)string {
    NSTextField *label = [NSTextField labelWithString:string];
    label.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
    [label setContentHuggingPriority:999 forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

- (NSString *)delayString {
    if (menuDelayCount == 0) { return @"Disabled"; }
    if (menuDelayCount == 1) { return @"No delay"; }
    return [NSString stringWithFormat:@"%dms", (menuDelayCount - 1) * pollMillis];
}

- (NSString *)ignoreAppsString {
    NSMutableArray *filtered = [[NSMutableArray alloc] init];
    for (NSString *app in ignoreApps) {
        if (![app isEqualToString:AssistiveControl]) {
            [filtered addObject:app];
        }
    }
    return [filtered componentsJoinedByString:@","];
}

- (void)showWindow {
    // Refresh values before showing
    _pollMillisSlider.intValue = pollMillis;
    _pollMillisLabel.stringValue = [NSString stringWithFormat:@"%dms", pollMillis];
    _delaySlider.intValue = menuDelayCount;
    _delayLabel.stringValue = [self delayString];
    _scaleDurationSlider.intValue = scaleDurationMs;
    _scaleDurationLabel.stringValue = [NSString stringWithFormat:@"%dms", scaleDurationMs];
    _warpXSlider.floatValue = warpX;
    _warpXLabel.stringValue = [NSString stringWithFormat:@"%.2f", warpX];
    _warpYSlider.floatValue = warpY;
    _warpYLabel.stringValue = [NSString stringWithFormat:@"%.2f", warpY];
    if (disableKey == (int)kCGEventFlagMaskControl) { [_disableKeyPopUp selectItemAtIndex:0]; }
    else if (disableKey == (int)kCGEventFlagMaskAlternate) { [_disableKeyPopUp selectItemAtIndex:1]; }
    else { [_disableKeyPopUp selectItemAtIndex:2]; }
    _ignoreAppsField.stringValue = [self ignoreAppsString] ?: @"";
    _ignoreTitlesField.stringValue = [ignoreTitles componentsJoinedByString:@","] ?: @"";
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        _launchAtLoginCheckbox.state = (service.status == SMAppServiceStatusEnabled) ? NSControlStateValueOn : NSControlStateValueOff;
    }

    _showIconCheckbox.state = showIcon ? NSControlStateValueOn : NSControlStateValueOff;
    _autoDisableScreenCheckbox.state = disableWhenNoExternalScreen ? NSControlStateValueOn : NSControlStateValueOff;

    [NSApp activateIgnoringOtherApps:YES];
    [_panel makeKeyAndOrderFront:nil];
}

// Actions

- (void)pollMillisSliderChanged:(NSSlider *)sender {
    // Round to nearest 10
    int raw = sender.intValue;
    pollMillis = ((raw + 5) / 10) * 10;
    if (pollMillis < 20) { pollMillis = 20; }
    sender.intValue = pollMillis;
    _pollMillisLabel.stringValue = [NSString stringWithFormat:@"%dms", pollMillis];
    _delayLabel.stringValue = [self delayString];
    [statusBarController saveConfig];
}

- (void)delaySliderChanged:(NSSlider *)sender {
    menuDelayCount = sender.intValue;
    if (menuDelayCount) { savedDelayCount = menuDelayCount; }
    _delayLabel.stringValue = [self delayString];
    [statusBarController updateIconState];
    [statusBarController saveConfig];
}

- (void)scaleDurationSliderChanged:(NSSlider *)sender {
    // Round to nearest 100
    int raw = sender.intValue;
    scaleDurationMs = ((raw + 50) / 100) * 100;
    sender.intValue = scaleDurationMs;
    _scaleDurationLabel.stringValue = [NSString stringWithFormat:@"%dms", scaleDurationMs];
    [statusBarController saveConfig];
}

- (void)warpXSliderChanged:(NSSlider *)sender {
    warpX = sender.floatValue;
    _warpXLabel.stringValue = [NSString stringWithFormat:@"%.2f", warpX];
    warpMouse = (warpX > 0 && warpY > 0);
    [workspaceWatcher updateWarpObserver];
    [statusBarController saveConfig];
}

- (void)warpYSliderChanged:(NSSlider *)sender {
    warpY = sender.floatValue;
    _warpYLabel.stringValue = [NSString stringWithFormat:@"%.2f", warpY];
    warpMouse = (warpX > 0 && warpY > 0);
    [workspaceWatcher updateWarpObserver];
    [statusBarController saveConfig];
}

- (void)disableKeyChanged:(NSPopUpButton *)sender {
    NSInteger idx = sender.indexOfSelectedItem;
    if (idx == 0) { disableKey = (int)kCGEventFlagMaskControl; }
    else if (idx == 1) { disableKey = (int)kCGEventFlagMaskAlternate; }
    else { disableKey = 0; }
    [statusBarController saveConfig];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *field = notification.object;
    if (field == _ignoreAppsField) {
        NSMutableArray *arr;
        if (field.stringValue.length) {
            arr = [[NSMutableArray alloc] initWithArray:[field.stringValue componentsSeparatedByString:@","]];
        } else {
            arr = [[NSMutableArray alloc] init];
        }
        [arr addObject:AssistiveControl];
        ignoreApps = [arr copy];
    } else if (field == _ignoreTitlesField) {
        if (field.stringValue.length) {
            ignoreTitles = [field.stringValue componentsSeparatedByString:@","];
        } else {
            ignoreTitles = @[];
        }
    }
    [statusBarController saveConfig];
}

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

- (void)openConfigFolder:(NSButton *)sender {
    NSString *configDir = [@"~/.config/hoist" stringByExpandingTildeInPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:configDir withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:configDir isDirectory:YES]];
}

- (void)launchAtLoginChanged:(NSButton *)sender API_AVAILABLE(macos(13.0)) {
    SMAppService *service = [SMAppService mainAppService];
    NSError *error = nil;
    if (sender.state == NSControlStateValueOn) {
        [service registerAndReturnError:&error];
    } else {
        [service unregisterAndReturnError:&error];
    }
    if (error) {
        NSLog(@"Launch at Login error: %@", error.localizedDescription);
        // Revert checkbox state on failure
        sender.state = (service.status == SMAppServiceStatusEnabled) ? NSControlStateValueOn : NSControlStateValueOff;
    }
}

@end // PreferencesWindowController

//--------------------------------------status bar controller impl-------------------------------------------

@implementation StatusBarController {
    NSTimer *_accessibilityTimer;
}

- (instancetype) init {
    self = [super init];
    if (self) {
        savedDelayCount = delayCount;
        _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        if (@available(macOS 11.0, *)) {
            _statusItem.button.image = [NSImage imageWithSystemSymbolName:@"cursorarrow.rays"
                accessibilityDescription:@"Hoist"];
        } else {
            _statusItem.button.title = @"AR";
        }
        _statusItem.button.toolTip = @"Hoist";
        [self buildMenu];
        [self updateIconState];

        // Poll Accessibility trust so the icon/menu can warn when permission is
        // missing, and auto-recover (within ~2s) once the user grants it.
        [self refreshAccessibilityState];
        _accessibilityTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
            target:self selector:@selector(refreshAccessibilityState) userInfo:nil repeats:YES];

        // Left click = toggle, right click = menu
        _statusItem.button.action = @selector(statusItemClicked:);
        _statusItem.button.target = self;
        [_statusItem.button sendActionOn:(NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp)];
    }
    return self;
}

- (void) statusItemClicked:(id)sender {
    NSEvent *event = [NSApp currentEvent];
    if (event.type == NSEventTypeRightMouseUp) {
        [self menuNeedsUpdate:_menu];
        _statusItem.menu = _menu;
        [_statusItem.button performClick:nil];
    } else {
        [self toggleEnabled:sender];
    }
}

- (void) menuDidClose:(NSMenu *)menu {
    _statusItem.menu = nil;
}

- (void) buildMenu {
    _menu = [[NSMenu alloc] init];
    _menu.delegate = self;
    _menu.autoenablesItems = NO;
}

- (void) menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];

    // Accessibility warning (only when untrusted). Surfaces the failure that
    // the OS prompt hides after an upgrade invalidates a stale TCC grant.
    if (!accessibilityTrusted) {
        NSMenuItem *warnItem = [[NSMenuItem alloc] initWithTitle:@"⚠ Accessibility permission needed"
            action:nil keyEquivalent:@""];
        warnItem.enabled = NO;
        [menu addItem:warnItem];

        NSMenuItem *fixItem = [[NSMenuItem alloc] initWithTitle:@"Fix Accessibility..."
            action:@selector(openAccessibilitySettings:) keyEquivalent:@""];
        fixItem.target = self;
        [menu addItem:fixItem];

        [menu addItem:[NSMenuItem separatorItem]];
    }

    // Delay submenu
    NSMenu *delayMenu = [[NSMenu alloc] init];
    int currentDelay = menuDelayCount ? menuDelayCount : savedDelayCount;
    for (int i = 0; i <= 10; i++) {
        NSString *title;
        if (i == 0) { title = @"Disabled"; }
        else if (i == 1) { title = @"No delay"; }
        else { title = [NSString stringWithFormat:@"%dms", (i-1)*pollMillis]; }
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setDelay:) keyEquivalent:@""];
        item.tag = i;
        item.target = self;
        item.state = (i == currentDelay) ? NSControlStateValueOn : NSControlStateValueOff;
        [delayMenu addItem:item];
    }
    NSMenuItem *delayItem = [[NSMenuItem alloc] initWithTitle:@"Delay" action:nil keyEquivalent:@""];
    delayItem.submenu = delayMenu;
    [menu addItem:delayItem];

    // Warp toggle
    NSMenuItem *warpItem = [[NSMenuItem alloc] initWithTitle:@"Warp"
        action:@selector(toggleWarp:) keyEquivalent:@""];
    warpItem.target = self;
    warpItem.state = warpMouse ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:warpItem];

    // Scale submenu
    NSMenu *scaleMenu = [[NSMenu alloc] init];
    float scaleValues[] = {1.0, 1.5, 2.0, 3.0};
    for (int i = 0; i < 4; i++) {
        NSString *title = [NSString stringWithFormat:@"%.1f", scaleValues[i]];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setScale:) keyEquivalent:@""];
        item.tag = (NSInteger)(scaleValues[i] * 10);
        item.target = self;
        item.state = (fabsf(cursorScale - scaleValues[i]) < 0.01) ? NSControlStateValueOn : NSControlStateValueOff;
        [scaleMenu addItem:item];
    }
    NSMenuItem *scaleItem = [[NSMenuItem alloc] initWithTitle:@"Scale" action:nil keyEquivalent:@""];
    scaleItem.submenu = scaleMenu;
    [menu addItem:scaleItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // Boolean toggles
    NSMenuItem *mouseStopItem = [[NSMenuItem alloc] initWithTitle:@"Require Mouse Stop"
        action:@selector(toggleRequireMouseStop:) keyEquivalent:@""];
    mouseStopItem.target = self;
    mouseStopItem.state = requireMouseStop ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:mouseStopItem];

    NSMenuItem *spaceItem = [[NSMenuItem alloc] initWithTitle:@"Ignore Space Changed"
        action:@selector(toggleIgnoreSpaceChanged:) keyEquivalent:@""];
    spaceItem.target = self;
    spaceItem.state = ignoreSpaceChanged ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:spaceItem];

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

    // Launch at Login
    if (@available(macOS 13.0, *)) {
        NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:@"Launch at Login"
            action:@selector(toggleLaunchAtLogin:) keyEquivalent:@""];
        loginItem.target = self;
        SMAppService *service = [SMAppService mainAppService];
        loginItem.state = (service.status == SMAppServiceStatusEnabled) ? NSControlStateValueOn : NSControlStateValueOff;
        [menu addItem:loginItem];
    }

    [menu addItem:[NSMenuItem separatorItem]];

    // Preferences
    NSMenuItem *prefsItem = [[NSMenuItem alloc] initWithTitle:@"Preferences..."
        action:@selector(showPreferences:) keyEquivalent:@","];
    prefsItem.target = self;
    [menu addItem:prefsItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
        action:@selector(quit:) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
}

- (void) updateIconState {
    // Missing Accessibility permission takes visual priority: nothing works
    // without it, so warn regardless of the enabled/disabled state.
    if (!accessibilityTrusted) {
        if (@available(macOS 11.0, *)) {
            NSImage *img = [NSImage imageWithSystemSymbolName:@"exclamationmark.triangle.fill"
                accessibilityDescription:@"Hoist needs Accessibility permission"];
            NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
                configurationWithPaletteColors:@[[NSColor systemYellowColor]]];
            _statusItem.button.image = [img imageWithSymbolConfiguration:config];
        } else {
            _statusItem.button.title = @"⚠";
        }
        _statusItem.button.toolTip = @"Hoist — Accessibility permission needed";
        return;
    }

    if (@available(macOS 11.0, *)) {
        NSImage *img = [NSImage imageWithSystemSymbolName:@"cursorarrow.rays"
            accessibilityDescription:@"Hoist"];
        if (!delayCount) {
            NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
                configurationWithPaletteColors:@[[NSColor tertiaryLabelColor]]];
            img = [img imageWithSymbolConfiguration:config];
        }
        _statusItem.button.image = img;
    } else {
        _statusItem.button.title = delayCount ? @"AR" : @"ar";
    }
    _statusItem.button.toolTip = @"Hoist";
}

// Query AX trust (no prompt) and refresh the indicator only on change.
- (void) refreshAccessibilityState {
    bool trusted = AXIsProcessTrusted();
    if (trusted != accessibilityTrusted) {
        accessibilityTrusted = trusted;
        [self updateIconState];
    }
}

// Actions

- (void) toggleEnabled:(id)sender {
    if (delayCount) {
        savedDelayCount = delayCount;
        delayCount = 0;
    } else {
        delayCount = savedDelayCount ? savedDelayCount : 1;
    }
    // Manual toggle takes over: surrender auto-disable ownership so a later
    // display reconnect won't override the user's explicit choice.
    autoDisabledForScreen = false;
    [self updateIconState];
    [self saveConfig];
}

- (void) setDelay:(NSMenuItem *)sender {
    menuDelayCount = (int)sender.tag;
    if (menuDelayCount) { savedDelayCount = menuDelayCount; }
    [self updateIconState];
    [self saveConfig];
}

- (void) toggleWarp:(id)sender {
    if (warpMouse) {
        warpX = 0;
        warpY = 0;
        warpMouse = false;
    } else {
        warpX = 0.5;
        warpY = 0.5;
        warpMouse = true;
    }
    [workspaceWatcher updateWarpObserver];
    [self saveConfig];
}

- (void) setScale:(NSMenuItem *)sender {
    cursorScale = sender.tag / 10.0;
    [self saveConfig];
}

- (void) showPreferences:(id)sender {
    [[PreferencesWindowController shared] showWindow];
}

- (void) openAccessibilitySettings:(id)sender {
    NSURL *url = [NSURL URLWithString:
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void) toggleRequireMouseStop:(id)sender {
    requireMouseStop = !requireMouseStop;
    [self saveConfig];
}

- (void) toggleIgnoreSpaceChanged:(id)sender {
    ignoreSpaceChanged = !ignoreSpaceChanged;
    [self saveConfig];
}

- (void) toggleAltTaskSwitcher:(id)sender {
    altTaskSwitcher = !altTaskSwitcher;
    [self saveConfig];
}

- (void) toggleDisableWhenNoExternalScreen:(id)sender {
    disableWhenNoExternalScreen = !disableWhenNoExternalScreen;
    applyScreenAutoDisable(); // applies immediate effect and updates the icon if needed
    [self saveConfig];
}

- (void) toggleLaunchAtLogin:(id)sender API_AVAILABLE(macos(13.0)) {
    SMAppService *service = [SMAppService mainAppService];
    NSError *error = nil;
    if (service.status == SMAppServiceStatusEnabled) {
        [service unregisterAndReturnError:&error];
    } else {
        [service registerAndReturnError:&error];
    }
    if (error) {
        NSLog(@"Launch at Login error: %@", error.localizedDescription);
    }
}

- (void) quit:(id)sender {
    [[NSApplication sharedApplication] terminate:nil];
}

- (void) saveConfig {
    [ConfigClass saveConfig];
}

@end // StatusBarController
