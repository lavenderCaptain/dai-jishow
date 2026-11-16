/**
 * @file dj_capi.cpp
 * @brief C11 ABI bridge translating internal C++20 vectors into arena-backed C structs.
 */

#include "dj_internal.hpp"
#include <new>

extern "C" {

dj_engine_t* dj_engine_create(const char* corpus_db_path) {
    if (!corpus_db_path) return nullptr;
    auto* engine = new (std::nothrow) dj_engine_s();
    if (!engine) return nullptr;

    int flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX;
    if (sqlite3_open_v2(corpus_db_path, &engine->db, flags, nullptr) != SQLITE_OK) {
        if (engine->db) sqlite3_close(engine->db);
        delete engine;
        return nullptr;
    }

    sqlite3_exec(engine->db, "PRAGMA mmap_size = 268435456;", nullptr, nullptr, nullptr);
    sqlite3_exec(engine->db, "PRAGMA query_only = ON;", nullptr, nullptr, nullptr);

    dj_state_push_card(engine, DJ_CARD_HOME, 0, "Home");
    return engine;
}

void dj_engine_destroy(dj_engine_t* engine) {
    if (!engine) return;
    if (engine->db) {
        sqlite3_close(engine->db);
    }
    delete engine;
}

const char* dj_nlp_romaji_to_kana(dj_engine_t* engine, const char* romaji, bool katakana) {
    if (!engine || !romaji) return "";
    engine->arena_str = dj::romaji_to_kana(romaji, katakana);
    return engine->arena_str.c_str();
}

size_t dj_dict_search(dj_engine_t* engine,
                      const char* query,
                      dj_search_mode_t mode,
                      bool include_names,
                      size_t limit,
                      const dj_word_hit_t** out_hits) {
    if (!engine || !query || !out_hits) return 0;
    engine->arena_word_storage = dj::db_search_words(engine->db, query, mode, include_names, limit);
    engine->arena_word_c.clear();
    engine->arena_word_c.reserve(engine->arena_word_storage.size());

    for (const auto& w : engine->arena_word_storage) {
        dj_word_hit_t c{};
        c.entry_id = w.entry_id;
        c.kanji_head = w.kanji_head.c_str();
        c.kana_head = w.kana_head.c_str();
        c.alt_forms = w.alt_forms.c_str();
        c.primary_gloss = w.primary_gloss.c_str();
        c.pos_mask = w.pos_mask;
        c.pitch_accent = w.pitch_accent;
        c.freq_rank = w.freq_rank;
        c.pair_entry_id = w.pair_entry_id;
        c.is_name = w.is_name;
        engine->arena_word_c.push_back(c);
    }

    *out_hits = engine->arena_word_c.data();
    return engine->arena_word_c.size();
}

bool dj_dict_get_entry_detail(dj_engine_t* engine,
                              uint32_t entry_id,
                              dj_entry_detail_t* out_detail) {
    if (!engine || !out_detail) return false;
    auto& d = engine->arena_entry_detail;
    if (!dj::db_get_entry_detail(engine->db, entry_id, d)) return false;

    d.c_ruby_cells.clear();
    d.c_ruby_cells.reserve(d.ruby_cells.size());
    for (const auto& rc : d.ruby_cells) {
        d.c_ruby_cells.push_back({rc.surface.c_str(), rc.furigana.c_str(), rc.kanji_cp});
    }

    d.c_senses.clear();
    d.c_senses.reserve(d.senses.size());
    for (const auto& s : d.senses) {
        d.c_senses.push_back({s.sense_idx, s.pos_mask, s.en_glosses.c_str(), s.ja_glosses.c_str()});
    }

    d.c_sentences.clear();
    d.c_sentences.reserve(d.sentences.size());
    for (auto& sent : d.sentences) {
        sent.c_tokens.clear();
        sent.c_tokens.reserve(sent.tokens.size());
        for (const auto& tok : sent.tokens) {
            sent.c_tokens.push_back({tok.utf16_offset, tok.utf16_length, tok.entry_id, tok.kana_reading.c_str()});
        }
        d.c_sentences.push_back({
            sent.sent_id,
            sent.jp_text.c_str(),
            sent.en_text.c_str(),
            sent.c_tokens.data(),
            sent.c_tokens.size()
        });
    }

    dj_entry_detail_t res{};
    res.header.entry_id = d.header.entry_id;
    res.header.kanji_head = d.header.kanji_head.c_str();
    res.header.kana_head = d.header.kana_head.c_str();
    res.header.alt_forms = d.header.alt_forms.c_str();
    res.header.primary_gloss = d.header.primary_gloss.c_str();
    res.header.pos_mask = d.header.pos_mask;
    res.header.pitch_accent = d.header.pitch_accent;
    res.header.freq_rank = d.header.freq_rank;
    res.header.pair_entry_id = d.header.pair_entry_id;
    res.header.is_name = d.header.is_name;
    res.paired_kanji = d.paired_kanji.c_str();
    res.paired_kana = d.paired_kana.c_str();
    res.ruby_cells = d.c_ruby_cells.data();
    res.ruby_cell_count = d.c_ruby_cells.size();
    res.senses = d.c_senses.data();
    res.sense_count = d.c_senses.size();
    res.sentences = d.c_sentences.data();
    res.sentence_count = d.c_sentences.size();

    *out_detail = res;
    return true;
}

bool dj_kanji_get_detail(dj_engine_t* engine,
                         uint32_t codepoint,
                         dj_kanji_detail_t* out_detail) {
    if (!engine || !out_detail) return false;
    auto& k = engine->arena_kanji_detail;
    if (!dj::db_get_kanji_detail(engine->db, codepoint, k)) return false;

    k.c_polylines.clear();
    k.c_polylines.reserve(k.strokes_points.size());
    for (const auto& poly : k.strokes_points) {
        k.c_polylines.push_back({poly.data(), poly.size()});
    }

    dj_kanji_detail_t res{};
    res.codepoint = k.codepoint;
    for (int i = 0; i < 8; ++i) res.utf8_glyph[i] = k.utf8_glyph[i];
    res.strokes = k.strokes;
    res.grade = k.grade;
    res.jlpt = k.jlpt;
    res.freq_rank = k.freq_rank;
    res.radical_id = k.radical_id;
    res.skip_code = k.skip_code;
    res.four_corner = k.four_corner;
    res.kyujitai_cp = k.kyujitai_cp;
    res.on_readings = k.on_readings.c_str();
    res.kun_readings = k.kun_readings.c_str();
    res.meanings = k.meanings.c_str();
    res.component_radicals = k.component_radicals.c_str();
    res.stroke_polylines = k.c_polylines.data();
    res.polyline_count = k.c_polylines.size();

    *out_detail = res;
    return true;
}

size_t dj_kanji_search_radicals(dj_engine_t* engine,
                                const uint8_t* radical_ids,
                                size_t radical_count,
                                int16_t target_strokes,
                                int8_t stroke_tolerance,
                                const uint32_t** out_codepoints) {
    if (!engine || !out_codepoints) return 0;
    engine->arena_cp_storage = dj::db_search_radicals(
        engine->db, radical_ids, radical_count, target_strokes, stroke_tolerance);
    *out_codepoints = engine->arena_cp_storage.data();
    return engine->arena_cp_storage.size();
}

size_t dj_graph_solve_fisheye(dj_engine_t* engine,
                              uint32_t center_codepoint,
                              dj_fisheye_mode_t mode,
                              float focus_x,
                              float focus_y,
                              float aspect_ratio,
                              size_t max_per_side,
                              const dj_fisheye_node_t** out_nodes) {
    if (!engine || !out_nodes) return 0;
    engine->arena_fisheye_storage = dj::solve_fisheye_graph(
        engine->db, center_codepoint, mode, focus_x, focus_y, aspect_ratio, max_per_side);
    engine->arena_fisheye_c.clear();
    engine->arena_fisheye_c.reserve(engine->arena_fisheye_storage.size());

    for (const auto& n : engine->arena_fisheye_storage) {
        dj_fisheye_node_t c{};
        c.codepoint = n.codepoint;
        for (int i = 0; i < 8; ++i) c.utf8_glyph[i] = n.utf8_glyph[i];
        c.side = n.side;
        c.commonality_tier = n.commonality_tier;
        c.top_entry_id = n.top_entry_id;
        c.compound_word = n.compound_word.c_str();
        c.compound_kana = n.compound_kana.c_str();
        c.compound_gloss = n.compound_gloss.c_str();
        c.norm_x = n.norm_x;
        c.norm_y = n.norm_y;
        c.scale = n.scale;
        c.opacity = n.opacity;
        engine->arena_fisheye_c.push_back(c);
    }

    *out_nodes = engine->arena_fisheye_c.data();
    return engine->arena_fisheye_c.size();
}

} // extern "C"
