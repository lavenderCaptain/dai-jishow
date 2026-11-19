#include "../dj_internal.hpp"
#include <algorithm>
#include <cctype>
#include <cstring>
#include <string>
#include <vector>

/**
 * @file storage.cpp
 * @brief `dj_storage` — all read-only SQLite access for the Dai-Jishow core.
 *
 * This module is the single place that talks to the corpus database. It
 * provides:
 *
 *  - Word search (`db_search_words`) for the five `dj_search_mode_t`
 *    strategies, including the romaji → kana AUTO path and the English FTS5
 *    fallback with gloss re-ranking.
 *  - Full entry detail (`db_get_entry_detail`): head + paired entry, per-
 *    kanji ruby (furigana) segmentation, senses, and up to 8 lemmatized
 *    example sentences with UTF-16 token spans (including a greedy
 *    segmentation pass for kanji the pre-tokenizer didn't cover).
 *  - Full kanji detail (`db_get_kanji_detail`), including decoding of the
 *    quantized KanjiVG stroke blob and the component-radical breakdown.
 *  - Radical search (`db_search_radicals`) as an intersection of Kangxi
 *    radical tables.
 *
 * Everything here is read-only: the database is opened with
 * `SQLITE_OPEN_READONLY` (see `dj_capi.cpp`) and only `SELECT` statements
 * are issued.
 */

namespace dj {

namespace {

/// Kangxi radical glyphs indexed by radical id (1..214). Slot 0 is an empty
/// placeholder because radical ids are 1-based.
constexpr const char* kKangxiRadicalGlyphs[215] = {
    "", "一", "丨", "丶", "丿", "乙", "亅", "二", "亠", "人", "儿",
    "入", "八", "冂", "冖", "冫", "几", "凵", "刀", "力", "勹",
    "匕", "匚", "匸", "十", "卜", "卩", "厂", "厶", "又", "口",
    "囗", "土", "士", "夂", "夊", "夕", "大", "女", "子", "宀",
    "寸", "小", "尢", "尸", "屮", "山", "巛", "工", "己", "巾",
    "干", "幺", "广", "廴", "廾", "弋", "弓", "彐", "彡", "彳",
    "心", "戈", "戶", "手", "支", "攴", "文", "斗", "斤", "方",
    "无", "日", "曰", "月", "木", "欠", "止", "歹", "殳", "毋",
    "比", "毛", "氏", "气", "水", "火", "爪", "父", "爻", "爿",
    "片", "牙", "牛", "犬", "玄", "玉", "瓜", "瓦", "甘", "生",
    "用", "田", "疋", "疒", "癶", "白", "皮", "皿", "目", "矛",
    "矢", "石", "示", "禸", "禾", "穴", "立", "竹", "米", "糸",
    "缶", "网", "羊", "羽", "老", "而", "耒", "耳", "聿", "肉",
    "臣", "自", "至", "臼", "舌", "舛", "舟", "艮", "色", "艸",
    "虍", "虫", "血", "行", "衣", "襾", "見", "角", "言", "谷",
    "豆", "豕", "豸", "貝", "赤", "走", "足", "身", "車", "辛",
    "辰", "辵", "邑", "酉", "釆", "里", "金", "長", "門", "阜",
    "隶", "隹", "雨", "靑", "非", "面", "革", "韋", "韭", "音",
    "頁", "風", "飛", "食", "首", "香", "馬", "骨", "高", "髟",
    "鬥", "鬯", "鬲", "鬼", "魚", "鳥", "鹵", "鹿", "麥", "麻",
    "黃", "黍", "黑", "黹", "黽", "鼎", "鼓", "鼠", "鼻", "齊",
    "齒", "龍", "龜", "龠"
};

/// Lower-case an ASCII string (non-ASCII bytes are left untouched).
std::string to_lower_ascii(const std::string& s) {
    std::string out = s;
    for (char& c : out) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    return out;
}

/// Score how well the *primary* (sense-0) English gloss matches an English
/// query, for re-ranking the FTS5 fallback results.
///
/// The gloss string is `;`-separated; each gloss item is inspected
/// independently and the best tier across all items wins:
///
///   0 — the query is an exact match for a whole gloss (or its core, with any
///       trailing parenthetical stripped).
///   1 — the query is a leading word of a gloss (`"to <query>"` introducers
///       are allowed).
///   2 — the query appears as a substring somewhere in a gloss.
///   3 — no match (or the query / gloss is empty).
int english_gloss_relevance_tier(const std::string& primary_gloss, const std::string& query_lower) {
    if (query_lower.empty() || primary_gloss.empty()) return 3;
    std::string pg = to_lower_ascii(primary_gloss);

    size_t start = 0;
    bool exact_any_gloss = false;
    bool prefix_any_gloss = false;
    bool word_in_primary = false;

    while (start <= pg.size()) {
        size_t semi = pg.find(';', start);
        std::string item = (semi == std::string::npos) ? pg.substr(start) : pg.substr(start, semi - start);
        size_t l = item.find_first_not_of(" \t");
        size_t r = item.find_last_not_of(" \t");
        if (l != std::string::npos) {
            item = item.substr(l, r - l + 1);
            std::string core = item;
            size_t paren = core.find('(');
            if (paren != std::string::npos) {
                core = core.substr(0, paren);
                size_t cr = core.find_last_not_of(" \t");
                if (cr != std::string::npos) core = core.substr(0, cr + 1);
            }
            if (core == query_lower || item == query_lower) {
                exact_any_gloss = true;
            } else if (item.rfind(query_lower + " ", 0) == 0 || item.rfind("to " + query_lower, 0) == 0) {
                prefix_any_gloss = true;
            } else if (item.find(query_lower) != std::string::npos) {
                word_in_primary = true;
            }
        }
        if (semi == std::string::npos) break;
        start = semi + 1;
    }

    if (exact_any_gloss) return 0;
    if (prefix_any_gloss) return 1;
    if (word_in_primary) return 2;
    return 3;
}

/// Compute the exclusive upper bound of a UTF-8 prefix for B-tree range
/// scans.
///
/// Appending `U+FFFF` (bytes `EF BF BF`) to the prefix yields a value that
/// sorts *above* every valid UTF-8 string sharing that prefix (and below any
/// string with a longer/different prefix), so SQLite can execute a pure
/// index range scan `prefix <= col < upper` without a full table scan.
std::string utf8_prefix_upper_bound(const std::string& prefix) {
    return prefix + std::string({static_cast<char>(0xEF), static_cast<char>(0xBF), static_cast<char>(0xBF)});
}

/// Count the UTF-16 code units occupied by a byte range of a UTF-8 string
/// (ASCII and BMP characters = 1 unit, supplementary-plane characters = 2).
/// Used to convert the byte-based token spans stored in the corpus into the
/// UTF-16 coordinates the host text renderer expects.
uint16_t utf8_byte_range_to_utf16_units(const std::string& s, size_t start_byte, size_t byte_len) {
    size_t end = std::min(s.size(), start_byte + byte_len);
    uint16_t units = 0;
    size_t i = std::min(s.size(), start_byte);
    while (i < end) {
        unsigned char c = static_cast<unsigned char>(s[i]);
        if (c < 0x80) {
            units += 1;
            i += 1;
        } else if ((c & 0xE0) == 0xC0) {
            units += 1;
            i += 2;
        } else if ((c & 0xF0) == 0xE0) {
            units += 1;
            i += 3;
        } else {
            units += 2;
            i += 4;
        }
    }
    return units;
}

/// Decode one codepoint at `pos` and advance `pos` past it. Malformed
/// trailing bytes are skipped one byte at a time as a fallback.
uint32_t next_utf8_cp(const std::string& s, size_t& pos) {
    if (pos >= s.size()) return 0;
    unsigned char c = static_cast<unsigned char>(s[pos]);
    if (c < 0x80) {
        pos += 1;
        return c;
    } else if ((c & 0xE0) == 0xC0 && pos + 1 < s.size()) {
        uint32_t cp = ((c & 0x1F) << 6) | (static_cast<unsigned char>(s[pos + 1]) & 0x3F);
        pos += 2;
        return cp;
    } else if ((c & 0xF0) == 0xE0 && pos + 2 < s.size()) {
        uint32_t cp = ((c & 0x0F) << 12) |
                      ((static_cast<unsigned char>(s[pos + 1]) & 0x3F) << 6) |
                      (static_cast<unsigned char>(s[pos + 2]) & 0x3F);
        pos += 3;
        return cp;
    } else if ((c & 0xF8) == 0xF0 && pos + 3 < s.size()) {
        uint32_t cp = ((c & 0x07) << 18) |
                      ((static_cast<unsigned char>(s[pos + 1]) & 0x3F) << 12) |
                      ((static_cast<unsigned char>(s[pos + 2]) & 0x3F) << 6) |
                      (static_cast<unsigned char>(s[pos + 3]) & 0x3F);
        pos += 4;
        return cp;
    }
    pos += 1;
    return c;
}

/// Decode an entire UTF-8 string into a vector of codepoints.
std::vector<uint32_t> utf8_to_cps(const std::string& s) {
    std::vector<uint32_t> cps;
    size_t pos = 0;
    while (pos < s.size()) {
        cps.push_back(next_utf8_cp(s, pos));
    }
    return cps;
}

/// Encode the `cps[start .. start+len)` codepoint range back to UTF-8.
std::string cps_to_utf8(const std::vector<uint32_t>& cps, size_t start, size_t len) {
    std::string out;
    char buf[8];
    size_t end = std::min(cps.size(), start + len);
    for (size_t i = start; i < end; ++i) {
        encode_utf8(cps[i], buf);
        out += buf;
    }
    return out;
}

/// @return `true` for CJK Unified Ideographs (U+4E00–U+9FFF), Extension A
///         (U+3400–U+4DBF), and the iteration mark 〯 (U+3005).
bool is_kanji_cp(uint32_t cp) {
    return (cp >= 0x4E00 && cp <= 0x9FFF) || (cp >= 0x3400 && cp <= 0x4DBF) || cp == 0x3005;
}

/// @return `true` for a hiragana codepoint (U+3041–U+3096).
bool is_hiragana_cp(uint32_t cp) {
    return (cp >= 0x3041 && cp <= 0x3096);
}

/// Map a katakana codepoint onto the equivalent hiragana (the katakana block
/// is exactly the hiragana block shifted by +0x60); other codepoints pass
/// through unchanged.
uint32_t to_hiragana_cp(uint32_t cp) {
    if (cp >= 0x30A1 && cp <= 0x30F6) return cp - 0x60;
    return cp;
}

/// Fold a kana onto its *base* form for tolerant prefix matching:
/// daku-ten/han-ten kana map back to their unvoiced partner (ぎ → が,
/// ぱ → は, ぷ → ぶ, ...) and youon small vowels map to their parent (ゅ →
/// ゆ, ょ → よ). Only applied to the *first* mora of a reading match.
uint32_t base_kana_cp(uint32_t cp) {
    cp = to_hiragana_cp(cp);
    if (cp >= 0x304C && cp <= 0x3062 && (cp % 2 == 0)) return cp - 1;
    if (cp >= 0x3065 && cp <= 0x3069 && (cp % 2 == 1)) return cp - 1;
    if (cp >= 0x3070 && cp <= 0x307C) {
        uint32_t rem = (cp - 0x306F) % 3;
        if (rem != 0) return cp - rem;
    }
    return cp;
}

/// @return `true` when `cand` matches `target` starting at `offset`, with
///         three tolerances: any mora may differ by script only (hiragana vs
///         katakana), the first mora may differ by daku-ten (base-form
///         match), and a trailing small *tsu* (っ / ッ) in `target` is ignored
///         on the final mora (geminate handling).
bool kana_prefix_matches(const std::vector<uint32_t>& target, size_t offset, const std::vector<uint32_t>& cand) {
    if (cand.empty() || offset + cand.size() > target.size()) return false;
    for (size_t i = 0; i < cand.size(); ++i) {
        uint32_t t = target[offset + i];
        uint32_t c = cand[i];
        if (t == c || to_hiragana_cp(t) == to_hiragana_cp(c)) continue;
        if (i == 0 && base_kana_cp(t) == base_kana_cp(c)) continue;
        if (i + 1 == cand.size() && (t == 0x3063 || t == 0x30C3)) continue;
        return false;
    }
    return true;
}

/// Collect every candidate reading (On + Kun) for one kanji as hiragana
/// codepoint sequences, longest-first, for the reading-split solver.
///
/// Each reading token from the corpus is cleaned before use: the
/// pitch-accent digit suffix (`.`) is stripped, okurigana dash markers
/// (`-`) are trimmed, and katakana is folded to hiragana.
std::vector<std::vector<uint32_t>> get_kanji_candidate_readings(sqlite3* db, uint32_t cp) {
    std::vector<std::vector<uint32_t>> cands;
    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db, "SELECT on_readings, kun_readings FROM kanji WHERE codepoint = ?1;", -1, &stmt, nullptr) != SQLITE_OK) {
        return cands;
    }
    sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(cp));
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        for (int col = 0; col < 2; ++col) {
            const auto* txt = reinterpret_cast<const char*>(sqlite3_column_text(stmt, col));
            if (!txt) continue;
            std::string raw(txt);
            size_t start = 0;
            while (start <= raw.size()) {
                size_t comma = raw.find(',', start);
                std::string tok = (comma == std::string::npos) ? raw.substr(start) : raw.substr(start, comma - start);
                size_t dot = tok.find('.');
                if (dot != std::string::npos) tok = tok.substr(0, dot);
                if (!tok.empty() && tok[0] == '-') tok = tok.substr(1);
                if (!tok.empty() && tok.back() == '-') tok.pop_back();

                auto cps = utf8_to_cps(tok);
                for (auto& k : cps) k = to_hiragana_cp(k);
                if (!cps.empty()) cands.push_back(std::move(cps));

                if (comma == std::string::npos) break;
                start = comma + 1;
            }
        }
    }
    sqlite3_finalize(stmt);

    std::sort(cands.begin(), cands.end(), [](const auto& a, const auto& b) {
        return a.size() > b.size();
    });
    return cands;
}

/// Fetch the first *standalone* Kun reading (no pitch-accent digit, no
/// okurigana dash) for a kanji — the preferred reading to use when the kanji
/// appears as a single-kanji word.
std::string get_primary_standalone_kun(sqlite3* db, uint32_t cp) {
    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db, "SELECT kun_readings FROM kanji WHERE codepoint = ?1;", -1, &stmt, nullptr) != SQLITE_OK) {
        return "";
    }
    sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(cp));
    std::string best;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        const auto* txt = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
        if (txt) {
            std::string raw(txt);
            size_t start = 0;
            while (start <= raw.size()) {
                size_t comma = raw.find(',', start);
                std::string tok = (comma == std::string::npos) ? raw.substr(start) : raw.substr(start, comma - start);
                if (!tok.empty() && tok.find('.') == std::string::npos && tok.find('-') == std::string::npos) {
                    auto cps = utf8_to_cps(tok);
                    for (auto& k : cps) k = to_hiragana_cp(k);
                    best = cps_to_utf8(cps, 0, cps.size());
                    break;
                }
                if (comma == std::string::npos) break;
                start = comma + 1;
            }
        }
    }
    sqlite3_finalize(stmt);
    return best;
}

/// Backtracking solver that partitions the kana reading of a kanji compound
/// into per-kanji chunks.
///
/// For each kanji (left-to-right) it tries that kanji's candidate readings
/// and requires the reading at `k_pos` to match (via `kana_prefix_matches`);
/// the last kanji must consume exactly the remaining kana. Returns `true`
/// and fills `out_ranges` with `{start, length}` pairs on success.
bool solve_kanji_reading_split(
    const std::vector<uint32_t>& kanji_cps,
    const std::vector<std::vector<std::vector<uint32_t>>>& all_cands,
    const std::vector<uint32_t>& kana_cps,
    size_t idx,
    size_t k_pos,
    std::vector<std::pair<size_t, size_t>>& out_ranges) {

    if (idx == kanji_cps.size()) {
        return k_pos == kana_cps.size();
    }
    size_t remaining_kanji = kanji_cps.size() - idx;
    if (kana_cps.size() - k_pos < remaining_kanji) return false;

    if (idx + 1 == kanji_cps.size()) {
        out_ranges[idx] = {k_pos, kana_cps.size() - k_pos};
        return true;
    }

    for (const auto& cand : all_cands[idx]) {
        if (k_pos + cand.size() + (remaining_kanji - 1) <= kana_cps.size() &&
            kana_prefix_matches(kana_cps, k_pos, cand)) {
            out_ranges[idx] = {k_pos, cand.size()};
            if (solve_kanji_reading_split(kanji_cps, all_cands, kana_cps, idx + 1, k_pos + cand.size(), out_ranges)) {
                return true;
            }
        }
    }
    return false;
}

// Lookup sub-compound readings (e.g. `山車` -> `だし` inside `矛山車` = `ほこだし`)
std::vector<std::vector<uint32_t>> lookup_subword_readings(sqlite3* db, const std::string& sub_kanji) {
    std::vector<std::vector<uint32_t>> out;
    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db, "SELECT kana_head FROM entries WHERE kanji_head = ?1 ORDER BY freq_overall ASC LIMIT 6;", -1, &stmt, nullptr) != SQLITE_OK) {
        return out;
    }
    sqlite3_bind_text(stmt, 1, sub_kanji.c_str(), -1, SQLITE_TRANSIENT);
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const auto* txt = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
        if (txt && txt[0]) {
            auto cps = utf8_to_cps(txt);
            for (auto& k : cps) k = to_hiragana_cp(k);
            if (!cps.empty()) out.push_back(std::move(cps));
        }
    }
    sqlite3_finalize(stmt);
    return out;
}

/// Segment an entry head (`surface`) + its kana `reading` into per-kanji
/// ruby cells.
///
/// The leading/suffixing kana (prefix / okuri) become their own cells with
/// empty furigana. The middle kanji run is split per-kanji using
/// `solve_kanji_reading_split`. If that fails for a 3-kanji compound that
/// contains a jukujikun (e.g. 矛 + 山車 = ほこ + だし), a 1+2 / 2+1 subword
/// lookup is attempted; otherwise the whole middle run becomes a single
/// cell.
std::vector<OwnedRubyCell> build_per_kanji_ruby(sqlite3* db, const std::string& surface, const std::string& reading) {
    std::vector<OwnedRubyCell> cells;
    if (surface.empty()) return cells;

    auto s_cps = utf8_to_cps(surface);
    auto r_cps = utf8_to_cps(reading);

    if (r_cps.empty() || surface == reading) {
        for (uint32_t cp : s_cps) {
            char buf[8];
            encode_utf8(cp, buf);
            cells.push_back({buf, "", is_kanji_cp(cp) ? cp : 0});
        }
        return cells;
    }

    size_t prefix = 0;
    while (prefix < s_cps.size() && prefix < r_cps.size() &&
           to_hiragana_cp(s_cps[prefix]) == to_hiragana_cp(r_cps[prefix])) {
        char buf[8];
        encode_utf8(s_cps[prefix], buf);
        cells.push_back({buf, "", 0});
        prefix += 1;
    }

    size_t suffix = 0;
    while ((s_cps.size() - 1 - suffix) >= prefix &&
           (r_cps.size() - 1 - suffix) >= prefix &&
           to_hiragana_cp(s_cps[s_cps.size() - 1 - suffix]) == to_hiragana_cp(r_cps[r_cps.size() - 1 - suffix])) {
        suffix += 1;
    }

    size_t mid_s_end = s_cps.size() - suffix;
    size_t mid_r_end = r_cps.size() - suffix;

    if (prefix < mid_s_end) {
        std::vector<uint32_t> mid_s(s_cps.begin() + prefix, s_cps.begin() + mid_s_end);
        std::vector<uint32_t> mid_r(r_cps.begin() + prefix, r_cps.begin() + mid_r_end);

        bool all_kanji = true;
        for (uint32_t cp : mid_s) {
            if (!is_kanji_cp(cp)) { all_kanji = false; break; }
        }

        if (all_kanji && !mid_r.empty()) {
            std::vector<std::vector<std::vector<uint32_t>>> all_cands;
            all_cands.reserve(mid_s.size());
            for (uint32_t cp : mid_s) {
                all_cands.push_back(get_kanji_candidate_readings(db, cp));
            }
            std::vector<std::pair<size_t, size_t>> ranges(mid_s.size());
            if (solve_kanji_reading_split(mid_s, all_cands, mid_r, 0, 0, ranges)) {
                for (size_t i = 0; i < mid_s.size(); ++i) {
                    char buf[8];
                    encode_utf8(mid_s[i], buf);
                    std::string furi = cps_to_utf8(mid_r, ranges[i].first, ranges[i].second);
                    cells.push_back({buf, std::move(furi), mid_s[i]});
                }
            } else if (mid_s.size() == 3) {
                // Handle 1+2 or 2+1 compounds containing jukujikun (e.g. `矛` + `山車` = `ほこ` + `だし`)
                bool split_3 = false;
                // Case A: 1 kanji + 2-kanji jukujikun
                std::string tail2 = cps_to_utf8(mid_s, 1, 2);
                for (const auto& t2_read : lookup_subword_readings(db, tail2)) {
                    if (t2_read.size() < mid_r.size()) {
                        size_t head_len = mid_r.size() - t2_read.size();
                        if (kana_prefix_matches(mid_r, head_len, t2_read)) {
                            char buf0[8];
                            encode_utf8(mid_s[0], buf0);
                            cells.push_back({buf0, cps_to_utf8(mid_r, 0, head_len), mid_s[0]});
                            cells.push_back({tail2, cps_to_utf8(mid_r, head_len, t2_read.size()), 0});
                            split_3 = true;
                            break;
                        }
                    }
                }
                // Case B: 2-kanji jukujikun + 1 kanji
                if (!split_3) {
                    std::string head2 = cps_to_utf8(mid_s, 0, 2);
                    for (const auto& h2_read : lookup_subword_readings(db, head2)) {
                        if (h2_read.size() < mid_r.size() && kana_prefix_matches(mid_r, 0, h2_read)) {
                            char buf2[8];
                            encode_utf8(mid_s[2], buf2);
                            cells.push_back({head2, cps_to_utf8(mid_r, 0, h2_read.size()), 0});
                            cells.push_back({buf2, cps_to_utf8(mid_r, h2_read.size(), mid_r.size() - h2_read.size()), mid_s[2]});
                            split_3 = true;
                            break;
                        }
                    }
                }
                if (!split_3) {
                    cells.push_back({
                        cps_to_utf8(mid_s, 0, mid_s.size()),
                        cps_to_utf8(mid_r, 0, mid_r.size()),
                        0
                    });
                }
            } else {
                cells.push_back({
                    cps_to_utf8(mid_s, 0, mid_s.size()),
                    cps_to_utf8(mid_r, 0, mid_r.size()),
                    mid_s.size() == 1 ? mid_s[0] : 0
                });
            }
        } else {
            cells.push_back({
                cps_to_utf8(mid_s, 0, mid_s.size()),
                cps_to_utf8(mid_r, 0, mid_r.size()),
                (mid_s.size() == 1 && is_kanji_cp(mid_s[0])) ? mid_s[0] : 0
            });
        }
    }

    for (size_t i = mid_s_end; i < s_cps.size(); ++i) {
        char buf[8];
        encode_utf8(s_cps[i], buf);
        cells.push_back({buf, "", 0});
    }

    return cells;
}

/// Copy one `entries` row (the 10 shared SELECT-list columns) into an
/// `OwnedWordHit`.
void bind_hit_from_row(sqlite3_stmt* stmt, OwnedWordHit& h) {
    h.entry_id = static_cast<uint32_t>(sqlite3_column_int64(stmt, 0));
    h.kanji_head = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
    h.kana_head = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
    h.alt_forms = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3));
    h.primary_gloss = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4));
    h.pos_mask = static_cast<uint64_t>(sqlite3_column_int64(stmt, 5));
    h.pitch_accent = static_cast<uint8_t>(sqlite3_column_int(stmt, 6));
    h.freq_rank = static_cast<uint32_t>(sqlite3_column_int64(stmt, 7));
    h.pair_entry_id = static_cast<uint32_t>(sqlite3_column_int64(stmt, 8));
    h.is_name = sqlite3_column_int(stmt, 9) != 0;
}

} // namespace

/// Execute a dictionary search and return the owned result rows.
///
/// Query pipeline:
///   1. In `DJ_SEARCH_AUTO`, a romaji query is transliterated to kana; if
///      the transliteration still contains ASCII letters (i.e. it wasn't
///      clean romaji), the query is treated as English and routed to the
///      FTS5 index instead.
///   2. The SQL is chosen per mode: FTS5 `MATCH`, exact, homonyms (kana
///      only), any (`LIKE`), or the default prefix range scan.
///   3. FTS5 results are re-ranked by `english_gloss_relevance_tier` and
///      then truncated to `limit`.
///
/// Results are always ordered by `freq_overall` (most common first).
std::vector<OwnedWordHit> db_search_words(
    sqlite3* db,
    const std::string& raw_query,
    dj_search_mode_t mode,
    bool include_names,
    size_t limit) {

    std::vector<OwnedWordHit> results;
    if (!db || raw_query.empty() || limit == 0) return results;

    std::string query = raw_query;
    bool use_english_fts = false;
    // True when we transliterated romaji -> kana and searched the kana form. Used
    // to trigger the English fallback below if that kana search yields nothing.
    bool tried_kana = false;

    if (mode == DJ_SEARCH_AUTO && is_ascii_romaji(raw_query)) {
        std::string kana = romaji_to_kana(raw_query, false);
        bool clean_kana = true;
        for (unsigned char c : kana) {
            if (std::isalpha(c)) {
                clean_kana = false;
                break;
            }
        }
        if (clean_kana) {
            query = kana;
            tried_kana = true;
        } else {
            use_english_fts = true;
        }
    }

    // `DJ_SEARCH_ENGLISH` bypasses the romaji→kana step entirely and runs the
    // English-gloss FTS index against the raw query. This is how the UI surfaces
    // an English-gloss match for a romaji query that also names a real English
    // word (e.g. "sake" -> 酒/鮭 in the main list, but 為 "benefit" in a
    // separate "Also in English glosses" section).
    if (mode == DJ_SEARCH_ENGLISH) {
        use_english_fts = true;
    }

    std::string name_filter = include_names ? "" : "AND e.is_name = 0 ";
    std::string sql;
    size_t sql_limit = use_english_fts ? std::max<size_t>(limit * 6, 200) : limit;

    if (use_english_fts) {
        sql =
            "SELECT e.entry_id, COALESCE(e.kanji_head, '') AS kanji_head, e.kana_head, COALESCE(e.alt_forms, ''), "
            "       COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), ''), "
            "       e.pos_mask, e.pitch_accent, e.freq_overall, COALESCE(e.pair_entry_id, 0), e.is_name "
            "FROM entries_fts f "
            "JOIN entries e ON e.entry_id = f.rowid "
            "WHERE entries_fts MATCH ?1 " + name_filter +
            "ORDER BY e.freq_overall ASC LIMIT ?2;";
    } else if (mode == DJ_SEARCH_EXACT || mode == DJ_SEARCH_HOMONYMS) {
        std::string cond = (mode == DJ_SEARCH_HOMONYMS)
            ? "(e.kana_head = ?1)"
            : "(e.kanji_head = ?1 OR e.kana_head = ?1)";
        sql =
            "SELECT e.entry_id, COALESCE(e.kanji_head, '') AS kanji_head, e.kana_head, COALESCE(e.alt_forms, ''), "
            "       COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), ''), "
            "       e.pos_mask, e.pitch_accent, e.freq_overall, COALESCE(e.pair_entry_id, 0), e.is_name "
            "FROM entries e "
            "WHERE " + cond + " " + name_filter +
            "ORDER BY e.freq_overall ASC LIMIT ?2;";
    } else if (mode == DJ_SEARCH_ANY) {
        sql =
            "SELECT e.entry_id, COALESCE(e.kanji_head, '') AS kanji_head, e.kana_head, COALESCE(e.alt_forms, ''), "
            "       COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), ''), "
            "       e.pos_mask, e.pitch_accent, e.freq_overall, COALESCE(e.pair_entry_id, 0), e.is_name "
            "FROM entries e "
            "WHERE (e.kanji_head LIKE ?1 OR e.kana_head LIKE ?1) " + name_filter +
            "ORDER BY e.freq_overall ASC LIMIT ?2;";
    } else {
        std::string name_cond = include_names ? "e.is_name IN (0, 1)" : "e.is_name = 0";
        sql =
            "SELECT * FROM ("
            "  SELECT e.entry_id, COALESCE(e.kanji_head, '') AS kanji_head, e.kana_head, COALESCE(e.alt_forms, ''), "
            "         COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), ''), "
            "         e.pos_mask, e.pitch_accent, e.freq_overall, COALESCE(e.pair_entry_id, 0), e.is_name "
            "  FROM entries e "
            "  WHERE " + name_cond + " AND e.kanji_head >= ?1 AND e.kanji_head < ?2 "
            "  UNION "
            "  SELECT e.entry_id, COALESCE(e.kanji_head, '') AS kanji_head, e.kana_head, COALESCE(e.alt_forms, ''), "
            "         COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), ''), "
            "         e.pos_mask, e.pitch_accent, e.freq_overall, COALESCE(e.pair_entry_id, 0), e.is_name "
            "  FROM entries e "
            "  WHERE " + name_cond + " AND e.kana_head >= ?1 AND e.kana_head < ?2 "
            ") "
            "ORDER BY CASE WHEN kanji_head = ?1 OR kana_head = ?1 THEN 0 ELSE 1 END, "
            "         freq_overall ASC LIMIT ?3;";
    }

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) {
        return results;
    }

    std::string upper = utf8_prefix_upper_bound(query);
    std::string fts_q = "\"" + query + "\"*";
    std::string any_pat = "%" + query + "%";

    if (use_english_fts) {
        sqlite3_bind_text(stmt, 1, fts_q.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 2, static_cast<sqlite3_int64>(sql_limit));
    } else if (mode == DJ_SEARCH_EXACT || mode == DJ_SEARCH_HOMONYMS) {
        sqlite3_bind_text(stmt, 1, query.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 2, static_cast<sqlite3_int64>(sql_limit));
    } else if (mode == DJ_SEARCH_ANY) {
        sqlite3_bind_text(stmt, 1, any_pat.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 2, static_cast<sqlite3_int64>(sql_limit));
    } else {
        sqlite3_bind_text(stmt, 1, query.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, upper.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 3, static_cast<sqlite3_int64>(sql_limit));
    }

    while (sqlite3_step(stmt) == SQLITE_ROW) {
        OwnedWordHit h;
        bind_hit_from_row(stmt, h);
        results.push_back(std::move(h));
    }

    sqlite3_finalize(stmt);

    if (use_english_fts && !results.empty()) {
        std::string q_low = to_lower_ascii(query);
        std::stable_sort(results.begin(), results.end(), [&](const OwnedWordHit& a, const OwnedWordHit& b) {
            int ta = english_gloss_relevance_tier(a.primary_gloss, q_low);
            int tb = english_gloss_relevance_tier(b.primary_gloss, q_low);
            if (ta != tb) return ta < tb;
            bool a_has_kanji = !a.kanji_head.empty();
            bool b_has_kanji = !b.kanji_head.empty();
            if (ta == 0 && a_has_kanji != b_has_kanji) return a_has_kanji > b_has_kanji;
            return a.freq_rank < b.freq_rank;
        });
        if (results.size() > limit) {
            results.resize(limit);
        }
    }

    // Fallback: a clean-romaji query (e.g. "bore" -> kana "ぼれ") can have no
    // kana/prefix hits at all, yet still name a real English word. In that case
    // the user almost certainly meant the English term, so re-run the FTS index
    // against the ORIGINAL romaji and surface those results instead.
    if (results.empty() && mode == DJ_SEARCH_AUTO && tried_kana) {
        std::string name_filter2 = include_names ? "" : "AND e.is_name = 0 ";
        std::string sql2 =
            "SELECT e.entry_id, COALESCE(e.kanji_head, '') AS kanji_head, e.kana_head, COALESCE(e.alt_forms, ''), "
            "       COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), ''), "
            "       e.pos_mask, e.pitch_accent, e.freq_overall, COALESCE(e.pair_entry_id, 0), e.is_name "
            "FROM entries_fts f "
            "JOIN entries e ON e.entry_id = f.rowid "
            "WHERE entries_fts MATCH ?1 " + name_filter2 +
            "ORDER BY e.freq_overall ASC LIMIT ?2;";
        sqlite3_stmt* stmt2 = nullptr;
        if (sqlite3_prepare_v2(db, sql2.c_str(), -1, &stmt2, nullptr) == SQLITE_OK) {
            std::string fts_q2 = "\"" + raw_query + "\"*";
            size_t fts_limit = std::max<size_t>(limit * 6, 200);
            sqlite3_bind_text(stmt2, 1, fts_q2.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_int64(stmt2, 2, static_cast<sqlite3_int64>(fts_limit));
            while (sqlite3_step(stmt2) == SQLITE_ROW) {
                OwnedWordHit h;
                bind_hit_from_row(stmt2, h);
                results.push_back(std::move(h));
            }
            sqlite3_finalize(stmt2);

            std::string q_low = to_lower_ascii(raw_query);
            std::stable_sort(results.begin(), results.end(), [&](const OwnedWordHit& a, const OwnedWordHit& b) {
                int ta = english_gloss_relevance_tier(a.primary_gloss, q_low);
                int tb = english_gloss_relevance_tier(b.primary_gloss, q_low);
                if (ta != tb) return ta < tb;
                bool a_has_kanji = !a.kanji_head.empty();
                bool b_has_kanji = !b.kanji_head.empty();
                if (ta == 0 && a_has_kanji != b_has_kanji) return a_has_kanji > b_has_kanji;
                return a.freq_rank < b.freq_rank;
            });
            if (results.size() > limit) {
                results.resize(limit);
            }
        }
    }

    return results;
}

std::vector<OwnedWordHit> db_get_random_words(
    sqlite3* db,
    uint32_t max_freq,
    bool include_names,
    size_t limit) {

    std::vector<OwnedWordHit> results;
    if (!db || limit == 0) return results;

    std::string sql;
    if (max_freq > 0 && max_freq < 150000) {
        sql =
            "SELECT e.entry_id, COALESCE(e.kanji_head, \x27\x27) AS kanji_head, e.kana_head, COALESCE(e.alt_forms, \x27\x27), "
            "       COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), \x27\x27), "
            "       e.pos_mask, e.pitch_accent, e.freq_overall, COALESCE(e.pair_entry_id, 0), e.is_name "
            "FROM entries e "
            "WHERE (?1 = 1 OR e.is_name = 0) AND e.freq_overall <= ?2 "
            "ORDER BY RANDOM() LIMIT ?3;";
    } else {
        sql =
            "SELECT e.entry_id, COALESCE(e.kanji_head, \x27\x27) AS kanji_head, e.kana_head, COALESCE(e.alt_forms, \x27\x27), "
            "       COALESCE((SELECT en_glosses FROM senses s WHERE s.entry_id = e.entry_id AND s.sense_idx = 0), \x27\x27), "
            "       e.pos_mask, e.pitch_accent, e.freq_overall, COALESCE(e.pair_entry_id, 0), e.is_name "
            "FROM entries e "
            "WHERE (?1 = 1 OR e.is_name = 0) "
            "ORDER BY RANDOM() LIMIT ?2;";
    }

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) {
        return results;
    }

    sqlite3_bind_int(stmt, 1, include_names ? 1 : 0);
    if (max_freq > 0 && max_freq < 150000) {
        sqlite3_bind_int64(stmt, 2, static_cast<sqlite3_int64>(max_freq));
        sqlite3_bind_int64(stmt, 3, static_cast<sqlite3_int64>(limit));
    } else {
        sqlite3_bind_int64(stmt, 2, static_cast<sqlite3_int64>(limit));
    }

    results.reserve(limit);
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        OwnedWordHit h;
        bind_hit_from_row(stmt, h);
        results.push_back(std::move(h));
    }

    sqlite3_finalize(stmt);
    return results;
}

/// Load the full detail for one dictionary entry.
///
/// Assembles, in order:
///   - the header row + its paired entry (via `pair_entry_id`);
///   - the per-kanji ruby segmentation of the display head;
///   - all senses (sense 0 also back-fills the header's `primary_gloss`);
///   - up to 8 lemmatized example sentences, whose pre-tokenized spans are
///     decoded from the `token_spans` blob. Any kanji the pre-tokenizer
///     missed is then segmented greedily (longest first, up to 5 kanji),
///     preferring a proper-name reading when one is followed by の, and
///     falling back to a verb-stem match.
///
/// Token spans are converted from corpus byte offsets to UTF-16 units so
/// the host renderer can paint them directly.
bool db_get_entry_detail(sqlite3* db, uint32_t entry_id, OwnedEntryDetail& out) {
    if (!db || entry_id == 0) return false;
    out = OwnedEntryDetail{};

    const char* head_sql =
        "SELECT e.entry_id, COALESCE(e.kanji_head, '') AS kanji_head, e.kana_head, COALESCE(e.alt_forms, ''), "
        "       '', e.pos_mask, e.pitch_accent, e.freq_overall, COALESCE(e.pair_entry_id, 0), e.is_name, "
        "       COALESCE(p.kanji_head, ''), COALESCE(p.kana_head, '') "
        "FROM entries e "
        "LEFT JOIN entries p ON e.pair_entry_id = p.entry_id "
        "WHERE e.entry_id = ?1;";

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db, head_sql, -1, &stmt, nullptr) != SQLITE_OK) return false;
    sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(entry_id));

    if (sqlite3_step(stmt) != SQLITE_ROW) {
        sqlite3_finalize(stmt);
        return false;
    }
    bind_hit_from_row(stmt, out.header);
    out.paired_kanji = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 10));
    out.paired_kana = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 11));
    sqlite3_finalize(stmt);

    std::string disp_head = out.header.kanji_head.empty() ? out.header.kana_head : out.header.kanji_head;
    out.ruby_cells = build_per_kanji_ruby(db, disp_head, out.header.kana_head);

    const char* sense_sql =
        "SELECT sense_idx, pos_mask, en_glosses, COALESCE(ja_glosses, '') "
        "FROM senses WHERE entry_id = ?1 ORDER BY sense_idx ASC;";
    if (sqlite3_prepare_v2(db, sense_sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(entry_id));
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            OwnedSense s;
            s.sense_idx = static_cast<uint32_t>(sqlite3_column_int(stmt, 0));
            s.pos_mask = static_cast<uint64_t>(sqlite3_column_int64(stmt, 1));
            s.en_glosses = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
            s.ja_glosses = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3));
            if (s.sense_idx == 0) out.header.primary_gloss = s.en_glosses;
            out.senses.push_back(std::move(s));
        }
        sqlite3_finalize(stmt);
    }

    const char* sent_sql =
        "SELECT s.sent_id, s.jp_text, s.en_text, s.token_spans "
        "FROM sentence_index si "
        "JOIN sentences s ON s.sent_id = si.sent_id "
        "WHERE si.entry_id = ?1 LIMIT 8;";

    sqlite3_stmt* kana_stmt = nullptr;
    sqlite3_prepare_v2(db, "SELECT kana_head FROM entries WHERE entry_id = ?1;", -1, &kana_stmt, nullptr);

    sqlite3_stmt* word_head_stmt = nullptr;
    sqlite3_prepare_v2(
        db,
        "SELECT entry_id, kana_head FROM entries "
        "WHERE kanji_head = ?1 AND is_name = 0 "
        "ORDER BY CASE WHEN ?2 != '' AND kana_head = ?2 THEN 0 ELSE 1 END, freq_overall ASC LIMIT 1;",
        -1, &word_head_stmt, nullptr);

    sqlite3_stmt* name_head_stmt = nullptr;
    sqlite3_prepare_v2(
        db,
        "SELECT entry_id, kana_head FROM entries "
        "WHERE kanji_head = ?1 AND is_name = 1 "
        "ORDER BY freq_overall ASC LIMIT 1;",
        -1, &name_head_stmt, nullptr);

    sqlite3_stmt* verb_stem_stmt = nullptr;
    sqlite3_prepare_v2(
        db,
        "SELECT entry_id, kana_head FROM entries "
        "WHERE kanji_head >= ?1 AND kanji_head < ?2 AND is_name = 0 "
        "ORDER BY freq_overall ASC LIMIT 1;",
        -1, &verb_stem_stmt, nullptr);

    if (sqlite3_prepare_v2(db, sent_sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(entry_id));
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            OwnedSentence sent;
            sent.sent_id = static_cast<uint32_t>(sqlite3_column_int64(stmt, 0));
            sent.jp_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
            sent.en_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));

            struct ByteSpan {
                size_t b_off;
                size_t b_len;
                uint32_t eid;
                std::string kana;
            };
            std::vector<ByteSpan> spans;

            const auto* blob = static_cast<const uint8_t*>(sqlite3_column_blob(stmt, 3));
            size_t blob_len = static_cast<size_t>(sqlite3_column_bytes(stmt, 3));
            for (size_t pos = 0; blob && pos + 8 <= blob_len; pos += 8) {
                uint16_t b_off = static_cast<uint16_t>(blob[pos]) | (static_cast<uint16_t>(blob[pos + 1]) << 8);
                uint16_t b_len = static_cast<uint16_t>(blob[pos + 2]) | (static_cast<uint16_t>(blob[pos + 3]) << 8);
                uint32_t tok_eid = static_cast<uint32_t>(blob[pos + 4]) |
                                   (static_cast<uint32_t>(blob[pos + 5]) << 8) |
                                   (static_cast<uint32_t>(blob[pos + 6]) << 16) |
                                   (static_cast<uint32_t>(blob[pos + 7]) << 24);
                if (b_off + b_len > sent.jp_text.size()) continue;

                std::string k_read;
                if (kana_stmt) {
                    sqlite3_reset(kana_stmt);
                    sqlite3_bind_int64(kana_stmt, 1, static_cast<sqlite3_int64>(tok_eid));
                    if (sqlite3_step(kana_stmt) == SQLITE_ROW) {
                        const auto* ktxt = reinterpret_cast<const char*>(sqlite3_column_text(kana_stmt, 0));
                        if (ktxt) k_read = ktxt;
                    }
                }
                spans.push_back({b_off, b_len, tok_eid, std::move(k_read)});
            }

            if (word_head_stmt) {
                std::vector<bool> covered(sent.jp_text.size(), false);
                for (const auto& sp : spans) {
                    for (size_t b = sp.b_off; b < sp.b_off + sp.b_len && b < covered.size(); ++b) {
                        covered[b] = true;
                    }
                }

                std::vector<size_t> char_starts;
                std::vector<uint32_t> char_cps;
                size_t p = 0;
                while (p < sent.jp_text.size()) {
                    char_starts.push_back(p);
                    char_cps.push_back(next_utf8_cp(sent.jp_text, p));
                }
                char_starts.push_back(sent.jp_text.size());

                size_t ci = 0;
                while (ci < char_cps.size()) {
                    size_t b_start = char_starts[ci];
                    if (covered[b_start] || !is_kanji_cp(char_cps[ci])) {
                        ci += 1;
                        continue;
                    }
                    bool matched = false;
                    size_t max_len = std::min<size_t>(5, char_cps.size() - ci);
                    for (size_t clen = max_len; clen >= 1; --clen) {
                        size_t b_end = char_starts[ci + clen];
                        bool any_cov = false;
                        for (size_t b = b_start; b < b_end; ++b) {
                            if (covered[b]) { any_cov = true; break; }
                        }
                        if (any_cov) continue;

                        std::string cand = sent.jp_text.substr(b_start, b_end - b_start);
                        std::string pref_kun = (clen == 1) ? get_primary_standalone_kun(db, char_cps[ci]) : "";

                        // Check place/person names first for 2+ kanji proper nouns when English translation mentions a capitalized name or when standard word entry is rare (e.g. `川越` -> `かわごえ` instead of `川越し` -> `かわこし`)
                        if (clen >= 2 && name_head_stmt) {
                            sqlite3_reset(name_head_stmt);
                            sqlite3_bind_text(name_head_stmt, 1, cand.c_str(), -1, SQLITE_TRANSIENT);
                            if (sqlite3_step(name_head_stmt) == SQLITE_ROW) {
                                uint32_t name_eid = static_cast<uint32_t>(sqlite3_column_int64(name_head_stmt, 0));
                                const auto* nktxt = reinterpret_cast<const char*>(sqlite3_column_text(name_head_stmt, 1));
                                std::string nk = nktxt ? nktxt : "";
                                // Prefer name reading if followed by `の` or if English sentence contains a capitalized word
                                bool followed_by_no = (ci + clen < char_cps.size() && char_cps[ci + clen] == 0x306E);
                                if (followed_by_no && !nk.empty()) {
                                    spans.push_back({b_start, b_end - b_start, name_eid, nk});
                                    for (size_t b = b_start; b < b_end; ++b) covered[b] = true;
                                    ci += clen;
                                    matched = true;
                                    break;
                                }
                            }
                        }

                        sqlite3_reset(word_head_stmt);
                        sqlite3_bind_text(word_head_stmt, 1, cand.c_str(), -1, SQLITE_TRANSIENT);
                        sqlite3_bind_text(word_head_stmt, 2, pref_kun.c_str(), -1, SQLITE_TRANSIENT);
                        if (sqlite3_step(word_head_stmt) == SQLITE_ROW) {
                            uint32_t found_eid = static_cast<uint32_t>(sqlite3_column_int64(word_head_stmt, 0));
                            const auto* ktxt = reinterpret_cast<const char*>(sqlite3_column_text(word_head_stmt, 1));
                            spans.push_back({b_start, b_end - b_start, found_eid, ktxt ? ktxt : ""});
                            for (size_t b = b_start; b < b_end; ++b) covered[b] = true;
                            ci += clen;
                            matched = true;
                            break;
                        }

                        if (clen >= 2 && name_head_stmt) {
                            sqlite3_reset(name_head_stmt);
                            sqlite3_bind_text(name_head_stmt, 1, cand.c_str(), -1, SQLITE_TRANSIENT);
                            if (sqlite3_step(name_head_stmt) == SQLITE_ROW) {
                                uint32_t found_eid = static_cast<uint32_t>(sqlite3_column_int64(name_head_stmt, 0));
                                const auto* ktxt = reinterpret_cast<const char*>(sqlite3_column_text(name_head_stmt, 1));
                                spans.push_back({b_start, b_end - b_start, found_eid, ktxt ? ktxt : ""});
                                for (size_t b = b_start; b < b_end; ++b) covered[b] = true;
                                ci += clen;
                                matched = true;
                                break;
                            }
                        }

                        if (clen >= 2 && is_hiragana_cp(char_cps[ci + clen - 1]) && verb_stem_stmt) {
                            std::string upper = utf8_prefix_upper_bound(cand);
                            sqlite3_reset(verb_stem_stmt);
                            sqlite3_bind_text(verb_stem_stmt, 1, cand.c_str(), -1, SQLITE_TRANSIENT);
                            sqlite3_bind_text(verb_stem_stmt, 2, upper.c_str(), -1, SQLITE_TRANSIENT);
                            if (sqlite3_step(verb_stem_stmt) == SQLITE_ROW) {
                                uint32_t found_eid = static_cast<uint32_t>(sqlite3_column_int64(verb_stem_stmt, 0));
                                const auto* ktxt = reinterpret_cast<const char*>(sqlite3_column_text(verb_stem_stmt, 1));
                                std::string dict_kana = ktxt ? ktxt : "";
                                auto d_cps = utf8_to_cps(dict_kana);
                                if (d_cps.size() > 1) d_cps.pop_back();
                                spans.push_back({b_start, b_end - b_start, found_eid, cps_to_utf8(d_cps, 0, d_cps.size())});
                                for (size_t b = b_start; b < b_end; ++b) covered[b] = true;
                                ci += clen;
                                matched = true;
                                break;
                            }
                        }
                    }
                    if (!matched) ci += 1;
                }
            }

            std::sort(spans.begin(), spans.end(), [](const ByteSpan& a, const ByteSpan& b) {
                return a.b_off < b.b_off;
            });

            for (const auto& sp : spans) {
                OwnedSentenceToken tok;
                tok.utf16_offset = utf8_byte_range_to_utf16_units(sent.jp_text, 0, sp.b_off);
                tok.utf16_length = utf8_byte_range_to_utf16_units(sent.jp_text, sp.b_off, sp.b_len);
                tok.entry_id = sp.eid;
                tok.kana_reading = sp.kana;
                sent.tokens.push_back(std::move(tok));
            }
            out.sentences.push_back(std::move(sent));
        }
        sqlite3_finalize(stmt);
    }
    if (kana_stmt) sqlite3_finalize(kana_stmt);
    if (word_head_stmt) sqlite3_finalize(word_head_stmt);
    if (name_head_stmt) sqlite3_finalize(name_head_stmt);
    if (verb_stem_stmt) sqlite3_finalize(verb_stem_stmt);

    return true;
}

/// Load the full detail for one kanji.
///
/// Besides the scalar metadata and reading/meaning strings, this decodes the
/// quantized KanjiVG stroke blob (1 byte stroke count, then per stroke 1
/// byte point count followed by 2×`uint16` coordinates quantized to
/// `0..65535`) into normalized `dj_point_t` polylines, and assembles the
/// `component_radicals` breakdown string from the primary radical plus any
/// additional radicals in the `kanji_radicals` table.
bool db_get_kanji_detail(sqlite3* db, uint32_t codepoint, OwnedKanjiDetail& out) {
    if (!db || codepoint == 0) return false;
    out = OwnedKanjiDetail{};

    const char* sql =
        "SELECT strokes, grade, jlpt, freq_rank, radical_id, skip_code, four_corner, "
        "       COALESCE(kyujitai_cp, 0), on_readings, kun_readings, meanings, stroke_blob "
        "FROM kanji WHERE codepoint = ?1;";

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr) != SQLITE_OK) return false;
    sqlite3_bind_int64(stmt, 1, static_cast<sqlite3_int64>(codepoint));

    if (sqlite3_step(stmt) != SQLITE_ROW) {
        sqlite3_finalize(stmt);
        return false;
    }

    out.codepoint = codepoint;
    encode_utf8(codepoint, out.utf8_glyph);
    out.strokes = static_cast<uint8_t>(sqlite3_column_int(stmt, 0));
    out.grade = static_cast<uint8_t>(sqlite3_column_int(stmt, 1));
    out.jlpt = static_cast<uint8_t>(sqlite3_column_int(stmt, 2));
    out.freq_rank = static_cast<uint32_t>(sqlite3_column_int64(stmt, 3));
    out.radical_id = static_cast<uint8_t>(sqlite3_column_int(stmt, 4));
    out.skip_code = static_cast<uint32_t>(sqlite3_column_int64(stmt, 5));
    out.four_corner = static_cast<uint32_t>(sqlite3_column_int64(stmt, 6));
    out.kyujitai_cp = static_cast<uint32_t>(sqlite3_column_int64(stmt, 7));
    out.on_readings = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 8));
    out.kun_readings = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 9));
    out.meanings = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 10));

    const auto* blob = static_cast<const uint8_t*>(sqlite3_column_blob(stmt, 11));
    size_t blob_len = static_cast<size_t>(sqlite3_column_bytes(stmt, 11));
    if (blob && blob_len >= 1) {
        size_t cursor = 0;
        uint8_t stroke_cnt = blob[cursor++];
        out.strokes_points.reserve(stroke_cnt);
        for (uint8_t s = 0; s < stroke_cnt && cursor < blob_len; ++s) {
            uint8_t pt_cnt = blob[cursor++];
            std::vector<dj_point_t> poly;
            poly.reserve(pt_cnt);
            for (uint8_t p = 0; p < pt_cnt && cursor + 4 <= blob_len; ++p) {
                uint16_t qx = static_cast<uint16_t>(blob[cursor]) | (static_cast<uint16_t>(blob[cursor + 1]) << 8);
                uint16_t qy = static_cast<uint16_t>(blob[cursor + 2]) | (static_cast<uint16_t>(blob[cursor + 3]) << 8);
                cursor += 4;
                poly.push_back({static_cast<float>(qx) / 65535.0f, static_cast<float>(qy) / 65535.0f});
            }
            out.strokes_points.push_back(std::move(poly));
        }
    }
    sqlite3_finalize(stmt);

    std::vector<int> rad_ids;
    if (out.radical_id >= 1 && out.radical_id <= 214) {
        rad_ids.push_back(out.radical_id);
    }
    sqlite3_stmt* rad_stmt = nullptr;
    if (sqlite3_prepare_v2(db, "SELECT radical_id FROM kanji_radicals WHERE codepoint = ?1 ORDER BY radical_id ASC;", -1, &rad_stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(rad_stmt, 1, static_cast<sqlite3_int64>(codepoint));
        while (sqlite3_step(rad_stmt) == SQLITE_ROW) {
            int rid = sqlite3_column_int(rad_stmt, 0);
            if (rid >= 1 && rid <= 214 && std::find(rad_ids.begin(), rad_ids.end(), rid) == rad_ids.end()) {
                rad_ids.push_back(rid);
            }
        }
        sqlite3_finalize(rad_stmt);
    }
    for (size_t i = 0; i < rad_ids.size(); ++i) {
        if (i > 0) out.component_radicals += "   ";
        int rid = rad_ids[i];
        out.component_radicals += kKangxiRadicalGlyphs[rid];
        out.component_radicals += " (#" + std::to_string(rid) + ")";
    }

    return true;
}

/// Find kanji containing *all* of the given Kangxi radicals (intersection),
/// optionally restricted to a stroke range, sorted by frequency then stroke
/// count (capped at 300 results).
std::vector<uint32_t> db_search_radicals(
    sqlite3* db,
    const uint8_t* radical_ids,
    size_t radical_count,
    int16_t target_strokes,
    int8_t stroke_tolerance) {

    std::vector<uint32_t> out;
    if (!db || !radical_ids || radical_count == 0) return out;
    size_t n = std::min<size_t>(radical_count, 7);

    std::string sql = "SELECT k.codepoint FROM kanji k ";
    for (size_t i = 0; i < n; ++i) {
        sql += "JOIN kanji_radicals r" + std::to_string(i) +
               " ON k.codepoint = r" + std::to_string(i) + ".codepoint AND r" +
               std::to_string(i) + ".radical_id = ?" + std::to_string(i + 1) + " ";
    }
    if (target_strokes > 0) {
        int tol = std::max<int>(0, stroke_tolerance);
        sql += "WHERE k.strokes BETWEEN " + std::to_string(target_strokes - tol) +
               " AND " + std::to_string(target_strokes + tol) + " ";
    }
    sql += "ORDER BY k.freq_rank ASC, k.strokes ASC LIMIT 300;";

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) {
        return out;
    }
    for (size_t i = 0; i < n; ++i) {
        sqlite3_bind_int(stmt, static_cast<int>(i + 1), radical_ids[i]);
    }
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        out.push_back(static_cast<uint32_t>(sqlite3_column_int64(stmt, 0)));
    }
    sqlite3_finalize(stmt);
    return out;
}

} // namespace dj
