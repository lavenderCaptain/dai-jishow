/**
 * @file dj_test_main.cpp
 * @brief Entry point for the C++ core regression suite.
 *
 * Walks the `djtest::registry()` (populated by the `TEST` macros in the
 * `test_*.cpp` files), runs every thunk, prints a one-line summary, and returns
 * non-zero on any failed `CHECK`. The build gate (`tools/build_app_bundle.sh`,
 * via `tools/build_cpp_tests.sh`) aborts a DMG build when this exits non-zero,
 * so a regression in the pure romaji/pair-head logic cannot ship.
 */
#include "dj_test.hpp"

#include <cstdio>

int main() {
    int ran = 0;
    for (const auto& t : djtest::registry()) {
        std::printf("[ RUN ] %s\n", t.name.c_str());
        t.fn();
        ++ran;
    }

    int fails = djtest::fail_count();
    std::printf("\n---- %d checks across %d tests, %d failure(s) ----\n",
                djtest::check_count(), ran, fails);
    if (fails == 0) {
        std::printf("ALL PASS\n");
        return 0;
    }
    std::printf("FAILURES DETECTED\n");
    return 1;
}
