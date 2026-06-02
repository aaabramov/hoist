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
 * Tiny dependency-free unit-test harness for Hoist.
 *
 * A "test" is a plain void() function. Assertion macros record failures into a
 * per-test counter; the runner (test_main.mm) reports pass/fail per test and
 * returns a non-zero exit code if any test failed.
 */

#ifndef HOIST_TEST_HARNESS_H
#define HOIST_TEST_HARNESS_H

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <math.h>

typedef void (*hoist_test_fn)(void);

// Defined in test_main.mm
extern int g_tests_run;
extern int g_tests_failed;
extern int g_asserts_failed_in_test;

void hoist_run_test(const char *name, hoist_test_fn fn);
int hoist_test_summary(void);

#define RUN_TEST(fn) hoist_run_test(#fn, (fn))

#define ASSERT_TRUE(cond, msg)                                                  \
    do {                                                                        \
        if (!(cond)) {                                                          \
            g_asserts_failed_in_test++;                                         \
            printf("    FAIL %s:%d: %s — expected true: %s\n",                  \
                   __FILE__, __LINE__, (msg), #cond);                           \
        }                                                                       \
    } while (0)

#define ASSERT_FALSE(cond, msg)                                                 \
    do {                                                                        \
        if ((cond)) {                                                           \
            g_asserts_failed_in_test++;                                         \
            printf("    FAIL %s:%d: %s — expected false: %s\n",                 \
                   __FILE__, __LINE__, (msg), #cond);                           \
        }                                                                       \
    } while (0)

#define ASSERT_EQ_INT(expected, actual, msg)                                    \
    do {                                                                        \
        long _e = (long)(expected);                                             \
        long _a = (long)(actual);                                               \
        if (_e != _a) {                                                         \
            g_asserts_failed_in_test++;                                         \
            printf("    FAIL %s:%d: %s — expected %ld, got %ld\n",              \
                   __FILE__, __LINE__, (msg), _e, _a);                          \
        }                                                                       \
    } while (0)

#define ASSERT_EQ_FLOAT(expected, actual, eps, msg)                             \
    do {                                                                        \
        double _e = (double)(expected);                                         \
        double _a = (double)(actual);                                           \
        if (fabs(_e - _a) > (eps)) {                                            \
            g_asserts_failed_in_test++;                                         \
            printf("    FAIL %s:%d: %s — expected %g, got %g\n",                \
                   __FILE__, __LINE__, (msg), _e, _a);                          \
        }                                                                       \
    } while (0)

// NSString equality (handles nil on either side).
#define ASSERT_EQ_STR(expected, actual, msg)                                    \
    do {                                                                        \
        NSString *_e = (expected);                                             \
        NSString *_a = (actual);                                               \
        BOOL _eq = (_e == nil && _a == nil) ||                                  \
                   (_e != nil && _a != nil && [_e isEqualToString:_a]);         \
        if (!_eq) {                                                             \
            g_asserts_failed_in_test++;                                         \
            printf("    FAIL %s:%d: %s — expected \"%s\", got \"%s\"\n",        \
                   __FILE__, __LINE__, (msg),                                   \
                   _e ? [_e UTF8String] : "(nil)",                              \
                   _a ? [_a UTF8String] : "(nil)");                             \
        }                                                                       \
    } while (0)

#endif // HOIST_TEST_HARNESS_H
