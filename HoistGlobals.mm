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

// ---- Global variables ----

CGPoint oldCorrectedPoint = {0, 0};

#ifdef FOCUS_FIRST
int raiseDelayCount = 0;
pid_t lastFocusedWindow_pid;
AXUIElementRef _lastFocusedWindow = NULL;
#endif

AXObserverRef axObserver = NULL;
uint64_t lastDestroyedMouseWindow_id = kCGNullWindowID;

CFMachPortRef eventTap = NULL;
char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
bool activated_by_task_switcher = false;
AXUIElementRef _accessibility_object = AXUIElementCreateSystemWide();
AXUIElementRef _previousFinderWindow = NULL;
AXUIElementRef _dock_app = NULL;
NSArray * ignoreApps = NULL;
NSArray * ignoreTitles = NULL;
NSArray * stayFocusedBundleIds = NULL;
NSArray * const mainWindowAppsWithoutTitle =@[
    @"System Settings",
    @"System Information",
    @"Photos",
    @"Calculator",
    @"Podcasts",
    @"Stickies Pro",
    @"Reeder"
];
NSArray * pwas = @[
    @"Chrome",
    @"Chromium",
    @"Vivaldi",
    @"Brave",
    @"Opera",
    @"edgemac",
    @"helium"
];
NSArray * AppsRaisingOnFocus = @[@"IntelliJ IDEA", @"PyCharm", @"WebStorm", @"Arc", @"Dia"];
NSString * const DockBundleId = @"com.apple.dock";
NSString * const FinderBundleId = @"com.apple.finder";
NSString * const LittleSnitchBundleId = @"at.obdev.littlesnitch";
NSString * const AssistiveControl = @"AssistiveControl";
NSString * const MissionControl = @"Mission Control";
NSString * const BartenderBar = @"Bartender Bar";
NSString * const AppStoreSearchResults = @"Search results";
NSString * const Untitled = @"Untitled";
NSString * const Zim = @"Zim";
NSString * const XQuartz = @"XQuartz";
NSString * const Finder = @"Finder";
NSString * const Pake = @"pake";
NSString * const NoTitle = @"";
CGPoint desktopOrigin = {0, 0};
CGPoint oldPoint = {0, 0};
bool propagateMouseMoved = false;
bool requireMouseStop = true;
bool ignoreSpaceChanged = false;
bool invertDisableKey = false;
bool invertIgnoreApps = false;
bool spaceHasChanged = false;
bool appWasActivated = false;
bool altTaskSwitcher = false;
bool warpMouse = false;
bool verbose = false;
float warpX = 0.5;
float warpY = 0.5;
float oldScale = 1;
float cursorScale = 2;
float mouseDelta = 0;
int ignoreTimes = 0;
int raiseTimes = 0;
int delayTicks = 0;
int delayCount = 0;
int pollMillis = 0;
int disableKey = 0;
int scaleDurationMs = 600;
bool showIcon = true;
bool disableWhenNoExternalScreen = false;
bool autoDisabledForScreen = false;

// ---- Config key constants ----

const NSString *kDelay = @"delay";
const NSString *kWarpX = @"warpX";
const NSString *kWarpY = @"warpY";
const NSString *kScale = @"scale";
const NSString *kVerbose = @"verbose";
const NSString *kAltTaskSwitcher = @"altTaskSwitcher";
const NSString *kRequireMouseStop = @"requireMouseStop";
const NSString *kIgnoreSpaceChanged = @"ignoreSpaceChanged";
const NSString *kStayFocusedBundleIds = @"stayFocusedBundleIds";
const NSString *kInvertDisableKey = @"invertDisableKey";
const NSString *kInvertIgnoreApps = @"invertIgnoreApps";
const NSString *kIgnoreApps = @"ignoreApps";
const NSString *kIgnoreTitles = @"ignoreTitles";
const NSString *kMouseDelta = @"mouseDelta";
const NSString *kPollMillis = @"pollMillis";
const NSString *kDisableKey = @"disableKey";
const NSString *kScaleDuration = @"scaleDuration";
const NSString *kShowIcon = @"showIcon";
const NSString *kDisableWhenNoExternalScreen = @"disableWhenNoExternalScreen";
#ifdef FOCUS_FIRST
const NSString *kFocusDelay = @"focusDelay";
NSArray *parametersDictionary = @[kDelay, kWarpX, kWarpY, kScale, kVerbose, kAltTaskSwitcher,
    kFocusDelay, kRequireMouseStop, kIgnoreSpaceChanged, kInvertDisableKey, kInvertIgnoreApps,
    kIgnoreApps, kIgnoreTitles, kStayFocusedBundleIds, kDisableKey, kMouseDelta, kPollMillis,
    kScaleDuration, kShowIcon, kDisableWhenNoExternalScreen];
#else
NSArray *parametersDictionary = @[kDelay, kWarpX, kWarpY, kScale, kVerbose, kAltTaskSwitcher,
    kRequireMouseStop, kIgnoreSpaceChanged, kInvertDisableKey, kInvertIgnoreApps, kIgnoreApps,
    kIgnoreTitles, kStayFocusedBundleIds, kDisableKey, kMouseDelta, kPollMillis, kScaleDuration,
    kShowIcon, kDisableWhenNoExternalScreen];
#endif
NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
