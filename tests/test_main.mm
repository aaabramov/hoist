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
 * Unit-test runner. Owns the harness counters and main().
 */

#import "test_harness.h"

int g_tests_run = 0;
int g_tests_failed = 0;
int g_asserts_failed_in_test = 0;

void hoist_run_test(const char *name, hoist_test_fn fn) {
    g_asserts_failed_in_test = 0;
    fn();
    g_tests_run++;
    if (g_asserts_failed_in_test > 0) {
        g_tests_failed++;
        printf("[FAIL] %s (%d assertion failure%s)\n",
               name, g_asserts_failed_in_test,
               g_asserts_failed_in_test == 1 ? "" : "s");
    } else {
        printf("[ ok ] %s\n", name);
    }
}

int hoist_test_summary(void) {
    printf("\n%d tests run, %d failed.\n", g_tests_run, g_tests_failed);
    return g_tests_failed == 0 ? 0 : 1;
}

extern void run_config_tests(void);
extern void run_helper_tests(void);
extern void run_screen_tests(void);

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        run_config_tests();
        run_helper_tests();
        run_screen_tests();
        return hoist_test_summary();
    }
}
