/**
 * @file test_pair_head.cpp
 * @brief Regression tests for the fisheye pair-head selector
 *        (`dj::select_pair_head`, in `core/dj_graph/fisheye.cpp`).
 *
 * `select_pair_head` decides which headword a hovered (center, neighbor)
 * compound edge *displays*. JMdict bundles a word's alternate kanji spellings
 * into one entry, and the corpus stores only the primary head — so an edge that
 * resolves to such an entry would render the wrong head (e.g. the (人,手) edge
 * on 海星's entry). The selector substitutes the shortest alt form that contains
 * *both* kanji of the pair. This locks that substitution so a regression cannot
 * silently show the wrong compound for a hovered pair.
 *
 * The function is pure (no DB), so it is exercised directly with small
 * UTF-8 fixtures rather than through the ~221 MB corpus.
 */
#include "dj_test.hpp"

#include "dj_internal.hpp"

#include <cstdint>
#include <string>

namespace {
/// Decode the first Unicode codepoint of a UTF-8 string. Used to turn a single
/// kanji glyph (e.g. "人") into the `uint32_t` codepoint the selector compares
/// against. Test-only; the production decoders live in `storage.cpp` /
/// `fisheye.cpp` and stay private to those modules.
uint32_t first_cp(const std::string& s) {
    auto c0 = static_cast<unsigned char>(s[0]);
    if (c0 < 0x80) return c0;
    if ((c0 & 0xE0) == 0xC0)
        return ((c0 & 0x1F) << 6) | (static_cast<unsigned char>(s[1]) & 0x3F);
    if ((c0 & 0xF0) == 0xE0)
        return ((c0 & 0x0F) << 12) |
               ((static_cast<unsigned char>(s[1]) & 0x3F) << 6) |
               (static_cast<unsigned char>(s[2]) & 0x3F);
    return 0;
}
}  // namespace

// The motivating case: a (人,手) edge resolves to 海星's entry, whose primary
// head is 海星 (neither kanji of the pair) but whose alt forms include 人手 —
// which contains both. The pair must render 人手, not 海星.
TEST(pair_head_substitutes_alt_form) {
    std::string out = dj::select_pair_head("海星", "人手|海盤車|ヒトデ",
                                           first_cp("人"), first_cp("手"));
    CHECK_EQ_STR(out, "人手");
}

// When the primary head already contains both kanji, it is returned unchanged
// (the alt-form scan is never even reached).
TEST(pair_head_keeps_primary_when_it_fits) {
    std::string out = dj::select_pair_head("人手", "海星|海盤車",
                                           first_cp("人"), first_cp("手"));
    CHECK_EQ_STR(out, "人手");
}

// Among several matching alt forms, the shortest wins, so 人手 beats 人手足 and
// ties with 手人 break by first-encountered order (strict `<`, no overwrite).
TEST(pair_head_shortest_match_wins) {
    std::string out = dj::select_pair_head("海星", "人手足|人手|手人",
                                           first_cp("人"), first_cp("手"));
    CHECK_EQ_STR(out, "人手");
}

// No alt form contains both kanji -> fall back to the primary head.
TEST(pair_head_falls_back_to_primary) {
    std::string out = dj::select_pair_head("海星", "海盤車|ヒトデ",
                                           first_cp("人"), first_cp("手"));
    CHECK_EQ_STR(out, "海星");
}

// An empty alt-forms list returns the primary head unchanged.
TEST(pair_head_empty_alt_forms) {
    std::string out = dj::select_pair_head("海星", "",
                                           first_cp("人"), first_cp("手"));
    CHECK_EQ_STR(out, "海星");
}

// A single-kanji primary that already *is* the pair (center == neighbor) renders
// itself.
TEST(pair_head_single_kanji_pair) {
    std::string out = dj::select_pair_head("人", "",
                                           first_cp("人"), first_cp("人"));
    CHECK_EQ_STR(out, "人");
}
