// Morph — the pure morphology core of Dai-Jishow: conjugation generation and
// part-of-speech / grammatical tag inference.
//
// WHY THIS MODULE EXISTS
// ---------------------
// `inflections` and `senseTags` previously lived as `private static` methods on
// the `@MainActor final class DaiJishowEngine` inside the `DaiJishowMac`
// *executable* target. SwiftPM cannot `@testable import` an executable target, so
// they were unreachable from any test. To make them — the most regression-prone
// logic in the app (a wrong conjugation is garbage Japanese on screen) — testable,
// they were extracted here into a dependency-free library as free functions taking
// plain `String` / `UInt64` parameters instead of the engine's `EntryDetail` /
// `SenseItem` aggregates.
//
// The move is *behavior-preserving*: each body is the exact algorithm that ran in
// the app; only the entry point changed (flat params instead of a nested aggregate)
// and the access level (`public`). `DaiJishowEngine` now calls
// `Morph.inflections(...)` / `Morph.senseTags(...)` and adapts its `EntryDetail` /
// `SenseItem` fields into these parameters — see the call sites in `EngineBridge`.
//
// POS encoding (POS_BITS in tools/corpus-builder/build_corpus.py; mirrored by
// SearchFilter.posBits). The corpus stores part-of-speech as a 64-bit mask:
//   bit0  = noun (n)
//   bit1  = v1  (ichidan / 一段 verb)
//   bit2  = v5  (godan / 五段 verb)
//   bit3  = vs  (suru/ku verb family)
//   bit4  = vt  (transitive / 他動詞)
//   bit5  = vi  (intransitive / 自動詞)
//   bit6  = adj-i  (い-adjective)
//   bit7  = adj-na (な-adjective / quasi-adjective)
//   bit8  = adverb (adv)
//   bit10 = particle (prt)
// This bitmask drives both functions; it replaced the old "does the English gloss
// start with 'to '?" heuristic, which mis-labeled nouns whose gloss happened to
// begin with "to " and never saw na-adjectives.
//
// `import Foundation` is required: `senseTags` uses Foundation's `String`
// extension `trimmingCharacters(in:)`. In `EngineBridge.swift` this came for free
// from that file's top-level `import Foundation`; a library module declares its own.

import Foundation

public enum Morph {

    // MARK: - Conjugation / inflection generation

    /// Generate the conjugation matrix for an entry's headword.
    ///
    /// - Parameters:
    ///   - surface: the display headword (kanji + okurigana where present; e.g.
    ///     "食べる", "静か"). Used for the kanji side of each form.
    ///   - kana: the all-kana reading (e.g. "たべる", "しずか"). Drives which
    ///     conjugation class applies and the all-kana side of each form.
    ///   - posMask: the corpus part-of-speech bitmask (see file header). Decides
    ///     verb vs adjective vs noun, and the transitive/intransitive tags.
    /// - Returns: the list of `InflectionForm` rows (empty for non-inflecting
    ///   entries) plus a human-readable section header, or nil when there is
    ///   nothing to conjugate.
    public static func inflections(surface: String, kana: String, posMask: UInt64)
        -> ([InflectionForm], String?) {
        guard surface.count >= 2, kana.count >= 2 else { return ([], nil) }

        let mask = posMask
        let verbBits: UInt64 = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5)
        let isVerb = (mask & verbBits) != 0

        if isVerb {
            // Irregular "る"-ending verbs. These look like ichidan but are not:
            // 来る/くる conjugate 来/こ (not 来/く), and ある / いる take ない
            // (not あらない / いらない) in the negative.
            if surface == "来る" || (surface == kana && kana == "くる") {
                let sStem = surface == "来る" ? "来" : "く"
                let kStem = "く"
                return ([
                    InflectionForm(id: "pol", label: "Polite", surface: sStem + "ます", kana: kStem + "ます"),
                    InflectionForm(id: "neg", label: "Negative", surface: (surface == "来る" ? "来ない" : "こない"), kana: "こない"),
                    InflectionForm(id: "past", label: "Past", surface: sStem + "た", kana: kStem + "た"),
                    InflectionForm(id: "te", label: "Te-form", surface: sStem + "て", kana: kStem + "て"),
                    InflectionForm(id: "pot", label: "Potential", surface: sStem + "られる", kana: kStem + "られる"),
                    InflectionForm(id: "pas", label: "Passive", surface: sStem + "られる", kana: kStem + "られる")
                ], "Irregular Verb (来る / くる)")
            }
            if surface == kana && kana == "ある" {
                return ([
                    InflectionForm(id: "pol", label: "Polite", surface: "あります", kana: "あります"),
                    InflectionForm(id: "neg", label: "Negative", surface: "ない", kana: "ない"),
                    InflectionForm(id: "past", label: "Past", surface: "あった", kana: "あった"),
                    InflectionForm(id: "te", label: "Te-form", surface: "あって", kana: "あって"),
                    InflectionForm(id: "pot", label: "Potential", surface: "あれる", kana: "あれる"),
                    InflectionForm(id: "pas", label: "Passive", surface: "あられる", kana: "あられる")
                ], "Irregular Verb (ある)")
            }
            if surface == kana && kana == "いる" {
                return ([
                    InflectionForm(id: "pol", label: "Polite", surface: "います", kana: "います"),
                    InflectionForm(id: "neg", label: "Negative", surface: "いない", kana: "いない"),
                    InflectionForm(id: "past", label: "Past", surface: "いた", kana: "いた"),
                    InflectionForm(id: "te", label: "Te-form", surface: "いて", kana: "いて"),
                    InflectionForm(id: "pot", label: "Potential", surface: "いられる", kana: "いられる"),
                    InflectionForm(id: "pas", label: "Passive", surface: "いられる", kana: "いられる")
                ], "Irregular Verb (いる)")
            }

            let sStem = String(surface.dropLast())
            let kStem = String(kana.dropLast())

            if kana == "する" || kana.hasSuffix("する") {
                let sBase = String(surface.dropLast(2))
                let kBase = String(kana.dropLast(2))
                return ([
                    InflectionForm(id: "pol", label: "Polite", surface: sBase + "します", kana: kBase + "します"),
                    InflectionForm(id: "neg", label: "Negative", surface: sBase + "しない", kana: kBase + "しない"),
                    InflectionForm(id: "past", label: "Past", surface: sBase + "した", kana: kBase + "した"),
                    InflectionForm(id: "te", label: "Te-form", surface: sBase + "して", kana: kBase + "して"),
                    InflectionForm(id: "pot", label: "Potential", surface: sBase + "できる", kana: kBase + "できる"),
                    InflectionForm(id: "pas", label: "Passive", surface: sBase + "される", kana: kBase + "される")
                ], "Suru Verb Inflections")
            }

            if kana.hasSuffix("る") {
                let preLast = kana.dropLast().last
                let ichidanVowels: Set<Character> = [
                    "い", "き", "ぎ", "し", "じ", "ち", "に", "ひ", "び", "ぴ", "み", "り",
                    "え", "け", "げ", "せ", "ぜ", "て", "で", "ね", "へ", "べ", "ぺ", "め", "れ"
                ]
                if let v = preLast, ichidanVowels.contains(v) {
                    return ([
                        InflectionForm(id: "pol", label: "Polite", surface: sStem + "ます", kana: kStem + "ます"),
                        InflectionForm(id: "neg", label: "Negative", surface: sStem + "ない", kana: kStem + "ない"),
                        InflectionForm(id: "past", label: "Past", surface: sStem + "た", kana: kStem + "た"),
                        InflectionForm(id: "te", label: "Te-form", surface: sStem + "て", kana: kStem + "て"),
                        InflectionForm(id: "pot", label: "Potential", surface: sStem + "られる", kana: kStem + "られる"),
                        InflectionForm(id: "pas", label: "Passive", surface: sStem + "られる", kana: kStem + "られる")
                    ], "Ichidan Verb Inflections")
                }
            }

            // Godan Verb table — keyed on the final kana syllable. 行く/ゆく get the
            // irregular te/ta "って/った" (not いく/ゆく → いて/いた).
            if let last = kana.last {
                struct GodanRow {
                    let a: String; let i: String; let e: String; let te: String; let ta: String
                }
                let table: [Character: GodanRow] = [
                    "う": GodanRow(a: "わ", i: "い", e: "え", te: "って", ta: "った"),
                    "く": GodanRow(a: "か", i: "き", e: "け", te: "いて", ta: "いた"),
                    "ぐ": GodanRow(a: "が", i: "ぎ", e: "げ", te: "いで", ta: "いだ"),
                    "す": GodanRow(a: "さ", i: "し", e: "せ", te: "して", ta: "した"),
                    "つ": GodanRow(a: "た", i: "ち", e: "て", te: "って", ta: "った"),
                    "ぬ": GodanRow(a: "な", i: "に", e: "ね", te: "んで", ta: "んだ"),
                    "ぶ": GodanRow(a: "ば", i: "び", e: "べ", te: "んで", ta: "んだ"),
                    "む": GodanRow(a: "ま", i: "み", e: "め", te: "んで", ta: "んだ"),
                    "る": GodanRow(a: "ら", i: "り", e: "れ", te: "って", ta: "った")
                ]
                if let row = table[last] {
                    // 行く/ゆく are the one godan verb with an irregular te/ta: って/った
                    // (not the regular いて/いた). `isIku` selects that pair for both
                    // the surface (kanji) and kana columns.
                    let isIku = (kana == "いく" || kana == "ゆく")
                    let teEnd = isIku ? "って" : row.te
                    let taEnd = isIku ? "った" : row.ta
                    return ([
                        InflectionForm(id: "pol", label: "Polite", surface: sStem + row.i + "ます", kana: kStem + row.i + "ます"),
                        InflectionForm(id: "neg", label: "Negative", surface: sStem + row.a + "ない", kana: kStem + row.a + "ない"),
                        // Past / Te-form: the surface uses the kanji stem (`sStem`) so
                        // 書く → 書いた / 書いて and 行く → 行った / 行って, matching every
                        // other row in this block and all other verb classes (ichidan
                        // 食べた, suru 勉強した, 来た). A prior version used the kana stem
                        // here, rendering 書いた → かいた — all-kana while its siblings
                        // were kanji. The `swift test` regression suite caught that; the
                        // kana column stays kana (kStem) so the all-kana reading remains.
                        InflectionForm(id: "past", label: "Past", surface: sStem + taEnd, kana: kStem + taEnd),
                        InflectionForm(id: "te", label: "Te-form", surface: sStem + teEnd, kana: kStem + teEnd),
                        InflectionForm(id: "pot", label: "Potential", surface: sStem + row.e + "る", kana: kStem + row.e + "る"),
                        InflectionForm(id: "pas", label: "Passive", surface: sStem + row.a + "れる", kana: kStem + row.a + "れる")
                    ], "Godan Verb Inflections")
                }
            }
        }

        // Na-adjective (keiyogo / quasi-adjective), bit 7: 静か → 静かな / 静かに /
        // 静かだった / 静かではない. The surface itself is the stem (no だ, no drop).
        if (mask & (1 << 7)) != 0 {
            return ([
                InflectionForm(id: "na", label: "Adjectival", surface: surface + "な", kana: kana + "な"),
                InflectionForm(id: "adv", label: "Adverbial", surface: surface + "に", kana: kana + "に"),
                InflectionForm(id: "past", label: "Past", surface: surface + "だった", kana: kana + "だった"),
                InflectionForm(id: "neg", label: "Negative", surface: surface + "ではない", kana: kana + "ではない")
            ], "Na-Adjective Inflections")
        }

        // i-Adjective check (e.g. 大きい, 新しい, 高い). Prefer the corpus bit (6),
        // but fall back to the kana heuristic when posMask is unknown (0).
        let isIAdj = (mask & (1 << 6)) != 0 ||
            (mask == 0 && kana.hasSuffix("い") && surface.hasSuffix("い") && !isVerb && kana.count >= 3)
        if isIAdj {
            let sStem = String(surface.dropLast())
            let kStem = String(kana.dropLast())
            return ([
                InflectionForm(id: "adv", label: "Adverbial", surface: sStem + "く", kana: kStem + "く"),
                InflectionForm(id: "neg", label: "Negative", surface: sStem + "くない", kana: kStem + "くない"),
                InflectionForm(id: "past", label: "Past", surface: sStem + "かった", kana: kStem + "かった"),
                InflectionForm(id: "te", label: "Te-form", surface: sStem + "くて", kana: kStem + "くて")
            ], "i-Adjective Inflections")
        }

        return ([], nil)
    }

    // MARK: - Part-of-speech / grammatical tag inference

    /// Infer the part-of-speech / grammatical tags shown under a sense.
    ///
    /// - Parameters:
    ///   - kana: the reading (e.g. "たべる"), used only by the legacy i-adjective
    ///     fallback when `posMask` carries no POS bits.
    ///   - posMask: the corpus part-of-speech bitmask (see file header). The
    ///     primary signal for the verdict.
    ///   - glosses: the raw English-gloss string (semicolon-separated, as stored
    ///     in the corpus). Sourced as the only fallback heuristic, and used to
    ///     detect prefix/suffix markers ("-").
    /// - Returns: up to two tag strings, e.g. ["Transitive • 他動詞", "Ichidan
    ///   Verb"], ["Na-Adj"], or ["Noun / Expr."].
    public static func senseTags(kana: String, posMask: UInt64, glosses: String) -> [String] {
        var tags: [String] = []

        // `glosses` is the raw English-gloss string (semicolon-separated). Split and
        // lowercase it into tokens; the corpus `posMask` below drives the verdict and
        // the glosses only supply the legacy fallback and the prefix/suffix markers.
        let glossTokens = glosses
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let mask = posMask
        // POS from the corpus bitmask (POS_BITS in build_corpus.py): bit0=n,
        // bits1–5=verbs (v1/v5/vs/vt/vi), bit6=adj-i, bit7=adj-na, bit8=adv,
        // bit10=prt. Replaces the old "gloss starts with 'to '" heuristic, which
        // mis-labeled nouns whose gloss began with "to " as verbs.
        let verbBits: UInt64 = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5)

        if glossTokens.contains(where: { $0.hasPrefix("-") }) {
            tags.append("Suffix")
        }
        if glossTokens.contains(where: { $0.hasSuffix("-") }) {
            tags.append("Prefix")
        }

        if (mask & verbBits) != 0 {
            if mask & (1 << 4) != 0 {           // vt
                tags.append("Transitive • 他動詞")
            } else if mask & (1 << 5) != 0 {    // vi
                tags.append("Intransitive • 自動詞")
            }
            if kana == "する" || kana.hasSuffix("する") {
                tags.append("Suru Verb")
            } else if mask & (1 << 1) != 0 {    // v1
                tags.append("Ichidan Verb")
            } else {
                tags.append("Godan Verb")
            }
        } else if mask & (1 << 7) != 0 {       // adj-na
            tags.append("Na-Adj")
        } else if mask & (1 << 6) != 0 {       // adj-i
            tags.append("i-Adj")
        } else if tags.isEmpty {
            // Fallback when posMask carries no POS bits: keep the legacy kana
            // heuristic for i-adjectives, otherwise treat as a noun / expression.
            if mask == 0 && kana.hasSuffix("い") &&
                !kana.hasSuffix("たい") && !kana.hasSuffix("ない") &&
                glossTokens.contains(where: { !$0.hasPrefix("to ") && !$0.contains(" ") }) {
                tags.append("i-Adj")
            } else {
                tags.append("Noun / Expr.")
            }
        }
        return Array(tags.prefix(2))
    }
}
