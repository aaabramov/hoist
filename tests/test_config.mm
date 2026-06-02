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
 * Tests for ConfigClass: JSON->parameters coercion, validation defaults/clamping,
 * and CLI-argument override precedence.
 */

#import "test_harness.h"
#import "../Hoist.h"

static ConfigClass *cfg(void) { return [[ConfigClass alloc] init]; }

// `parameters` and the config globals are process-wide; reset before each test.
static void reset(void) {
    [parameters removeAllObjects];
    warpMouse = false;
    disableKey = 0;
    savedDelayCount = 0;
    delayCount = 0;
    mouseDelta = 0;
    verbose = false;
    ignoreTitles = nil;
}

// ---- JSON dictionary -> parameters coercion ----

static void test_coerce_bool_true_to_string(void) {
    reset();
    [cfg() applyConfigDictionary:@{kVerbose: @YES}];
    ASSERT_EQ_STR(@"true", parameters[kVerbose], "JSON true should coerce to \"true\"");
}

static void test_coerce_bool_false_to_string(void) {
    reset();
    [cfg() applyConfigDictionary:@{kVerbose: @NO}];
    ASSERT_EQ_STR(@"false", parameters[kVerbose], "JSON false should coerce to \"false\"");
}

static void test_coerce_int_to_string(void) {
    reset();
    [cfg() applyConfigDictionary:@{kPollMillis: @120}];
    ASSERT_EQ_STR(@"120", parameters[kPollMillis], "JSON int should coerce to its string form");
}

static void test_coerce_float_to_string(void) {
    reset();
    [cfg() applyConfigDictionary:@{kScale: @2.5}];
    ASSERT_EQ_STR(@"2.5", parameters[kScale], "JSON float should coerce to its string form");
}

static void test_coerce_array_to_csv(void) {
    reset();
    [cfg() applyConfigDictionary:@{kIgnoreApps: @[@"Safari", @"Mail"]}];
    ASSERT_EQ_STR(@"Safari,Mail", parameters[kIgnoreApps], "JSON array should join with commas");
}

static void test_coerce_string_passthrough(void) {
    reset();
    [cfg() applyConfigDictionary:@{kDisableKey: @"option"}];
    ASSERT_EQ_STR(@"option", parameters[kDisableKey], "JSON string should pass through unchanged");
}

static void test_coerce_ignores_unknown_keys(void) {
    reset();
    [cfg() applyConfigDictionary:@{@"totallyBogusKey": @"x"}];
    ASSERT_TRUE(parameters[@"totallyBogusKey"] == nil,
                "keys not in parametersDictionary must be ignored");
}

// ---- validateParameters: defaults + clamping ----

static void test_validate_applies_defaults_on_empty(void) {
    reset();
    [cfg() validateParameters];
    ASSERT_EQ_STR(@"1",       parameters[kDelay],            "default delay");
    ASSERT_EQ_STR(@"true",    parameters[kRequireMouseStop], "default requireMouseStop");
    ASSERT_EQ_STR(@"50",      parameters[kPollMillis],       "default pollMillis (clamped from 0)");
    ASSERT_EQ_STR(@"2.0",     parameters[kScale],            "default scale");
    ASSERT_EQ_STR(@"control", parameters[kDisableKey],       "default disableKey");
    ASSERT_EQ_STR(@"600",     parameters[kScaleDuration],    "default scaleDuration");
    ASSERT_EQ_STR(@"0.5",     parameters[kWarpX],            "default warpX");
    ASSERT_EQ_STR(@"0.5",     parameters[kWarpY],            "default warpY");
    ASSERT_TRUE(warpMouse, "warpMouse should be true for default warp 0.5/0.5");
}

static void test_validate_clamps_low_pollMillis(void) {
    reset();
    parameters[kPollMillis] = @"5";
    [cfg() validateParameters];
    ASSERT_EQ_STR(@"50", parameters[kPollMillis], "pollMillis < 20 clamps to 50");
}

static void test_validate_keeps_valid_pollMillis(void) {
    reset();
    parameters[kPollMillis] = @"33";
    [cfg() validateParameters];
    ASSERT_EQ_STR(@"33", parameters[kPollMillis], "valid pollMillis is preserved");
}

static void test_validate_clamps_negative_mouseDelta(void) {
    reset();
    parameters[kMouseDelta] = @"-1";
    [cfg() validateParameters];
    ASSERT_EQ_STR(@"0", parameters[kMouseDelta], "negative mouseDelta clamps to 0");
}

static void test_validate_resets_scale_below_one(void) {
    reset();
    parameters[kScale] = @"0.5";
    [cfg() validateParameters];
    ASSERT_EQ_STR(@"2.0", parameters[kScale], "scale < 1 resets to 2.0");
}

static void test_validate_resets_low_scaleDuration(void) {
    reset();
    parameters[kScaleDuration] = @"100";
    [cfg() validateParameters];
    ASSERT_EQ_STR(@"600", parameters[kScaleDuration], "scaleDuration < 200 resets to 600");
}

static void test_validate_warpMouse_false_when_out_of_range(void) {
    reset();
    parameters[kWarpX] = @"1.5";
    parameters[kWarpY] = @"0.5";
    [cfg() validateParameters];
    ASSERT_FALSE(warpMouse, "warpMouse must be false when warpX is outside (0,1]");
}

// ---- CLI overrides ----

static void test_cli_override_replaces_value(void) {
    reset();
    parameters[kDelay] = @"1";
    [cfg() applyCLIOverrides:@{kDelay: @"5"}];
    ASSERT_EQ_STR(@"5", parameters[kDelay], "CLI arg should override existing value");
}

static void test_cli_override_leaves_other_keys(void) {
    reset();
    parameters[kScale] = @"2.0";
    [cfg() applyCLIOverrides:@{kDelay: @"5"}];
    ASSERT_EQ_STR(@"2.0", parameters[kScale], "keys absent from CLI args are untouched");
}

// ---- saveConfig serialization (buildConfigDictionary) ----

static void test_build_config_disableKey_control(void) {
    reset();
    disableKey = (int)kCGEventFlagMaskControl;
    NSDictionary *c = [ConfigClass buildConfigDictionary];
    ASSERT_EQ_STR(@"control", c[@"disableKey"], "control mask serializes to \"control\"");
}

static void test_build_config_disableKey_option(void) {
    reset();
    disableKey = (int)kCGEventFlagMaskAlternate;
    NSDictionary *c = [ConfigClass buildConfigDictionary];
    ASSERT_EQ_STR(@"option", c[@"disableKey"], "alternate mask serializes to \"option\"");
}

static void test_build_config_disableKey_disabled(void) {
    reset();
    disableKey = 0;
    NSDictionary *c = [ConfigClass buildConfigDictionary];
    ASSERT_EQ_STR(@"disabled", c[@"disableKey"], "no mask serializes to \"disabled\"");
}

static void test_build_config_delay_falls_back_to_saved(void) {
    reset();
    delayCount = 0;       // menuDelayCount (no active menu delay)
    savedDelayCount = 3;
    NSDictionary *c = [ConfigClass buildConfigDictionary];
    ASSERT_EQ_INT(3, [c[@"delay"] intValue], "delay falls back to savedDelayCount");
}

static void test_build_config_omits_mouseDelta_when_zero(void) {
    reset();
    mouseDelta = 0;
    NSDictionary *c = [ConfigClass buildConfigDictionary];
    ASSERT_TRUE(c[@"mouseDelta"] == nil, "mouseDelta is omitted when 0");
}

static void test_build_config_includes_mouseDelta_when_positive(void) {
    reset();
    mouseDelta = 2.5;
    NSDictionary *c = [ConfigClass buildConfigDictionary];
    ASSERT_EQ_FLOAT(2.5, [c[@"mouseDelta"] doubleValue], 0.0001, "mouseDelta included when > 0");
}

static void test_build_config_omits_verbose_when_false(void) {
    reset();
    verbose = false;
    NSDictionary *c = [ConfigClass buildConfigDictionary];
    ASSERT_TRUE(c[@"verbose"] == nil, "verbose is omitted when false");
}

void run_config_tests(void) {
    RUN_TEST(test_coerce_bool_true_to_string);
    RUN_TEST(test_coerce_bool_false_to_string);
    RUN_TEST(test_coerce_int_to_string);
    RUN_TEST(test_coerce_float_to_string);
    RUN_TEST(test_coerce_array_to_csv);
    RUN_TEST(test_coerce_string_passthrough);
    RUN_TEST(test_coerce_ignores_unknown_keys);
    RUN_TEST(test_validate_applies_defaults_on_empty);
    RUN_TEST(test_validate_clamps_low_pollMillis);
    RUN_TEST(test_validate_keeps_valid_pollMillis);
    RUN_TEST(test_validate_clamps_negative_mouseDelta);
    RUN_TEST(test_validate_resets_scale_below_one);
    RUN_TEST(test_validate_resets_low_scaleDuration);
    RUN_TEST(test_validate_warpMouse_false_when_out_of_range);
    RUN_TEST(test_cli_override_replaces_value);
    RUN_TEST(test_cli_override_leaves_other_keys);
    RUN_TEST(test_build_config_disableKey_control);
    RUN_TEST(test_build_config_disableKey_option);
    RUN_TEST(test_build_config_disableKey_disabled);
    RUN_TEST(test_build_config_delay_falls_back_to_saved);
    RUN_TEST(test_build_config_omits_mouseDelta_when_zero);
    RUN_TEST(test_build_config_includes_mouseDelta_when_positive);
    RUN_TEST(test_build_config_omits_verbose_when_false);
}
