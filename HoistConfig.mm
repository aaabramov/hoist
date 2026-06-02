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

@implementation ConfigClass
- (NSString *) getFilePath:(NSString *) filename {
    filename = [NSString stringWithFormat: @"%@/%@", NSHomeDirectory(), filename];
    if (not [[NSFileManager defaultManager] fileExistsAtPath: filename]) { filename = NULL; }
    return filename;
}

- (void) readConfig:(int) argc {
    // Always read config file first as a base
    [self readHiddenConfig];

    // CLI arguments (e.g. -delay 3) override config file values.
    // Only check NSArgumentDomain to avoid picking up registered defaults.
    if (argc > 1) {
        NSDictionary *arguments = [[NSUserDefaults standardUserDefaults]
            volatileDomainForName: NSArgumentDomain];

        for (id key in parametersDictionary) {
            id arg = arguments[key];
            if (arg != NULL) {
                NSLog(@"CLI override: %@ = %@", key, arg);
                parameters[key] = arg;
            }
        }
    }
    NSLog(@"Config result: delay=%@, warpX=%@, warpY=%@, scale=%@, scaleDuration=%@",
        parameters[kDelay], parameters[kWarpX], parameters[kWarpY],
        parameters[kScale], parameters[kScaleDuration]);
    return;
}

- (void) readHiddenConfig {
    NSString * configFilePath = [self getFilePath: @".config/hoist/config.json"];

    if (configFilePath) {
        NSLog(@"Reading config from: %@", configFilePath);
        NSError * error;
        NSData * data = [NSData dataWithContentsOfFile: configFilePath];
        if (!data) { return; }

        NSDictionary * json = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &error];
        if (!json || error) {
            NSLog(@"Error parsing config JSON: %@", error.localizedDescription);
            return;
        }

        for (id key in parametersDictionary) {
            id value = json[key];
            if (value != nil) {
                if ([value isKindOfClass: [NSArray class]]) {
                    parameters[key] = [value componentsJoinedByString: @","];
                } else if ([value isKindOfClass: [NSNumber class]]) {
                    // NSNumber can be bool, int, or float
                    if (strcmp([value objCType], @encode(BOOL)) == 0 ||
                        strcmp([value objCType], @encode(char)) == 0) {
                        parameters[key] = [value boolValue] ? @"true" : @"false";
                    } else {
                        parameters[key] = [value stringValue];
                    }
                } else {
                    parameters[key] = [NSString stringWithFormat: @"%@", value];
                }
            }
        }
    }
    return;
}

- (void) validateParameters {
    // validate and fix wrong/absent parameters
    if (!parameters[kDelay]) { parameters[kDelay] = @"1"; }
#ifdef FOCUS_FIRST
    if (!parameters[kFocusDelay]) { parameters[kFocusDelay] = @"1"; }
#endif
    if (!parameters[kRequireMouseStop]) { parameters[kRequireMouseStop] = @"true"; }
    if ([parameters[kPollMillis] intValue] < 20) { parameters[kPollMillis] = @"50"; }
    if ([parameters[kMouseDelta] floatValue] < 0) { parameters[kMouseDelta] = @"0"; }
    if ([parameters[kScale] floatValue] < 1) { parameters[kScale] = @"2.0"; }
    if (!parameters[kDisableKey]) { parameters[kDisableKey] = @"control"; }
    if ([parameters[kScaleDuration] intValue] < 200) { parameters[kScaleDuration] = @"600"; }
    if (!parameters[kWarpX]) { parameters[kWarpX] = @"0.5"; }
    if (!parameters[kWarpY]) { parameters[kWarpY] = @"0.5"; }
    warpMouse =
        [parameters[kWarpX] floatValue] > 0 && [parameters[kWarpX] floatValue] <= 1 &&
        [parameters[kWarpY] floatValue] > 0 && [parameters[kWarpY] floatValue] <= 1;
#ifdef ALTERNATIVE_TASK_SWITCHER
    if (!parameters[kAltTaskSwitcher]) { parameters[kAltTaskSwitcher] = @"true"; }
#endif
#ifdef FOCUS_FIRST
    if (![parameters[kDelay] intValue] && !parameters[kFocusDelay]) { parameters[kFocusDelay] = @"1"; }
    if (!parameters[kDelay] && ![parameters[kFocusDelay] intValue]) { parameters[kDelay] = @"1"; }
#endif
    return;
}
+ (void) saveConfig {
    NSString *configDir = [NSString stringWithFormat:@"%@/.config/hoist", NSHomeDirectory()];
    NSString *configPath = [NSString stringWithFormat:@"%@/config.json", configDir];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:configDir]) {
        [fm createDirectoryAtPath:configDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSMutableDictionary *config = [[NSMutableDictionary alloc] init];
    config[@"delay"] = @(menuDelayCount ? menuDelayCount : savedDelayCount);
    config[@"warpX"] = @(warpX);
    config[@"warpY"] = @(warpY);
    config[@"scale"] = @(cursorScale);
    config[@"scaleDuration"] = @(scaleDurationMs);
    config[@"pollMillis"] = @(pollMillis);
    config[@"requireMouseStop"] = @(requireMouseStop);
    config[@"ignoreSpaceChanged"] = @(ignoreSpaceChanged);
    config[@"altTaskSwitcher"] = @(altTaskSwitcher);

    if (disableKey == (int)kCGEventFlagMaskControl) {
        config[@"disableKey"] = @"control";
    } else if (disableKey == (int)kCGEventFlagMaskAlternate) {
        config[@"disableKey"] = @"option";
    } else {
        config[@"disableKey"] = @"disabled";
    }

    NSString *ignoreAppsStr = [[PreferencesWindowController shared] ignoreAppsString];
    if (ignoreAppsStr.length) {
        config[@"ignoreApps"] = [ignoreAppsStr componentsSeparatedByString:@","];
    }
    NSString *ignoreTitlesStr = [ignoreTitles componentsJoinedByString:@","];
    if (ignoreTitlesStr.length) {
        config[@"ignoreTitles"] = [ignoreTitlesStr componentsSeparatedByString:@","];
    }
    config[@"showIcon"] = @(showIcon);
    config[@"disableWhenNoExternalScreen"] = @(disableWhenNoExternalScreen);
    if (mouseDelta > 0) { config[@"mouseDelta"] = @(mouseDelta); }
    if (verbose) { config[@"verbose"] = @YES; }

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:config
        options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    [jsonData writeToFile:configPath atomically:YES];
}

@end // ConfigClass
