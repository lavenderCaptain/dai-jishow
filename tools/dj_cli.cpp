#include "dj_capi.h"
#include <chrono>
#include <cstdio>
#include <iostream>

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

    // 1. Test Wa-puro Romaji Parser
    std::printf("[nlp]  Romaji 'yappari' -> %s\n", dj_nlp_romaji_to_kana(engine, "yappari", false));
    std::printf("[nlp]  Romaji 'n\'ya'    -> %s\n\n", dj_nlp_romaji_to_kana(engine, "n'ya", false));

    // 2. Test Auto-Detecting Search (Romaji -> Kana -> Dictionary)
    const dj_word_hit_t* hits = nullptr;
    auto s0 = std::chrono::high_resolution_clock::now();
    size_t hit_cnt = dj_dict_search(engine, "shousan", DJ_SEARCH_AUTO, false, 5, &hits);
    auto s1 = std::chrono::high_resolution_clock::now();
    double search_ms = std::chrono::duration<double, std::milli>(s1 - s0).count();

    std::printf("[dict] Search 'shousan' (%zu hits in %.3f ms):\n", hit_cnt, search_ms);
    for (size_t i = 0; i < hit_cnt; ++i) {
        std::printf("  - [%u] %s (%s) [pitch=%u] : %s\n",
                    hits[i].entry_id,
                    hits[i].kanji_head[0] ? hits[i].kanji_head : hits[i].kana_head,
                    hits[i].kana_head,
                    hits[i].pitch_accent,
                    hits[i].primary_gloss);
    }
    std::printf("\n");

    // 3. Test Dokusha Spatial Fisheye Solver for '称' (U+79F0)
    const dj_fisheye_node_t* nodes = nullptr;
    auto f0 = std::chrono::high_resolution_clock::now();
    size_t node_cnt = dj_graph_solve_fisheye(engine, 0x79F0, DJ_EDGE_COMPOUNDS, 0.0f, 0.0f, 1.5f, 4, &nodes);
    auto f1 = std::chrono::high_resolution_clock::now();
    double fisheye_ms = std::chrono::duration<double, std::milli>(f1 - f0).count();

    std::printf("[graph] Dokusha Fisheye for '称' (%zu nodes solved in %.3f ms):\n", node_cnt, fisheye_ms);
    for (size_t i = 0; i < node_cnt; ++i) {
        std::printf("  - %s %s -> %s (%s) @ (%.2f, %.2f) scale=%.2f\n",
                    nodes[i].side == 0 ? "[LEFT ]" : "[RIGHT]",
                    nodes[i].utf8_glyph,
                    nodes[i].compound_word,
                    nodes[i].compound_kana,
                    nodes[i].norm_x,
                    nodes[i].norm_y,
                    nodes[i].scale);
    }
    std::printf("\n");

    // 4. Test 3D Time Machine Z-Stack & 6-Kanji Ring
    dj_state_push_card(engine, DJ_CARD_WORD_ENTRY, 1001, "称賛");
    dj_state_push_card(engine, DJ_CARD_FISHEYE_EXPLORER, 0x79F0, "称");
    dj_state_set_zoomed_out(engine, true);

    const dj_zcard_t* stack = nullptr;
    size_t depth = dj_state_get_zstack(engine, &stack);
    std::printf("[zstack] Zoomed-Out 3D Stack (%zu layers):\n", depth);
    for (size_t i = 0; i < depth; ++i) {
        std::printf("  - Z=%d [%s] scale=%.2f blur=%.1fpx\n",
                    stack[i].z_depth, stack[i].title_badge, stack[i].scale, stack[i].blur_radius);
    }

    dj_engine_destroy(engine);
    return 0;
}
