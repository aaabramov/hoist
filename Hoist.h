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

#ifndef HOIST_H
#define HOIST_H

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <Carbon/Carbon.h>
#include <ServiceManagement/ServiceManagement.h>
#include <libproc.h>

// ---- Constants ----

#define HOIST_VERSION "5.6"
#define STACK_THRESHOLD 20

#ifdef EXPERIMENTAL_FOCUS_FIRST
#if SKYLIGHT_AVAILABLE
#define FOCUS_FIRST
#else
#pragma message "Skylight api is unavailable, Focus First is disabled"
#endif
#endif

#define WINDOW_CORRECTION 3
#define MENUBAR_CORRECTION 8
#define SCREEN_EDGE_CORRECTION 1
#define ACTIVATE_DELAY_MS 10
#define SCALE_DELAY_MS 400
#define TASK_SWITCHER_MODIFIER_KEY kCGEventFlagMaskCommand

// ---- Private API declarations ----

#ifdef FOCUS_FIRST
#define kCPSUserGenerated 0x200
extern "C" CGError SLPSPostEventRecordTo(ProcessSerialNumber *psn, uint8_t *bytes);
extern "C" CGError _SLPSSetFrontProcessWithOptions(
  ProcessSerialNumber *psn, uint32_t wid, uint32_t mode);
#endif

typedef int CGSConnectionID;
extern "C" CGSConnectionID CGSMainConnectionID(void);
extern "C" CGError CGSSetCursorScale(CGSConnectionID connectionId, float scale);
extern "C" CGError CGSGetCursorScale(CGSConnectionID connectionId, float *scale);
extern "C" AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID *out);

// ---- menuDelayCount macro ----

#ifdef FOCUS_FIRST
#define menuDelayCount raiseDelayCount
#else
#define menuDelayCount delayCount
#endif

// ---- Extern globals ----

extern CGPoint oldCorrectedPoint;

#ifdef FOCUS_FIRST
extern int raiseDelayCount;
extern pid_t lastFocusedWindow_pid;
extern AXUIElementRef _lastFocusedWindow;
#endif

extern AXObserverRef axObserver;
extern uint64_t lastDestroyedMouseWindow_id;

extern CFMachPortRef eventTap;
extern char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
extern bool activated_by_task_switcher;
extern AXUIElementRef _accessibility_object;
extern AXUIElementRef _previousFinderWindow;
extern AXUIElementRef _dock_app;
extern NSArray * ignoreApps;
extern NSArray * ignoreTitles;
extern NSArray * stayFocusedBundleIds;
extern NSArray * const mainWindowAppsWithoutTitle;
extern NSArray * pwas;
extern NSArray * AppsRaisingOnFocus;
extern NSString * const DockBundleId;
extern NSString * const FinderBundleId;
extern NSString * const LittleSnitchBundleId;
extern NSString * const AssistiveControl;
extern NSString * const MissionControl;
extern NSString * const BartenderBar;
extern NSString * const AppStoreSearchResults;
extern NSString * const Untitled;
extern NSString * const Zim;
extern NSString * const XQuartz;
extern NSString * const Finder;
extern NSString * const Pake;
extern NSString * const NoTitle;
extern CGPoint desktopOrigin;
extern CGPoint oldPoint;
extern bool propagateMouseMoved;
extern bool requireMouseStop;
extern bool ignoreSpaceChanged;
extern bool invertDisableKey;
extern bool invertIgnoreApps;
extern bool spaceHasChanged;
extern bool appWasActivated;
extern bool altTaskSwitcher;
extern bool warpMouse;
extern bool verbose;
extern float warpX;
extern float warpY;
extern float oldScale;
extern float cursorScale;
extern float mouseDelta;
extern int ignoreTimes;
extern int raiseTimes;
extern int delayTicks;
extern int delayCount;
extern int pollMillis;
extern int disableKey;
extern int scaleDurationMs;
extern bool showIcon;
extern bool disableWhenNoExternalScreen;
extern bool autoDisabledForScreen;

// ---- Config key constants ----

extern const NSString *kDelay;
extern const NSString *kWarpX;
extern const NSString *kWarpY;
extern const NSString *kScale;
extern const NSString *kVerbose;
extern const NSString *kAltTaskSwitcher;
extern const NSString *kRequireMouseStop;
extern const NSString *kIgnoreSpaceChanged;
extern const NSString *kStayFocusedBundleIds;
extern const NSString *kInvertDisableKey;
extern const NSString *kInvertIgnoreApps;
extern const NSString *kIgnoreApps;
extern const NSString *kIgnoreTitles;
extern const NSString *kMouseDelta;
extern const NSString *kPollMillis;
extern const NSString *kDisableKey;
extern const NSString *kScaleDuration;
extern const NSString *kShowIcon;
extern const NSString *kDisableWhenNoExternalScreen;
#ifdef FOCUS_FIRST
extern const NSString *kFocusDelay;
#endif
extern NSArray *parametersDictionary;
extern NSMutableDictionary *parameters;

// ---- Class interfaces ----

@class StatusBarController;
@class PreferencesWindowController;

@interface MDWorkspaceWatcher : NSObject {}
- (id)init;
- (void)updateWarpObserver;
- (void)onTick:(NSNumber *)timerInterval;
- (void)onAppActivated;
- (void)onScaleCursorUp;
- (void)onScaleCursorDown;
#ifdef FOCUS_FIRST
- (void)windowFocused:(AXUIElementRef)_window;
#endif
@end

extern MDWorkspaceWatcher * workspaceWatcher;

@interface ConfigClass : NSObject
- (NSString *) getFilePath:(NSString *) filename;
- (void) readConfig:(int) argc;
- (void) readHiddenConfig;
- (void) applyConfigDictionary:(NSDictionary *) json;
- (void) applyCLIOverrides:(NSDictionary *) arguments;
- (void) validateParameters;
+ (NSMutableDictionary *) buildConfigDictionary;
+ (void) saveConfig;
@end

@interface PreferencesWindowController : NSObject <NSTextFieldDelegate>
@property (strong, nonatomic) NSPanel *panel;
@property (strong, nonatomic) NSSlider *pollMillisSlider;
@property (strong, nonatomic) NSTextField *pollMillisLabel;
@property (strong, nonatomic) NSSlider *delaySlider;
@property (strong, nonatomic) NSTextField *delayLabel;
@property (strong, nonatomic) NSSlider *scaleDurationSlider;
@property (strong, nonatomic) NSTextField *scaleDurationLabel;
@property (strong, nonatomic) NSSlider *warpXSlider;
@property (strong, nonatomic) NSTextField *warpXLabel;
@property (strong, nonatomic) NSSlider *warpYSlider;
@property (strong, nonatomic) NSTextField *warpYLabel;
@property (strong, nonatomic) NSPopUpButton *disableKeyPopUp;
@property (strong, nonatomic) NSTextField *ignoreAppsField;
@property (strong, nonatomic) NSTextField *ignoreTitlesField;
@property (strong, nonatomic) NSButton *launchAtLoginCheckbox;
@property (strong, nonatomic) NSButton *showIconCheckbox;
@property (strong, nonatomic) NSButton *autoDisableScreenCheckbox;
+ (instancetype)shared;
- (void)showWindow;
- (NSString *)ignoreAppsString;
@end

@interface StatusBarController : NSObject <NSMenuDelegate>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSMenu *menu;
- (void) saveConfig;
- (void) updateIconState;
@end

extern StatusBarController *statusBarController;
extern int savedDelayCount;

// ---- Free function prototypes ----

// Helpers
void activate(pid_t pid);
void raiseAndActivate(AXUIElementRef _window, pid_t window_pid);
void logWindowTitle(NSString * prefix, AXUIElementRef _window);
bool titleEquals(AXUIElementRef _element, NSArray * _titles, NSArray * _patterns = NULL, bool logTitle = false);
bool dock_active();
bool mc_active();
NSDictionary * topwindow(CGPoint point);
AXUIElementRef fallback(CGPoint point);
AXUIElementRef get_raisable_window(AXUIElementRef _element, CGPoint point, int count);
AXUIElementRef get_mousewindow(CGPoint point);
CGPoint get_mousepoint(AXUIElementRef _window);
bool contained_within(AXUIElementRef _window1, AXUIElementRef _window2);
void findDockApplication();
void findDesktopOrigin();
NSScreen * findScreen(CGPoint point);
bool hasExternalScreen();
void applyScreenAutoDisable();
bool is_desktop_window(AXUIElementRef _window);
bool is_full_screen(AXUIElementRef _window);
bool is_main_window(AXUIElementRef _app, AXUIElementRef _window, bool chrome_app);
bool is_pwa(NSString * bundleIdentifier);

#ifdef FOCUS_FIRST
void window_manager_make_key_window(ProcessSerialNumber * _window_psn, uint32_t window_id);
void window_manager_focus_window_without_raise(
    ProcessSerialNumber * _window_psn, uint32_t window_id,
    ProcessSerialNumber * _focused_window_psn, uint32_t focused_window_id);
#endif

// Main event loop
void spaceChanged();
bool appActivated();
void onTick();
void AXCallback(AXObserverRef observer, AXUIElementRef _element, CFStringRef notification, void * destroyedMouseWindow_id);
CGEventRef eventTapHandler(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo);

#endif // HOIST_H
