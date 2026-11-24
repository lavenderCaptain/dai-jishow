// KanaNormalizer — pure kana / romaji helpers for Dai-Jishow.
//
// WHY THIS MODULE EXISTS
// ---------------------
// This file was moved out of the `DaiJishowMac` executable target (where it lived
// inside `EngineBridge.swift`) into a standalone, dependency-free Swift *library*
// so it — and the conjugation / part-of-speech / pitch logic it supports — can be
// unit-tested. SwiftPM cannot `@testable import` an *executable* target, so any
// logic we want to lock down with tests first has to live in a library module.
//
// The move is behavior-preserving: the bodies below are the exact same functions
// that ran in the app; only their access level changed (`public`) so the library's
// consumers — `DaiJishowMorph.Morph`, `PitchAccentContour`, and the executable —
// can reach them across the module boundary.
//
// The enum is pure: it touches only `String` / `Character` / `UnicodeScalar`. No
// engine, no database, no UI, no `MainActor`. That purity is what makes it cheap
// and deterministic to test, and what lets the morphology sit in its own layer.
//
// `import Foundation` is required: `splitMorae` / `cleanReadingToken` /
// `romajiToHiragana` use Foundation's `String` extensions (`trimmingCharacters(in:)`,
// `replacingOccurrences(of:with:)`). In `EngineBridge.swift` these came for free from
// that file's top-level `import Foundation`; a library module must declare its own.

import Foundation

public enum KanaNormalizer {
    /// Combining (small) kana that fuse onto the preceding mora rather than
    /// starting a new one — e.g. the ぁ in 「しゃ」. Used by `splitMorae` to decide
    /// where mora boundaries fall, which in turn drives the pitch-accent diagram.
    private static let smallCombiningKana: Set<Character> = [
        "ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ゎ",
        "ャ", "ュ", "ョ", "ァ", "ィ", "ゥ", "ェ", "ォ", "ヮ"
    ]

    /// Romaji → kana table, longest-prefix-first. Multi-character digraphs (しゃ,
    /// つ as 「ttsu」, ん as 「nn」/「n'」, …) are listed before their single-char
    /// substrings so the greedy `hasPrefix` match in `romajiToHiragana` picks the
    /// longest valid token and never splits a digraph.
    private static let romajiTable: [(String, String)] = [
        ("ltsu", "っ"), ("xtsu", "っ"),
        ("sha", "しゃ"), ("shu", "しゅ"), ("sho", "しょ"),
        ("shi", "し"), ("sya", "しゃ"), ("syu", "しゅ"), ("syo", "しょ"),
        ("cha", "ちゃ"), ("chu", "ちゅ"), ("cho", "ちょ"),
        ("chi", "ち"), ("tya", "ちゃ"), ("tyu", "ちゅ"), ("tyo", "ちょ"),
        ("tsu", "つ"),
        ("ja", "じゃ"), ("ju", "じゅ"), ("jo", "じょ"),
        ("jya", "じゃ"), ("jyu", "じゅ"), ("jyo", "じょ"),
        ("zya", "じゃ"), ("zyu", "じゅ"), ("zyo", "じょ"),
        ("kya", "きゃ"), ("kyu", "きゅ"), ("kyo", "きょ"),
        ("gya", "ぎゃ"), ("gyu", "ぎゅ"), ("gyo", "ぎょ"),
        ("nya", "にゃ"), ("nyu", "にゅ"), ("nyo", "にょ"),
        ("hya", "ひゃ"), ("hyu", "ひゅ"), ("hyo", "ひょ"),
        ("bya", "びゃ"), ("byu", "びゅ"), ("byo", "びょ"),
        ("pya", "ぴゃ"), ("pyu", "ぴゅ"), ("pyo", "ぴょ"),
        ("mya", "みゃ"), ("myu", "みゅ"), ("myo", "みょ"),
        ("rya", "りゃ"), ("ryu", "りゅ"), ("ryo", "りょ"),
        ("fu", "ふ"), ("hu", "ふ"),
        ("ji", "じ"), ("zi", "じ"),
        ("di", "ぢ"), ("du", "づ"),
        ("ti", "ち"), ("tu", "つ"), ("si", "し"),
        ("ka", "か"), ("ki", "き"), ("ku", "く"), ("ke", "け"), ("ko", "こ"),
        ("ga", "が"), ("gi", "ぎ"), ("gu", "ぐ"), ("ge", "げ"), ("go", "ご"),
        ("sa", "さ"), ("su", "す"), ("se", "せ"), ("so", "そ"),
        ("za", "ざ"), ("zu", "ず"), ("ze", "ぜ"), ("zo", "ぞ"),
        ("ta", "た"), ("te", "て"), ("to", "と"),
        ("da", "だ"), ("de", "で"), ("do", "ど"),
        ("na", "な"), ("ni", "に"), ("nu", "ぬ"), ("ne", "ね"), ("no", "の"),
        ("ha", "は"), ("hi", "ひ"), ("he", "へ"), ("ho", "ほ"),
        ("ba", "ば"), ("bi", "び"), ("bu", "ぶ"), ("be", "べ"), ("bo", "ぼ"),
        ("pa", "ぱ"), ("pi", "ぴ"), ("pu", "ぷ"), ("pe", "ぺ"), ("po", "ぽ"),
        ("ma", "ま"), ("mi", "み"), ("mu", "む"), ("me", "め"), ("mo", "も"),
        ("ya", "や"), ("yu", "ゆ"), ("yo", "よ"),
        ("ra", "ら"), ("ri", "り"), ("ru", "る"), ("re", "れ"), ("ro", "ろ"),
        ("wa", "わ"), ("wi", "ゐ"), ("we", "ゑ"), ("wo", "を"),
        ("nn", "ん"), ("n'", "ん"),
        ("a", "あ"), ("i", "い"), ("u", "う"), ("e", "え"), ("o", "お")
    ]

    /// Split a kana string into its mora units, folding combining kana onto the
    /// mora they modify. 「しゃ」→ ["しゃ"], 「にほん」→ ["に","ほ","ん"].
    /// The pitch-accent diagram walks these units, so correct mora boundaries are
    /// what make the downstep land on the right syllable.
    public static func splitMorae(_ kana: String) -> [String] {
        let trimmed = kana.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var morae: [String] = []
        for ch in trimmed {
            if smallCombiningKana.contains(ch), let last = morae.popLast() {
                morae.append(last + String(ch))
            } else {
                morae.append(String(ch))
            }
        }
        return morae
    }

    /// Map katakana codepoints to hiragana (a one-codepoint-offset transform in
    /// the 0x30A1…0x30F6 range). Used so readings stored in katakana can be
    /// compared against hiragana headwords.
    public static func katakanaToHiragana(_ input: String) -> String {
        var out = ""
        out.reserveCapacity(input.count)
        for scalar in input.unicodeScalars {
            let v = scalar.value
            if (0x30A1...0x30F6).contains(v), let h = UnicodeScalar(v - 0x60) {
                out.unicodeScalars.append(h)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Normalize a raw reading token: strip the okurigana-dot / dash separators the
    /// corpus uses and fold katakana to hiragana, so 「おお.きい」 and 「オオキイ」
    /// both compare as "おおきい".
    public static func cleanReadingToken(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return katakanaToHiragana(stripped)
    }

    /// Stem before an okurigana dot (e.g. "おお.きい" -> "おお"). The part-of-speech
    /// logic keys on the stem, not the full conjugated reading.
    public static func stemBeforeDot(_ raw: String) -> String {
        let base = raw.split(separator: ".").first.map(String.init) ?? raw
        return cleanReadingToken(base)
    }

    /// Greedy longest-prefix romaji → hiragana transliteration. Doubled consonants
    /// become sokuon 「っ」; a trailing/inter-vowel "n" becomes 「ん」. Powers the
    /// romaji search path.
    public static func romajiToHiragana(_ input: String) -> String {
        let s = katakanaToHiragana(input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        var result = ""
        var idx = s.startIndex

        while idx < s.endIndex {
            let rem = s[idx...]
            if rem.count >= 2 {
                let c1 = rem[rem.startIndex]
                let c2 = rem[rem.index(after: rem.startIndex)]
                if c1 == c2 && c1 >= "a" && c1 <= "z" && !"aeiouyn".contains(c1) {
                    result.append("っ")
                    idx = s.index(after: idx)
                    continue
                }
            }

            var matched = false
            for (rom, hira) in romajiTable {
                if rem.hasPrefix(rom) {
                    result.append(hira)
                    idx = s.index(idx, offsetBy: rom.count)
                    matched = true
                    break
                }
            }
            if matched { continue }

            let ch = s[idx]
            if ch == "n" {
                let nextIdx = s.index(after: idx)
                if nextIdx == s.endIndex {
                    result.append("ん")
                    idx = nextIdx
                    continue
                }
                let nextCh = s[nextIdx]
                if !"aeiouy".contains(nextCh) {
                    result.append("ん")
                    idx = nextIdx
                    continue
                }
            }

            result.append(ch)
            idx = s.index(after: idx)
        }
        return result
    }
}
