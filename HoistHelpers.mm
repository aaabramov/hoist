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

//----------------------------------------yabai focus only methods------------------------------------------

#ifdef FOCUS_FIRST
void window_manager_make_key_window(ProcessSerialNumber * _window_psn, uint32_t window_id) {
    uint8_t * bytes = (uint8_t *) malloc(0xf8);
    memset(bytes, 0, 0xf8);

    bytes[0x04] = 0xf8;
    bytes[0x3a] = 0x10;

    memcpy(bytes + 0x3c, &window_id, sizeof(uint32_t));
    memset(bytes + 0x20, 0xFF, 0x10);

    bytes[0x08] = 0x01;
    SLPSPostEventRecordTo(_window_psn, bytes);

    bytes[0x08] = 0x02;
    SLPSPostEventRecordTo(_window_psn, bytes);
    free(bytes);
}

void window_manager_focus_window_without_raise(
    ProcessSerialNumber * _window_psn, uint32_t window_id,
    ProcessSerialNumber * _focused_window_psn, uint32_t focused_window_id
) {
    if (verbose) { NSLog(@"Focus"); }
    if (_focused_window_psn) {
        Boolean same_process;
        SameProcess(_window_psn, _focused_window_psn, &same_process);
        if (same_process) {
            if (verbose) { NSLog(@"Same process"); }
            uint8_t * bytes = (uint8_t *) malloc(0xf8);
            memset(bytes, 0, 0xf8);
            bytes[0x04] = 0xf8;
            bytes[0x08] = 0x0d;

            bytes[0x8a] = 0x02;
            memcpy(bytes + 0x3c, &focused_window_id, sizeof(uint32_t));
            SLPSPostEventRecordTo(_focused_window_psn, bytes);

            // @hack
            // Artificially delay the activation by 1ms. This is necessary
            // because some applications appear to be confused if both of
            // the events appear instantaneously.
            usleep(10000);

            bytes[0x8a] = 0x01;
            memcpy(bytes + 0x3c, &window_id, sizeof(uint32_t));
            SLPSPostEventRecordTo(_window_psn, bytes);
            free(bytes);
        }
    }

    _SLPSSetFrontProcessWithOptions(_window_psn, window_id, kCPSUserGenerated);
    window_manager_make_key_window(_window_psn, window_id);
}
#endif

//---------------------------------------------helper methods-----------------------------------------------

void activate(pid_t pid) {
    if (verbose) { NSLog(@"Activate"); }
#ifdef OLD_ACTIVATION_METHOD
    ProcessSerialNumber process;
    OSStatus error = GetProcessForPID(pid, &process);
    if (!error) { SetFrontProcessWithOptions(&process, kSetFrontProcessFrontWindowOnly); }
#else
    [[NSRunningApplication runningApplicationWithProcessIdentifier: pid]
        activateWithOptions: 0];
#endif
}

void raiseAndActivate(AXUIElementRef _window, pid_t window_pid) {
    if (verbose) { NSLog(@"Raise"); }
    if (AXUIElementPerformAction(_window, kAXRaiseAction) == kAXErrorSuccess) {
        activate(window_pid);
    }
}

void logWindowTitle(NSString * prefix, AXUIElementRef _window) {
    CFStringRef _windowTitle = NULL;
    AXUIElementCopyAttributeValue(_window, kAXTitleAttribute, (CFTypeRef *) &_windowTitle);
    if (_windowTitle) {
        NSLog(@"%@: `%@`", prefix, _windowTitle);
        CFRelease(_windowTitle);
    } else {
        pid_t pid;
        NSString * _appName = NULL;
        if (AXUIElementGetPid(_window, &pid) == kAXErrorSuccess) {
            _appName = [NSRunningApplication runningApplicationWithProcessIdentifier: pid].localizedName;
        }
        if (_appName) { NSLog(@"%@ (app name): `%@`", prefix, _appName); }
        else { NSLog(@"%@: null", prefix); }
    }
}

// TODO: does not take into account different languages
bool titleEquals(AXUIElementRef _element, NSArray * _titles, NSArray * _patterns, bool logTitle) {
    bool equal = false;
    CFStringRef _elementTitle = NULL;
    AXUIElementCopyAttributeValue(_element, kAXTitleAttribute, (CFTypeRef *) &_elementTitle);
    if (logTitle) { NSLog(@"element title: `%@`", _elementTitle); }
    if (_elementTitle) {
        NSString * _title = (__bridge NSString *) _elementTitle;
        equal = [_titles containsObject: _title];
        if (!equal && _patterns) {
            for (NSString * _pattern in _patterns) {
                equal = [_title rangeOfString: _pattern options: NSRegularExpressionSearch].location != NSNotFound;
                if (equal) { break; }
            }
        }
        CFRelease(_elementTitle);
    } else { equal = [_titles containsObject: NoTitle]; }
    return equal;
}

bool dock_active() {
    bool active = false;
    AXUIElementRef _focusedUIElement = NULL;
    AXUIElementCopyAttributeValue(_dock_app, kAXFocusedUIElementAttribute, (CFTypeRef *) &_focusedUIElement);
    if (_focusedUIElement) {
        active = true;
        if (verbose) { NSLog(@"Dock is active"); }
        CFRelease(_focusedUIElement);
    }
    return active;
}

bool mc_active() {
    bool active = false;
    CFArrayRef _children = NULL;
    AXUIElementCopyAttributeValue(_dock_app, kAXChildrenAttribute, (CFTypeRef *) &_children);
    if (_children) {
        CFIndex count = CFArrayGetCount(_children);
        for (CFIndex i=0;!active && i != count;i++) {
            CFStringRef _element_role = NULL;
            AXUIElementRef _element = (AXUIElementRef) CFArrayGetValueAtIndex(_children, i);
            AXUIElementCopyAttributeValue(_element, kAXRoleAttribute, (CFTypeRef *) &_element_role);
            if (_element_role) {
                active = CFEqual(_element_role, kAXGroupRole) && titleEquals(_element, @[MissionControl]);
                CFRelease(_element_role);
            }
        }
        CFRelease(_children);
    }

    if (verbose && active) { NSLog(@"Mission Control is active"); }
    return active;
}

NSDictionary * topwindow(CGPoint point) {
    NSDictionary * top_window = NULL;
    NSArray * window_list = (NSArray *) CFBridgingRelease(CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID));

    for (NSDictionary * window in window_list) {
        NSDictionary * window_bounds_dict = window[(NSString *) CFBridgingRelease(kCGWindowBounds)];

        if (![window[(__bridge id) kCGWindowLayer] isEqual: @0]) { continue; }

        NSRect window_bounds = NSMakeRect(
            [window_bounds_dict[@"X"] intValue],
            [window_bounds_dict[@"Y"] intValue],
            [window_bounds_dict[@"Width"] intValue],
            [window_bounds_dict[@"Height"] intValue]);

        if (NSPointInRect(NSPointFromCGPoint(point), window_bounds)) {
            top_window = window;
            break;
        }
    }

    return top_window;
}

AXUIElementRef fallback(CGPoint point) {
    if (verbose) { NSLog(@"Fallback"); }
    AXUIElementRef _window = NULL;
    NSDictionary * top_window = topwindow(point);
    if (top_window) {
        CFTypeRef _windows_cf = NULL;
        pid_t pid = [top_window[(__bridge id) kCGWindowOwnerPID] intValue];
        AXUIElementRef _window_owner = AXUIElementCreateApplication(pid);
        AXUIElementCopyAttributeValue(_window_owner, kAXWindowsAttribute, &_windows_cf);
        CFRelease(_window_owner);
        if (_windows_cf) {
            NSArray * application_windows = (NSArray *) CFBridgingRelease(_windows_cf);
            CGWindowID top_window_id = [top_window[(__bridge id) kCGWindowNumber] intValue];
            if (top_window_id) {
                for (id application_window in application_windows) {
                    CGWindowID application_window_id;
                    AXUIElementRef application_window_ax =
                        (__bridge AXUIElementRef) application_window;
                    if (_AXUIElementGetWindow(
                        application_window_ax,
                        &application_window_id) == kAXErrorSuccess) {
                        if (application_window_id == top_window_id) {
                            _window = application_window_ax;
                            CFRetain(_window);
                            break;
                        }
                    }
                }
            }
        } else {
            activate(pid);
        }
    }

    return _window;
}

AXUIElementRef get_raisable_window(AXUIElementRef _element, CGPoint point, int count) {
    AXUIElementRef _window = NULL;
    if (_element) {
        if (count >= STACK_THRESHOLD) {
            if (verbose) {
                NSLog(@"Stack threshold reached");
                pid_t application_pid;
                if (AXUIElementGetPid(_element, &application_pid) == kAXErrorSuccess) {
                    proc_pidpath(application_pid, pathBuffer, sizeof(pathBuffer));
                    NSLog(@"Application path: %s", pathBuffer);
                }
            }
            CFRelease(_element);
        } else {
            CFStringRef _element_role = NULL;
            AXUIElementCopyAttributeValue(_element, kAXRoleAttribute, (CFTypeRef *) &_element_role);
            bool check_attributes = !_element_role;
            if (_element_role) {
                if (CFEqual(_element_role, kAXDockItemRole) ||
                    CFEqual(_element_role, kAXMenuItemRole) ||
                    CFEqual(_element_role, kAXMenuRole) ||
                    CFEqual(_element_role, kAXMenuBarRole) ||
                    CFEqual(_element_role, kAXMenuBarItemRole)) {
                    CFRelease(_element_role);
                    CFRelease(_element);
                } else if (
                    CFEqual(_element_role, kAXWindowRole) ||
                    CFEqual(_element_role, kAXSheetRole) ||
                    CFEqual(_element_role, kAXDrawerRole)) {
                    CFRelease(_element_role);
                    _window = _element;
                } else if (CFEqual(_element_role, kAXApplicationRole)) {
                    CFRelease(_element_role);
                    if (titleEquals(_element, @[XQuartz])) {
                        pid_t application_pid;
                        if (AXUIElementGetPid(_element, &application_pid) == kAXErrorSuccess) {
                            pid_t frontmost_pid = [[[NSWorkspace sharedWorkspace]
                                frontmostApplication] processIdentifier];
                            if (application_pid != frontmost_pid) {
                                activate(application_pid);
                            }
                        }
                        CFRelease(_element);
                    } else { check_attributes = true; }
                } else {
                    CFRelease(_element_role);
                    check_attributes = true;
                }
            }

            if (check_attributes) {
                AXUIElementCopyAttributeValue(_element, kAXParentAttribute, (CFTypeRef *) &_window);
                bool no_parent = !_window;
                _window = get_raisable_window(_window, point, ++count);
                if (!_window) {
                    AXUIElementCopyAttributeValue(_element, kAXWindowAttribute, (CFTypeRef *) &_window);
                    if (!_window && no_parent) { _window = fallback(point); }
                }
                CFRelease(_element);
            }
        }
    }

    return _window;
}

AXUIElementRef get_mousewindow(CGPoint point) {
    AXUIElementRef _element = NULL;
    AXError error = AXUIElementCopyElementAtPosition(_accessibility_object, point.x, point.y, &_element);

    AXUIElementRef _window = NULL;
    if (_element) {
        _window = get_raisable_window(_element, point, 0);
    } else if (error == kAXErrorCannotComplete || error == kAXErrorNotImplemented) {
        if (verbose) { NSLog(@"Copy element: no accessibility support"); }
        _window = fallback(point);
    } else if (error == kAXErrorIllegalArgument) {
        if (verbose) { NSLog(@"Copy element: illegal argument"); }
        _window = fallback(point);
    } else if (error == kAXErrorNoValue) {
        if (verbose) { NSLog(@"Copy element: no value"); }
        _window = fallback(point);
    } else if (error == kAXErrorAttributeUnsupported) {
        if (verbose) { NSLog(@"Copy element: attribute unsupported"); }
    } else if (error == kAXErrorFailure) {
        if (verbose) { NSLog(@"Copy element: failure"); }
    } else if (verbose) {
        NSLog(@"Copy element: AXError %d", error);
    }

    if (verbose) {
        if (_window) { logWindowTitle(@"Mouse window", _window); }
        else { NSLog(@"No raisable window"); }
    }

    return _window;
}

CGPoint get_mousepoint(AXUIElementRef _window) {
    CGPoint mousepoint = {0, 0};
    AXValueRef _size = NULL;
    AXValueRef _pos = NULL;
    AXUIElementCopyAttributeValue(_window, kAXSizeAttribute, (CFTypeRef *) &_size);
    if (_size) {
        AXUIElementCopyAttributeValue(_window, kAXPositionAttribute, (CFTypeRef *) &_pos);
        if (_pos) {
            CGSize cg_size;
            CGPoint cg_pos;
            if (AXValueGetValue(_size, kAXValueTypeCGSize, &cg_size) &&
                AXValueGetValue(_pos, kAXValueTypeCGPoint, &cg_pos)) {
                mousepoint.x = cg_pos.x + (cg_size.width * warpX);
                mousepoint.y = cg_pos.y + (cg_size.height * warpY);
            }
            CFRelease(_pos);
        }
        CFRelease(_size);
    }

    return mousepoint;
}

bool contained_within(AXUIElementRef _window1, AXUIElementRef _window2) {
    bool contained = false;
    AXValueRef _size1 = NULL;
    AXValueRef _size2 = NULL;
    AXValueRef _pos1 = NULL;
    AXValueRef _pos2 = NULL;

    AXUIElementCopyAttributeValue(_window1, kAXSizeAttribute, (CFTypeRef *) &_size1);
    if (_size1) {
        AXUIElementCopyAttributeValue(_window1, kAXPositionAttribute, (CFTypeRef *) &_pos1);
        if (_pos1) {
            AXUIElementCopyAttributeValue(_window2, kAXSizeAttribute, (CFTypeRef *) &_size2);
            if (_size2) {
                AXUIElementCopyAttributeValue(_window2, kAXPositionAttribute, (CFTypeRef *) &_pos2);
                if (_pos2) {
                    CGSize cg_size1;
                    CGSize cg_size2;
                    CGPoint cg_pos1;
                    CGPoint cg_pos2;
                    if (AXValueGetValue(_size1, kAXValueTypeCGSize, &cg_size1) &&
                        AXValueGetValue(_pos1, kAXValueTypeCGPoint, &cg_pos1) &&
                        AXValueGetValue(_size2, kAXValueTypeCGSize, &cg_size2) &&
                        AXValueGetValue(_pos2, kAXValueTypeCGPoint, &cg_pos2)) {
                        contained = cg_pos1.x > cg_pos2.x && cg_pos1.y > cg_pos2.y &&
                            cg_pos1.x + cg_size1.width < cg_pos2.x + cg_size2.width &&
                            cg_pos1.y + cg_size1.height < cg_pos2.y + cg_size2.height;
                    }
                    CFRelease(_pos2);
                }
                CFRelease(_size2);
            }
            CFRelease(_pos1);
        }
        CFRelease(_size1);
    }

    return contained;
}

void findDockApplication() {
    NSArray * _apps = [[NSWorkspace sharedWorkspace] runningApplications];
    for (NSRunningApplication * app in _apps) {
        if ([app.bundleIdentifier isEqual: DockBundleId]) {
            _dock_app = AXUIElementCreateApplication(app.processIdentifier);
            break;
        }
    }

    if (verbose && !_dock_app) { NSLog(@"Dock application isn't running"); }
}

void findDesktopOrigin() {
    NSScreen * main_screen = NSScreen.screens[0];
    float mainScreenTop = NSMaxY(main_screen.frame);
    for (NSScreen * screen in [NSScreen screens]) {
        float screenOriginY = mainScreenTop - NSMaxY(screen.frame);
        if (screenOriginY < desktopOrigin.y) { desktopOrigin.y = screenOriginY; }
        if (screen.frame.origin.x < desktopOrigin.x) { desktopOrigin.x = screen.frame.origin.x; }
    }

    if (verbose) { NSLog(@"Desktop origin (%f, %f)", desktopOrigin.x, desktopOrigin.y); }
}

NSScreen * findScreen(CGPoint point) {
    NSScreen * main_screen = NSScreen.screens[0];
    point.y = NSMaxY(main_screen.frame) - point.y;
    for (NSScreen * screen in [NSScreen screens]) {
        NSRect screen_bounds = NSMakeRect(
            screen.frame.origin.x,
            screen.frame.origin.y,
            NSWidth(screen.frame) + 1,
            NSHeight(screen.frame) + 1
        );
        if (NSPointInRect(NSPointFromCGPoint(point), screen_bounds)) {
            return screen;
        }
    }
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
    bool desktop_window = false;
    AXValueRef _pos = NULL;
    AXUIElementCopyAttributeValue(_window, kAXPositionAttribute, (CFTypeRef *) &_pos);
    if (_pos) {
        CGPoint cg_pos;
        desktop_window = AXValueGetValue(_pos, kAXValueTypeCGPoint, &cg_pos) &&
            NSEqualPoints(NSPointFromCGPoint(cg_pos), NSPointFromCGPoint(desktopOrigin));
        CFRelease(_pos);
    }

    if (verbose && desktop_window) { NSLog(@"Desktop window"); }
    return desktop_window;
}

bool is_full_screen(AXUIElementRef _window) {
    bool full_screen = false;
    AXValueRef _pos = NULL;
    AXUIElementCopyAttributeValue(_window, kAXPositionAttribute, (CFTypeRef *) &_pos);
    if (_pos) {
        CGPoint cg_pos;
        if (AXValueGetValue(_pos, kAXValueTypeCGPoint, &cg_pos)) {
            NSScreen * screen = findScreen(cg_pos);
            if (screen) {
                AXValueRef _size = NULL;
                AXUIElementCopyAttributeValue(_window, kAXSizeAttribute, (CFTypeRef *) &_size);
                if (_size) {
                    CGSize cg_size;
                    if (AXValueGetValue(_size, kAXValueTypeCGSize, &cg_size)) {
                        float menuBarHeight =
                            fmax(0, NSMaxY(screen.frame) - NSMaxY(screen.visibleFrame) - 1);
                        NSScreen * main_screen = NSScreen.screens[0];
                        float screenOriginY = NSMaxY(main_screen.frame) - NSMaxY(screen.frame);
                        full_screen = cg_pos.x == NSMinX(screen.frame) &&
                                      cg_pos.y == screenOriginY + menuBarHeight &&
                                      cg_size.width == NSWidth(screen.frame) &&
                                      cg_size.height == NSHeight(screen.frame) - menuBarHeight;
                    }
                    CFRelease(_size);
                }
            }
        }
        CFRelease(_pos);
    }

    if (verbose && full_screen) { NSLog(@"Full screen window"); }
    return full_screen;
}

bool is_main_window(AXUIElementRef _app, AXUIElementRef _window, bool chrome_app) {
    bool main_window = false;
    CFBooleanRef _result = NULL;
    AXUIElementCopyAttributeValue(_window, kAXMainAttribute, (CFTypeRef *) &_result);
    if (_result) {
        main_window = CFEqual(_result, kCFBooleanTrue);
        if (main_window) {
            CFStringRef _element_sub_role = NULL;
            AXUIElementCopyAttributeValue(_window, kAXSubroleAttribute, (CFTypeRef *) &_element_sub_role);
            if (_element_sub_role) {
                main_window = !CFEqual(_element_sub_role, kAXDialogSubrole);
                if (verbose && !main_window) { NSLog(@"Dialog window"); }
                CFRelease(_element_sub_role);
            }
        }
        CFRelease(_result);
    }

    bool finder_app = titleEquals(_app, @[Finder]);
    main_window = main_window && (chrome_app || finder_app ||
        !titleEquals(_window, @[NoTitle]) ||
        titleEquals(_app, mainWindowAppsWithoutTitle));

    main_window = main_window || (!finder_app && is_full_screen(_window));

    if (verbose && !main_window) { NSLog(@"Not a main window"); }
    return main_window;
}

bool is_pwa(NSString * bundleIdentifier) {
    NSArray * components = [bundleIdentifier componentsSeparatedByString: @"."];
    bool pake = components.count == 3 && [components[1] isEqual: Pake];
    bool pwa = pake || (components.count > 4 &&
        [pwas containsObject: components[2]] && [components[3] isEqual: @"app"]);
    if (verbose && pwa) { NSLog(@"PWA: %@", components[2]); }
    return pwa;
}
