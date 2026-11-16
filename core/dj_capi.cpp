#include "dj_internal.hpp"
#include <algorithm>

extern "C" {

dj_engine_t* dj_engine_create(const char* db_path) {
    if (!db_path) return nullptr;
    sqlite3* db = nullptr;
    int flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX;
    if (sqlite3_open_v2(db_path, &db, flags, nullptr) != SQLITE_OK) {
        if (db) sqlite3_close(db);
        return nullptr;
    }
    sqlite3_exec(db, "PRAGMA mmap_size = 268435456;", nullptr, nullptr, nullptr);
    sqlite3_exec(db, "PRAGMA cache_size = -65536;", nullptr, nullptr, nullptr);

    auto* engine = new dj_engine();
    engine->db = db;
    return engine;
}

void dj_engine_destroy(dj_engine_t* engine) {
    if (!engine) return;
    if (engine->db) sqlite3_close(engine->db);
    delete engine;
}

size_t dj_dict_search(
    dj_engine_t*          engine,
    const char*           utf8_query,
    dj_search_mode_t      mode,
    bool                  include_names,
    size_t                limit,
    const dj_word_hit_t** out_hits) {

    if (out_hits) *out_hits = nullptr;
    if (!engine || !engine->db || !utf8_query) return 0;

    engine->owned_hits = dj::db_search_words(engine->db, utf8_query, mode, include_names, limit);
    engine->abi_hits.clear();
    engine->abi_hits.reserve(engine->owned_hits.size());

    for (const auto& h : engine->owned_hits) {
        dj_word_hit_t abi{};
        abi.entry_id      = h.entry_id;
        abi.kanji_head    = h.kanji_head.c_str();
        abi.kana_head     = h.kana_head.c_str();
        abi.alt_forms     = h.alt_forms.c_str();
        abi.primary_gloss = h.primary_gloss.c_str();
        abi.pos_mask      = h.pos_mask;
        abi.pitch_accent  = h.pitch_accent;
        abi.freq_rank     = h.freq_rank;
        abi.pair_entry_id = h.pair_entry_id;
        abi.is_name       = h.is_name;
        engine->abi_hits.push_back(abi);
    }

    if (out_hits && !engine->abi_hits.empty()) {
        *out_hits = engine->abi_hits.data();
    }
    return engine->abi_hits.size();
}

bool dj_dict_get_entry_detail(
    dj_engine_t*       engine,
    uint32_t           entry_id,
    dj_entry_detail_t* out_detail) {

    if (!engine || !engine->db || !out_detail) return false;
    if (!dj::db_get_entry_detail(engine->db, entry_id, engine->owned_entry)) return false;

    const auto& src = engine->owned_entry;
    out_detail->header.entry_id      = src.header.entry_id;
    out_detail->header.kanji_head    = src.header.kanji_head.c_str();
    out_detail->header.kana_head     = src.header.kana_head.c_str();
    out_detail->header.alt_forms     = src.header.alt_forms.c_str();
    out_detail->header.primary_gloss = src.header.primary_gloss.c_str();
    out_detail->header.pos_mask      = src.header.pos_mask;
    out_detail->header.pitch_accent  = src.header.pitch_accent;
    out_detail->header.freq_rank     = src.header.freq_rank;
    out_detail->header.pair_entry_id = src.header.pair_entry_id;
    out_detail->header.is_name       = src.header.is_name;
    out_detail->paired_kanji         = src.paired_kanji.c_str();
    out_detail->paired_kana          = src.paired_kana.c_str();

    engine->abi_ruby_cells.clear();
    engine->abi_ruby_cells.reserve(src.ruby_cells.size());
    for (const auto& rc : src.ruby_cells) {
        dj_ruby_cell_t abi_rc{};
        abi_rc.surface  = rc.surface.c_str();
        abi_rc.furigana = rc.furigana.c_str();
        abi_rc.kanji_cp = rc.kanji_cp;
        engine->abi_ruby_cells.push_back(abi_rc);
    }
    out_detail->ruby_cells      = engine->abi_ruby_cells.empty() ? nullptr : engine->abi_ruby_cells.data();
    out_detail->ruby_cell_count = engine->abi_ruby_cells.size();

    engine->abi_senses.clear();
    engine->abi_senses.reserve(src.senses.size());
    for (const auto& s : src.senses) {
        dj_sense_t abi_s{};
        abi_s.sense_idx  = s.sense_idx;
        abi_s.pos_mask   = s.pos_mask;
        abi_s.en_glosses = s.en_glosses.c_str();
        abi_s.ja_glosses = s.ja_glosses.c_str();
        engine->abi_senses.push_back(abi_s);
    }
    out_detail->senses      = engine->abi_senses.empty() ? nullptr : engine->abi_senses.data();
    out_detail->sense_count = engine->abi_senses.size();

    engine->abi_sent_tokens.clear();
    size_t total_tokens = 0;
    for (const auto& st : src.sentences) total_tokens += st.tokens.size();
    engine->abi_sent_tokens.reserve(total_tokens);

    engine->abi_sentences.clear();
    engine->abi_sentences.reserve(src.sentences.size());
    for (const auto& st : src.sentences) {
        size_t offset = engine->abi_sent_tokens.size();
        for (const auto& tok : st.tokens) {
            dj_sentence_token_t abi_t{};
            abi_t.utf16_offset = tok.utf16_offset;
            abi_t.utf16_length = tok.utf16_length;
            abi_t.entry_id     = tok.entry_id;
            abi_t.kana_reading = tok.kana_reading.c_str();
            engine->abi_sent_tokens.push_back(abi_t);
        }
        dj_sentence_t abi_st{};
        abi_st.sent_id     = st.sent_id;
        abi_st.jp_text     = st.jp_text.c_str();
        abi_st.en_text     = st.en_text.c_str();
        abi_st.tokens      = st.tokens.empty() ? nullptr : (engine->abi_sent_tokens.data() + offset);
        abi_st.token_count = st.tokens.size();
        engine->abi_sentences.push_back(abi_st);
    }
    out_detail->sentences      = engine->abi_sentences.empty() ? nullptr : engine->abi_sentences.data();
    out_detail->sentence_count = engine->abi_sentences.size();

    return true;
}

bool dj_kanji_get_detail(
    dj_engine_t*       engine,
    uint32_t           codepoint,
    dj_kanji_detail_t* out_detail) {

    if (!engine || !engine->db || !out_detail) return false;
    if (!dj::db_get_kanji_detail(engine->db, codepoint, engine->owned_kanji)) return false;

    const auto& src = engine->owned_kanji;
    out_detail->codepoint          = src.codepoint;
    out_detail->utf8_glyph         = src.utf8_glyph;
    out_detail->strokes            = src.strokes;
    out_detail->grade              = src.grade;
    out_detail->jlpt               = src.jlpt;
    out_detail->freq_rank          = src.freq_rank;
    out_detail->radical_id         = src.radical_id;
    out_detail->skip_code          = src.skip_code;
    out_detail->four_corner        = src.four_corner;
    out_detail->kyujitai_cp        = src.kyujitai_cp;
    out_detail->on_readings        = src.on_readings.c_str();
    out_detail->kun_readings       = src.kun_readings.c_str();
    out_detail->meanings           = src.meanings.c_str();
    out_detail->component_radicals = src.component_radicals.c_str();

    engine->abi_polylines.clear();
    engine->abi_polylines.reserve(src.strokes_points.size());
    for (const auto& poly : src.strokes_points) {
        dj_stroke_polyline_t pl{};
        pl.points      = poly.empty() ? nullptr : poly.data();
        pl.point_count = poly.size();
        engine->abi_polylines.push_back(pl);
    }
    out_detail->stroke_polylines = engine->abi_polylines.empty() ? nullptr : engine->abi_polylines.data();
    out_detail->polyline_count   = engine->abi_polylines.size();
    return true;
}

size_t dj_kanji_search_radicals(
    dj_engine_t*     engine,
    const uint8_t*   radical_ids,
    size_t           radical_count,
    int16_t          target_strokes,
    int8_t           stroke_tolerance,
    const uint32_t** out_codepoints) {

    if (out_codepoints) *out_codepoints = nullptr;
    if (!engine || !engine->db) return 0;

    engine->abi_radical_cps = dj::db_search_radicals(
        engine->db, radical_ids, radical_count, target_strokes, stroke_tolerance);

    if (out_codepoints && !engine->abi_radical_cps.empty()) {
        *out_codepoints = engine->abi_radical_cps.data();
    }
    return engine->abi_radical_cps.size();
}

size_t dj_graph_solve_fisheye(
    dj_engine_t*              engine,
    uint32_t                  center_codepoint,
    dj_fisheye_mode_t         mode,
    bool                      include_names,
    float                     focus_norm_x,
    float                     focus_norm_y,
    float                     aspect_ratio,
    size_t                    max_per_side,
    size_t*                   out_left_overflow,
    size_t*                   out_right_overflow,
    const dj_fisheye_node_t** out_nodes) {

    if (out_nodes) *out_nodes = nullptr;
    if (out_left_overflow) *out_left_overflow = 0;
    if (out_right_overflow) *out_right_overflow = 0;
    if (!engine || !engine->db) return 0;

    size_t left_ov = 0, right_ov = 0;
    engine->owned_fisheye = dj::solve_fisheye_graph(
        engine->db, center_codepoint, mode, include_names,
        focus_norm_x, focus_norm_y, aspect_ratio, max_per_side, left_ov, right_ov);

    if (out_left_overflow) *out_left_overflow = left_ov;
    if (out_right_overflow) *out_right_overflow = right_ov;

    engine->abi_fisheye.clear();
    engine->abi_fisheye.reserve(engine->owned_fisheye.size());
    for (const auto& n : engine->owned_fisheye) {
        dj_fisheye_node_t abi{};
        abi.codepoint           = n.codepoint;
        abi.utf8_glyph          = n.utf8_glyph;
        abi.side                = n.side;
        abi.commonality_tier    = n.commonality_tier;
        abi.is_overflow_preview = n.is_overflow_preview;
        abi.top_entry_id        = n.top_entry_id;
        abi.compound_word       = n.compound_word.c_str();
        abi.compound_kana       = n.compound_kana.c_str();
        abi.compound_gloss      = n.compound_gloss.c_str();
        abi.share_pct           = n.share_pct;
        abi.norm_x              = n.norm_x;
        abi.norm_y              = n.norm_y;
        abi.scale               = n.scale;
        abi.opacity             = n.opacity;
        engine->abi_fisheye.push_back(abi);
    }

    if (out_nodes && !engine->abi_fisheye.empty()) {
        *out_nodes = engine->abi_fisheye.data();
    }
    return engine->abi_fisheye.size();
}

void dj_state_push_recent_kanji(dj_engine_t* engine, uint32_t codepoint) {
    if (!engine || codepoint == 0) return;
    size_t write = 0;
    std::array<uint32_t, 6> next{};
    next[write++] = codepoint;
    for (size_t i = 0; i < engine->recent_kanji_count && write < 6; ++i) {
        if (engine->recent_kanji[i] != codepoint) {
            next[write++] = engine->recent_kanji[i];
        }
    }
    engine->recent_kanji = next;
    engine->recent_kanji_count = write;
}

size_t dj_state_get_recent_kanji(dj_engine_t* engine, uint32_t out_six[6]) {
    if (!engine || !out_six) return 0;
    for (size_t i = 0; i < engine->recent_kanji_count; ++i) {
        out_six[i] = engine->recent_kanji[i];
    }
    return engine->recent_kanji_count;
}

} // extern "C"
