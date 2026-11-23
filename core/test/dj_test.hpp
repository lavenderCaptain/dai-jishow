/**
 * @file dj_test.hpp
 * @brief A tiny, dependency-free regression harness for the C++ core.
 *
 * Why hand-rolled instead of gtest/Catch
 * ---------------------------------------
 * The C++ core is shipped inside a SwiftPM package and a CMake build that link
 * only against the system `sqlite3` and the C++ stdlib. Adding a third-party
 * test framework would drag a dependency into that lean surface, so the tests
 * here use a ~50-line harness in the same spirit as the existing `dj_cli.cpp`
 * CLI harness: no external packages, just a registry, a couple of `CHECK`
 * macros, and a `main()` that reports pass/fail and sets the exit code.
 *
 * How to add a test
 * -----------------
 * In a translation unit, register a named thunk:
 *
 *     TEST(my_case) {
 *         CHECK(dj::is_ascii_romaji("hello"));
 *         CHECK_EQ_STR(dj::romaji_to_kana("konnichiwa"), "こんにちは");
 *     }
 *
 * The file-scope `Registrar` that `TEST` expands to runs at static-init time and
 * appends the thunk to the process-wide `registry()`. `dj_test_main.cpp`'s
 * `main()` walks the registry, runs every thunk, prints a one-line summary, and
 * returns non-zero if any `CHECK` failed — so the build gate can gate on it.
 *
 * Exit-code contract
 * ------------------
 *   0  every CHECK passed
 *   1  one or more CHECKs failed
 *
 * The harness is header-only except for `dj_test_main.cpp` (the `main()`), so a
 * new test file is just `#include "dj_test.hpp"` plus `TEST(...)` blocks.
 */
#pragma once

#include <cstdio>
#include <functional>
#include <string>
#include <vector>

namespace djtest {

/// One registered test: a human-readable name and the thunk that runs it.
struct TestCase {
    std::string          name;
    std::function<void()> fn;
};

/// Process-wide registry, populated by file-scope `Registrar` objects.
inline std::vector<TestCase>& registry() {
    static std::vector<TestCase> tests;
    return tests;
}

/// Running counters, shared by every CHECK macro and read by main().
inline int& check_count() {
    static int n = 0;
    return n;
}
inline int& fail_count() {
    static int n = 0;
    return n;
}

/// Registers a thunk at static-init time. Constructed as a file-scope static by
/// the `TEST` macro, so simply writing `TEST(foo) { ... }` is enough to add a
/// test to the suite with no central list to maintain.
struct Registrar {
    Registrar(const char* name, std::function<void()> fn) {
        registry().push_back({name, std::move(fn)});
    }
};

}  // namespace djtest

/// Define and register a test named `name`.
///
/// Expands to a forward declaration, a file-scope `Registrar` that holds the
/// thunk's address (registered at static-init), and the thunk definition — so
/// the body below the macro is the test itself.
#define TEST(name)                                                       \
    static void djtest_##name();                                         \
    static ::djtest::Registrar djtest_reg_##name(#name, &djtest_##name); \
    static void djtest_##name()

/// Assert a boolean condition; on failure, record it and print a locator so the
/// offending test/line shows up in the log.
#define CHECK(cond)                                             \
    do {                                                        \
        ++::djtest::check_count();                              \
        if (!(cond)) {                                          \
            ++::djtest::fail_count();                           \
            std::fprintf(stderr, "  FAIL %s:%d: CHECK(%s)\n",   \
                         __FILE__, __LINE__, #cond);            \
        }                                                       \
    } while (0)

/// Assert two strings are equal, printing both on failure. The expected/actual
/// are shown as raw UTF-8 so a wrong kana/kanji output is visible in the log
/// rather than an opaque mismatch.
#define CHECK_EQ_STR(actual, expected)                                      \
    do {                                                                    \
        ++::djtest::check_count();                                          \
        ::std::string dj_act = (actual);                                    \
        ::std::string dj_exp = (expected);                                  \
        if (dj_act != dj_exp) {                                             \
            ++::djtest::fail_count();                                       \
            std::fprintf(stderr,                                            \
                         "  FAIL %s:%d: string mismatch\n"                  \
                         "       expected: %s\n       got:      %s\n",      \
                         __FILE__, __LINE__, dj_exp.c_str(), dj_act.c_str());\
        }                                                                   \
    } while (0)
