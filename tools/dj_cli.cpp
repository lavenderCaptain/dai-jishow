/**
 * @file dj_cli.cpp
 * @brief Native CLI test harness & benchmark tool for the Dai-Jishow core.
 *
 * Exercises the full C11 ABI surface (`dj_capi.h`) end-to-end against a real
 * corpus DB, timing each call. Run with: `dj_cli [path/to/daijishow.db]`.
 */
#include "dj_capi.h"
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <iostream>
#include <string>

/// Render a single BMP codepoint as a UTF-8 string (kanji live in 0x4E00..0x9FFF).
static std::string utf8_of(uint32_t cp) {
    char buf[4];
    int n = 0;
    if (cp < 0x80) {
        buf[n++] = static_cast<char>(cp);
    } else if (cp < 0x800) {
        buf[n++] = static_cast<char>(0xC0 | (cp >> 6));
        buf[n++] = static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        buf[n++] = static_cast<char>(0xE0 | (cp >> 12));
        buf[n++] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        buf[n++] = static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        buf[n++] = static_cast<char>(0xF0 | (cp >> 18));
        buf[n++] = static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        buf[n++] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        buf[n++] = static_cast<char>(0x80 | (cp & 0x3F));
    }
    return std::string(buf, n);
}

int main(int argc, char** argv) {
    const char* db_path = (argc > 1) ? argv[1] : "build/daijishow.db";

    auto t0 = std::chrono::high_resolution_clock::now();
    dj_engine_t* engine = dj_engine_create(db_path);
    auto t1 = std::chrono::high_resolution_clock::now();

    if (!engine) {
        std::cerr << "Failed to open corpus DB at: " << db_path << "\n";
        return 1;
    }

    double init_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
    std::printf("[init] Opened mmap SQLite corpus in %.3f ms\n\n", init_ms);

    // 1. Auto-Detecting Search (romaji -> kana -> dictionary). The romaji
    //    transliterator lives inside dj_dict_search's AUTO mode, so we drive it
    //    through the same call a host would.
    const dj_word_hit_t* hits = nullptr;
    auto s0 = std::chrono::high_resolution_clock::now();
    size_t hit_cnt = dj_dict_search(engine, "shousan", DJ_SEARCH_AUTO, false, 5, &hits);
    auto s1 = std::chrono::high_resolution_clock::now();
    double search_ms = std::chrono::duration<double, std::milli>(s1 - s0).count();

    std::printf("[dict] Search 'shousan' AUTO (%zu hits in %.3f ms):\n", hit_cnt, search_ms);
    for (size_t i = 0; i < hit_cnt; ++i) {
        std::printf("  - [%u] %s (%s) [pitch=%u] : %s\n",
                    hits[i].entry_id,
                    hits[i].kanji_head[0] ? hits[i].kanji_head : hits[i].kana_head,
                    hits[i].kana_head,
                    hits[i].pitch_accent,
                    hits[i].primary_gloss);
    }
    std::printf("\n");

    // 2. Word Cosmos sampler: random words filtered by a prevalence ceiling.
    //    Exercises the new dj_dict_get_random_words across three tiers.
    struct Tier { const char* label; uint32_t max_freq; };
    const Tier tiers[] = {
        {"Core  (<=2500)", 2500u},
        {"Common(<=12000)", 12000u},
        {"All   (no filter)", 0u},
    };
    for (const Tier& tier : tiers) {
        auto r0 = std::chrono::high_resolution_clock::now();
        const dj_word_hit_t* words = nullptr;
        size_t word_cnt = dj_dict_get_random_words(engine, tier.max_freq, false, 6, &words);
        auto r1 = std::chrono::high_resolution_clock::now();
        double sample_ms = std::chrono::duration<double, std::milli>(r1 - r0).count();

        std::printf("[cosmos] Random words [%s] (%zu sampled in %.3f ms):\n",
                    tier.label, word_cnt, sample_ms);
        for (size_t i = 0; i < word_cnt; ++i) {
            const char* head = words[i].kanji_head[0] ? words[i].kanji_head : words[i].kana_head;
            std::printf("  - #%-7u %-14s : %s\n",
                        words[i].freq_rank, head, words[i].primary_gloss);
        }
    }
    std::printf("\n");

    // 3. Dokusha Spatial Fisheye Solver for '称' (U+79F0), compound edges.
    const dj_fisheye_node_t* nodes = nullptr;
    size_t left_ov = 0, right_ov = 0;
    auto f0 = std::chrono::high_resolution_clock::now();
    size_t node_cnt = dj_graph_solve_fisheye(
        engine, 0x79F0, DJ_EDGE_COMPOUNDS,
        /*include_names*/false, /*has_focus*/false,
        /*focus_x*/0.0f, /*focus_y*/0.0f, /*aspect_ratio*/1.5f,
        /*max_per_side*/4, &left_ov, &right_ov, &nodes);
    auto f1 = std::chrono::high_resolution_clock::now();
    double fisheye_ms = std::chrono::duration<double, std::milli>(f1 - f0).count();

    std::printf("[graph] Dokusha Fisheye for '称' (%zu nodes, L+%-zu/R+%-zu in %.3f ms):\n",
                node_cnt, left_ov, right_ov, fisheye_ms);
    for (size_t i = 0; i < node_cnt; ++i) {
        std::printf("  - %s %s -> %s (%s) @ (%.2f, %.2f) scale=%.2f share=%.1f%%\n",
                    nodes[i].side == 0 ? "[LEFT ]" : "[RIGHT]",
                    nodes[i].utf8_glyph,
                    nodes[i].compound_word,
                    nodes[i].compound_kana,
                    nodes[i].norm_x,
                    nodes[i].norm_y,
                    nodes[i].scale,
                    nodes[i].share_pct);
    }
    std::printf("\n");

    // 4. 6-slot recent-kanji ring (most-recent first, deduplicated).
    dj_state_push_recent_kanji(engine, 0x5927); // 大
    dj_state_push_recent_kanji(engine, 0x79F0); // 称
    dj_state_push_recent_kanji(engine, 0x65E5); // 国
    dj_state_push_recent_kanji(engine, 0x79F0); // 称 again (should dedupe to front)

    uint32_t ring[6] = {0};
    size_t depth = dj_state_get_recent_kanji(engine, ring);
    std::printf("[state] Recent-kanji ring (%zu slots, most-recent first):\n", depth);
    for (size_t i = 0; i < depth; ++i) {
        std::printf("  - %zu  U+%04X  %s\n", i, ring[i], utf8_of(ring[i]).c_str());
    }
    std::printf("\n");

    dj_engine_destroy(engine);
    return 0;
}
