/**
 * @file romaji.cpp
 * @brief Deterministic Wa-puro Romaji-to-Kana state machine and UTF-8 codec.
 *
 * Handles standard Hepburn + Kunrei-shiki + Wa-puro typing conventions:
 *   - Geminate consonants (`pp`, `kk`, `tt`, `t-`) -> small tsu (`っ`)
 *   - Syllabic `n` before consonants/end-of-string (`n`, `nn`, `n'`) -> `ん`
 *   - Youon palatalized glides (`kya`, `sha`, `cha`, `nya`, `ja`, etc.)
 *   - UTF-32 -> UTF-8 encoding and Hiragana -> Katakana scalar offset (+0x60)
 */

#include "../dj_internal.hpp"
#include <algorithm>
#include <cctype>
#include <unordered_map>

namespace dj {

/// Encode a single Unicode codepoint into `out` as 1–4 bytes of UTF-8, always
/// NUL-terminating within the 8-byte buffer (so it can be used as a C string).
/// Codepoints above U+10FFFF produce only the NUL terminator.
void encode_utf8(uint32_t cp, char out[8]) {
    for (int i = 0; i < 8; ++i) out[i] = 0;
    if (cp <= 0x7F) {
        out[0] = static_cast<char>(cp);
    } else if (cp <= 0x7FF) {
        out[0] = static_cast<char>(0xC0 | ((cp >> 6) & 0x1F));
        out[1] = static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp <= 0xFFFF) {
        out[0] = static_cast<char>(0xE0 | ((cp >> 12) & 0x0F));
        out[1] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out[2] = static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp <= 0x10FFFF) {
        out[0] = static_cast<char>(0xF0 | ((cp >> 18) & 0x07));
        out[1] = static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        out[2] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out[3] = static_cast<char>(0x80 | (cp & 0x3F));
    }
}

/// @return `true` when `s` is non-empty, pure ASCII (no bytes ≥ 0x80), and
///         contains at least one alphabetic letter — i.e. it is plausibly a
///         romaji input rather than kanji/kana or a pure-number query.
bool is_ascii_romaji(const std::string& s) {
    if (s.empty()) return false;
    bool has_alpha = false;
    for (unsigned char c : s) {
        if (c >= 0x80) return false;
        if (std::isalpha(c)) has_alpha = true;
    }
    return has_alpha;
}

namespace {

/// The romaji → hiragana lookup table.
///
/// Keys are the *longest-first* mora spellings (3 letters for yōon, 2 for
/// basic morae, 1 for the vowels). Alternate romanizations of the same kana
/// are all present (`si`/`shi`, `tu`/`tsu`, `hu`/`fu`, `zi`/`ji`, ...), and
/// `nn` is the explicit syllabic-n escape. Letters that never form a kana on
/// their own (`x`, `c`, `q`, `v`) are intentionally absent and fall through
/// to the pass-through branch in `romaji_to_kana`.
const std::unordered_map<std::string, std::string>& kana_table() {
    static const std::unordered_map<std::string, std::string> tbl = {
        {"a","あ"},{"i","い"},{"u","う"},{"e","え"},{"o","お"},
        {"ka","か"},{"ki","き"},{"ku","く"},{"ke","け"},{"ko","こ"},
        {"sa","さ"},{"shi","し"},{"si","し"},{"su","す"},{"se","せ"},{"so","そ"},
        {"ta","た"},{"chi","ち"},{"ti","ち"},{"tsu","つ"},{"tu","つ"},{"te","て"},{"to","と"},
        {"na","な"},{"ni","に"},{"nu","ぬ"},{"ne","ね"},{"no","の"},
        {"ha","は"},{"hi","ひ"},{"fu","ふ"},{"hu","ふ"},{"he","へ"},{"ho","ほ"},
        {"ma","ま"},{"mi","み"},{"mu","む"},{"me","め"},{"mo","も"},
        {"ya","や"},{"yu","ゆ"},{"yo","よ"},
        {"ra","ら"},{"ri","り"},{"ru","る"},{"re","れ"},{"ro","ろ"},
        {"wa","わ"},{"wi","ゐ"},{"we","ゑ"},{"wo","を"},{"nn","ん"},
        {"ga","が"},{"gi","ぎ"},{"gu","ぐ"},{"ge","げ"},{"go","ご"},
        {"za","ざ"},{"ji","じ"},{"zi","じ"},{"zu","ず"},{"ze","ぜ"},{"zo","ぞ"},
        {"da","だ"},{"di","ぢ"},{"dji","ぢ"},{"du","づ"},{"dzu","づ"},{"tzu","づ"},{"de","で"},{"do","ど"},
        {"ba","ば"},{"bi","び"},{"bu","ぶ"},{"be","べ"},{"bo","ぼ"},
        {"pa","ぱ"},{"pi","ぴ"},{"pu","ぷ"},{"pe","ぺ"},{"po","ぽ"},
        // Palatalized glides (youon)
        {"kya","きゃ"},{"kyu","きゅ"},{"kyo","きょ"},
        {"sha","しゃ"},{"shu","しゅ"},{"sho","しょ"},{"sya","しゃ"},{"syu","しゅ"},{"syo","しょ"},
        {"cha","ちゃ"},{"chu","ちゅ"},{"cho","ちょ"},{"tya","ちゃ"},{"tyu","ちゅ"},{"tyo","ちょ"},
        {"nya","にゃ"},{"nyu","にゅ"},{"nyo","にょ"},
        {"hya","ひゃ"},{"hyu","ひゅ"},{"hyo","ひょ"},
        {"mya","みゃ"},{"myu","みゅ"},{"myo","みょ"},
        {"rya","りゃ"},{"ryu","りゅ"},{"ryo","りょ"},
        {"gya","ぎゃ"},{"gyu","ぎゅ"},{"gyo","ぎょ"},
        {"ja","じゃ"},{"ju","じゅ"},{"jo","じょ"},{"jya","じゃ"},{"jyu","じゅ"},{"jyo","じょ"},{"zya","じゃ"},{"zyu","じゅ"},{"zyo","じょ"},
        {"bya","びゃ"},{"byu","びゅ"},{"byo","びょ"},
        {"pya","ぴゃ"},{"pyu","ぴゅ"},{"pyo","ぴょ"},
        {"-","ー"}
    };
    return tbl;
}

/// @return `true` for the five romaji vowels (lower-case, post-normalization).
bool is_vowel(char c) {
    return c == 'a' || c == 'i' || c == 'u' || c == 'e' || c == 'o';
}

/// Convert a UTF-8 hiragana string to katakana.
///
/// Hiragana U+3041–U+3096 sit in a contiguous block, and katakana is exactly
/// the same block shifted by +0x60, so the conversion is a per-codepoint
/// offset. Only 3-byte UTF-8 sequences starting with the `0xE3` lead byte
/// (i.e. codepoints in the U+3000–U+3FFF CJK/kana plane) are rewritten;
/// everything else is copied through untouched.
std::string hiragana_to_katakana(const std::string& hira) {
    std::string out;
    out.reserve(hira.size());
    size_t i = 0;
    while (i < hira.size()) {
        unsigned char c0 = static_cast<unsigned char>(hira[i]);
        if (c0 == 0xE3 && i + 2 < hira.size()) {
            uint32_t cp = ((c0 & 0x0F) << 12) |
                          ((static_cast<unsigned char>(hira[i + 1]) & 0x3F) << 6) |
                          (static_cast<unsigned char>(hira[i + 2]) & 0x3F);
            if (cp >= 0x3041 && cp <= 0x3096) {
                char buf[8];
                encode_utf8(cp + 0x60, buf);
                out.append(buf);
                i += 3;
                continue;
            }
        }
        out.push_back(hira[i++]);
    }
    return out;
}

} // namespace

/// Deterministic romaji → kana transliteration (Hepburn + Kunrei-shiki +
/// wa-puro conventions).
///
/// The scanner is a single left-to-right pass with the following precedence:
///   1. `n'` apostrophe escape → `ん` (disables the n + youon join).
///   2. A doubled consonant (`kk`, `tt`, ...) → small *tsu* `っ`, consuming
///      only the first letter so the second starts the next mora.
///   3. Wa-puro `t-` geminate shorthand → `っ`.
///   4. Greedy 3 → 2 → 1 letter table lookup (handles yōon and daku-ten).
///   5. A bare `n` at end-of-string or before a non-vowel/non-`y` → `ん`.
///   6. Anything else is passed through verbatim (e.g. `x`, `c`, `q`, `v`).
///
/// @param input     The romaji text.
/// @param katakana  If `true`, the hiragana result is shifted to katakana.
/// @return The kana string (UTF-8).
std::string romaji_to_kana(const std::string& input, bool katakana) {
    std::string s;
    s.reserve(input.size());
    for (unsigned char c : input) {
        s.push_back(static_cast<char>(std::tolower(c)));
    }

    const auto& tbl = kana_table();
    std::string hira;
    hira.reserve(s.size() * 2);

    size_t i = 0;
    while (i < s.size()) {
        // Explicit apostrophe escape (`n'ya` -> `んや` instead of `にゃ`)
        if (s[i] == 'n' && i + 1 < s.size() && s[i + 1] == 0x27) {
            hira += "ん";
            i += 2;
            continue;
        }
        // Geminate consonant -> small tsu (`っ`)
        if (i + 1 < s.size() && s[i] == s[i + 1] && std::isalpha(static_cast<unsigned char>(s[i])) &&
            !is_vowel(s[i]) && s[i] != 'n') {
            hira += "っ";
            i += 1;
            continue;
        }
        // Wa-puro `t-` geminate shorthand
        if (s[i] == 't' && i + 1 < s.size() && s[i + 1] == '-') {
            hira += "っ";
            i += 2;
            continue;
        }

        // Greedy 3 -> 2 -> 1 character mora lookup
        bool matched = false;
        for (size_t len = std::min<size_t>(3, s.size() - i); len >= 1; --len) {
            auto it = tbl.find(s.substr(i, len));
            if (it != tbl.end()) {
                hira += it->second;
                i += len;
                matched = true;
                break;
            }
        }
        if (matched) continue;

        // Standalone syllabic `n` when followed by end-of-string or a non-vowel/non-y
        if (s[i] == 'n') {
            if (i + 1 == s.size() || (!is_vowel(s[i + 1]) && s[i + 1] != 'y')) {
                hira += "ん";
                i += 1;
                continue;
            }
        }

        // 6. Pass-through: letters that never form a kana on their own
        //    (`x`, `c`, `q`, `v`, ...) are kept verbatim so the user's
        //    typing is never silently dropped.
        hira.push_back(s[i++]);
    }

    // Convert to katakana only at the very end, so the whole pass can work
    // in hiragana and apply the +0x60 scalar offset in one final sweep.
    return katakana ? hiragana_to_katakana(hira) : hira;
}

bool anchor_lemmas_contains(const std::string& anchor_lemmas, const std::string& token) {
    if (anchor_lemmas.empty() || token.empty()) return false;
    size_t start = 0;
    while (start <= anchor_lemmas.size()) {
        size_t comma = anchor_lemmas.find(',', start);
        size_t end = (comma == std::string::npos) ? anchor_lemmas.size() : comma;
        while (start < end && (anchor_lemmas[start] == ' ' || anchor_lemmas[start] == '\t')) {
            ++start;
        }
        while (end > start && (anchor_lemmas[end - 1] == ' ' || anchor_lemmas[end - 1] == '\t')) {
            --end;
        }
        if (end - start == token.size() && anchor_lemmas.compare(start, end - start, token) == 0) {
            return true;
        }
        if (comma == std::string::npos) break;
        start = comma + 1;
    }
    return false;
}

} // namespace dj
