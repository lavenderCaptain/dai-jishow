#!/usr/bin/env bash
#
# build_cpp_tests.sh — compile and run the C++ core regression suite.
#
# This is the C++ counterpart to `swift test` for the Swift `DaiJishowMorph`
# library. It locks the *pure, no-DB* logic of the native engine:
#
#   core/dj_nlp/romaji.cpp   — romaji_to_kana / is_ascii_romaji / encode_utf8
#   core/dj_graph/fisheye.cpp— select_pair_head (the fisheye pair-head selector)
#
# It compiles those two translation units together with the hand-rolled harness
# (core/test/dj_test.hpp + dj_test_main.cpp + test_*.cpp) into build/dj_core_tests
# and runs it. The runner exits non-zero on any failed CHECK, so a broken
# transliteration or pair-head selection aborts the build gate (this script is
# invoked by tools/build_app_bundle.sh right after `swift test`).
#
# Design notes (see core/test/dj_test.hpp for the full rationale):
#   - No test framework: the suite is ~50 lines of CHECK macros + a registry, so
#     the lean C++ core (linked only against system sqlite3 + the stdlib) stays
#     dependency-free.
#   - No DB: the tested functions are pure, so the suite never touches the
#     ~221 MB corpus. `select_pair_head` and its DB-dependent siblings live in
#     the same translation unit; they link cleanly against system sqlite3 even
#     though the tests never call the DB paths.
#
# Usage:
#   ./tools/build_cpp_tests.sh        # compile + run, fail on any CHECK failure
#   CXX=clang++ ./tools/build_cpp_tests.sh   # override the compiler
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CXX="${CXX:-c++}"
OUT="build/dj_core_tests"
mkdir -p build

# Pure-logic translation units under test.
CORE_SRC="core/dj_nlp/romaji.cpp core/dj_graph/fisheye.cpp"
# Harness + test cases.
TEST_SRC="core/test/dj_test_main.cpp core/test/test_romaji.cpp core/test/test_pair_head.cpp core/test/test_idioms.cpp"

echo "==> compiling C++ core tests ($CXX -std=c++20 -Wall -Wextra -Wpedantic)"
# -Icore        lets the test TUs #include "dj_internal.hpp"
# -Icore/include (belt and braces) for a direct #include "dj_capi.h"
# -lsqlite3     resolves the (unreached) DB paths inside fisheye.cpp; romaji.cpp
#               references no sqlite symbols, so the link is satisfied for both.
"$CXX" -std=c++20 -O2 -Wall -Wextra -Wpedantic \
  -Icore -Icore/include \
  $CORE_SRC $TEST_SRC \
  -o "$OUT" \
  -lsqlite3

echo "==> running $OUT"
"$OUT"
