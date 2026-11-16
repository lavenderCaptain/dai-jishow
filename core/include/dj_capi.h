#ifndef DJ_CAPI_H
#define DJ_CAPI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct dj_engine dj_engine_t;

typedef enum {
    DJ_SEARCH_AUTO     = 0,
    DJ_SEARCH_PREFIX   = 1,
    DJ_SEARCH_EXACT    = 2,
    DJ_SEARCH_ANY      = 3,
    DJ_SEARCH_HOMONYMS = 4
} dj_search_mode_t;

typedef enum {
    DJ_EDGE_COMPOUNDS  = 0,
    DJ_EDGE_COMPONENTS = 1,
    DJ_EDGE_YOJIJUKUGO = 2
} dj_fisheye_mode_t;

typedef struct {
    float x;
    float y;
} dj_point_t;

typedef struct {
    const dj_point_t* points;
    size_t            point_count;
} dj_stroke_polyline_t;

typedef struct {
    uint32_t    entry_id;
    const char* kanji_head;
    const char* kana_head;
    const char* alt_forms;
    const char* primary_gloss;
    uint64_t    pos_mask;
    uint8_t     pitch_accent;
    uint32_t    freq_rank;
    uint32_t    pair_entry_id;
    bool        is_name;
} dj_word_hit_t;

typedef struct {
    const char* surface;
    const char* furigana;
    uint32_t    kanji_cp;
} dj_ruby_cell_t;

typedef struct {
    uint32_t    sense_idx;
    uint64_t    pos_mask;
    const char* en_glosses;
    const char* ja_glosses;
} dj_sense_t;

typedef struct {
    uint16_t    utf16_offset;
    uint16_t    utf16_length;
    uint32_t    entry_id;
    const char* kana_reading;
} dj_sentence_token_t;

typedef struct {
    uint32_t                   sent_id;
    const char*                jp_text;
    const char*                en_text;
    const dj_sentence_token_t* tokens;
    size_t                     token_count;
} dj_sentence_t;

typedef struct {
    dj_word_hit_t         header;
    const char*           paired_kanji;
    const char*           paired_kana;
    const dj_ruby_cell_t* ruby_cells;
    size_t                ruby_cell_count;
    const dj_sense_t*     senses;
    size_t                sense_count;
    const dj_sentence_t*  sentences;
    size_t                sentence_count;
} dj_entry_detail_t;

typedef struct {
    uint32_t                    codepoint;
    const char*                 utf8_glyph;
    uint8_t                     strokes;
    uint8_t                     grade;
    uint8_t                     jlpt;
    uint32_t                    freq_rank;
    uint8_t                     radical_id;
    uint32_t                    skip_code;
    uint32_t                    four_corner;
    uint32_t                    kyujitai_cp;
    const char*                 on_readings;
    const char*                 kun_readings;
    const char*                 meanings;
    const char*                 component_radicals;
    const dj_stroke_polyline_t* stroke_polylines;
    size_t                      polyline_count;
} dj_kanji_detail_t;

typedef struct {
    uint32_t    codepoint;
    const char* utf8_glyph;
    uint8_t     side;                /* 0 = left/prefix, 1 = right/suffix */
    uint8_t     commonality_tier;    /* 0 = Core, 1 = Joyo, 2 = Literary, 3 = Kyujitai/Non-Joyo */
    uint8_t     is_overflow_preview; /* 0 = main bubble, 1 = overflow sub-bubble for "+N more" */
    uint32_t    top_entry_id;
    const char* compound_word;
    const char* compound_kana;
    const char* compound_gloss;
    float       share_pct;           /* Compound frequency share % within this side */
    float       norm_x;
    float       norm_y;
    float       scale;
    float       opacity;
} dj_fisheye_node_t;

dj_engine_t* dj_engine_create(const char* db_path);
void dj_engine_destroy(dj_engine_t* engine);

size_t dj_dict_search(
    dj_engine_t*          engine,
    const char*           utf8_query,
    dj_search_mode_t      mode,
    bool                  include_names,
    size_t                limit,
    const dj_word_hit_t** out_hits);

bool dj_dict_get_entry_detail(
    dj_engine_t*       engine,
    uint32_t           entry_id,
    dj_entry_detail_t* out_detail);

bool dj_kanji_get_detail(
    dj_engine_t*       engine,
    uint32_t           codepoint,
    dj_kanji_detail_t* out_detail);

size_t dj_kanji_search_radicals(
    dj_engine_t*     engine,
    const uint8_t*   radical_ids,
    size_t           radical_count,
    int16_t          target_strokes,
    int8_t           stroke_tolerance,
    const uint32_t** out_codepoints);

size_t dj_graph_solve_fisheye(
    dj_engine_t*              engine,
    uint32_t                  center_codepoint,
    dj_fisheye_mode_t         mode,
    bool                      include_names,
    bool                      has_focus,
    float                     focus_norm_x,
    float                     focus_norm_y,
    float                     aspect_ratio,
    size_t                    max_per_side,
    size_t*                   out_left_overflow,
    size_t*                   out_right_overflow,
    const dj_fisheye_node_t** out_nodes);

void   dj_state_push_recent_kanji(dj_engine_t* engine, uint32_t codepoint);
size_t dj_state_get_recent_kanji(dj_engine_t* engine, uint32_t out_six[6]);

#ifdef __cplusplus
}
#endif

#endif /* DJ_CAPI_H */
