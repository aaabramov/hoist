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

//-----------------------------------------------notifications----------------------------------------------

MDWorkspaceWatcher * workspaceWatcher = NULL;

@implementation MDWorkspaceWatcher
- (id)init {
    if ((self = [super init])) {
        NSNotificationCenter * center =
            [[NSWorkspace sharedWorkspace] notificationCenter];
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
        if (warpMouse) {
            [center
                addObserver: self
                selector: @selector(appActivated:)
                name: NSWorkspaceDidActivateApplicationNotification
                object: nil];
            if (verbose) { NSLog(@"Registered app activated selector"); }
        }
    }
    return self;
}

- (void)updateWarpObserver {
    NSNotificationCenter * center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center removeObserver:self name:NSWorkspaceDidActivateApplicationNotification object:nil];
    if (warpMouse) {
        [center addObserver:self selector:@selector(appActivated:)
            name:NSWorkspaceDidActivateApplicationNotification object:nil];
        if (verbose) { NSLog(@"Registered app activated selector"); }
    } else {
        if (verbose) { NSLog(@"Unregistered app activated selector"); }
    }
}

- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)spaceChanged:(NSNotification *)notification {
    if (verbose) { NSLog(@"Space changed"); }
    spaceChanged();
}

- (void)screenParametersChanged:(NSNotification *)notification {
    if (verbose) { NSLog(@"Screen parameters changed"); }
    applyScreenAutoDisable();
}

- (void)appActivated:(NSNotification *)notification {
    if (verbose) { NSLog(@"App activated, waiting %0.3fs", ACTIVATE_DELAY_MS/1000.0); }
    [self performSelector: @selector(onAppActivated) withObject: nil afterDelay: ACTIVATE_DELAY_MS/1000.0];
}

- (void)onAppActivated {
    if (appActivated() && cursorScale != oldScale) {
        [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(onScaleCursorUp) object: nil];
        [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(onScaleCursorDown) object: nil];
        if (verbose) { NSLog(@"Set cursor scale after %0.3fs", SCALE_DELAY_MS/1000.0); }
        [self performSelector: @selector(onScaleCursorUp)
            withObject: nil
            afterDelay: SCALE_DELAY_MS/1000.0];
        [self performSelector: @selector(onScaleCursorDown)
            withObject: nil
            afterDelay: (SCALE_DELAY_MS + scaleDurationMs)/1000.0];
    }
}

- (void)onScaleCursorUp {
    if (verbose) { NSLog(@"Set cursor scale: %.0f (up)", cursorScale); }
    CGSSetCursorScale(CGSMainConnectionID(), cursorScale);
}

- (void)onScaleCursorDown {
    if (verbose) { NSLog(@"Set cursor scale: %.0f (down)", oldScale); }
    CGSSetCursorScale(CGSMainConnectionID(), oldScale);
}

- (void)onTick:(NSNumber *)timerInterval {
    [self performSelector: @selector(onTick:)
        withObject: timerInterval
        afterDelay: pollMillis/1000.0];
    onTick();
}

#ifdef FOCUS_FIRST
- (void)windowFocused:(AXUIElementRef)_window {
    if (verbose) { NSLog(@"Window focused, waiting %0.3fs", raiseDelayCount*pollMillis/1000.0); }
    [self performSelector: @selector(onWindowFocused:)
        withObject: [NSNumber numberWithUnsignedLong: (uint64_t) _window]
        afterDelay: raiseDelayCount*pollMillis/1000.0];
}

- (void)onWindowFocused:(NSNumber *)_window {
    if (_window.unsignedLongValue == (uint64_t) _lastFocusedWindow) {
        raiseAndActivate(_lastFocusedWindow, lastFocusedWindow_pid);
    } else if (verbose) { NSLog(@"Ignoring window focused event"); }
}
#endif
@end // MDWorkspaceWatcher
