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
 * Tests for the "auto-disable when no external screen" state machine.
 * Drives applyScreenAutoDisableForExternal(external) directly so the disable/
 * restore transitions are testable without real displays.
 */

#import "test_harness.h"
#import "../Hoist.h"

// Reset the globals the screen auto-disable logic reads/writes.
static void reset_screen(void) {
    disableWhenNoExternalScreen = false;
    autoDisabledForScreen = false;
    delayCount = 0;
    savedDelayCount = 0;
}

// --- Option enabled ---

static void test_disables_when_external_lost_while_enabled(void) {
    reset_screen();
    disableWhenNoExternalScreen = true;
    delayCount = 5;                 // currently enabled
    applyScreenAutoDisableForExternal(false);   // external disconnected
    ASSERT_EQ_INT(0, delayCount, "delayCount goes to 0 (disabled)");
    ASSERT_EQ_INT(5, savedDelayCount, "previous delay is saved");
    ASSERT_TRUE(autoDisabledForScreen, "marked as auto-disabled");
}

// This is the regression guard for the reported "doesn't re-enable" bug.
static void test_reenables_when_external_reconnected(void) {
    reset_screen();
    disableWhenNoExternalScreen = true;
    autoDisabledForScreen = true;   // we previously auto-disabled
    delayCount = 0;
    savedDelayCount = 5;
    applyScreenAutoDisableForExternal(true);    // external reconnected
    ASSERT_EQ_INT(5, delayCount, "delay restored on reconnect");
    ASSERT_FALSE(autoDisabledForScreen, "auto-disable cleared on reconnect");
}

static void test_reenable_falls_back_to_one_when_no_saved(void) {
    reset_screen();
    disableWhenNoExternalScreen = true;
    autoDisabledForScreen = true;
    delayCount = 0;
    savedDelayCount = 0;            // nothing saved
    applyScreenAutoDisableForExternal(true);
    ASSERT_EQ_INT(1, delayCount, "restore falls back to delay 1 when nothing was saved");
    ASSERT_FALSE(autoDisabledForScreen, "auto-disable cleared");
}

static void test_no_autodisable_when_already_disabled(void) {
    reset_screen();
    disableWhenNoExternalScreen = true;
    delayCount = 0;                 // already disabled by the user
    applyScreenAutoDisableForExternal(false);
    ASSERT_FALSE(autoDisabledForScreen, "must not claim ownership of a user-disabled state");
    ASSERT_EQ_INT(0, delayCount, "stays disabled");
}

static void test_noop_when_external_present_and_not_autodisabled(void) {
    reset_screen();
    disableWhenNoExternalScreen = true;
    delayCount = 5;
    applyScreenAutoDisableForExternal(true);    // normal: external present, enabled
    ASSERT_EQ_INT(5, delayCount, "no change in the normal enabled+external state");
    ASSERT_FALSE(autoDisabledForScreen, "no auto-disable claimed");
}

static void test_does_not_redisable_after_reconnect_handled(void) {
    reset_screen();
    disableWhenNoExternalScreen = true;
    autoDisabledForScreen = false;  // already restored
    delayCount = 5;
    applyScreenAutoDisableForExternal(true);
    ASSERT_EQ_INT(5, delayCount, "idempotent once restored");
    ASSERT_FALSE(autoDisabledForScreen, "stays restored");
}

// --- Option disabled (cleanup path) ---

static void test_option_off_undoes_previous_autodisable(void) {
    reset_screen();
    disableWhenNoExternalScreen = false;
    autoDisabledForScreen = true;   // we had auto-disabled earlier
    delayCount = 0;
    savedDelayCount = 5;
    applyScreenAutoDisableForExternal(false);   // external value irrelevant when option off
    ASSERT_EQ_INT(5, delayCount, "turning the option off restores the saved delay");
    ASSERT_FALSE(autoDisabledForScreen, "auto-disable cleared when option off");
}

static void test_option_off_leaves_manual_state_alone(void) {
    reset_screen();
    disableWhenNoExternalScreen = false;
    autoDisabledForScreen = false;  // user controls state
    delayCount = 0;                 // user disabled manually
    applyScreenAutoDisableForExternal(true);
    ASSERT_EQ_INT(0, delayCount, "option off must not touch a manual disable");
}

void run_screen_tests(void) {
    RUN_TEST(test_disables_when_external_lost_while_enabled);
    RUN_TEST(test_reenables_when_external_reconnected);
    RUN_TEST(test_reenable_falls_back_to_one_when_no_saved);
    RUN_TEST(test_no_autodisable_when_already_disabled);
    RUN_TEST(test_noop_when_external_present_and_not_autodisabled);
    RUN_TEST(test_does_not_redisable_after_reconnect_handled);
    RUN_TEST(test_option_off_undoes_previous_autodisable);
    RUN_TEST(test_option_off_leaves_manual_state_alone);
}
