/**
 * @file test_storage.cpp
 * @brief Pure-logic regression suite for `dj_storage/storage.cpp` helpers and
 *        the `dj_capi.cpp` recent-kanji ring buffer.
 *
 * Covers the pure, DB-free functions promoted from the anonymous namespace in
 * `storage.cpp` to `namespace dj`, plus the 6-slot MRU recent-kanji buffer on
 * `dj_engine`. Zero dependency on the corpus database.
 */
#include "dj_test.hpp"
#include "dj_internal.hpp"

#include <array>
#include <cstdint>
#include <string>
#include <vector>

TEST(to_lower_ascii_preserves_utf8) {
    CHECK_EQ_STR(dj::to_lower_ascii(""), "");
    CHECK_EQ_STR(dj::to_lower_ascii("Hello-World_123!"), "hello-world_123!");
    CHECK_EQ_STR(dj::to_lower_ascii("already_lower"), "already_lower");
    CHECK_EQ_STR(dj::to_lower_ascii("日本語ABCカタカナxyz"), "日本語abcカタカナxyz");
}

TEST(english_gloss_relevance_tiers) {
    // Tier 3: empty inputs or no match.
    CHECK_EQ(dj::english_gloss_relevance_tier("", "water"), 3);
    CHECK_EQ(dj::english_gloss_relevance_tier("water", ""), 3);
    CHECK_EQ(dj::english_gloss_relevance_tier("fire; flame", "water"), 3);

    // Tier 0: exact whole gloss, case-insensitive, whitespace-trimmed, or core before parenthetical.
    CHECK_EQ(dj::english_gloss_relevance_tier("water", "water"), 0);
    CHECK_EQ(dj::english_gloss_relevance_tier("Water", "water"), 0);
    CHECK_EQ(dj::english_gloss_relevance_tier("H2O;  water  ; liquid", "water"), 0);
    CHECK_EQ(dj::english_gloss_relevance_tier("bank (river)", "bank"), 0);
    CHECK_EQ(dj::english_gloss_relevance_tier("dash; run (quickly)", "run"), 0);

    // Tier 1: leading word or "to <query>" introducer.
    CHECK_EQ(dj::english_gloss_relevance_tier("water bottle", "water"), 1);
    CHECK_EQ(dj::english_gloss_relevance_tier("to eat", "eat"), 1);
    CHECK_EQ(dj::english_gloss_relevance_tier("consume; to drink", "drink"), 1);

    // Tier 2: non-leading substring match.
    CHECK_EQ(dj::english_gloss_relevance_tier("drinking water", "water"), 2);
    CHECK_EQ(dj::english_gloss_relevance_tier("underwater", "water"), 2);

    // Best tier across semicolon-separated items wins even when later in list.
    CHECK_EQ(dj::english_gloss_relevance_tier("drinking water; water (cold)", "water"), 0);
    CHECK_EQ(dj::english_gloss_relevance_tier("cold water; water bottle", "water"), 1);
}

TEST(utf8_prefix_upper_bound_ordering) {
    std::string bound = dj::utf8_prefix_upper_bound("漢");
    CHECK(bound == std::string("漢\xEF\xBF\xBF"));
    CHECK(std::string("漢") < bound);
    CHECK(std::string("漢字") < bound);
    CHECK(std::string("漢\xEE\x80\x80") < bound);

    std::string hira_bound = dj::utf8_prefix_upper_bound("あ");
    CHECK(std::string("あいう") < hira_bound);
    CHECK(hira_bound < std::string("い"));
}

TEST(utf8_byte_range_to_utf16_units_mixed_planes) {
    // ASCII: 1 byte -> 1 UTF-16 unit
    std::string ascii = "hello";
    CHECK_EQ(dj::utf8_byte_range_to_utf16_units(ascii, 0, ascii.size()), 5);
    CHECK_EQ(dj::utf8_byte_range_to_utf16_units(ascii, 1, 3), 3);

    // 2-byte UTF-8 ("é" U+00E9) + 3-byte BMP kanji ("日本語"): 1 unit per char
    std::string bmp = "é日本語";
    // byte offsets: é=[0..2), 日=[2..5), 本=[5..8), 語=[8..11)
    CHECK_EQ(dj::utf8_byte_range_to_utf16_units(bmp, 0, bmp.size()), 4);
    CHECK_EQ(dj::utf8_byte_range_to_utf16_units(bmp, 2, 6), 2);

    // 4-byte supplementary plane (U+2000B = \xF0\xA0\x80\x8B) takes 2 UTF-16 units (surrogate pair)
    std::string supp = "a\xF0\xA0\x80\x8B漢";
    CHECK_EQ(dj::utf8_byte_range_to_utf16_units(supp, 0, 1), 1);
    CHECK_EQ(dj::utf8_byte_range_to_utf16_units(supp, 1, 4), 2);
    CHECK_EQ(dj::utf8_byte_range_to_utf16_units(supp, 0, supp.size()), 4);

    // Out-of-bounds clamping
    CHECK_EQ(dj::utf8_byte_range_to_utf16_units("abc", 1, 999), 2);
    CHECK_EQ(dj::utf8_byte_range_to_utf16_units("abc", 99, 5), 0);
}

TEST(utf8_decode_and_encode_round_trip) {
    std::string sample = "Aé日\xF0\xA0\x80\x8B";
    auto cps = dj::utf8_to_cps(sample);
    CHECK_EQ(cps.size(), 4u);
    CHECK_EQ(cps[0], 0x41u);
    CHECK_EQ(cps[1], 0xE9u);
    CHECK_EQ(cps[2], 0x65E5u);
    CHECK_EQ(cps[3], 0x2000Bu);

    CHECK_EQ_STR(dj::cps_to_utf8(cps, 0, cps.size()), sample);
    CHECK_EQ_STR(dj::cps_to_utf8(cps, 1, 2), "é日");
    CHECK_EQ_STR(dj::cps_to_utf8(cps, 2, 99), "日\xF0\xA0\x80\x8B");
    CHECK_EQ_STR(dj::cps_to_utf8(cps, 10, 2), "");

    // Malformed / truncated lead byte advances pos cleanly by 1 without looping
    std::string bad = "\xF0\x80";
    size_t pos = 0;
    uint32_t c0 = dj::next_utf8_cp(bad, pos);
    CHECK_EQ(c0, 0xF0u);
    CHECK_EQ(pos, 1u);
    uint32_t c1 = dj::next_utf8_cp(bad, pos);
    CHECK_EQ(c1, 0x80u);
    CHECK_EQ(pos, 2u);
    CHECK_EQ(dj::next_utf8_cp(bad, pos), 0u);
}

TEST(codepoint_classifiers_and_kana_folding) {
    // Kanji: Unified Ideographs, Ext A, and iteration mark 々
    CHECK(dj::is_kanji_cp(0x4E00));
    CHECK(dj::is_kanji_cp(0x65E5));
    CHECK(dj::is_kanji_cp(0x9FFF));
    CHECK(dj::is_kanji_cp(0x3400));
    CHECK(dj::is_kanji_cp(0x4DBF));
    CHECK(dj::is_kanji_cp(0x3005));
    CHECK(!dj::is_kanji_cp(0x3042)); // あ
    CHECK(!dj::is_kanji_cp('A'));

    // Hiragana
    CHECK(dj::is_hiragana_cp(0x3041)); // ぁ
    CHECK(dj::is_hiragana_cp(0x3042)); // あ
    CHECK(dj::is_hiragana_cp(0x3096)); // ゖ
    CHECK(!dj::is_hiragana_cp(0x3040));
    CHECK(!dj::is_hiragana_cp(0x30A2)); // ア
    CHECK(!dj::is_hiragana_cp(0x30FC)); // ー

    // Katakana -> Hiragana
    CHECK_EQ(dj::to_hiragana_cp(0x30A1), 0x3041u); // ァ -> ぁ
    CHECK_EQ(dj::to_hiragana_cp(0x30F3), 0x3093u); // ン -> ん
    CHECK_EQ(dj::to_hiragana_cp(0x30F6), 0x3096u); // ヶ -> ゖ
    CHECK_EQ(dj::to_hiragana_cp(0x3042), 0x3042u); // あ unchanged
    CHECK_EQ(dj::to_hiragana_cp(0x30FC), 0x30FCu); // ー unchanged
    CHECK_EQ(dj::to_hiragana_cp('Z'), static_cast<uint32_t>('Z'));

    // Base kana folding (dakuten / handakuten + katakana -> base hiragana)
    CHECK_EQ(dj::base_kana_cp(0x304C), 0x304Bu); // が -> か
    CHECK_EQ(dj::base_kana_cp(0x30AE), 0x304Du); // ギ -> き
    CHECK_EQ(dj::base_kana_cp(0x3062), 0x3061u); // ぢ -> ち
    CHECK_EQ(dj::base_kana_cp(0x3065), 0x3064u); // づ -> つ
    CHECK_EQ(dj::base_kana_cp(0x3069), 0x3068u); // ど -> と
    CHECK_EQ(dj::base_kana_cp(0x3070), 0x306Fu); // ば -> は
    CHECK_EQ(dj::base_kana_cp(0x3071), 0x306Fu); // ぱ -> は
    CHECK_EQ(dj::base_kana_cp(0x30D7), 0x3075u); // プ -> ふ
    CHECK_EQ(dj::base_kana_cp(0x307D), 0x307Bu); // ぽ -> ほ
    CHECK_EQ(dj::base_kana_cp(0x3042), 0x3042u); // あ unchanged
}

TEST(kana_prefix_matches_tolerances) {
    auto cps = [](const std::string& s) { return dj::utf8_to_cps(s); };

    // Exact and non-zero offset match
    CHECK(dj::kana_prefix_matches(cps("がっこう"), 0, cps("がっ")));
    CHECK(dj::kana_prefix_matches(cps("がっこう"), 2, cps("こう")));

    // Script folding (katakana vs hiragana on any mora)
    CHECK(dj::kana_prefix_matches(cps("カッパ"), 0, cps("かっぱ")));

    // First-mora dakuten/handakuten tolerance (i == 0 only)
    CHECK(dj::kana_prefix_matches(cps("ばなな"), 0, cps("はな")));
    CHECK(dj::kana_prefix_matches(cps("ぱなな"), 0, cps("はな")));
    CHECK(!dj::kana_prefix_matches(cps("あば"), 0, cps("あは"))); // i == 1 voicing mismatch rejected

    // Trailing small tsu gemination tolerance (final mora of cand only)
    CHECK(dj::kana_prefix_matches(cps("がっこう"), 0, cps("がく")));
    CHECK(dj::kana_prefix_matches(cps("ガッコウ"), 0, cps("がく")));
    CHECK(!dj::kana_prefix_matches(cps("がっこう"), 0, cps("がくこう"))); // 'っ' at i=1 != cand.size()-1
    CHECK(dj::kana_prefix_matches(cps("がっこう"), 0, cps("がっこう")));

    // Empty / out-of-bounds rejected
    CHECK(!dj::kana_prefix_matches(cps("あ"), 0, {}));
    CHECK(!dj::kana_prefix_matches(cps("あ"), 0, cps("あいう")));
    CHECK(!dj::kana_prefix_matches(cps("あいう"), 2, cps("うお")));
}

TEST(solve_kanji_reading_split_pure_cases) {
    // 学校 = がっこう with candidates: 学 -> {がく}, 校 -> {こう}
    auto kanji = dj::utf8_to_cps("学校");
    auto kana = dj::utf8_to_cps("がっこう");
    std::vector<std::vector<std::vector<uint32_t>>> cands = {
        { dj::utf8_to_cps("がく") },
        { dj::utf8_to_cps("こう") },
    };
    std::vector<std::pair<size_t, size_t>> ranges(2);
    CHECK(dj::solve_kanji_reading_split(kanji, cands, kana, 0, 0, ranges));
    CHECK_EQ(ranges[0].first, 0u);
    CHECK_EQ(ranges[0].second, 2u); // がっ
    CHECK_EQ(ranges[1].first, 2u);
    CHECK_EQ(ranges[1].second, 2u); // こう

    // Backtracking: first candidate "にほん" doesn't leave valid tail, second "にっ" succeeds via trailing っ
    auto kanji2 = dj::utf8_to_cps("日本");
    auto kana2 = dj::utf8_to_cps("にっぽん");
    std::vector<std::vector<std::vector<uint32_t>>> cands2 = {
        { dj::utf8_to_cps("にほん"), dj::utf8_to_cps("にち") },
        { dj::utf8_to_cps("ほん") },
    };
    std::vector<std::pair<size_t, size_t>> ranges2(2);
    CHECK(dj::solve_kanji_reading_split(kanji2, cands2, kana2, 0, 0, ranges2));
    CHECK_EQ_STR(dj::cps_to_utf8(kana2, ranges2[0].first, ranges2[0].second), "にっ");
    CHECK_EQ_STR(dj::cps_to_utf8(kana2, ranges2[1].first, ranges2[1].second), "ぽん");

    // Impossible split: fewer kana than kanji
    CHECK(!dj::solve_kanji_reading_split(kanji2, cands2, dj::utf8_to_cps("に"), 0, 0, ranges2));
}

TEST(capi_recent_kanji_ring_buffer) {
    // Null / invalid argument checks
    uint32_t out[6] = {0};
    CHECK_EQ(dj_state_get_recent_kanji(nullptr, out), 0u);
    dj_engine eng;
    CHECK_EQ(dj_state_get_recent_kanji(&eng, nullptr), 0u);
    dj_state_push_recent_kanji(nullptr, 0x65E5);
    dj_state_push_recent_kanji(&eng, 0);
    CHECK_EQ(dj_state_get_recent_kanji(&eng, out), 0u);

    // Push 3 distinct kanji -> MRU order [3, 2, 1]
    dj_state_push_recent_kanji(&eng, 0x4E00); // 一
    dj_state_push_recent_kanji(&eng, 0x4E8C); // 二
    dj_state_push_recent_kanji(&eng, 0x4E09); // 三
    CHECK_EQ(dj_state_get_recent_kanji(&eng, out), 3u);
    CHECK_EQ(out[0], 0x4E09u);
    CHECK_EQ(out[1], 0x4E8Cu);
    CHECK_EQ(out[2], 0x4E00u);

    // Re-pushing 一 moves it to front without changing count
    dj_state_push_recent_kanji(&eng, 0x4E00);
    CHECK_EQ(dj_state_get_recent_kanji(&eng, out), 3u);
    CHECK_EQ(out[0], 0x4E00u);
    CHECK_EQ(out[1], 0x4E09u);
    CHECK_EQ(out[2], 0x4E8Cu);

    // Fill to capacity (6) and push a 7th distinct kanji -> oldest (二) evicted
    dj_state_push_recent_kanji(&eng, 0x56DB); // 四
    dj_state_push_recent_kanji(&eng, 0x4E94); // 五
    dj_state_push_recent_kanji(&eng, 0x516D); // 六
    CHECK_EQ(dj_state_get_recent_kanji(&eng, out), 6u);
    dj_state_push_recent_kanji(&eng, 0x4E03); // 七
    CHECK_EQ(dj_state_get_recent_kanji(&eng, out), 6u);

    std::array<uint32_t, 6> expected = {0x4E03, 0x516D, 0x4E94, 0x56DB, 0x4E00, 0x4E09};
    for (size_t i = 0; i < 6; ++i) {
        CHECK_EQ(out[i], expected[i]);
    }
}
