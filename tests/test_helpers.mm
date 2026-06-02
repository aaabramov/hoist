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
 * Tests for pure helper functions in HoistHelpers.mm.
 */

#import "test_harness.h"
#import "../Hoist.h"

// is_pwa() classifies a bundle identifier by its dot-separated segments:
//  - a "pake" wrapper: exactly 3 segments with the 2nd equal to "pake"
//  - a browser PWA: >4 segments, 3rd segment a known browser, 4th equal to "app"

static void test_is_pwa_detects_chrome_pwa(void) {
    ASSERT_TRUE(is_pwa(@"com.google.Chrome.app.fmgjjmmmlfnkbppncabfk"),
                "Chrome PWA bundle id should be detected");
}

static void test_is_pwa_detects_pake_wrapper(void) {
    ASSERT_TRUE(is_pwa(@"com.pake.myapp"),
                "pake-wrapped app bundle id should be detected");
}

static void test_is_pwa_rejects_regular_app(void) {
    ASSERT_FALSE(is_pwa(@"com.apple.finder"),
                 "a regular three-segment app id is not a PWA");
}

static void test_is_pwa_requires_app_segment(void) {
    ASSERT_FALSE(is_pwa(@"com.google.Chrome.helper.x"),
                 "a known browser id without an \"app\" segment is not a PWA");
}

static void test_is_pwa_requires_known_browser(void) {
    ASSERT_FALSE(is_pwa(@"com.acme.Unknown.app.x"),
                 "an unknown browser id is not a PWA even with an \"app\" segment");
}

void run_helper_tests(void) {
    RUN_TEST(test_is_pwa_detects_chrome_pwa);
    RUN_TEST(test_is_pwa_detects_pake_wrapper);
    RUN_TEST(test_is_pwa_rejects_regular_app);
    RUN_TEST(test_is_pwa_requires_app_segment);
    RUN_TEST(test_is_pwa_requires_known_browser);
}
