#include "../dj_internal.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <string>
#include <unordered_map>
#include <vector>

namespace dj {

namespace {
constexpr float kPi = 3.14159265358979323846f;
constexpr float kCenterClearanceX = 0.17f;

void clamp_node_hemisphere(OwnedFisheyeNode& n) {
    if (n.side == 0) {
        n.norm_x = std::clamp(n.norm_x, -0.88f, -kCenterClearanceX);
    } else {
        n.norm_x = std::clamp(n.norm_x, kCenterClearanceX, 0.88f);
    }
    n.norm_y = std::clamp(n.norm_y, -0.80f, 0.80f);
}

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

bool is_kanji_cp_local(uint32_t cp) {
    return (cp >= 0x4E00 && cp <= 0x9FFF) || (cp >= 0x3400 && cp <= 0x4DBF);
}

struct KanjiEdgesSchema {
    std::string side_col;
    std::string edge_type_col;
    std::string weight_col;
    std::string entry_col;
    bool detected = false;
};

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
        cached.edge_type_col = pick({"edge_type", "type", "kind", "mode"});
        cached.weight_col = pick({"weight", "score", "freq", "count"});
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
        cached.detected = true;
    }
    return cached;
}
} // namespace

std::vector<OwnedFisheyeNode> solve_fisheye_graph(
    sqlite3* db,
    uint32_t center_cp,
    dj_fisheye_mode_t mode,
    bool include_names,
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

    float ar = (aspect_ratio > 0.2f) ? aspect_ratio : 1.5f;

    sqlite3_stmt* grade_stmt = nullptr;
    sqlite3_prepare_v2(db, "SELECT COALESCE(grade, 0) FROM kanji WHERE codepoint = ?1;", -1, &grade_stmt, nullptr);

    struct ScoredCandidate {
        OwnedFisheyeNode node;
        double effective_score;
        float commonality_scale;
    };

    std::vector<ScoredCandidate> side_cands[2];

    if (mode == DJ_EDGE_YOJIJUKUGO) {
        char center_utf8[8];
        encode_utf8(center_cp, center_utf8);
        std::string like_pat = std::string("%") + center_utf8 + "%";
        std::string name_cond = include_names ? "" : "AND e.is_name = 0 ";

        std::string yoji_sql =
            "SELECT e.entry_id, e.kanji_head, e.kana_head, "
            "       COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), ''), "
            "       COALESCE(e.freq_overall, 999999) "
            "FROM entries e "
            "WHERE LENGTH(e.kanji_head) = 4 AND e.kanji_head LIKE ?1 " + name_cond +
            "ORDER BY e.freq_overall ASC LIMIT 300;";

        sqlite3_stmt* ystmt = nullptr;
        if (sqlite3_prepare_v2(db, yoji_sql.c_str(), -1, &ystmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(ystmt, 1, like_pat.c_str(), -1, SQLITE_TRANSIENT);
            std::unordered_map<uint64_t, bool> seen_side_cp;

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

                float comm_scale = (grade == 0) ? 0.85f : (freq <= 8000 ? 1.24f : 1.02f);
                n.commonality_tier = (grade == 0) ? 3 : (freq <= 8000 ? 0 : 1);
                double score = 1000000.0 / (100.0 + static_cast<double>(freq));
                side_cands[side].push_back({std::move(n), score, comm_scale});
            }
            sqlite3_finalize(ystmt);
        }
    } else {
        auto schema = detect_kanji_edges_schema(db);
        std::string side_expr = schema.side_col.empty() ? "0" : ("ke." + schema.side_col);
        std::string weight_expr = schema.weight_col.empty() ? "1.0" : ("ke." + schema.weight_col);
        std::string entry_expr = schema.entry_col.empty() ? "0" : ("ke." + schema.entry_col);

        std::string where_clause = "WHERE ke.center_cp = ?1 ";
        if (!schema.edge_type_col.empty()) {
            where_clause += "AND ke." + schema.edge_type_col + " = 0 ";
        }
        if (!schema.side_col.empty()) {
            where_clause += "AND ke." + schema.side_col + " = ?2 ";
        }

        std::string sql =
            "SELECT ke.neighbor_cp, " + side_expr + ", " + weight_expr + ", " + entry_expr + ", "
            "       COALESCE(e.kanji_head, e.kana_head, ''), COALESCE(e.kana_head, ''), "
            "       COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), ''), "
            "       COALESCE(e.freq_overall, 999999), COALESCE(e.is_name, 0) "
            "FROM kanji_edges ke "
            "LEFT JOIN entries e ON e.entry_id = " + entry_expr + " " +
            where_clause +
            "ORDER BY " + weight_expr + " DESC LIMIT 120;";

        sqlite3_stmt* stmt = nullptr;
        if (sqlite3_prepare_v2(db, sql.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
            uint8_t num_sides = schema.side_col.empty() ? 1 : 2;
            for (uint8_t side = 0; side < num_sides; ++side) {
                sqlite3_reset(stmt);
                sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(center_cp));
                sqlite3_bind_int(stmt, 2, side);

                std::unordered_map<uint32_t, bool> seen_cp;
                size_t row_idx = 0;
                while (sqlite3_step(stmt) == SQLITE_ROW) {
                    uint32_t ncp = static_cast<uint32_t>(sqlite3_column_int64(stmt, 0));
                    if (seen_cp[ncp]) continue;
                    seen_cp[ncp] = true;

                    OwnedFisheyeNode n;
                    n.codepoint = ncp;
                    encode_utf8(n.codepoint, n.utf8_glyph);
                    int raw_side = sqlite3_column_int(stmt, 1);
                    uint8_t actual_side = schema.side_col.empty()
                        ? static_cast<uint8_t>(row_idx % 2)
                        : static_cast<uint8_t>(raw_side != 0 ? 1 : 0);
                    n.side = actual_side;
                    row_idx++;

                    double raw_weight = sqlite3_column_double(stmt, 2);
                    n.top_entry_id = static_cast<uint32_t>(sqlite3_column_int64(stmt, 3));
                    const auto* cw = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4));
                    const auto* ck = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));
                    const auto* cg = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 6));
                    n.compound_word = cw ? cw : "";
                    n.compound_kana = ck ? ck : "";
                    n.compound_gloss = cg ? cg : "";
                    uint32_t freq_overall = static_cast<uint32_t>(sqlite3_column_int64(stmt, 7));

                    int grade = 1;
                    if (grade_stmt) {
                        sqlite3_reset(grade_stmt);
                        sqlite3_bind_int64(grade_stmt, 1, static_cast<sqlite3_int64>(n.codepoint));
                        if (sqlite3_step(grade_stmt) == SQLITE_ROW) {
                            grade = sqlite3_column_int(grade_stmt, 0);
                        }
                    }

                    float comm_scale = 1.0f;
                    if (grade == 0) {
                        n.commonality_tier = 3;
                        comm_scale = 0.80f;
                    } else if (freq_overall <= 2500) {
                        n.commonality_tier = 0;
                        comm_scale = 1.32f;
                    } else if (freq_overall <= 12000) {
                        n.commonality_tier = 1;
                        comm_scale = 1.06f;
                    } else {
                        n.commonality_tier = 2;
                        comm_scale = 0.86f;
                    }

                    double score = raw_weight;
                    if (freq_overall <= 1500) score *= 2.10;
                    else if (freq_overall <= 5000) score *= 1.45;
                    if (grade == 0) score *= 0.35;

                    side_cands[actual_side].push_back({std::move(n), score, comm_scale});
                }
            }
            sqlite3_finalize(stmt);
        }

        // When `Names` toggle is enabled, also surface prominent 2-kanji name compounds (`is_name = 1`)
        if (include_names) {
            char center_utf8[8];
            encode_utf8(center_cp, center_utf8);
            std::string pat_prefix = std::string(center_utf8) + "_";
            std::string pat_suffix = std::string("_") + center_utf8;

            const char* name_sql =
                "SELECT e.entry_id, e.kanji_head, e.kana_head, "
                "       COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), 'Name') "
                "FROM entries e "
                "WHERE e.is_name = 1 AND LENGTH(e.kanji_head) = 2 AND (e.kanji_head LIKE ?1 OR e.kanji_head LIKE ?2) "
                "ORDER BY e.freq_overall ASC LIMIT 60;";

            sqlite3_stmt* nstmt = nullptr;
            if (sqlite3_prepare_v2(db, name_sql, -1, &nstmt, nullptr) == SQLITE_OK) {
                sqlite3_bind_text(nstmt, 1, pat_prefix.c_str(), -1, SQLITE_TRANSIENT);
                sqlite3_bind_text(nstmt, 2, pat_suffix.c_str(), -1, SQLITE_TRANSIENT);
                while (sqlite3_step(nstmt) == SQLITE_ROW) {
                    uint32_t eid = static_cast<uint32_t>(sqlite3_column_int64(nstmt, 0));
                    const auto* kh = reinterpret_cast<const char*>(sqlite3_column_text(nstmt, 1));
                    const auto* ka = reinterpret_cast<const char*>(sqlite3_column_text(nstmt, 2));
                    const auto* gl = reinterpret_cast<const char*>(sqlite3_column_text(nstmt, 3));
                    if (!kh) continue;
                    auto cps = utf8_to_cps_local(kh);
                    if (cps.size() != 2) continue;

                    uint8_t side = (cps[0] == center_cp) ? 1 : 0;
                    uint32_t ncp = (side == 1) ? cps[1] : cps[0];
                    if (!is_kanji_cp_local(ncp)) continue;

                    bool exists = false;
                    for (const auto& existing : side_cands[side]) {
                        if (existing.node.codepoint == ncp) { exists = true; break; }
                    }
                    if (exists) continue;

                    OwnedFisheyeNode n;
                    n.codepoint = ncp;
                    encode_utf8(ncp, n.utf8_glyph);
                    n.side = side;
                    n.commonality_tier = 1;
                    n.top_entry_id = eid;
                    n.compound_word = kh;
                    n.compound_kana = ka ? ka : "";
                    n.compound_gloss = std::string("[Name] ") + (gl ? gl : "");
                    side_cands[side].push_back({std::move(n), 2.5, 1.02f});
                }
                sqlite3_finalize(nstmt);
            }
        }
    }

    for (uint8_t side = 0; side <= 1; ++side) {
        auto& cands = side_cands[side];
        std::sort(cands.begin(), cands.end(), [](const ScoredCandidate& a, const ScoredCandidate& b) {
            return a.effective_score > b.effective_score;
        });

        double total_score = 0.0;
        for (const auto& c : cands) total_score += std::max(0.1, c.effective_score);
        if (total_score <= 0.0) total_score = 1.0;

        size_t visible_count = std::min(cands.size(), max_per_side);
        size_t overflow_count = (cands.size() > max_per_side) ? (cands.size() - max_per_side) : 0;
        if (side == 0) out_left_overflow = overflow_count;
        else out_right_overflow = overflow_count;

        for (size_t idx = 0; idx < visible_count; ++idx) {
            double sc_val = cands[idx].effective_score;
            OwnedFisheyeNode n = std::move(cands[idx].node);
            n.share_pct = static_cast<float>((sc_val / total_score) * 100.0);
            float comm_scale = cands[idx].commonality_scale;

            const size_t ring = (idx < 5) ? 0 : 1;
            const size_t ring_idx = (ring == 0) ? idx : (idx - 5);
            const size_t ring_count = (ring == 0) ? std::min<size_t>(visible_count, 5) : (visible_count - 5);

            float t = (ring_count <= 1) ? 0.5f : (static_cast<float>(ring_idx) / static_cast<float>(ring_count - 1));
            float span = (ring == 0) ? 0.68f : 0.78f;
            float theta = (t - 0.5f) * kPi * span;
            if (ring == 1 && ring_count > 1) {
                theta += (0.04f * ((ring_idx % 2 == 0) ? 1.0f : -1.0f));
            }

            float base_r = (ring == 0) ? 0.35f : 0.67f;
            float dir_x = (n.side == 0) ? -std::cos(theta) : std::cos(theta);
            float dir_y = std::sin(theta);

            float raw_x = (dir_x * base_r) / std::max(1.0f, ar * 0.72f);
            float raw_y = dir_y * base_r * 1.18f;

            float dx = raw_x - focus_x;
            float dy = raw_y - focus_y;
            float dist = std::sqrt(dx * dx + dy * dy);
            const float lens_radius = 0.55f;
            const float lens_strength = 0.34f;

            if (dist < lens_radius && dist > 1e-4f) {
                float factor = 1.0f + lens_strength * std::cos((dist / lens_radius) * (kPi * 0.5f));
                n.norm_x = focus_x + dx * factor;
                n.norm_y = focus_y + dy * factor;
                n.scale = std::min(1.52f, comm_scale * factor);
                n.opacity = 1.0f;
            } else {
                n.norm_x = raw_x;
                n.norm_y = raw_y;
                n.scale = comm_scale;
                n.opacity = (ring == 0) ? 0.98f : 0.84f;
            }

            clamp_node_hemisphere(n);
            nodes.push_back(std::move(n));
        }

        // Emit up to 5 overflow preview sub-nodes (`is_overflow_preview = 1`) for the "+N more" pop-out bubble
        size_t preview_count = std::min<size_t>(overflow_count, 5);
        for (size_t p = 0; p < preview_count; ++p) {
            size_t src_idx = visible_count + p;
            double sc_val = cands[src_idx].effective_score;
            OwnedFisheyeNode n = std::move(cands[src_idx].node);
            n.is_overflow_preview = 1;
            n.share_pct = static_cast<float>((sc_val / total_score) * 100.0);
            n.scale = 0.65f;
            n.opacity = 0.95f;
            nodes.push_back(std::move(n));
        }
    }

    for (int iter = 0; iter < 6; ++iter) {
        for (size_t i = 0; i < nodes.size(); ++i) {
            if (nodes[i].is_overflow_preview) continue;
            for (size_t j = i + 1; j < nodes.size(); ++j) {
                if (nodes[j].is_overflow_preview) continue;
                float dx = (nodes[j].norm_x - nodes[i].norm_x) * ar;
                float dy = (nodes[j].norm_y - nodes[i].norm_y);
                float d = std::sqrt(dx * dx + dy * dy);
                float min_d = 0.21f;
                if (d < min_d && d > 1e-4f) {
                    float push = (min_d - d) * 0.5f;
                    float ux = (dx / d) / ar;
                    float uy = (dy / d);
                    nodes[i].norm_x -= ux * push;
                    nodes[i].norm_y -= uy * push;
                    nodes[j].norm_x += ux * push;
                    nodes[j].norm_y += uy * push;
                    clamp_node_hemisphere(nodes[i]);
                    clamp_node_hemisphere(nodes[j]);
                }
            }
        }
    }

    if (grade_stmt) sqlite3_finalize(grade_stmt);
    return nodes;
}

} // namespace dj
