#include "../dj_internal.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <string>
#include <unordered_map>
#include <vector>

/**
 * @file fisheye.cpp
 * @brief `dj_graph` — fisheye layout solver for the kanji compound graph.
 *
 * Given a center kanji, this module loads its neighbor kanji (two-kanji
 * compounds, components, or four-kanji idioms) from the corpus, scores and
 * sorts them by frequency/commonality, and lays them out as two hemispheres
 * (left and right) on three concentric elliptical rings.
 *
 * Key design points:
 *
 *  - **Batch cache.** Candidates for a given `(db, center, mode, names)`
 *    tuple are loaded from SQLite exactly once and cached in
 *    `g_fisheye_cache`; subsequent hover/resize/top-N frames do zero
 *    database work.
 *  - **Schema-tolerant.** The `kanji_edges` column names are auto-detected
 *    (and a precomputed-name fast path is probed) so older corpus builds
 *    keep working.
 *  - **Deterministic geometry.** All positions/scales/opacities are computed
 *    here in C++ so Metal (Apple) and AGSL (Android) render identical
 *    geometry without duplicating the math.
 */

namespace dj {

namespace {
constexpr float kPi = 3.14159265358979323846f;
/// Cap on candidates cached per side (covers the largest UI `max_per_side`
/// plus the "+N more" overflow fan).
constexpr size_t kMaxCachedPerSide = 160;

/// Keep a node on its own hemisphere (left/right) and clamp it so it can't
/// overlap the center glyph or leave the viewport.
void clamp_node_hemisphere(OwnedFisheyeNode& n, float ar) {
    // Keep clear of center glyph (radius ~50px -> ~0.12 in Y, ~0.12/ar in X)
    float min_x = std::max(0.13f, 0.24f / std::max(1.0f, ar));
    if (n.side == 0) {
        n.norm_x = std::clamp(n.norm_x, -0.88f, -min_x);
    } else {
        n.norm_x = std::clamp(n.norm_x, min_x, 0.88f);
    }
    n.norm_y = std::clamp(n.norm_y, -0.82f, 0.82f);
}

/// Local UTF-8 → codepoint decoder (kept in this module so the graph solver
/// stays self-contained and doesn't depend on `storage.cpp`'s private
/// helpers).
std::vector<uint32_t> utf8_to_cps_local(const std::string& s) {
    std::vector<uint32_t> cps;
    size_t i = 0;
    while (i < s.size()) {
        unsigned char c = static_cast<unsigned char>(s[i]);
        if (c < 0x80) {
            cps.push_back(c);
            i += 1;
        } else if ((c & 0xE0) == 0xC0 && i + 1 < s.size()) {
            cps.push_back(((c & 0x1F) << 6) | (static_cast<unsigned char>(s[i + 1]) & 0x3F));
            i += 2;
        } else if ((c & 0xF0) == 0xE0 && i + 2 < s.size()) {
            cps.push_back(((c & 0x0F) << 12) |
                          ((static_cast<unsigned char>(s[i + 1]) & 0x3F) << 6) |
                          (static_cast<unsigned char>(s[i + 2]) & 0x3F));
            i += 3;
        } else if ((c & 0xF8) == 0xF0 && i + 3 < s.size()) {
            cps.push_back(((c & 0x07) << 18) |
                          ((static_cast<unsigned char>(s[i + 1]) & 0x3F) << 12) |
                          ((static_cast<unsigned char>(s[i + 2]) & 0x3F) << 6) |
                          (static_cast<unsigned char>(s[i + 3]) & 0x3F));
            i += 4;
        } else {
            i += 1;
        }
    }
    return cps;
}

// Computes the exclusive upper bound for a UTF-8 prefix so SQLite can execute a pure B-tree range scan
std::string utf8_prefix_upper_bound(const std::string& prefix) {
    std::string upper = prefix;
    while (!upper.empty()) {
        unsigned char last = static_cast<unsigned char>(upper.back());
        if (last < 0xFF) {
            upper.back() = static_cast<char>(last + 1);
            return upper;
        }
        upper.pop_back();
    }
    return prefix + "\xF4\x8F\xBF\xBF";
}

/// @return `true` for CJK Unified Ideographs and Extension A. (The graph
///         solver only deals with real kanji, so the 〯 iteration mark is not
///         included here, unlike `storage.cpp`'s `is_kanji_cp`.)
bool is_kanji_cp_local(uint32_t cp) {
    return (cp >= 0x4E00 && cp <= 0x9FFF) || (cp >= 0x3400 && cp <= 0x4DBF);
}

/// The detected column layout of the `kanji_edges` table. Column names vary
/// across corpus schema versions, so they are resolved once at runtime.
struct KanjiEdgesSchema {
    std::string side_col;
    std::string edge_type_col;
    std::string weight_col;
    std::string entry_col;
    bool has_precomputed_names = false;
    bool has_alt_forms = false;   // `entries` carries JMdict alternate kanji spellings
    bool detected = false;
};

/// Auto-detect the `kanji_edges` schema (column names + whether precomputed
/// proper-name edges exist) and cache the result.
///
/// For each logical field we try a list of candidate column names and take
/// the first that exists; if no "side" column is found we fall back to the
/// first unknown column. Finally we probe for precomputed name edges
/// (`edge_kind IN (3,4)`) to pick the fast O(1) B-tree name path.
KanjiEdgesSchema detect_kanji_edges_schema(sqlite3* db) {
    static KanjiEdgesSchema cached;
    if (cached.detected) return cached;

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db, "PRAGMA table_info(kanji_edges);", -1, &stmt, nullptr) == SQLITE_OK) {
        std::vector<std::string> cols;
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const auto* name = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
            if (name) cols.emplace_back(name);
        }
        sqlite3_finalize(stmt);

        auto pick = [&](std::initializer_list<const char*> candidates) -> std::string {
            for (const char* cand : candidates) {
                if (std::find(cols.begin(), cols.end(), cand) != cols.end()) {
                    return cand;
                }
            }
            return "";
        };

        cached.side_col = pick({"side", "position", "dir", "direction", "pos", "rel_pos", "slot", "is_suffix"});
        cached.edge_type_col = pick({"edge_type", "edge_kind", "type", "kind", "mode"});
        cached.weight_col = pick({"weight", "pmi_score", "score", "freq", "count"});
        cached.entry_col = pick({"top_entry_id", "entry_id", "best_entry_id"});

        if (cached.side_col.empty()) {
            for (const auto& c : cols) {
                if (c != "center_cp" && c != "neighbor_cp" &&
                    c != cached.edge_type_col && c != cached.weight_col && c != cached.entry_col) {
                    cached.side_col = c;
                    break;
                }
            }
        }

        if (!cached.edge_type_col.empty()) {
            std::string chk_sql = "SELECT 1 FROM kanji_edges WHERE " + cached.edge_type_col + " IN (3, 4) LIMIT 1;";
            sqlite3_stmt* chk = nullptr;
            if (sqlite3_prepare_v2(db, chk_sql.c_str(), -1, &chk, nullptr) == SQLITE_OK) {
                if (sqlite3_step(chk) == SQLITE_ROW) {
                    cached.has_precomputed_names = true;
                }
                sqlite3_finalize(chk);
            }
        }

        // Probe the `entries` table for an `alt_forms` column (JMdict bundles a
        // word's alternate kanji spellings into one record, e.g. 海星's entry
        // also carries 人手|海盤車|ヒトデ). When present, the standard compound
        // edge load can substitute the alt form that actually fits a (center,
        // neighbor) pair instead of the entry's primary head. Guarded so older
        // corpus builds without the column keep working unchanged.
        sqlite3_stmt* alt_stmt = nullptr;
        if (sqlite3_prepare_v2(db, "PRAGMA table_info(entries);", -1, &alt_stmt, nullptr) == SQLITE_OK) {
            while (sqlite3_step(alt_stmt) == SQLITE_ROW) {
                const auto* name = reinterpret_cast<const char*>(sqlite3_column_text(alt_stmt, 1));
                if (name && std::string(name) == "alt_forms") {
                    cached.has_alt_forms = true;
                }
            }
            sqlite3_finalize(alt_stmt);
        }
        cached.detected = true;
    }
    return cached;
}

void ensure_name_lookup_indexes(sqlite3* db) {
    static bool initialized = false;
    if (initialized || !db) return;
    initialized = true;
    // Fast covering index for suffix-kanji 2-character name lookups if the DB predates edge_kind 3/4
    sqlite3_exec(
        db,
        "CREATE INDEX IF NOT EXISTS idx_entries_name_len2_suffix "
        "ON entries(is_name, SUBSTR(kanji_head, 2, 1), freq_overall) "
        "WHERE is_name = 1 AND kanji_head IS NOT NULL AND LENGTH(kanji_head) = 2;",
        nullptr, nullptr, nullptr
    );
}

/// One cached candidate bubble: the node plus the scoring metadata used to
/// order and size it.
struct CachedCandidate {
    OwnedFisheyeNode node;
    double effective_score;
    float commonality_scale;
};

/// Per-`(db, center, mode, names)` batch cache of candidate bubbles for both
/// sides, so repeated frames do zero SQLite work.
struct FisheyeBatchCache {
    sqlite3* db = nullptr;
    uint32_t center_cp = 0;
    dj_fisheye_mode_t mode = DJ_EDGE_COMPOUNDS;
    bool include_names = false;
    std::vector<CachedCandidate> side_cands[2];

    bool matches(sqlite3* q_db, uint32_t cp, dj_fisheye_mode_t m, bool names) const {
        return db == q_db && center_cp == cp && mode == m && include_names == names;
    }
};

/// The single global batch cache (only one center kanji is "hot" at a time).
FisheyeBatchCache g_fisheye_cache;

/// Load + score + sort the candidate bubbles for one `(db, center, mode,
/// names)` tuple into `g_fisheye_cache`.
///
/// Three sources are handled:
///   - `DJ_EDGE_YOJIJUKUGO` — scan four-kanji idioms containing the center
///     kanji and attribute each to the side the center sits on.
///   - standard `kanji_edges` (compounds / components) — batch-load both
///     sides in a single JOIN, dedupe per side, and score by edge weight +
///     frequency + grade.
///   - proper names (when `include_names`) — use the precomputed
///     `edge_kind 3/4` name edges if present, otherwise an indexed fallback
///     over the `entries` table.
///
/// After loading, each side is sorted by effective score (descending) and a
/// `share_pct` (this bubble's share of the side's total score) is
/// precomputed, so later layout frames do zero sorting.
void populate_fisheye_batch_cache(sqlite3* db, uint32_t center_cp, dj_fisheye_mode_t mode, bool include_names) {
    g_fisheye_cache.db = db;
    g_fisheye_cache.center_cp = center_cp;
    g_fisheye_cache.mode = mode;
    g_fisheye_cache.include_names = include_names;
    g_fisheye_cache.side_cands[0].clear();
    g_fisheye_cache.side_cands[1].clear();
    g_fisheye_cache.side_cands[0].reserve(kMaxCachedPerSide);
    g_fisheye_cache.side_cands[1].reserve(kMaxCachedPerSide);

    if (mode == DJ_EDGE_YOJIJUKUGO) {
        char center_utf8[8];
        encode_utf8(center_cp, center_utf8);
        std::string like_pat = std::string("%") + center_utf8 + "%";
        std::string name_cond = include_names ? "" : "AND e.is_name = 0 ";

        std::string yoji_sql =
            "SELECT e.entry_id, e.kanji_head, e.kana_head, "
            "       COALESCE(s.en_glosses, ''), COALESCE(e.freq_overall, 999999), COALESCE(k.grade, 1) "
            "FROM entries e "
            "LEFT JOIN senses s ON s.entry_id = e.entry_id AND s.sense_idx = 0 "
            "LEFT JOIN kanji k ON k.codepoint = ?2 "
            "WHERE LENGTH(e.kanji_head) = 4 AND e.kanji_head LIKE ?1 " + name_cond +
            "ORDER BY e.freq_overall ASC LIMIT 320;";

        sqlite3_stmt* ystmt = nullptr;
        if (sqlite3_prepare_v2(db, yoji_sql.c_str(), -1, &ystmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(ystmt, 1, like_pat.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_int64(ystmt, 2, static_cast<sqlite3_int64>(center_cp));
            std::unordered_map<uint64_t, bool> seen_side_cp;

            sqlite3_stmt* grade_stmt = nullptr;
            sqlite3_prepare_v2(db, "SELECT COALESCE(grade, 0) FROM kanji WHERE codepoint = ?1;", -1, &grade_stmt, nullptr);

            while (sqlite3_step(ystmt) == SQLITE_ROW) {
                uint32_t eid = static_cast<uint32_t>(sqlite3_column_int64(ystmt, 0));
                const auto* kh = reinterpret_cast<const char*>(sqlite3_column_text(ystmt, 1));
                const auto* ka = reinterpret_cast<const char*>(sqlite3_column_text(ystmt, 2));
                const auto* gl = reinterpret_cast<const char*>(sqlite3_column_text(ystmt, 3));
                uint32_t freq = static_cast<uint32_t>(sqlite3_column_int64(ystmt, 4));
                if (!kh) continue;

                auto cps = utf8_to_cps_local(kh);
                if (cps.size() != 4) continue;
                bool all_k = true;
                int center_idx = -1;
                for (int i = 0; i < 4; ++i) {
                    if (!is_kanji_cp_local(cps[i])) { all_k = false; break; }
                    if (cps[i] == center_cp && center_idx == -1) center_idx = i;
                }
                if (!all_k || center_idx < 0) continue;

                uint8_t side = (center_idx <= 1) ? 1 : 0;
                if (g_fisheye_cache.side_cands[side].size() >= kMaxCachedPerSide) continue;

                uint32_t neighbor_cp = (side == 1) ? cps[3] : cps[0];
                if (neighbor_cp == center_cp) {
                    neighbor_cp = (side == 1) ? cps[2] : cps[1];
                }
                if (neighbor_cp == center_cp) continue;

                uint64_t key = (static_cast<uint64_t>(side) << 32) | neighbor_cp;
                if (seen_side_cp[key]) continue;
                seen_side_cp[key] = true;

                OwnedFisheyeNode n;
                n.codepoint = neighbor_cp;
                encode_utf8(neighbor_cp, n.utf8_glyph);
                n.side = side;
                n.top_entry_id = eid;
                n.compound_word = kh;
                n.compound_kana = ka ? ka : "";
                n.compound_gloss = gl ? gl : "";

                int grade = 1;
                if (grade_stmt) {
                    sqlite3_reset(grade_stmt);
                    sqlite3_bind_int64(grade_stmt, 1, static_cast<sqlite3_int64>(neighbor_cp));
                    if (sqlite3_step(grade_stmt) == SQLITE_ROW) grade = sqlite3_column_int(grade_stmt, 0);
                }

                float comm_scale = (grade == 0) ? 0.86f : (freq <= 8000 ? 1.16f : 1.0f);
                n.commonality_tier = (grade == 0) ? 3 : (freq <= 8000 ? 0 : 1);
                double score = 1000000.0 / (100.0 + static_cast<double>(freq));
                g_fisheye_cache.side_cands[side].push_back({std::move(n), score, comm_scale});
            }
            if (grade_stmt) sqlite3_finalize(grade_stmt);
            sqlite3_finalize(ystmt);
        }
    } else {
        auto schema = detect_kanji_edges_schema(db);
        const bool is_edge_kind_schema = (schema.edge_type_col == "edge_kind");

        // 1. Batch-load both Left (0) and Right (1) standard compound edges in a single JOIN query
        //
        // When the corpus carries `alt_forms` (JMdict alternate kanji spellings),
        // we pull it in as a final column so a row's displayed head can be
        // corrected to the alt form that actually fits the (center, neighbor)
        // pair — see `select_pair_head` below. The clause is appended only when
        // the column exists, so older corpus builds keep working unchanged.
        const bool has_alt = schema.has_alt_forms;
        const std::string alt_clause = has_alt ? ", COALESCE(e.alt_forms, '')" : "";
        std::string sql;
        if (is_edge_kind_schema) {
            sql =
                "SELECT ke.neighbor_cp, ke.edge_kind, " + schema.weight_col + ", ke.top_entry_id, "
                "       COALESCE(e.kanji_head, e.kana_head, ''), COALESCE(e.kana_head, ''), "
                "       COALESCE(s.en_glosses, ''), COALESCE(e.freq_overall, 999999), COALESCE(k.grade, 1)"
                + alt_clause +
                " FROM kanji_edges ke "
                "LEFT JOIN entries e ON e.entry_id = ke.top_entry_id "
                "LEFT JOIN senses s ON s.entry_id = ke.top_entry_id AND s.sense_idx = 0 "
                "LEFT JOIN kanji k ON k.codepoint = ke.neighbor_cp "
                "WHERE ke.center_cp = ?1 AND ke.edge_kind IN (0, 1) "
                "ORDER BY ke.edge_kind ASC, ke.rank ASC LIMIT 320;";
        } else {
            std::string side_expr = schema.side_col.empty() ? "0" : ("ke." + schema.side_col);
            std::string weight_expr = schema.weight_col.empty() ? "1.0" : ("ke." + schema.weight_col);
            std::string entry_expr = schema.entry_col.empty() ? "0" : ("ke." + schema.entry_col);
            std::string where_clause = "WHERE ke.center_cp = ?1 ";
            if (!schema.edge_type_col.empty()) {
                where_clause += "AND ke." + schema.edge_type_col + " = 0 ";
            }
            sql =
                "SELECT ke.neighbor_cp, " + side_expr + ", " + weight_expr + ", " + entry_expr + ", "
                "       COALESCE(e.kanji_head, e.kana_head, ''), COALESCE(e.kana_head, ''), "
                "       COALESCE(s.en_glosses, ''), COALESCE(e.freq_overall, 999999), COALESCE(k.grade, 1)"
                + alt_clause +
                " FROM kanji_edges ke "
                "LEFT JOIN entries e ON e.entry_id = " + entry_expr + " "
                "LEFT JOIN senses s ON s.entry_id = " + entry_expr + " AND s.sense_idx = 0 "
                "LEFT JOIN kanji k ON k.codepoint = ke.neighbor_cp " +
                where_clause +
                "ORDER BY " + weight_expr + " DESC LIMIT 320;";
        }

        std::unordered_map<uint64_t, bool> seen_side_cp;
        sqlite3_stmt* stmt = nullptr;
        if (sqlite3_prepare_v2(db, sql.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(center_cp));
            size_t row_idx = 0;

            while (sqlite3_step(stmt) == SQLITE_ROW) {
                uint32_t ncp = static_cast<uint32_t>(sqlite3_column_int64(stmt, 0));
                int raw_side = sqlite3_column_int(stmt, 1);
                uint8_t actual_side = (!is_edge_kind_schema && schema.side_col.empty())
                    ? static_cast<uint8_t>(row_idx % 2)
                    : static_cast<uint8_t>(raw_side != 0 ? 1 : 0);
                row_idx++;

                if (g_fisheye_cache.side_cands[actual_side].size() >= kMaxCachedPerSide) continue;
                uint64_t key = (static_cast<uint64_t>(actual_side) << 32) | ncp;
                if (seen_side_cp[key]) continue;
                seen_side_cp[key] = true;

                OwnedFisheyeNode n;
                n.codepoint = ncp;
                encode_utf8(ncp, n.utf8_glyph);
                n.side = actual_side;

                double raw_weight = sqlite3_column_double(stmt, 2);
                n.top_entry_id = static_cast<uint32_t>(sqlite3_column_int64(stmt, 3));
                const auto* cw = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4));
                const auto* ck = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));
                const auto* cg = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 6));
                n.compound_word = cw ? cw : "";
                // When the primary head doesn't fit this (center, neighbor) pair
                // (JMdict bundled the compound under a different spelling), show
                // the alt form that does instead — see `select_pair_head`.
                if (has_alt && !n.compound_word.empty()) {
                    const auto* alts = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 9));
                    n.compound_word = select_pair_head(n.compound_word, alts ? alts : "", center_cp, ncp);
                }
                n.compound_kana = ck ? ck : "";
                n.compound_gloss = cg ? cg : "";
                uint32_t freq_overall = static_cast<uint32_t>(sqlite3_column_int64(stmt, 7));
                int grade = sqlite3_column_int(stmt, 8);

                float comm_scale = 1.0f;
                if (grade == 0) {
                    n.commonality_tier = 3;
                    comm_scale = 0.84f;
                } else if (freq_overall <= 2500) {
                    n.commonality_tier = 0;
                    comm_scale = 1.18f;
                } else if (freq_overall <= 12000) {
                    n.commonality_tier = 1;
                    comm_scale = 1.02f;
                } else {
                    n.commonality_tier = 2;
                    comm_scale = 0.88f;
                }

                double score = raw_weight;
                if (freq_overall <= 1500) score *= 2.10;
                else if (freq_overall <= 5000) score *= 1.45;
                if (grade == 0) score *= 0.35;

                g_fisheye_cache.side_cands[actual_side].push_back({std::move(n), score, comm_scale});
            }
            sqlite3_finalize(stmt);
        }

        // 2. Batch-load JMnedict proper-name edges when Names mode is enabled
        if (include_names) {
            if (is_edge_kind_schema && schema.has_precomputed_names) {
                // Fast O(1) B-tree seek on precomputed name edges (edge_kind 3 = prefix, 4 = suffix)
                const char* pre_name_sql =
                    "SELECT ke.neighbor_cp, ke.edge_kind, ke.top_entry_id, "
                    "       COALESCE(e.kanji_head, e.kana_head, ''), COALESCE(e.kana_head, ''), "
                    "       COALESCE(s.en_glosses, 'Name') "
                    "FROM kanji_edges ke "
                    "LEFT JOIN entries e ON e.entry_id = ke.top_entry_id "
                    "LEFT JOIN senses s ON s.entry_id = ke.top_entry_id AND s.sense_idx = 0 "
                    "WHERE ke.center_cp = ?1 AND ke.edge_kind IN (3, 4) "
                    "ORDER BY ke.edge_kind ASC, ke.rank ASC LIMIT 320;";

                sqlite3_stmt* nstmt = nullptr;
                if (sqlite3_prepare_v2(db, pre_name_sql, -1, &nstmt, nullptr) == SQLITE_OK) {
                    sqlite3_bind_int64(nstmt, 1, static_cast<sqlite3_int64>(center_cp));
                    while (sqlite3_step(nstmt) == SQLITE_ROW) {
                        uint32_t ncp = static_cast<uint32_t>(sqlite3_column_int64(nstmt, 0));
                        int ek = sqlite3_column_int(nstmt, 1);
                        uint8_t side = (ek == 4) ? 1 : 0;
                        if (g_fisheye_cache.side_cands[side].size() >= kMaxCachedPerSide) continue;

                        uint64_t key = (static_cast<uint64_t>(side) << 32) | ncp;
                        if (seen_side_cp[key]) continue;
                        seen_side_cp[key] = true;

                        OwnedFisheyeNode n;
                        n.codepoint = ncp;
                        encode_utf8(ncp, n.utf8_glyph);
                        n.side = side;
                        n.commonality_tier = 1;
                        n.top_entry_id = static_cast<uint32_t>(sqlite3_column_int64(nstmt, 2));
                        const auto* kh = reinterpret_cast<const char*>(sqlite3_column_text(nstmt, 3));
                        const auto* ka = reinterpret_cast<const char*>(sqlite3_column_text(nstmt, 4));
                        const auto* gl = reinterpret_cast<const char*>(sqlite3_column_text(nstmt, 5));
                        n.compound_word = kh ? kh : "";
                        n.compound_kana = ka ? ka : "";
                        n.compound_gloss = std::string("[Name] ") + (gl ? gl : "Name");
                        g_fisheye_cache.side_cands[side].push_back({std::move(n), 2.5, 1.0f});
                    }
                    sqlite3_finalize(nstmt);
                }
            } else {
                // Indexed fallback for databases built prior to edge_kind 3/4
                ensure_name_lookup_indexes(db);
                char center_utf8[8];
                encode_utf8(center_cp, center_utf8);
                std::string prefix_lo(center_utf8);
                std::string prefix_hi = utf8_prefix_upper_bound(prefix_lo);

                // Side 1 (center + suffix): uses idx_entries_kanji(is_name, kanji_head, freq_overall) range scan
                const char* suffix_name_sql =
                    "SELECT e.entry_id, e.kanji_head, e.kana_head, COALESCE(s.en_glosses, 'Name') "
                    "FROM entries e "
                    "LEFT JOIN senses s ON s.entry_id = e.entry_id AND s.sense_idx = 0 "
                    "WHERE e.is_name = 1 AND e.kanji_head >= ?1 AND e.kanji_head < ?2 AND LENGTH(e.kanji_head) = 2 "
                    "LIMIT 240;";

                sqlite3_stmt* sstmt = nullptr;
                if (sqlite3_prepare_v2(db, suffix_name_sql, -1, &sstmt, nullptr) == SQLITE_OK) {
                    sqlite3_bind_text(sstmt, 1, prefix_lo.c_str(), -1, SQLITE_TRANSIENT);
                    sqlite3_bind_text(sstmt, 2, prefix_hi.c_str(), -1, SQLITE_TRANSIENT);
                    while (sqlite3_step(sstmt) == SQLITE_ROW) {
                        if (g_fisheye_cache.side_cands[1].size() >= kMaxCachedPerSide) break;
                        uint32_t eid = static_cast<uint32_t>(sqlite3_column_int64(sstmt, 0));
                        const auto* kh = reinterpret_cast<const char*>(sqlite3_column_text(sstmt, 1));
                        const auto* ka = reinterpret_cast<const char*>(sqlite3_column_text(sstmt, 2));
                        const auto* gl = reinterpret_cast<const char*>(sqlite3_column_text(sstmt, 3));
                        if (!kh) continue;
                        auto cps = utf8_to_cps_local(kh);
                        if (cps.size() != 2 || cps[0] != center_cp || !is_kanji_cp_local(cps[1])) continue;

                        uint32_t ncp = cps[1];
                        uint64_t key = (1ULL << 32) | ncp;
                        if (seen_side_cp[key]) continue;
                        seen_side_cp[key] = true;

                        OwnedFisheyeNode n;
                        n.codepoint = ncp;
                        encode_utf8(ncp, n.utf8_glyph);
                        n.side = 1;
                        n.commonality_tier = 1;
                        n.top_entry_id = eid;
                        n.compound_word = kh;
                        n.compound_kana = ka ? ka : "";
                        n.compound_gloss = std::string("[Name] ") + (gl ? gl : "Name");
                        g_fisheye_cache.side_cands[1].push_back({std::move(n), 2.5, 1.0f});
                    }
                    sqlite3_finalize(sstmt);
                }

                // Side 0 (prefix + center): uses idx_entries_name_len2_suffix
                const char* prefix_name_sql =
                    "SELECT e.entry_id, e.kanji_head, e.kana_head, COALESCE(s.en_glosses, 'Name') "
                    "FROM entries e "
                    "LEFT JOIN senses s ON s.entry_id = e.entry_id AND s.sense_idx = 0 "
                    "WHERE e.is_name = 1 AND kanji_head IS NOT NULL AND LENGTH(e.kanji_head) = 2 "
                    "  AND SUBSTR(e.kanji_head, 2, 1) = ?1 "
                    "LIMIT 240;";

                sqlite3_stmt* pstmt = nullptr;
                if (sqlite3_prepare_v2(db, prefix_name_sql, -1, &pstmt, nullptr) == SQLITE_OK) {
                    sqlite3_bind_text(pstmt, 1, prefix_lo.c_str(), -1, SQLITE_TRANSIENT);
                    while (sqlite3_step(pstmt) == SQLITE_ROW) {
                        if (g_fisheye_cache.side_cands[0].size() >= kMaxCachedPerSide) break;
                        uint32_t eid = static_cast<uint32_t>(sqlite3_column_int64(pstmt, 0));
                        const auto* kh = reinterpret_cast<const char*>(sqlite3_column_text(pstmt, 1));
                        const auto* ka = reinterpret_cast<const char*>(sqlite3_column_text(pstmt, 2));
                        const auto* gl = reinterpret_cast<const char*>(sqlite3_column_text(pstmt, 3));
                        if (!kh) continue;
                        auto cps = utf8_to_cps_local(kh);
                        if (cps.size() != 2 || cps[1] != center_cp || !is_kanji_cp_local(cps[0])) continue;

                        uint32_t ncp = cps[0];
                        uint64_t key = ncp;
                        if (seen_side_cp[key]) continue;
                        seen_side_cp[key] = true;

                        OwnedFisheyeNode n;
                        n.codepoint = ncp;
                        encode_utf8(ncp, n.utf8_glyph);
                        n.side = 0;
                        n.commonality_tier = 1;
                        n.top_entry_id = eid;
                        n.compound_word = kh;
                        n.compound_kana = ka ? ka : "";
                        n.compound_gloss = std::string("[Name] ") + (gl ? gl : "Name");
                        g_fisheye_cache.side_cands[0].push_back({std::move(n), 2.5, 1.0f});
                    }
                    sqlite3_finalize(pstmt);
                }
            }
        }
    }

    // Sort once and precompute share_pct for both sides so subsequent layout frames do zero sorting
    for (uint8_t side = 0; side <= 1; ++side) {
        auto& cands = g_fisheye_cache.side_cands[side];
        std::sort(cands.begin(), cands.end(), [](const CachedCandidate& a, const CachedCandidate& b) {
            return a.effective_score > b.effective_score;
        });

        double total_score = 0.0;
        for (const auto& c : cands) total_score += std::max(0.1, c.effective_score);
        if (total_score <= 0.0) total_score = 1.0;

        for (auto& c : cands) {
            c.node.share_pct = static_cast<float>((c.effective_score / total_score) * 100.0);
        }
    }
}
} // namespace

/// Pick the headword to *display* for a `(center, neighbor)` compound edge.
///
/// JMdict bundles a word's alternate kanji spellings into one entry (e.g. entry
/// 2194790 has `kanji_head` 海星 but also the alt forms 人手 | 海盤車 | ヒトデ;
/// 2572910 has 獄 with 人屋 | 囚獄 | ひとや). The corpus stores only the *primary*
/// head, so a fisheye edge (人, 手) that resolves to that entry would render 海星 —
/// the wrong word for the pair the user hovered. When the primary head contains
/// *neither* kanji of the pair, substitute the alt form that contains *both*
/// (the shortest such form wins, so 人手 beats the longer 海盤車). The entry's
/// senses/glosses are shared across all its spellings, so only the displayed
/// head changes. Returns the primary head unchanged when it already fits or when
/// no alt form matches (a small population with no alt form at all).
///
/// (Promoted out of the anonymous namespace to external linkage so the C++
/// regression suite can lock it — see `core/dj_internal.hpp`.)
std::string select_pair_head(const std::string& primary, const std::string& alt_forms,
                             uint32_t center_cp, uint32_t neighbor_cp) {
    auto contains_both = [&](const std::string& s) {
        auto cps = utf8_to_cps_local(s);
        bool has_center = false, has_neighbor = false;
        for (uint32_t cp : cps) {
            if (cp == center_cp) has_center = true;
            if (cp == neighbor_cp) has_neighbor = true;
        }
        return has_center && has_neighbor;
    };
    if (contains_both(primary)) return primary;
    std::string best;
    size_t start = 0;
    for (size_t i = 0; i <= alt_forms.size(); ++i) {
        if (i == alt_forms.size() || alt_forms[i] == '|') {
            std::string form = alt_forms.substr(start, i - start);
            start = i + 1;
            if (!form.empty() && contains_both(form) && (best.empty() || form.size() < best.size())) {
                best = form;
            }
        }
    }
    return best.empty() ? primary : best;
}

/// Lay out the fisheye bubbles for one center kanji and return them.
///
/// Pipeline:
///   1. Ensure the batch cache is populated for this `(db, center, mode,
///      names)` tuple (a no-op if it already matches).
///   2. For each side, take the top `max_per_side` candidates and place them
///      on three concentric elliptical rings (5 / 9 / rest), with a small
///      angular jitter on rings 1+ to avoid a perfectly straight line.
///   3. If a focus point is supplied, apply the fisheye lens: bubbles near
///      the focus grow and push out, bubbles far away shrink and fade.
///   4. Emit any overflow candidates as `is_overflow_preview` nodes (the
///      "+N more" fan) and report the overflow counts.
///   5. Run a few iterations of non-overlap relaxation (in aspect-corrected
///      space, weighted by bubble scale) and re-clamp to each hemisphere.
std::vector<OwnedFisheyeNode> solve_fisheye_graph(
    sqlite3* db,
    uint32_t center_cp,
    dj_fisheye_mode_t mode,
    bool include_names,
    bool has_focus,
    float focus_x,
    float focus_y,
    float aspect_ratio,
    size_t max_per_side,
    size_t& out_left_overflow,
    size_t& out_right_overflow) {

    out_left_overflow = 0;
    out_right_overflow = 0;
    std::vector<OwnedFisheyeNode> nodes;
    if (!db || center_cp == 0 || max_per_side == 0) return nodes;

    // Populate in-memory cache once on load; subsequent hover/resize/top-N calls execute with zero SQLite queries
    if (!g_fisheye_cache.matches(db, center_cp, mode, include_names)) {
        populate_fisheye_batch_cache(db, center_cp, mode, include_names);
    }

    float ar = (aspect_ratio > 0.3f) ? aspect_ratio : 1.85f;
    nodes.reserve(g_fisheye_cache.side_cands[0].size() + g_fisheye_cache.side_cands[1].size());

    for (uint8_t side = 0; side <= 1; ++side) {
        const auto& cands = g_fisheye_cache.side_cands[side];
        size_t visible_count = std::min(cands.size(), max_per_side);
        size_t overflow_count = (cands.size() > max_per_side) ? (cands.size() - max_per_side) : 0;
        if (side == 0) out_left_overflow = overflow_count;
        else out_right_overflow = overflow_count;

        for (size_t idx = 0; idx < visible_count; ++idx) {
            OwnedFisheyeNode n = cands[idx].node;
            n.is_overflow_preview = 0;
            float comm_scale = cands[idx].commonality_scale;

            size_t ring = 0;
            size_t ring_idx = idx;
            size_t ring_count = std::min<size_t>(visible_count, 5);
            if (idx >= 5 && idx < 14) {
                ring = 1;
                ring_idx = idx - 5;
                ring_count = std::min<size_t>(visible_count - 5, 9);
            } else if (idx >= 14) {
                ring = 2;
                ring_idx = idx - 14;
                ring_count = visible_count - 14;
            }

            float t = (ring_count <= 1) ? 0.5f : (static_cast<float>(ring_idx) / static_cast<float>(ring_count - 1));
            float span = (ring == 0) ? 0.68f : (ring == 1 ? 0.80f : 0.86f);
            float theta = (t - 0.5f) * kPi * span;
            if (ring >= 1 && ring_count > 1) {
                theta += (0.035f * ((ring_idx % 2 == 0) ? 1.0f : -1.0f));
            }

            float base_rx = (ring == 0) ? 0.27f : (ring == 1 ? 0.50f : 0.72f);
            float base_ry = (ring == 0) ? 0.36f : (ring == 1 ? 0.64f : 0.78f);

            float dir_x = (n.side == 0) ? -std::cos(theta) : std::cos(theta);
            float dir_y = std::sin(theta);

            float raw_x = dir_x * base_rx;
            float raw_y = dir_y * base_ry;

            if (has_focus) {
                float dx_ar = (raw_x - focus_x) * ar;
                float dy_ar = (raw_y - focus_y);
                float dist = std::sqrt(dx_ar * dx_ar + dy_ar * dy_ar);

                const float lens_radius = 0.68f;
                if (dist < lens_radius) {
                    float u = dist / lens_radius;
                    float falloff = std::cos(u * (kPi * 0.5f));
                    float dock_curve = falloff * falloff;
                    float mag = 1.0f + 0.54f * dock_curve;

                    float push = 0.11f * std::sin(u * kPi) * falloff;
                    if (dist > 1e-4f) {
                        n.norm_x = raw_x + ((dx_ar / dist) / ar) * push;
                        n.norm_y = raw_y + (dy_ar / dist) * push;
                    } else {
                        n.norm_x = raw_x;
                        n.norm_y = raw_y;
                    }
                    n.scale = std::min(1.65f, comm_scale * mag);
                    n.opacity = 1.0f;
                } else {
                    float far_t = std::min(1.0f, (dist - lens_radius) / 1.1f);
                    float shrink = 1.0f - 0.18f * far_t;
                    n.norm_x = raw_x;
                    n.norm_y = raw_y;
                    n.scale = std::max(0.72f, comm_scale * shrink);
                    n.opacity = std::max(0.68f, 0.94f - 0.22f * far_t);
                }
            } else {
                n.norm_x = raw_x;
                n.norm_y = raw_y;
                n.scale = comm_scale;
                n.opacity = (ring == 0) ? 0.98f : 0.88f;
            }

            clamp_node_hemisphere(n, ar);
            nodes.push_back(std::move(n));
        }

        // Emit all cached overflow items (`is_overflow_preview = 1`) for the multi-stage "+N more" fan
        for (size_t src_idx = visible_count; src_idx < cands.size(); ++src_idx) {
            OwnedFisheyeNode n = cands[src_idx].node;
            n.is_overflow_preview = 1;
            n.scale = 1.0f;
            n.opacity = 1.0f;
            nodes.push_back(std::move(n));
        }
    }

    // Gentle non-overlap relaxation using actual scaled bubble radii in aspect-corrected space
    for (int iter = 0; iter < 8; ++iter) {
        for (size_t i = 0; i < nodes.size(); ++i) {
            if (nodes[i].is_overflow_preview) continue;
            for (size_t j = i + 1; j < nodes.size(); ++j) {
                if (nodes[j].is_overflow_preview) continue;
                float dx = (nodes[j].norm_x - nodes[i].norm_x) * ar;
                float dy = (nodes[j].norm_y - nodes[i].norm_y);
                float d = std::sqrt(dx * dx + dy * dy);
                float min_d = 0.135f * (nodes[i].scale + nodes[j].scale);
                if (d < min_d && d > 1e-4f) {
                    float wi = 1.0f / (nodes[i].scale * nodes[i].scale * nodes[i].scale);
                    float wj = 1.0f / (nodes[j].scale * nodes[j].scale * nodes[j].scale);
                    float wsum = wi + wj;
                    float overlap = (min_d - d) * 0.75f;
                    float ux = (dx / d) / ar;
                    float uy = (dy / d);
                    nodes[i].norm_x -= ux * overlap * (wi / wsum);
                    nodes[i].norm_y -= uy * overlap * (wi / wsum);
                    nodes[j].norm_x += ux * overlap * (wj / wsum);
                    nodes[j].norm_y += uy * overlap * (wj / wsum);
                    clamp_node_hemisphere(nodes[i], ar);
                    clamp_node_hemisphere(nodes[j], ar);
                }
            }
        }
    }

    return nodes;
}

} // namespace dj
