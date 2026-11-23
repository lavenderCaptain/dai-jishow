/**
 * @file test_romaji.cpp
 * @brief Regression tests for the wa-puro romaji->kana state machine and the
 *        UTF-8 codec (`core/dj_nlp/romaji.cpp`).
 *
 * These lock the pure, deterministic transliteration logic the search field
 * relies on: geminate consonants, youon glides, syllabic-n, daku-ten, the
 * katakana sweep, and pass-through of letters that are never kana on their own.
 * A regression here would silently mistranslate the user's keystrokes — exactly
 * the kind of bug the Swift-side `DaiJishowMorph` suite caught with godan
 * past/te — so we pin the behavior with expected kana asserted *independently*
 * of whatever the code currently emits.
 *
 * Note on string literals: the source is UTF-8, so a literal like "こんにちは"
 * is the 15 UTF-8 bytes of that string; `romaji_to_kana` returns UTF-8, so a
 * direct string comparison checks the byte-level output.
 */
#include "dj_test.hpp"

#include "dj_internal.hpp"

#include <string>

// --- romaji_to_kana: basic morae ------------------------------------------
TEST(romaji_basic_morae) {
    CHECK_EQ_STR(dj::romaji_to_kana("a"), "あ");
    CHECK_EQ_STR(dj::romaji_to_kana("ka"), "か");
    CHECK_EQ_STR(dj::romaji_to_kana("shi"), "し");
    CHECK_EQ_STR(dj::romaji_to_kana("tsu"), "つ");
    CHECK_EQ_STR(dj::romaji_to_kana("chi"), "ち");
    // Hepburn "fu" and the older "hu" both map to ふ.
    CHECK_EQ_STR(dj::romaji_to_kana("fu"), "ふ");
    CHECK_EQ_STR(dj::romaji_to_kana("hu"), "ふ");
    CHECK_EQ_STR(dj::romaji_to_kana("wo"), "を");
}

// --- alternate romanizations of one mora ----------------------------------
TEST(romaji_alternate_spellings) {
    // Hepburn + Kunrei-shiki variants of the same kana all converge.
    CHECK_EQ_STR(dj::romaji_to_kana("si"), "し");   // Kunrei for し
    CHECK_EQ_STR(dj::romaji_to_kana("ti"), "ち");
    CHECK_EQ_STR(dj::romaji_to_kana("tu"), "つ");
    CHECK_EQ_STR(dj::romaji_to_kana("ji"), "じ");
    CHECK_EQ_STR(dj::romaji_to_kana("zi"), "じ");
    CHECK_EQ_STR(dj::romaji_to_kana("dji"), "ぢ");
}

// --- youon (palatalized glides) -------------------------------------------
TEST(romaji_youon_glides) {
    CHECK_EQ_STR(dj::romaji_to_kana("kya"), "きゃ");
    CHECK_EQ_STR(dj::romaji_to_kana("kyu"), "きゅ");
    CHECK_EQ_STR(dj::romaji_to_kana("kyo"), "きょ");
    CHECK_EQ_STR(dj::romaji_to_kana("sha"), "しゃ");
    CHECK_EQ_STR(dj::romaji_to_kana("syu"), "しゅ");
    CHECK_EQ_STR(dj::romaji_to_kana("cha"), "ちゃ");
    CHECK_EQ_STR(dj::romaji_to_kana("nya"), "にゃ");
    CHECK_EQ_STR(dj::romaji_to_kana("ja"), "じゃ");
    CHECK_EQ_STR(dj::romaji_to_kana("zya"), "じゃ");  // Kunrei variant
    CHECK_EQ_STR(dj::romaji_to_kana("gya"), "ぎゃ");
    CHECK_EQ_STR(dj::romaji_to_kana("pya"), "ぴゃ");
}

// --- geminate consonants (small tsu っ) -----------------------------------
TEST(romaji_geminate) {
    CHECK_EQ_STR(dj::romaji_to_kana("kappu"), "かっぷ");
    CHECK_EQ_STR(dj::romaji_to_kana("sapporo"), "さっぽろ");
    CHECK_EQ_STR(dj::romaji_to_kana("katta"), "かった");
    CHECK_EQ_STR(dj::romaji_to_kana("sukkiri"), "すっきり");
    // wa-puro "t-" shorthand is equivalent to a doubled consonant.
    CHECK_EQ_STR(dj::romaji_to_kana("t-ta"), "った");
}

// --- syllabic n -----------------------------------------------------------
TEST(romaji_syllabic_n) {
    CHECK_EQ_STR(dj::romaji_to_kana("n"), "ん");       // bare n at end-of-string
    CHECK_EQ_STR(dj::romaji_to_kana("nn"), "ん");       // explicit escape
    CHECK_EQ_STR(dj::romaji_to_kana("san"), "さん");    // n before a consonant
    CHECK_EQ_STR(dj::romaji_to_kana("hon"), "ほん");
    // The apostrophe escape keeps an n separate from a following youon
    // (n'ya -> んや, not にゃ).
    CHECK_EQ_STR(dj::romaji_to_kana("n'ya"), "んや");
}

// --- katakana sweep -------------------------------------------------------
TEST(romaji_katakana_sweep) {
    // Default output is hiragana.
    CHECK_EQ_STR(dj::romaji_to_kana("katakana"), "かたかな");
    // With katakana=true the whole hiragana result is shifted +0x60 in one pass.
    CHECK_EQ_STR(dj::romaji_to_kana("katakana", true), "カタカナ");
    CHECK_EQ_STR(dj::romaji_to_kana("sapporo", true), "サッポロ");
}

// --- pass-through ---------------------------------------------------------
TEST(romaji_pass_through) {
    // Letters that never form a kana on their own are kept verbatim so the
    // user's keystrokes are never silently dropped.
    CHECK_EQ_STR(dj::romaji_to_kana("x"), "x");
    CHECK_EQ_STR(dj::romaji_to_kana("q"), "q");
    CHECK_EQ_STR(dj::romaji_to_kana("v"), "v");
}

// --- is_ascii_romaji ------------------------------------------------------
TEST(romaji_is_ascii_romaji) {
    CHECK(dj::is_ascii_romaji("hello"));      // has a letter, pure ASCII
    CHECK(dj::is_ascii_romaji("123abc"));     // letters alongside digits
    CHECK(!dj::is_ascii_romaji("123"));       // no letter at all
    CHECK(!dj::is_ascii_romaji(""));          // empty
    CHECK(!dj::is_ascii_romaji("こんにちは"));  // non-ASCII (kana) is not romaji
}

// --- encode_utf8 ----------------------------------------------------------
TEST(romaji_encode_utf8) {
    char out[8];

    // 1-byte ASCII.
    dj::encode_utf8(0x41, out);
    CHECK_EQ_STR(std::string(out), "A");

    // 3-byte CJK / kana — compare against the UTF-8 form of the same glyph so we
    // don't hard-code byte sequences by hand.
    dj::encode_utf8(0x6771, out);  // 東 (U+6771)
    CHECK_EQ_STR(std::string(out), "東");
    dj::encode_utf8(0x3042, out);  // あ (U+3042)
    CHECK_EQ_STR(std::string(out), "あ");

    // Out-of-range codepoint (> U+10FFFF) yields only a NUL terminator.
    dj::encode_utf8(0x110000, out);
    CHECK(out[0] == 0);
}
