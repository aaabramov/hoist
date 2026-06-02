/*
 * Hoist - Copyright (C) 2026 aaabramov
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
 *
 * Link stubs for the unit-test binary.
 *
 * The pure-logic production sources we test (HoistConfig, HoistHelpers) reference
 * a few symbols that live in the GUI / main-loop translation units we deliberately
 * exclude from the headless test binary. We provide minimal stand-ins here so the
 * test binary links. None of these stubs are exercised by the tests; they exist
 * purely to satisfy the linker.
 */

#import "../Hoist.h"

// ConfigClass::saveConfig sends +shared/-ignoreAppsString to this class.
@implementation PreferencesWindowController
+ (instancetype)shared { return nil; }
- (void)showWindow {}
- (NSString *)ignoreAppsString { return @""; }
@end

// Referenced by HoistHelpers' applyScreenAutoDisable() (not exercised by tests).
// Lives in HoistUI.mm in the real app; stubbed here so the GUI TU stays out.
StatusBarController *statusBarController = nil;
