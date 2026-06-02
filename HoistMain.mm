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

//------------------------------------------where it all happens--------------------------------------------

void spaceChanged() {
    spaceHasChanged = true;
    oldPoint.x = oldPoint.y = 0;
}

bool appActivated() {
    if (verbose) { NSLog(@"App activated"); }
    if (!altTaskSwitcher) {
        if (!activated_by_task_switcher) { return false; }
        activated_by_task_switcher = false;
    }
    appWasActivated = true;

    NSRunningApplication *frontmostApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    pid_t frontmost_pid = frontmostApp.processIdentifier;

    AXUIElementRef _activatedWindow = NULL;
    AXUIElementRef _frontmostApp = AXUIElementCreateApplication(frontmost_pid);
    AXUIElementCopyAttributeValue(_frontmostApp,
        kAXMainWindowAttribute, (CFTypeRef *) &_activatedWindow);
    if (!_activatedWindow) {
        if (verbose) { NSLog(@"No main window, trying focused window"); }
        AXUIElementCopyAttributeValue(_frontmostApp,
            kAXFocusedWindowAttribute, (CFTypeRef *) &_activatedWindow);
    }
    CFRelease(_frontmostApp);

    if (verbose) { NSLog(@"BundleIdentifier: %@", frontmostApp.bundleIdentifier); }
    bool finder_app = [frontmostApp.bundleIdentifier isEqual: FinderBundleId];
    if (finder_app) {
        if (_activatedWindow) {
            if (is_desktop_window(_activatedWindow)) {
                CFRelease(_activatedWindow);
                _activatedWindow = _previousFinderWindow;
            } else {
                if (_previousFinderWindow) { CFRelease(_previousFinderWindow); }
                _previousFinderWindow = _activatedWindow;
            }
        } else { _activatedWindow = _previousFinderWindow; }
    }

    if (altTaskSwitcher) {
        CGEventRef _event = CGEventCreate(NULL);
        CGPoint mousePoint = CGEventGetLocation(_event);
        if (_event) { CFRelease(_event); }

        bool ignoreActivated = false;
        // TODO: is the uncorrected mousePoint good enough?
        AXUIElementRef _mouseWindow = get_mousewindow(mousePoint);
        if (_mouseWindow) {
            if (!activated_by_task_switcher) {
                pid_t mouseWindow_pid;
                ignoreActivated = fabs(mousePoint.x-oldPoint.x) > 0;
                ignoreActivated = ignoreActivated || fabs(mousePoint.y-oldPoint.y) > 0;
                ignoreActivated = ignoreActivated || (AXUIElementGetPid(_mouseWindow,
                    &mouseWindow_pid) == kAXErrorSuccess && mouseWindow_pid == frontmost_pid);
            }
            CFRelease(_mouseWindow);
        } else {
            ignoreActivated = true;
        }

        activated_by_task_switcher = false;

        if (ignoreActivated) {
            if (verbose) { NSLog(@"Ignoring app activated"); }
            if (!finder_app && _activatedWindow) { CFRelease(_activatedWindow); }
            return false;
        }
    }

    if (_activatedWindow) {
        if (verbose) { NSLog(@"Warp mouse"); }
        CGWarpMouseCursorPosition(get_mousepoint(_activatedWindow));
        if (!finder_app) { CFRelease(_activatedWindow); }
    }

    return true;
}

void AXCallback(AXObserverRef observer, AXUIElementRef _element, CFStringRef notification, void * destroyedMouseWindow_id) {
    if (CFEqual(notification, kAXUIElementDestroyedNotification)) {
        lastDestroyedMouseWindow_id = (uint64_t) destroyedMouseWindow_id;
    }
}

void onTick() {
    // determine if mouseMoved
    CGEventRef _event = CGEventCreate(NULL);
    CGPoint mousePoint = CGEventGetLocation(_event);
    if (_event) { CFRelease(_event); }

    float mouse_x_diff = mousePoint.x-oldPoint.x;
    float mouse_y_diff = mousePoint.y-oldPoint.y;
    oldPoint = mousePoint;

    bool mouseMoved = fabs(mouse_x_diff) > mouseDelta;
    mouseMoved = mouseMoved || fabs(mouse_y_diff) > mouseDelta;
    bool mouseStopped = !mouseMoved;
    mouseMoved = mouseMoved || propagateMouseMoved;
    propagateMouseMoved = false;

#ifdef FOCUS_FIRST
    // !delayCount && !raiseDelayCount -> warp only (no focus, no raise)
    if (altTaskSwitcher && !delayCount && !raiseDelayCount) { return; }
    bool focus_first = delayCount && raiseDelayCount != 1;
#else
    // !delayCount -> warp only (no raise)
    if (altTaskSwitcher && !delayCount) { return; }
#endif

    // delayTicks = 0 -> delay disabled
    // delayTicks = 1 -> delay finished
    // delayTicks = n -> delay started
    if (delayTicks > 1) { delayTicks--; }

    if (@available(macOS 12.00, *)) {
        if (mouseMoved) {
            NSScreen * screen = findScreen(mousePoint);
            mousePoint.x += mouse_x_diff > 0 ? WINDOW_CORRECTION : -WINDOW_CORRECTION;
            mousePoint.y += mouse_y_diff > 0 ? WINDOW_CORRECTION : -WINDOW_CORRECTION;
            if (screen) {
                NSScreen * main_screen = NSScreen.screens[0];
                float screenOriginX = NSMinX(screen.frame) - NSMinX(main_screen.frame);
                float screenOriginY = NSMaxY(main_screen.frame) - NSMaxY(screen.frame);

                if (oldPoint.x > screenOriginX + NSWidth(screen.frame) - WINDOW_CORRECTION) {
                    if (verbose) { NSLog(@"Screen edge correction"); }
                    mousePoint.x = screenOriginX + NSWidth(screen.frame) - SCREEN_EDGE_CORRECTION;
                } else if (oldPoint.x < screenOriginX + WINDOW_CORRECTION - 1) {
                    if (verbose) { NSLog(@"Screen edge correction"); }
                    mousePoint.x = screenOriginX + SCREEN_EDGE_CORRECTION;
                }

                if (oldPoint.y > screenOriginY + NSHeight(screen.frame) - WINDOW_CORRECTION) {
                    if (verbose) { NSLog(@"Screen edge correction"); }
                    mousePoint.y = screenOriginY + NSHeight(screen.frame) - SCREEN_EDGE_CORRECTION;
                } else {
                    float menuBarHeight = fmax(0, NSMaxY(screen.frame) - NSMaxY(screen.visibleFrame) - 1);
                    if (mousePoint.y < screenOriginY + menuBarHeight + MENUBAR_CORRECTION) {
                        if (verbose) { NSLog(@"Menu bar correction"); }
                        mousePoint.y = screenOriginY;
                    }
                }
            }
            oldCorrectedPoint = mousePoint;
        } else {
            mousePoint = oldCorrectedPoint;
        }
    }

    if (ignoreTimes) {
        ignoreTimes--;
        return;
    } else if (appWasActivated) {
        appWasActivated = false;
        return;
    } else if (spaceHasChanged) {
        if (mouseMoved) { return; }
        else if (!ignoreSpaceChanged) {
            raiseTimes = 3;
            delayTicks = 0;
        }
        spaceHasChanged = false;
    } else if (requireMouseStop && !mouseStopped && mouseMoved) {
        delayTicks = 0;
        propagateMouseMoved = true;
        return;
    }

    if (mouseMoved || delayTicks || raiseTimes) {
        bool abort = CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonLeft) ||
            CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonRight) ||
            dock_active() || mc_active();

        if (!abort && disableKey) {
            CGEventRef _keyDownEvent = CGEventCreateKeyboardEvent(NULL, 0, true);
            CGEventFlags flags = CGEventGetFlags(_keyDownEvent);
            if (_keyDownEvent) { CFRelease(_keyDownEvent); }
            abort = (flags & disableKey) == disableKey;
            abort = abort != invertDisableKey;
        }

        NSRunningApplication *frontmostApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
        abort = abort || [stayFocusedBundleIds containsObject: frontmostApp.bundleIdentifier];

        if (abort) {
            if (verbose) { NSLog(@"Abort focus/raise"); }
            raiseTimes = 0;
            delayTicks = 0;
            return;
        }

        AXUIElementRef _mouseWindow = get_mousewindow(mousePoint);
        if (_mouseWindow) {
            pid_t mouseWindow_pid;
            if (AXUIElementGetPid(_mouseWindow, &mouseWindow_pid) == kAXErrorSuccess) {
                CGWindowID mouseWindow_id;
                _AXUIElementGetWindow(_mouseWindow, &mouseWindow_id);
                bool mouseWindowPresent = mouseWindow_id != lastDestroyedMouseWindow_id;
                if (mouseWindowPresent) {
                    static CGWindowID previous_id = kCGNullWindowID;
                    if (mouseWindow_id != previous_id) {
                        previous_id = mouseWindow_id;

                        lastDestroyedMouseWindow_id = kCGNullWindowID;
                        raiseTimes = 0;
                        delayTicks = 0;

                        if (axObserver) {
                            CFRelease(axObserver);
                            axObserver = NULL;
                        }

                        AXObserverCreate(
                            mouseWindow_pid,
                            AXCallback,
                            &axObserver
                        );

                        AXObserverAddNotification(
                            axObserver,
                            _mouseWindow,
                            kAXUIElementDestroyedNotification,
                            (void *) ((uint64_t) mouseWindow_id)
                        );

                        CFRunLoopAddSource(
                            CFRunLoopGetCurrent(),
                            AXObserverGetRunLoopSource(axObserver),
                            kCFRunLoopCommonModes
                        );
                    }
                } else if (verbose) { NSLog(@"Mouse window not present"); }

#ifdef FOCUS_FIRST
                bool workaround_for_apps_raising_on_focus = false;
#endif
                bool needs_raise = !invertIgnoreApps && mouseWindowPresent;
                AXUIElementRef _mouseWindowApp = AXUIElementCreateApplication(mouseWindow_pid);
                if (needs_raise && titleEquals(_mouseWindow, @[NoTitle, Untitled])) {
                    needs_raise = is_main_window(_mouseWindowApp, _mouseWindow, is_pwa(
                        [NSRunningApplication runningApplicationWithProcessIdentifier:
                        mouseWindow_pid].bundleIdentifier));
                    if (verbose && !needs_raise) { NSLog(@"Excluding window"); }
                } else if (needs_raise &&
                    titleEquals(_mouseWindow, @[BartenderBar, Zim, AppStoreSearchResults], ignoreTitles)) {
                    needs_raise = false;
                    if (verbose) { NSLog(@"Excluding window"); }
                } else if (mouseWindowPresent) {
                    if (titleEquals(_mouseWindowApp, ignoreApps)) {
                        needs_raise = invertIgnoreApps;
                        if (verbose) {
                            if (invertIgnoreApps) {
                                NSLog(@"Including app");
                            } else {
                                NSLog(@"Excluding app");
                            }
                        }
                    }
#ifdef FOCUS_FIRST
                    workaround_for_apps_raising_on_focus = titleEquals(_mouseWindowApp, AppsRaisingOnFocus);
#endif
                }
                CFRelease(_mouseWindowApp);
                CGWindowID focusedWindow_id;
#ifdef FOCUS_FIRST
                ProcessSerialNumber mouseWindow_psn;
                ProcessSerialNumber focusedWindow_psn;
                ProcessSerialNumber * _focusedWindow_psn = NULL;
#endif
                if (needs_raise) {
                    pid_t frontmost_pid = frontmostApp.processIdentifier;
                    AXUIElementRef _frontmostApp = AXUIElementCreateApplication(frontmost_pid);
                    AXUIElementRef _focusedWindow = NULL;
                    AXUIElementCopyAttributeValue(
                        _frontmostApp,
                        kAXFocusedWindowAttribute,
                        (CFTypeRef *) &_focusedWindow);
                    if (_focusedWindow) {
                        if (verbose) { logWindowTitle(@"Focused window", _focusedWindow); }
                        _AXUIElementGetWindow(_focusedWindow, &focusedWindow_id);
                        needs_raise = mouseWindow_id != focusedWindow_id;
#ifdef FOCUS_FIRST
                        if (!focus_first) {
#endif
                            needs_raise = needs_raise && !contained_within(_focusedWindow, _mouseWindow);
#ifdef FOCUS_FIRST
                        } else {
                            needs_raise = needs_raise && is_main_window(_frontmostApp, _focusedWindow,
                                is_pwa(frontmostApp.bundleIdentifier)) && ((mouseWindow_pid != frontmost_pid &&
                                !workaround_for_apps_raising_on_focus) || !contained_within(_focusedWindow, _mouseWindow));
                            if (needs_raise) {
                                OSStatus error = GetProcessForPID(frontmost_pid, &focusedWindow_psn);
                                if (!error) { _focusedWindow_psn = &focusedWindow_psn; }
                            }
                        }
#endif
                        CFRelease(_focusedWindow);
                    } else {
                        if (verbose) { NSLog(@"No focused window"); }
                        AXUIElementRef _activatedWindow = NULL;
                        AXUIElementCopyAttributeValue(_frontmostApp,
                            kAXMainWindowAttribute, (CFTypeRef *) &_activatedWindow);
                        if (_activatedWindow) {
                          needs_raise = false;
                          CFRelease(_activatedWindow);
                        }
                    }
                    CFRelease(_frontmostApp);
                }

                if (needs_raise) {
                    if (!delayTicks) {
                        // start the delay
                        delayTicks = delayCount;
                    }
                    if (raiseTimes || delayTicks == 1) {
                        delayTicks = 0; // disable delay

                        if (raiseTimes) { raiseTimes--; }
                        else { raiseTimes = 3; }
#ifdef FOCUS_FIRST
                        if (focus_first) {
                            OSStatus error = GetProcessForPID(mouseWindow_pid, &mouseWindow_psn);
                            if (!error) {
                                bool floating_window = false;
                                CFStringRef _element_sub_role = NULL;
                                AXUIElementCopyAttributeValue(
                                    _mouseWindow,
                                    kAXSubroleAttribute,
                                    (CFTypeRef *) &_element_sub_role);
                                if (_element_sub_role) {
                                    floating_window =
                                        CFEqual(_element_sub_role, kAXFloatingWindowSubrole) ||
                                        CFEqual(_element_sub_role, kAXSystemFloatingWindowSubrole) ||
                                        CFEqual(_element_sub_role, kAXUnknownSubrole);
                                    CFRelease(_element_sub_role);
                                }
                                if (!floating_window) {
                                    if (!workaround_for_apps_raising_on_focus || raiseDelayCount == 0) {
                                        window_manager_focus_window_without_raise(&mouseWindow_psn,
                                            mouseWindow_id, _focusedWindow_psn, focusedWindow_id);
                                    }
                                } else if (verbose) { NSLog(@"Unable to focus floating window"); }
                                if (_lastFocusedWindow) { CFRelease(_lastFocusedWindow); }
                                _lastFocusedWindow = _mouseWindow;
                                lastFocusedWindow_pid = mouseWindow_pid;
                                if (raiseDelayCount) { [workspaceWatcher windowFocused: _lastFocusedWindow]; }
                            }
                        } else {
#endif
                        raiseAndActivate(_mouseWindow, mouseWindow_pid);
#ifdef FOCUS_FIRST
                        }
#endif
                    }
                } else {
                    raiseTimes = 0;
                    delayTicks = 0;
                }
            }
#ifdef FOCUS_FIRST
            if (_mouseWindow != _lastFocusedWindow) {
#endif
                CFRelease(_mouseWindow);
#ifdef FOCUS_FIRST
            }
#endif
        }
    }
}

CGEventRef eventTapHandler(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    CGEventFlags flags = CGEventGetFlags(event);
    bool commandPressed = (flags & TASK_SWITCHER_MODIFIER_KEY) == TASK_SWITCHER_MODIFIER_KEY;

    static bool commandTabPressed = false;
    if (!commandPressed && commandTabPressed) {
        commandTabPressed = false;
        activated_by_task_switcher = true;
        ignoreTimes = 3;
    }

    static bool commandGravePressed = false;
    if (!commandPressed && commandGravePressed) {
        commandGravePressed = false;
        activated_by_task_switcher = true;
        ignoreTimes = 3;
        [workspaceWatcher onAppActivated];
    }

    if (type == kCGEventKeyDown) {
        CGKeyCode keycode = (CGKeyCode) CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        if (keycode == kVK_Tab) {
            commandTabPressed = commandTabPressed || commandPressed;
        } else if (warpMouse && keycode == kVK_ANSI_Grave) {
            commandGravePressed = commandGravePressed || commandPressed;
        }
    } else if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (verbose) { NSLog(@"Got event tap disabled event, re-enabling..."); }
        CGEventTapEnable(eventTap, true);
    }

    return event;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        ConfigClass * config = [[ConfigClass alloc] init];
        [config readConfig: argc];
        [config validateParameters];

        delayCount         = [parameters[kDelay] intValue];
        savedDelayCount    = delayCount ? delayCount : 1;
        warpX              = [parameters[kWarpX] floatValue];
        warpY              = [parameters[kWarpY] floatValue];
        cursorScale        = [parameters[kScale] floatValue];
        verbose            = [parameters[kVerbose] boolValue];
        altTaskSwitcher    = [parameters[kAltTaskSwitcher] boolValue];
        mouseDelta         = [parameters[kMouseDelta] floatValue];
        pollMillis         = [parameters[kPollMillis] intValue];
        scaleDurationMs    = [parameters[kScaleDuration] intValue];
        requireMouseStop   = [parameters[kRequireMouseStop] boolValue];
        ignoreSpaceChanged = [parameters[kIgnoreSpaceChanged] boolValue];
        invertIgnoreApps   = [parameters[kInvertIgnoreApps] boolValue];
        invertDisableKey   = [parameters[kInvertDisableKey] boolValue];
        if (parameters[kShowIcon]) {
            showIcon = [parameters[kShowIcon] boolValue];
        }
        // No nil-guard needed: defaults to false and [nil boolValue] is also false.
        disableWhenNoExternalScreen = [parameters[kDisableWhenNoExternalScreen] boolValue];

        printf("\nv%s by aaabramov(c) 2026, usage:\n\nHoist\n", HOIST_VERSION);
        printf("  -pollMillis <20, 30, 40, 50, ...>\n");
        printf("  -delay <0=no-raise, 1=no-delay, 2=%dms, 3=%dms, ...>\n", pollMillis, pollMillis*2);
#ifdef FOCUS_FIRST
        printf("  -focusDelay <0=no-focus, 1=no-delay, 2=%dms, 3=%dms, ...>\n", pollMillis, pollMillis*2);
#endif
        printf("  -warpX <0.5> -warpY <0.5> -scale <2.0>\n");
        printf("  -altTaskSwitcher <true|false>\n");
        printf("  -requireMouseStop <true|false>\n");
        printf("  -ignoreSpaceChanged <true|false>\n");
        printf("  -invertDisableKey <true|false>\n");
        printf("  -invertIgnoreApps <true|false>\n");
        printf("  -ignoreApps \"<App1,App2,...>\"\n");
        printf("  -ignoreTitles \"<Regex1,Regex2,...>\"\n");
        printf("  -stayFocusedBundleIds \"<Id1,Id2,...>\"\n");
        printf("  -disableKey <control|option|disabled>\n");
        printf("  -mouseDelta <0.1>\n");
        printf("  -verbose <true|false>\n\n");

        printf("Started with:\n");
        printf("  * pollMillis: %dms\n", pollMillis);
        if (delayCount) {
            printf("  * delay: %dms\n", (delayCount-1)*pollMillis);
        } else {
            printf("  * delay: disabled\n");
        }
#ifdef FOCUS_FIRST
        if ([parameters[kFocusDelay] intValue]) {
            raiseDelayCount = delayCount;
            delayCount = [parameters[kFocusDelay] intValue];
            printf("  * focusDelay: %dms\n", (delayCount-1)*pollMillis);
        } else {
            raiseDelayCount = 1;
            printf("  * focusDelay: disabled\n");
        }
#endif

        if (warpMouse) {
            printf("  * warpX: %.1f, warpY: %.1f, scale: %.1f\n", warpX, warpY, cursorScale);
            printf("  * altTaskSwitcher: %s\n", altTaskSwitcher ? "true" : "false");
        }

        printf("  * requireMouseStop: %s\n", requireMouseStop ? "true" : "false");
        printf("  * ignoreSpaceChanged: %s\n", ignoreSpaceChanged ? "true" : "false");
        printf("  * invertDisableKey: %s\n", invertDisableKey ? "true" : "false");
        printf("  * invertIgnoreApps: %s\n", invertIgnoreApps ? "true" : "false");
        printf("  * disableWhenNoExternalScreen: %s\n", disableWhenNoExternalScreen ? "true" : "false");

        NSMutableArray * ignoreA;
        if (parameters[kIgnoreApps]) {
            ignoreA = [[NSMutableArray alloc] initWithArray:
                [parameters[kIgnoreApps] componentsSeparatedByString:@","]];
        } else { ignoreA = [[NSMutableArray alloc] init]; }

        for (id ignoreApp in ignoreA) {
            printf("  * ignoreApp: %s\n", [ignoreApp UTF8String]);
        }
        [ignoreA addObject: AssistiveControl];
        ignoreApps = [ignoreA copy];

        NSMutableArray * ignoreT;
        if (parameters[kIgnoreTitles]) {
            ignoreT = [[NSMutableArray alloc] initWithArray:
                [parameters[kIgnoreTitles] componentsSeparatedByString: @","]];
        } else { ignoreT = [[NSMutableArray alloc] init]; }

        for (id ignoreTitle in ignoreT) {
            printf("  * ignoreTitle: %s\n", [ignoreTitle UTF8String]);
        }
        ignoreTitles = [ignoreT copy];

        NSMutableArray * stayFocused;
        if (parameters[kStayFocusedBundleIds]) {
            stayFocused = [[NSMutableArray alloc] initWithArray:
                [parameters[kStayFocusedBundleIds] componentsSeparatedByString: @","]];
        } else { stayFocused = [[NSMutableArray alloc] init]; }

        for (id stayFocusedBundleId in stayFocused) {
            printf("  * stayFocusedBundleId: %s\n", [stayFocusedBundleId UTF8String]);
        }
        stayFocusedBundleIds = [stayFocused copy];

        if ([parameters[kDisableKey] isEqualToString: @"control"]) {
            printf("  * disableKey: control\n");
            disableKey = kCGEventFlagMaskControl;
        } else if ([parameters[kDisableKey] isEqualToString: @"option"]) {
            printf("  * disableKey: option\n");
            disableKey = kCGEventFlagMaskAlternate;
        } else { printf("  * disableKey: disabled\n"); }

        if (mouseDelta) { printf("  * mouseDelta: %.1f\n", mouseDelta); }

        printf("  * verbose: %s\n", verbose ? "true" : "false");
#if defined OLD_ACTIVATION_METHOD or defined FOCUS_FIRST or defined ALTERNATIVE_TASK_SWITCHER
        printf("\nCompiled with:\n");
#ifdef OLD_ACTIVATION_METHOD
        printf("  * OLD_ACTIVATION_METHOD\n");
#endif
#ifdef FOCUS_FIRST
        printf("  * EXPERIMENTAL_FOCUS_FIRST\n");
#endif
#ifdef ALTERNATIVE_TASK_SWITCHER
        printf("  * ALTERNATIVE_TASK_SWITCHER\n");
#endif
#endif
        printf("\n");

        NSDictionary * options = @{(id) CFBridgingRelease(kAXTrustedCheckOptionPrompt): @YES};
        bool trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef) options);
        if (verbose) { NSLog(@"AXIsProcessTrusted: %s", trusted ? "YES" : "NO"); }

        CGSGetCursorScale(CGSMainConnectionID(), &oldScale);
        if (oldScale != 1) {
            if (verbose) { NSLog(@"Resetting leftover cursor scale: %f -> 1", oldScale); }
            CGSSetCursorScale(CGSMainConnectionID(), 1);
            oldScale = 1;
        }
        if (verbose) { NSLog(@"System cursor scale: %f", oldScale); }

        CFRunLoopSourceRef runLoopSource = NULL;
        eventTap = CGEventTapCreate(
            kCGSessionEventTap,
            kCGHeadInsertEventTap,
            kCGEventTapOptionListenOnly,
            CGEventMaskBit(kCGEventKeyDown) |
            CGEventMaskBit(kCGEventFlagsChanged),
            eventTapHandler,
            NULL
        );
        if (eventTap) {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
            if (runLoopSource) {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
                CGEventTapEnable(eventTap, true);
            }
        }
        if (verbose) { NSLog(@"Got run loop source: %s", runLoopSource ? "YES" : "NO"); }

        workspaceWatcher = [[MDWorkspaceWatcher alloc] init];
#ifdef FOCUS_FIRST
        if (altTaskSwitcher || raiseDelayCount || delayCount) {
#else
        if (altTaskSwitcher || delayCount) {
#endif
            [workspaceWatcher onTick: [NSNumber numberWithFloat: pollMillis/1000.0]];
        }

        findDockApplication();
        findDesktopOrigin();

        if (showIcon) {
            statusBarController = [[StatusBarController alloc] init];
        }
        applyScreenAutoDisable();
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [[NSApplication sharedApplication] run];
    }
    return 0;
}
