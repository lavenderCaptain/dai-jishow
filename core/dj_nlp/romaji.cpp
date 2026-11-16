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

bool is_vowel(char c) {
    return c == 'a' || c == 'i' || c == 'u' || c == 'e' || c == 'o';
}

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

        hira.push_back(s[i++]);
    }

    return katakana ? hiragana_to_katakana(hira) : hira;
}

} // namespace dj
