import Foundation
import Combine
import SwiftUI
import DaiJishowCore
// Pure morphology core (conjugation, POS tags, pitch contour + kana helpers) lives
// in the DaiJishowMorph library so it can be unit-tested. The engine adapts its
// EntryDetail / SenseItem into Morph's flat parameters at the call sites below.
import DaiJishowMorph
#if os(macOS)
import AppKit
#endif

struct WordHit: Identifiable, Hashable {
    let id: UInt32
    let kanjiHead: String
    let kanaHead: String
    let altForms: String
    let primaryGloss: String
    let posMask: UInt64
    let pitchAccent: UInt8
    let freqRank: UInt32
    let pairEntryId: UInt32
    let isName: Bool

    var displayHeadword: String {
        kanjiHead.isEmpty ? kanaHead : kanjiHead
    }

    var variantList: [String] {
        altForms
            .split(whereSeparator: { $0 == ";" || $0 == "," || $0 == "、" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// The codepoint of the first CJK ideograph in the display headword, if any.
    /// Used to pivot a kanji-bearing word into its Kanji Fisheye (the fisheye
    /// two-tap rule). Kana-only words return nil and fall back to the Cockpit.
    var firstKanjiCodepoint: UInt32? {
        for scalar in displayHeadword.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) {
                return v
            }
        }
        return nil
    }

    /// Whether this hit satisfies a single quick filter (see `SearchFilter`).
    func matches(_ filter: SearchFilter) -> Bool {
        switch filter {
        case .common:
            // "Common" = an overall frequency rank within the Jōyō band. A rank of
            // 0 means "no frequency data", which is *not* common.
            return freqRank > 0 && freqRank <= SearchFilter.commonFreqThreshold
        default:
            return (posMask & filter.posBits) != 0
        }
    }
}

/// Quick filters for the omni-search results dropdown. Applied client-side to the
/// in-memory `searchResults` so a large result set can be narrowed instantly,
/// without re-querying the lexicon. POS bits mirror the corpus builder's
/// `POS_BITS` table (tools/corpus-builder/build_corpus.py).
enum SearchFilter: String, CaseIterable, Identifiable, Hashable {
    // Part-of-speech + frequency chips (matched against a hit's POS bitmask / rank).
    case common = "Common"
    case nouns = "Nouns"
    case verbs = "Verbs"
    case adjectives = "Adjectives"
    case adverbs = "Adverbs"
    case particles = "Particles"
    case onomatopoeia = "Onomatopoeia"
    case yojijukugo = "Yojijukugo"
    case idioms = "Idioms"
    case proverbs = "Proverbs"
    case keigo = "Keigo"
    case colloquial = "Colloquial"
    // JLPT level + grade chips. These are *derived* from a word's head kanji (see
    // `derivedGradeJlpt`), not stored on the hit, so they need the kanji catalog.
    case jlpt5 = "N5"
    case jlpt4 = "N4"
    case jlpt3 = "N3"
    case jlpt2 = "N2"
    case jlpt1 = "N1"
    case grade1 = "Grade 1"
    case grade2 = "Grade 2"
    case grade3 = "Grade 3"

    var id: String { rawValue }

    /// POS bitmask this filter matches (0 ⇒ not a POS filter, e.g. `.common` or a
    /// derived JLPT/grade chip).
    var posBits: UInt64 {
        switch self {
        case .nouns:        return 1 << 0          // n
        case .verbs:        return (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5) // v1 v5 vs vt vi
        case .adjectives:   return (1 << 6) | (1 << 7)   // adj-i (keiyoushi) + adj-na (keiyogo)
        case .adverbs:      return 1 << 8          // adv
        case .particles:    return 1 << 10         // prt
        case .yojijukugo:   return 1 << 11         // yoji
        case .idioms:       return 1 << 12         // id
        case .onomatopoeia: return 1 << 13         // on-mim
        case .keigo:        return (1 << 14) | (1 << 15) | (1 << 16) // hon + hum + pol
        case .colloquial:   return (1 << 17) | (1 << 18) // col + sl
        case .proverbs:     return 1 << 21         // proverb
        default:            return 0              // common + all derived filters
        }
    }

    /// The JLPT level (5…1) this chip matches, or nil if it is not a JLPT chip.
    var jlptLevel: Int? {
        switch self {
        case .jlpt5: return 5
        case .jlpt4: return 4
        case .jlpt3: return 3
        case .jlpt2: return 2
        case .jlpt1: return 1
        default:      return nil
        }
    }

    /// The school grade (1…3) this chip matches, or nil if it is not a grade chip.
    var gradeLevel: Int? {
        switch self {
        case .grade1: return 1
        case .grade2: return 2
        case .grade3: return 3
        default:      return nil
        }
    }

    /// True when the filter is derived from per-kanji telemetry (JLPT / grade)
    /// rather than a hit's POS bits or frequency rank.
    var isDerived: Bool {
        jlptLevel != nil || gradeLevel != nil
    }

    /// Jōyō frequency threshold: a "common" word has an overall rank ≤ 12,000.
    static let commonFreqThreshold: UInt32 = 12_000

    /// Distinct tint per filter, so the chip row reads as a colour-coded legend.
    var tint: Color {
        switch self {
        case .common:     return Color(red: 0.20, green: 0.78, blue: 0.62) // teal — "core/common"
        case .nouns:      return Color(red: 0.30, green: 0.58, blue: 0.95) // blue
        case .verbs:      return Color(red: 0.97, green: 0.55, blue: 0.18) // orange — action
        case .adjectives: return Color(red: 0.72, green: 0.45, blue: 0.95) // purple
        case .adverbs:      return Color(red: 0.45, green: 0.78, blue: 0.35) // green
        case .particles:    return Color(red: 0.42, green: 0.52, blue: 0.85) // indigo/slate
        case .onomatopoeia: return Color(red: 0.96, green: 0.54, blue: 0.72) // rose
        case .yojijukugo:   return Color(red: 0.95, green: 0.72, blue: 0.24) // gold
        case .idioms:       return Color(red: 0.36, green: 0.78, blue: 0.88) // cyan
        case .proverbs:     return Color(red: 0.76, green: 0.56, blue: 0.96) // lavender
        case .keigo:        return Color(red: 0.88, green: 0.64, blue: 0.36) // bronze
        case .colloquial:   return Color(red: 0.54, green: 0.82, blue: 0.56) // mint
        // JLPT chips: a green→red ramp by difficulty (N5 easiest, N1 hardest).
        case .jlpt5:      return Color(red: 0.42, green: 0.78, blue: 0.35) // green
        case .jlpt4:      return Color(red: 0.86, green: 0.74, blue: 0.20) // yellow
        case .jlpt3:      return Color(red: 0.96, green: 0.60, blue: 0.25) // amber
        case .jlpt2:      return Color(red: 0.95, green: 0.45, blue: 0.28) // orange
        case .jlpt1:      return Color(red: 0.92, green: 0.35, blue: 0.35) // red — advanced
        // Grade chips: a cool slate ramp by difficulty (Grade 1 → 3).
        case .grade1:     return Color(red: 0.55, green: 0.65, blue: 0.85)
        case .grade2:     return Color(red: 0.50, green: 0.58, blue: 0.80)
        case .grade3:     return Color(red: 0.45, green: 0.52, blue: 0.75)
        }
    }
}

struct RubyCell: Identifiable {
    let id: Int
    let surface: String
    let furigana: String
    let kanjiCodepoint: UInt32
}

struct SenseItem: Identifiable {
    let id: UInt32
    let posMask: UInt64
    let enGlosses: String
    let jaGlosses: String
}

struct SentenceSegment: Identifiable {
    let id: Int
    let text: String
    let furigana: String?
    let entryId: UInt32?
}

struct SentenceItem: Identifiable {
    let id: UInt32
    let jpText: String
    let enText: String
    let segments: [SentenceSegment]
}

struct EntryDetail {
    let header: WordHit
    let pairedKanji: String
    let pairedKana: String
    let rubyCells: [RubyCell]
    let senses: [SenseItem]
    let sentences: [SentenceItem]

    var hasJapaneseGlosses: Bool {
        senses.contains { !$0.jaGlosses.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Plain-text rendering for the clipboard / "Copy Entry": headword with
    /// kana and variant forms, followed by one line per sense (EN / JA).
    var copyText: String {
        var lines: [String] = []
        var head = header.displayHeadword
        if !header.kanaHead.isEmpty {
            head += " (\(header.kanaHead))"
        }
        let variants = header.variantList
        if !variants.isEmpty {
            head += "  [\(variants.joined(separator: ", "))]"
        }
        lines.append(head)
        for sense in senses {
            var parts: [String] = []
            let en = sense.enGlosses.trimmingCharacters(in: .whitespacesAndNewlines)
            let ja = sense.jaGlosses.trimmingCharacters(in: .whitespacesAndNewlines)
            if !en.isEmpty { parts.append(en) }
            if !ja.isEmpty { parts.append(ja) }
            if !parts.isEmpty {
                lines.append("• " + parts.joined(separator: " / "))
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Word Cockpit Rich Lexical Models

enum GlossLanguageMode: String, CaseIterable, Identifiable {
    case english = "EN"
    case japanese = "国語"
    case both = "Both"
    var id: String { rawValue }
}

// `PitchAccentContour` and its `build` factory were extracted to the
// `DaiJishowMorph` library (PitchAccentContour.swift) so the pitch-accent logic
// — including the rc7 trailing-が noun-gating — can be unit-tested. This file
// imports the library, so the type is in scope here.

struct WordTelemetry {
    let frequencyTier: String
    let frequencyRankText: String
    let popularityRatio: Double   // 0.12 ... 1.0
    let tierColor: Color
    let gradeLabel: String?
    let jlptLabel: String?
    let totalStrokes: Int
}

struct WordKanjiDNA: Identifiable {
    let id: Int
    let codepoint: UInt32
    let glyph: String
    let strokes: Int
    let gradeLabel: String
    let jlptLabel: String
    let meanings: String
    let onReadings: [String]
    let kunReadings: [String]
    let matchedReadingNormalized: String?
    let isJukujikun: Bool

    /// The reading to use for this kanji's per-kanji speaker button: the in-compound
    /// matched reading when the corpus records one, else the kanji's standard on-reading
    /// (then kun) so the speaker always has something to say. `intermediateIsFallback`
    /// marks the on-reading case so the UI can phrase it as the kanji's own reading
    /// rather than a reading it takes inside the compound.
    var intermediateReading: String? {
        if let m = matchedReadingNormalized, !m.isEmpty { return m }
        if let on = onReadings.first, !on.isEmpty { return on }
        if let kun = kunReadings.first, !kun.isEmpty { return kun }
        return nil
    }
    var intermediateIsFallback: Bool {
        matchedReadingNormalized == nil || matchedReadingNormalized?.isEmpty == true
    }
}

/// One "Try:" example chip for the Compound Kanji screen's search row. Seeded from
/// the recent-kanji ring: the most frequent compound containing a recently
/// inspected kanji, so the examples track what the user has been studying.
struct CompoundExample: Identifiable, Hashable {
    var id: UInt32 { entryId }
    let entryId: UInt32
    let word: String
    let kana: String
    /// The recent kanji this example was derived from (shown in the tooltip).
    let seedGlyph: String
}

struct CollocationPattern: Identifiable, Hashable {
    let id: String
    let pattern: String
    let roleLabel: String
    let count: Int
}

// `InflectionForm` was extracted to the `DaiJishowMorph` library
// (InflectionForm.swift) so the conjugation matrix it populates can be tested.
// Imported above, so it remains in scope for `WordLexicalInsights.inflections`.

struct IdiomItem: Identifiable, Hashable {
    var id: UInt32 { entryId }
    let entryId: UInt32
    let idiomKind: UInt8
    let kanjiHead: String
    let kanaHead: String
    let figurativeGloss: String
    let anchorLemmas: String

    var displayHeadword: String {
        kanjiHead.isEmpty ? kanaHead : kanjiHead
    }

    var kindLabel: String {
        switch idiomKind {
        case 1: return "四字熟語 • Yojijukugo"
        case 3: return "諺 • Proverb"
        default: return "慣用句 • Idiom"
        }
    }

    var shortKindLabel: String {
        switch idiomKind {
        case 1: return "四字熟語"
        case 3: return "諺"
        default: return "慣用句"
        }
    }
}

struct WordLexicalInsights {
    let entryId: UInt32
    let telemetry: WordTelemetry
    let senseTags: [UInt32: [String]]
    let kanjiDNA: [WordKanjiDNA]
    let homonyms: [WordHit]
    let prefixCompounds: [WordHit]
    let suffixCompounds: [WordHit]
    let collocations: [CollocationPattern]
    let fallbackSentences: [SentenceItem]
    let fallbackSourceWord: String?
    let fallbackSourceEntryId: UInt32?
    let inflections: [InflectionForm]
    let inflectionHeader: String?
    let idioms: [IdiomItem]
}

// MARK: - Kanji Index & Detail Models

struct KanjiIndexItem: Identifiable, Hashable {
    var id: UInt32 { codepoint }
    let codepoint: UInt32
    let glyph: String
    let strokes: Int
    let grade: Int
    let jlpt: Int
    let freqRank: UInt32
    let radicalId: Int
    let skipPattern: Int
    let skipPart1: Int
    let skipPart2: Int
    let fourCornerCode: String
    let onReadings: [String]
    let kunReadings: [String]
    let normalizedOn: [String]
    let normalizedKun: [String]
    let meanings: String
    let meaningsLower: String

    var gradeLabel: String {
        switch grade {
        case 1...6: return "G\(grade)"
        case 8: return "Jōyō"
        case 9, 10: return "Jinmei"
        default: return ""
        }
    }

    var jlptLabel: String {
        jlpt > 0 ? "N\(jlpt)" : ""
    }

    var primaryReading: String {
        if let on = onReadings.first, !on.isEmpty { return on }
        if let kun = kunReadings.first, !kun.isEmpty { return kun }
        return ""
    }
}

struct KanjiDetail {
    let codepoint: UInt32
    let glyph: String
    let strokes: Int
    let grade: Int
    let jlpt: Int
    let freqRank: UInt32
    let radicalId: Int
    let skipCode: UInt32
    let fourCorner: UInt32
    let skipCodeLabel: String
    let fourCornerLabel: String
    let kyujitaiGlyph: String?
    let onReadings: [String]
    let kunReadings: [String]
    let meanings: String
    let componentRadicals: String
    let strokePolylines: [[CGPoint]]
    let standaloneEntries: [EntryDetail]
    let relatedWords: [WordHit]
    let idioms: [IdiomItem]

    var unicodeHex: String {
        String(format: "U+%04X", codepoint)
    }

    var unicodeBlockLabel: String {
        switch codepoint {
        case 0x3400...0x4DBF:
            return "CJK Unified Ideographs Extension A"
        case 0x4E00...0x9FFF:
            return "CJK Unified Ideographs"
        case 0xF900...0xFAFF:
            return "CJK Compatibility Ideographs"
        case 0x20000...0x2FFFF:
            return "CJK Unified Ideographs Extension B+"
        default:
            return "CJK Ideograph"
        }
    }

    var isUncatalogued: Bool {
        meanings.isEmpty && onReadings.isEmpty && kunReadings.isEmpty
    }

    var specialCaseTitle: String? {
        if (0x3400...0x4DBF).contains(codepoint) {
            return "Extended / Variant Kanji (\(unicodeHex) • CJK Extension A)"
        }
        if (0xF900...0xFAFF).contains(codepoint) {
            return "CJK Compatibility Variant (\(unicodeHex))"
        }
        if codepoint >= 0x20000 {
            return "Rare Plane 2 Ideograph (\(unicodeHex) • CJK Extension B+)"
        }
        if isUncatalogued {
            return "Uncatalogued Variant / Non-Standard Kanji (\(unicodeHex))"
        }
        return nil
    }

    var specialCaseExplanation: String? {
        if (0x3400...0x4DBF).contains(codepoint) {
            return "This character belongs to Unicode's CJK Extension A block, which houses historical variants (itaiji), shorthand abbreviations (ryakuji—such as 㐂 for 喜), and non-standard forms outside KANJIDIC2 and KanjiVG. Standard readings, meanings, and stroke vectors are not indexed, though dictionary words containing it are listed below."
        }
        if (0xF900...0xFAFF).contains(codepoint) {
            return "This codepoint is a Unicode compatibility ideograph preserved for legacy character-set round-tripping and is not separately indexed in KANJIDIC2 or KanjiVG."
        }
        if codepoint >= 0x20000 || isUncatalogued {
            return "This glyph appears in vocabulary headwords (such as variant spellings or proper names) but has no standalone lexical entry in KANJIDIC2 or stroke diagram in KanjiVG."
        }
        return nil
    }

    /// Plain-text rendering for the clipboard / "Copy": glyph, Unicode codepoint,
    /// metadata, readings, and meanings — matching what the Kanji Fisheye shows.
    var copyText: String {
        var lines: [String] = []
        var meta: [String] = []
        if strokes > 0 { meta.append("\(strokes) strokes") }
        switch grade {
        case 1...6: meta.append("G\(grade)")
        case 8: meta.append("Jōyō")
        case 9, 10: meta.append("Jinmei")
        default: break
        }
        if jlpt > 0 { meta.append("N\(jlpt)") }
        if freqRank > 0 { meta.append("freq #\(freqRank)") }
        var head = glyph + "  " + unicodeHex
        if !meta.isEmpty { head += "  (" + meta.joined(separator: ", ") + ")" }
        lines.append(head)
        if !onReadings.isEmpty { lines.append("On:  " + onReadings.joined(separator: " / ")) }
        if !kunReadings.isEmpty { lines.append("Kun: " + kunReadings.joined(separator: " / ")) }
        for meaning in meanings.split(whereSeparator: { $0 == ";" || $0 == "\n" }) {
            let trimmed = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { lines.append("• " + trimmed) }
        }
        return lines.joined(separator: "\n")
    }
}

struct FisheyeNode: Identifiable {
    var id: String { "\(isOverflowPreview)-\(side)-\(codepoint)" }
    let codepoint: UInt32
    let glyph: String
    let side: UInt8
    let commonalityTier: UInt8
    let isOverflowPreview: Bool
    let topEntryId: UInt32
    let compoundWord: String
    let compoundKana: String
    let compoundGloss: String
    let sharePct: Float
    let normX: CGFloat
    let normY: CGFloat
    let scale: CGFloat
    let opacity: Double

    var tierColor: Color {
        switch commonalityTier {
        case 0: return Color(red: 0.22, green: 0.74, blue: 0.97) // Core
        case 1: return Color(red: 0.20, green: 0.83, blue: 0.60) // Joyo
        case 2: return Color(red: 0.98, green: 0.75, blue: 0.14) // Literary
        default: return Color(red: 0.65, green: 0.55, blue: 0.98) // Kyujitai
        }
    }

    var tierLabel: String {
        switch commonalityTier {
        case 0: return "Core"
        case 1: return "Jōyō"
        case 2: return "Literary"
        default: return "Kyūjitai"
        }
    }

    var shareText: String {
        if sharePct >= 1.0 {
            return String(format: "%.0f%%", sharePct)
        } else if sharePct >= 0.1 {
            return String(format: "%.1f%%", sharePct)
        } else {
            return "<0.1%"
        }
    }
}

enum ActiveScreenKind: String {
    case fisheye
    case wordEntry
    case kanjiDetail
    case radicalBuilder
    case kanjiLookup
    case wordCosmos
    case compoundKanji
    case studyLibrary
}

/// Prevalence-tier ceiling for the Word Cosmos sampler. `maxFreqRank` is the
/// ceiling passed to `dj_dict_get_random_words`; `0` means "no ceiling" (the C++
/// fast path samples the entire lexicon).
enum WordCosmosTier: String, CaseIterable, Identifiable {
    case core
    case common
    case all

    var id: String { rawValue }

    var maxFreqRank: UInt32 {
        switch self {
        case .core: return 2500
        case .common: return 12000
        case .all: return 0
        }
    }

    var label: String {
        switch self {
        case .core: return "Core"
        case .common: return "Common"
        case .all: return "All"
        }
    }

    var detail: String {
        switch self {
        case .core: return "Top 2,500"
        case .common: return "Top 12,000"
        case .all: return "Entire lexicon"
        }
    }
}

/// How the ~50-word cloud is arranged. `cloud` is a randomized Poisson-disk
/// scatter; `constellation` lays tiers out as concentric rings around the center.
enum WordCosmosLayout: String, CaseIterable, Identifiable {
    case cloud
    case constellation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cloud: return "Cloud"
        case .constellation: return "Constellation"
        }
    }
}

/// Whether the screen shows the randomized bubble cloud or a ranked prevalence
/// list of the current sample.
enum WordCosmosMode: String, CaseIterable, Identifiable {
    case cosmos
    case ranked

    var id: String { rawValue }
}

/// How a Word Cloud bubble is *tinted*. `prevalence` (the historical colouring)
/// shades by frequency rank; the JLPT / grade modes shade by a word's *derived*
/// difficulty — its hardest JLPT level and its highest head-kanji grade, both
/// derived from the head kanji (kana-only words carry no kanji, so they fall to
/// a neutral "no level" tint rather than the hardest tier).
enum WordCosmosColorMode: String, CaseIterable, Identifiable {
    case prevalence
    case jlpt
    case grade

    var id: String { rawValue }

    var label: String {
        switch self {
        case .prevalence: return "Prevalence"
        case .jlpt:       return "JLPT"
        case .grade:      return "Grade"
        }
    }
}

enum KanjiLookupMode: String, CaseIterable, Identifiable {
    case strokes = "Strokes"
    case reading = "Reading"
    case skip = "SKIP"
    case fourCorner = "Four-Corner"
    case gradeJlpt = "Grade / JLPT"
    case meaning = "Meaning"
    var id: String { rawValue }
}

enum KanjiSortOrder: String, CaseIterable, Identifiable {
    case popularity = "Popularity"
    case grade = "Grade"
    case jlpt = "JLPT"
    case strokes = "Strokes"
    case radical = "Radical #"
    var id: String { rawValue }
}

struct NavBreadcrumb: Identifiable, Equatable {
    let id = UUID()
    let kind: ActiveScreenKind
    let targetId: UInt32
    let label: String
    let subtitle: String
}

enum HistorySnapshot {
    case wordEntry(EntryDetail)
    case kanjiDetail(KanjiDetail)
    case fisheye(kanji: KanjiDetail, nodes: [FisheyeNode], leftOverflow: Int, rightOverflow: Int)
    case radicalBuilder(selectedIds: [UInt8], targetStrokes: Int, matches: [UInt32])
    case kanjiLookup(mode: KanjiLookupMode, strokeCount: Int, sortOrder: KanjiSortOrder, results: [KanjiIndexItem])
    case wordCosmos(words: [WordHit], tier: WordCosmosTier, layout: WordCosmosLayout, colorMode: WordCosmosColorMode)
    case compoundWord(entryId: UInt32)
    case studyLibrary(deckCount: Int, itemCount: Int)
}

enum RecallMode: String, CaseIterable, Identifiable {
    case full = "Full"
    case hideKana = "Hide Kana"
    case hideGloss = "Hide Defn."
    var id: String { rawValue }
}

/// How the kanji detail screen's "Vocabulary & Compounds" list is filtered and
/// ordered. Persisted per user.
enum KanjiRelatedDisplayMode: String, CaseIterable, Identifiable {
    case prevalence = "Prevalence"
    case startsWith = "Starts"
    case endsWith = "Ends"

    var id: String { rawValue }

    var help: String {
        switch self {
        case .prevalence:
            return "Every word containing this kanji, most common first"
        case .startsWith:
            return "Only headwords that begin with this kanji, most common first"
        case .endsWith:
            return "Only headwords that end with this kanji, most common first"
        }
    }
}

// Kana / mora / romaji helpers (`KanaNormalizer`) were extracted to the
// `DaiJishowMorph` library (KanaNormalizer.swift) so the pitch-accent and
// conjugation logic can be unit-tested. This file imports the library, so
// `KanaNormalizer.splitMorae` / `cleanReadingToken` / `stemBeforeDot` resolve
// from there.

/// A transient "hidden proper name" nudge, surfaced above the search results.
///
/// With Names off, the omni-search excludes proper names (`is_name = 1`), so a
/// place like 秋葉原 "Akihabara" can be hidden behind the only visible result — an
/// event compound such as 秋葉原通り魔事件. Because proper names carry a frequency
/// sentinel, the AUTO search ranks a name at #1 *only* when it is the genuine best
/// match and the names-off view is hiding it. When that happens we surface the
/// hidden name and, on the user's behalf, flip Names on — or, once they've turned
/// it off themselves, merely *suggest* turning it back on.
struct NameNudge: Identifiable {
    let id = UUID()
    let hit: WordHit          // the hidden proper name (the engine's best match)
    let autoEnabled: Bool     // true = we flipped Names on; false = suggest-only
}

@MainActor
final class DaiJishowEngine: ObservableObject {
    private static let cockpitDefaultsKey = "daijishow.wordCockpitExpanded"
    private static let kanjiRelatedModeKey = "daijishow.kanjiRelatedMode"
    private static let recallModeKey = "daijishow.recallMode"
    private static let includeNamesKey = "daijishow.includeNames"
    private static let maxFisheyePerSideKey = "daijishow.maxFisheyePerSide"
    private static let showFisheyePercentagesKey = "daijishow.showFisheyePercentages"
    private static let recentKanjiKey = "daijishow.recentKanji"
    private static let wordCosmosTierKey = "daijishow.wordCosmosTier"
    private static let wordCosmosLayoutKey = "daijishow.wordCosmosLayout"
    private static let wordCosmosCountKey = "daijishow.wordCosmosCount"
    private static let wordCosmosColorModeKey = "daijishow.wordCosmosColorMode"
    private static let lastScreenKey = "daijishow.lastScreen"
    private static let lastTargetIdKey = "daijishow.lastTargetId"

    private var handle: OpaquePointer?
    private var isBootstrapped = false
    private var searchDebounceTask: Task<Void, Never>?
    private var historySnapshots: [UUID: HistorySnapshot] = [:]
    private var cachedKanjiCatalog: [KanjiIndexItem]?
    private var cachedKanjiByCodepoint: [UInt32: KanjiIndexItem]?
    private var wordInsightsCache: [String: WordLexicalInsights] = [:]
    private var entryDetailCache: [UInt32: EntryDetail] = [:]
    private var studyStoreCancellable: AnyCancellable?

    let studyStore = StudyStore()

    @Published var searchQuery: String = ""
    @Published var searchContainsMode: Bool = false {
        didSet {
            if isBootstrapped && !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                performSearch()
            }
        }
    }
    @Published var selectedSearchIndex: Int = 0
    @Published var includeNames: Bool = false {
        didSet {
            if isBootstrapped {
                UserDefaults.standard.set(includeNames, forKey: Self.includeNamesKey)
            }
        }
    }
    @Published var recallMode: RecallMode = .full {
        didSet {
            if isBootstrapped {
                UserDefaults.standard.set(recallMode.rawValue, forKey: Self.recallModeKey)
            }
        }
    }
    @Published var searchResults: [WordHit] = [] {
        didSet {
            selectedSearchIndex = 0
        }
    }

    // MARK: Proper-name auto-nudge

    /// A "hidden proper name" nudge currently shown above the results. See
    /// `NameNudge`. Cleared by a new query or by its own dismissal timer.
    @Published var nameNudge: NameNudge?

    /// True when the user has *manually* turned Names off this session. The
    /// auto-nudge then stops flipping it back on, but still leaves a gentle
    /// "you might want to turn it back on" suggestion when the signal fires.
    private var userToggledNamesManually = false

    /// A query the user has already dismissed/undid the nudge for, so the same
    /// query does not instantly re-raise the banner; a *new* query may still nudge.
    private var suppressedNudgeQuery = ""

    /// The query that raised the current nudge. A re-search of the *same* query
    /// (e.g. the auto-enable's `includeNames = true` firing the toggle's
    /// `.onChange` → `performSearch`) must **not** clear the banner, or the nudge
    /// would vanish the instant Names flips on; only a *different* query supersedes it.
    private var nudgeSourceQuery = ""

    /// Backing timer for the auto-dismissing nudge banner.
    private var nameNudgeDismissal: Task<Void, Never>?

    /// Monotonic token so overlapping pulse timers only the latest one can clear
    /// the flash.
    private var nameFlashToken = 0

    /// True briefly while the top-bar Names toggle is flashing, so an auto-enable
    /// reads as "this control just changed" rather than a silent result shift.
    @Published private(set) var namesToggleFlash = false

    /// English-gloss matches for the current romaji query, surfaced as a separate
    /// "Also in English glosses" section beneath the main (Japanese) results.
    /// Populated only for ASCII-romaji-looking queries, and deduped against
    /// `searchResults` so no entry appears in both. Empty when there's no query
    /// or no English-gloss hit.
    @Published var englishMatches: [WordHit] = []
    /// Active quick filters for the search results dropdown (Common / Nouns / …).
    /// Sticky across searches: the same filters apply to the next query too.
    @Published var searchFilters: Set<SearchFilter> = []

    /// `searchResults` narrowed by the active quick filters. An empty filter set
    /// returns the full list unchanged, so the dropdown is a no-op when no chip is
    /// selected.
    ///
    /// POS + frequency chips match against a hit's bitmask/rank via `WordHit.matches`.
    /// JLPT / grade chips are *derived* from the word's head kanji (see
    /// `derivedGradeJlpt`); they are evaluated together, and the kanji catalog is
    /// loaded only when at least one derived chip is active.
    var filteredSearchResults: [WordHit] {
        guard !searchFilters.isEmpty else { return searchResults }

        // Fast path: no derived chips ⇒ pure hit-level matching.
        if !searchFilters.contains(where: { $0.isDerived }) {
            return searchResults.filter { hit in
                searchFilters.allSatisfy { hit.matches($0) }
            }
        }

        ensureKanjiCatalogLoaded()
        let posFilters = searchFilters.filter { !$0.isDerived }
        let derivedFilters = searchFilters.filter { $0.isDerived }
        return searchResults.filter { hit in
            // POS + frequency chips first (cheap, hit-level).
            guard posFilters.allSatisfy({ hit.matches($0) }) else { return false }
            // JLPT / grade chips: derive the word's level once, then compare.
            let derived = derivedGradeJlpt(for: hit)
            return derivedFilters.allSatisfy { filter in
                if let jlptLevel = filter.jlptLevel {
                    return derived.hardestJlpt == jlptLevel
                }
                if let gradeLevel = filter.gradeLevel {
                    return derived.highestGrade == gradeLevel
                }
                return false
            }
        }
    }

    /// The word's derived JLPT and grade, mirroring `buildWordInsights`: the JLPT
    /// is the *hardest* (smallest) level among its head kanji, and the grade the
    /// *highest* grade among its head kanji. Kana-only words have no head kanji, so
    /// they yield `(6, 0)` and never match any JLPT or grade chip.
    private func derivedGradeJlpt(for hit: WordHit) -> (hardestJlpt: Int, highestGrade: Int) {
        var hardestJlpt = 6
        var highestGrade = 0
        for scalar in hit.kanjiHead.unicodeScalars where isKanjiScalar(scalar.value) {
            guard let meta = cachedKanjiByCodepoint?[scalar.value] else { continue }
            if (1...10).contains(meta.grade) { highestGrade = max(highestGrade, meta.grade) }
            if (1...5).contains(meta.jlpt) { hardestJlpt = min(hardestJlpt, meta.jlpt) }
        }
        return (hardestJlpt, highestGrade)
    }

    /// The colour a Word Cloud bubble takes for `word`, by the active
    /// `wordCosmosColorMode`. `prevalence` reuses the frequency-tier palette; the
    /// JLPT / grade modes derive the word's difficulty from its head kanji (the
    /// catalog is loaded on demand) and map it onto a green→red / slate ramp.
    func cosmosColor(for word: WordHit) -> Color {
        switch wordCosmosColorMode {
        case .prevalence:
            return CosmosTierInfo.of(word).color
        case .jlpt:
            ensureKanjiCatalogLoaded()
            return Self.cosmosJlptRamp(derivedGradeJlpt(for: word).hardestJlpt)
        case .grade:
            ensureKanjiCatalogLoaded()
            return Self.cosmosGradeRamp(derivedGradeJlpt(for: word).highestGrade)
        }
    }

    /// A green→red difficulty ramp for JLPT: green (easy, N5) → red (hard, N1).
    /// Kana-only words (level 6) get a muted neutral so they read as "no JLPT
    /// level" rather than as the hardest tier.
    static func cosmosJlptRamp(_ jlpt: Int) -> Color {
        switch jlpt {
        case 5: return Color(red: 0.20, green: 0.80, blue: 0.45)   // N5 — green
        case 4: return Color(red: 0.62, green: 0.85, blue: 0.24)   // N4 — lime
        case 3: return Color(red: 0.98, green: 0.80, blue: 0.20)   // N3 — amber
        case 2: return Color(red: 0.96, green: 0.56, blue: 0.18)   // N2 — orange
        case 1: return Color(red: 0.92, green: 0.31, blue: 0.33)   // N1 — red
        default: return Color(white: 0.62)                          // kana-only / unranked
        }
    }

    /// A slate ramp for grade: light slate (early grade) deepening to
    /// indigo-slate (late grade). Kana-only words (grade 0) get a neutral gray.
    static func cosmosGradeRamp(_ grade: Int) -> Color {
        guard (1...10).contains(grade) else { return Color(white: 0.55) }
        let t = Double(grade - 1) / 9.0
        let hue = 0.58 + 0.08 * t
        let saturation = 0.14 + 0.34 * t
        let brightness = 0.84 - 0.52 * t
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Canonical JLPT level definitions (N5 easiest → N1 hardest), kept in one
    /// place so the colour legend, the ranked-row JLPT chip, and the search
    /// filter chips all explain *what a level means* — not merely which words
    /// match a given level.
    static func jlptLevelDescription(_ level: Int) -> String {
        switch level {
        case 5: return "Basic phrases, hiragana, katakana, simple kanji, and short, slow conversations."
        case 4: return "Basic everyday Japanese — simple daily topics and slowly spoken conversations."
        case 3: return "A bridge between basic and advanced Japanese, used in everyday situations."
        case 2: return "Everyday Japanese across broader settings — clear articles and natural-speed speech."
        case 1: return "Complex, abstract texts (editorials, critiques) and natural-speed speech across varied settings."
        default: return "Kana-only — no JLPT level (the word has no head kanji)."
        }
    }

    /// Short difficulty chips for a word's *derived* level, mirroring
    /// `derivedGradeJlpt`: the JLPT is the hardest (smallest) head-kanji level,
    /// the grade the highest. Both are nil for kana-only words, which have no
    /// head kanji to derive a level or grade from. The catalog is loaded on
    /// demand (cheap after the first call).
    func derivedDifficultyChips(for word: WordHit) -> (jlptLevel: Int?, gradeLevel: Int?) {
        ensureKanjiCatalogLoaded()
        let d = derivedGradeJlpt(for: word)
        let jlptLevel = (1...5).contains(d.hardestJlpt) ? d.hardestJlpt : nil
        let gradeLevel = (1...10).contains(d.highestGrade) ? d.highestGrade : nil
        return (jlptLevel, gradeLevel)
    }

    /// A short label for the difficulty a difficulty-coloured bubble encodes, for
    /// the inspector ribbon / legend. Prevalence falls back to the tier label.
    func cosmosDifficultyLabel(for word: WordHit) -> String {
        switch wordCosmosColorMode {
        case .prevalence:
            return CosmosTierInfo.of(word).label
        case .jlpt:
            let level = derivedGradeJlpt(for: word).hardestJlpt
            return (1...5).contains(level) ? "JLPT N\(level)" : "Kana only"
        case .grade:
            let grade = derivedGradeJlpt(for: word).highestGrade
            return grade >= 1 ? "Grade \(grade)" : "Kana only"
        }
    }

    func toggleSearchFilter(_ filter: SearchFilter) {
        if searchFilters.contains(filter) {
            searchFilters.remove(filter)
        } else {
            searchFilters.insert(filter)
        }
    }

    // MARK: Proper-name auto-nudge controls

    /// Route a Names-toggle change through here. A *user* change records intent: a
    /// manual off suppresses the auto-nudge for the rest of the session, a manual
    /// on re-enables it. The engine's own auto-enable passes `userInitiated: false`,
    /// leaving intent untouched. Setting `includeNames` triggers the toggle's
    /// `.onChange`, which re-runs the search (and the fisheye side-effects).
    func setNamesIncluded(_ on: Bool, userInitiated: Bool) {
        if userInitiated {
            userToggledNamesManually = (on == false)
        }
        includeNames = on
    }

    /// Briefly flash the top-bar Names toggle so an auto-enable is visible as the
    /// cause of a result change. Only the latest pulse can clear the flag, so rapid
    /// nudges never prematurely end each other.
    func pulseNamesToggle() {
        nameFlashToken &+= 1
        let token = nameFlashToken
        namesToggleFlash = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.25))
            guard !Task.isCancelled, let self else { return }
            if self.nameFlashToken == token { self.namesToggleFlash = false }
        }
    }

    /// Surface a "hidden proper name" nudge for `trimmed`. With Names off, run a
    /// small speculative Names-on search and, if its #1 hit is a proper name, raise
    /// a nudge. This is precise: proper names carry a frequency sentinel, so by the
    /// AUTO search's `CASE WHEN head = query THEN 0, freq_overall` ordering a name
    /// sits at #1 *only* when no common word has an exact reading match — i.e. the
    /// hidden name really is the best answer. It never fires on ordinary words like
    /// "aoi", whose common reading always outranks the name homonym.
    ///
    /// Honours explicit intent: when not suppressed, it flips Names on *for the
    /// user* (and flashes the toggle); once they've turned it off themselves, it
    /// leaves a gentle "turn it back on?" suggestion instead. A query the user has
    /// already dismissed is not re-nudged until they run a new one.
    private func checkHiddenProperName(for trimmed: String, handle h: OpaquePointer) {
        // Skip a query the user already dismissed/undid; a new query may still nudge.
        if suppressedNudgeQuery == trimmed { return }
        var rawPtr: UnsafePointer<dj_word_hit_t>?
        let count = trimmed.withCString { cStr in
            dj_dict_search(h, cStr, DJ_SEARCH_AUTO, true, 8, &rawPtr)
        }
        guard let ptr = rawPtr, count > 0 else { return }
        let top = Self.wordHit(from: ptr[0])
        guard top.isName else { return }   // #1 is a proper name the names-off view hides

        let nudge = NameNudge(hit: top, autoEnabled: !userToggledNamesManually)
        nameNudge = nudge
        nudgeSourceQuery = trimmed
        scheduleNudgeDismissal()

        if userToggledNamesManually {
            // Respect the user's explicit off: don't flip it back, just nudge.
            return
        }
        // Auto-enable on the user's behalf. Setting `includeNames` re-runs the
        // search via the toggle's `.onChange`, repopulating with names included.
        includeNames = true
        pulseNamesToggle()
    }

    private func scheduleNudgeDismissal() {
        guard let current = nameNudge else { return }
        nameNudgeDismissal?.cancel()
        nameNudgeDismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, let self else { return }
            // Clear only if nothing newer has superseded this nudge.
            if self.nameNudge?.id == current.id { self.nameNudge = nil }
        }
    }

    /// Undo a proper-name auto-enable: turn Names off and, since the user is opting
    /// out *for this query*, suppress the nudge for it until they run a new one.
    /// This is per-query (not the global `userToggledNamesManually` flag, which only
    /// a *manual* Names-off sets), so the next place-name search can still auto-enable.
    func undoNamesAutoEnable() {
        suppressedNudgeQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        nameNudgeDismissal?.cancel()
        nameNudge = nil
        setNamesIncluded(false, userInitiated: false)
    }

    /// Dismiss the nudge banner without changing Names, suppressing it for the
    /// current query so it does not instantly re-raise on the re-search.
    func dismissNameNudge() {
        suppressedNudgeQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        nameNudgeDismissal?.cancel()
        nameNudge = nil
    }

    /// The suggest banner's "Turn on Names" button. The user wants proper names, so
    /// re-enable auto-flip *globally* (clearing the manual-off suppression) and clear
    /// the now-satisfied nudge — its job is done once the name is visible, so it must
    /// not linger as a stale "Turn on Names" prompt after names flip on.
    func turnOnNamesFromNudge() {
        suppressedNudgeQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        nameNudgeDismissal?.cancel()
        nameNudge = nil
        setNamesIncluded(true, userInitiated: true)
    }

    /// Drives the About / Credits sheet (standard Mac "About" chrome).
    @Published var showAbout: Bool = false

    @Published var isWordCockpitExpanded: Bool {
        didSet {
            UserDefaults.standard.set(isWordCockpitExpanded, forKey: Self.cockpitDefaultsKey)
        }
    }
    @Published var glossLanguageMode: GlossLanguageMode = .english

    /// How the kanji detail screen orders/filters its "Vocabulary & Compounds"
    /// list. Persisted like the cockpit toggle.
    @Published var kanjiRelatedMode: KanjiRelatedDisplayMode = .prevalence {
        didSet {
            UserDefaults.standard.set(kanjiRelatedMode.rawValue, forKey: Self.kanjiRelatedModeKey)
        }
    }

    @Published var activeWordInsights: WordLexicalInsights?

    @Published var activeScreen: ActiveScreenKind = .fisheye
    @Published var history: [NavBreadcrumb] = []
    @Published var historyIndex: Int = -1
    @Published var isZStackOpen: Bool = false
    @Published var zStackFocusedIndex: Int = 0
    @Published var recentKanji: [UInt32] = []

    @Published var activeEntry: EntryDetail?
    @Published var activeKanji: KanjiDetail?

    /// The word the Compound Kanji screen is currently decomposing, kept separate
    /// from `activeEntry` so opening the screen (or searching a word into it) does
    /// not clobber the word-detail view the user just came from.
    @Published var compoundEntry: EntryDetail?
    @Published var compoundInsights: WordLexicalInsights?

    /// A "no word matched" message surfaced under the compound search field when a
    /// typed word (or name) resolves to nothing — so the field never silently
    /// fails. Cleared the moment a decomposition succeeds.
    @Published var compoundSearchNotice: String? = nil

    /// Example compounds seeded from the user's recent-kanji ring: the single most
    /// frequent compound containing each recently inspected kanji, de-duplicated by
    /// compound word. Shown as chips in the compound screen's search row so the
    /// "Try:" row is personalized to what the user has been studying.
    @Published var recentCompoundExamples: [CompoundExample] = []
    @Published var fisheyeNodes: [FisheyeNode] = []
    @Published var overflowPreviewNodes: [FisheyeNode] = []
    @Published var leftOverflowCount: Int = 0
    @Published var rightOverflowCount: Int = 0
    @Published var maxFisheyePerSide: Int = 12 {
        didSet {
            if isBootstrapped {
                UserDefaults.standard.set(maxFisheyePerSide, forKey: Self.maxFisheyePerSideKey)
            }
        }
    }
    @Published var showFisheyePercentages: Bool = true {
        didSet {
            if isBootstrapped {
                UserDefaults.standard.set(showFisheyePercentages, forKey: Self.showFisheyePercentagesKey)
            }
        }
    }
    @Published var fisheyeMode: dj_fisheye_mode_t = DJ_EDGE_COMPOUNDS
    @Published var selectedFisheyeNode: FisheyeNode?
    @Published var hoveredFisheyeNode: FisheyeNode?

    // MARK: - Word Cosmos (randomized prevalence bubble cloud)
    @Published var wordCosmosWords: [WordHit] = []
    @Published var wordCosmosSeed: UInt64 = 0
    @Published var wordCosmosTier: WordCosmosTier = .core {
        didSet {
            if isBootstrapped {
                UserDefaults.standard.set(wordCosmosTier.rawValue, forKey: Self.wordCosmosTierKey)
            }
        }
    }
    @Published var wordCosmosLayout: WordCosmosLayout = .cloud {
        didSet {
            if isBootstrapped {
                UserDefaults.standard.set(wordCosmosLayout.rawValue, forKey: Self.wordCosmosLayoutKey)
            }
        }
    }
    @Published var wordCosmosMode: WordCosmosMode = .cosmos
    @Published var wordCosmosCount: Int = 50 {
        didSet {
            if isBootstrapped {
                UserDefaults.standard.set(wordCosmosCount, forKey: Self.wordCosmosCountKey)
            }
        }
    }
    /// Synchronized with global `includeNames` so the top-bar toggle and Word Cloud never drift apart.
    var wordCosmosIncludeNames: Bool {
        get { includeNames }
        set { setNamesIncluded(newValue, userInitiated: true) }
    }
    /// How cloud bubbles are tinted (prevalence / JLPT / grade). Defaults to JLPT
    /// so difficulty is visible at a glance; the user can switch to the
    /// historical prevalence palette or a grade ramp.
    @Published var wordCosmosColorMode: WordCosmosColorMode = .jlpt {
        didSet {
            if isBootstrapped {
                UserDefaults.standard.set(wordCosmosColorMode.rawValue, forKey: Self.wordCosmosColorModeKey)
            }
        }
    }

    @Published var radicalSelectedIds: [UInt8] = []
    @Published var radicalTargetStrokes: Int = 0
    @Published var radicalStrokeTolerance: Int8 = 0
    @Published var radicalMatches: [UInt32] = []

    @Published var kanjiLookupMode: KanjiLookupMode = .strokes
    @Published var kanjiLookupSort: KanjiSortOrder = .popularity
    @Published var kanjiLookupStrokeCount: Int = 8
    @Published var kanjiLookupStrokeTolerance: Int = 0
    @Published var kanjiLookupLevelFilter: Int = 0
    @Published var kanjiLookupReadingQuery: String = ""
    @Published var kanjiLookupReadingScope: Int = 0
    @Published var kanjiLookupReadingExact: Bool = false
    @Published var kanjiLookupSkipPattern: Int = 1
    @Published var kanjiLookupSkipPart1: Int = 0
    @Published var kanjiLookupSkipPart2: Int = 0
    @Published var kanjiLookupFourCorner: String = ""
    @Published var kanjiLookupGradeFilter: Int = 1
    @Published var kanjiLookupMeaningQuery: String = ""
    @Published var kanjiLookupResults: [KanjiIndexItem] = []

    init(dbPath: String) {
        let d = UserDefaults.standard
        let savedCockpit = d.object(forKey: Self.cockpitDefaultsKey) as? Bool
        self.isWordCockpitExpanded = savedCockpit ?? true
        if let savedMode = d.string(forKey: Self.kanjiRelatedModeKey),
           let mode = KanjiRelatedDisplayMode(rawValue: savedMode) {
            self.kanjiRelatedMode = mode
        }
        if let savedRecall = d.string(forKey: Self.recallModeKey),
           let rMode = RecallMode(rawValue: savedRecall) {
            self.recallMode = rMode
        }
        if let savedNames = d.object(forKey: Self.includeNamesKey) as? Bool {
            self.includeNames = savedNames
        }
        if let savedMaxPerSide = d.object(forKey: Self.maxFisheyePerSideKey) as? Int,
           (4...30).contains(savedMaxPerSide) {
            self.maxFisheyePerSide = savedMaxPerSide
        }
        if let savedShowPct = d.object(forKey: Self.showFisheyePercentagesKey) as? Bool {
            self.showFisheyePercentages = savedShowPct
        }
        if let savedTier = d.string(forKey: Self.wordCosmosTierKey),
           let tier = WordCosmosTier(rawValue: savedTier) {
            self.wordCosmosTier = tier
        }
        if let savedLayout = d.string(forKey: Self.wordCosmosLayoutKey),
           let layout = WordCosmosLayout(rawValue: savedLayout) {
            self.wordCosmosLayout = layout
        }
        if let savedCount = d.object(forKey: Self.wordCosmosCountKey) as? Int,
           (6...300).contains(savedCount) {
            self.wordCosmosCount = savedCount
        }
        if let savedColorMode = d.string(forKey: Self.wordCosmosColorModeKey),
           let colorMode = WordCosmosColorMode(rawValue: savedColorMode) {
            self.wordCosmosColorMode = colorMode
        }

        self.studyStoreCancellable = studyStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        self.handle = dj_engine_create(dbPath)
        self.isBootstrapped = true

        if self.handle != nil {
            if let savedRecent = d.array(forKey: Self.recentKanjiKey) as? [Int], !savedRecent.isEmpty {
                for cp in savedRecent.reversed() where cp > 0 {
                    pushRecentKanji(UInt32(cp))
                }
            } else {
                pushRecentKanji(0x5927) // 大
            }

            let restoredScreen = d.string(forKey: Self.lastScreenKey).flatMap(ActiveScreenKind.init(rawValue:))
            let restoredTarget = UInt32(max(0, d.integer(forKey: Self.lastTargetIdKey)))
            switch restoredScreen {
            case .wordEntry where restoredTarget > 0:
                openWordEntry(entryId: restoredTarget, recordHistory: true)
            case .kanjiDetail where restoredTarget > 0:
                openKanjiDetail(codepoint: restoredTarget, recordHistory: true)
            case .fisheye where restoredTarget > 0:
                openFisheye(codepoint: restoredTarget, recordHistory: true)
            case .compoundKanji:
                openCompoundKanji(seedEntryId: restoredTarget > 0 ? restoredTarget : nil, recordHistory: true)
            case .wordCosmos:
                openWordCosmos(recordHistory: true)
            case .studyLibrary:
                openStudyLibrary(recordHistory: true)
            default:
                let firstCp = recentKanji.first ?? 0x5927
                openFisheye(codepoint: firstCp, recordHistory: true)
            }
            if history.isEmpty {
                openFisheye(codepoint: 0x5927, recordHistory: true)
            }
        }
    }

    deinit {
        if let h = handle {
            dj_engine_destroy(h)
        }
    }

    var isReady: Bool { handle != nil }
    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex + 1 < history.count }

    // MARK: - Clipboard (copy / paste to the system pasteboard)

    /// Copies `text` to the system clipboard. No-op on non-macOS targets.
    func copyText(_ text: String) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
    }

    /// Copies the primary content of the active screen to the clipboard: the
    /// active word entry if one is open, otherwise the active kanji. Returns
    /// what was copied (nil if there is nothing on screen to copy).
    @discardableResult
    func copyActiveEntry() -> String? {
        if let entry = activeEntry {
            copyText(entry.copyText)
            return entry.copyText
        }
        if let kanji = activeKanji {
            copyText(kanji.copyText)
            return kanji.copyText
        }
        return nil
    }

    // MARK: - Study Library, Bookmarks & Anki Export

    func studyItem(for entry: EntryDetail, insights: WordLexicalInsights? = nil) -> StudySavedItem {
        let gloss = entry.senses.prefix(2).map(\.enGlosses).filter { !$0.isEmpty }.joined(separator: " | ")
        var metaParts: [String] = []
        if let jlpt = insights?.telemetry.jlptLabel { metaParts.append(jlpt) }
        if let grade = insights?.telemetry.gradeLabel { metaParts.append(grade) }
        if let tags = insights?.kanjiDNA.map({ "\($0.glyph)(\($0.meanings.split(separator: ";").first ?? ""))" }), !tags.isEmpty {
            metaParts.append(tags.joined(separator: " "))
        }
        let ex = entry.sentences.first ?? insights?.fallbackSentences.first
        return StudySavedItem(
            kind: .word,
            targetId: entry.header.id,
            headword: entry.header.displayHeadword,
            reading: entry.header.kanaHead,
            gloss: gloss.isEmpty ? entry.header.primaryGloss : gloss,
            pitchAccent: entry.header.pitchAccent < 255 ? entry.header.pitchAccent : nil,
            metadata: metaParts.joined(separator: " • "),
            exampleJp: ex?.jpText ?? "",
            exampleEn: ex?.enText ?? ""
        )
    }

    func studyItem(for hit: WordHit) -> StudySavedItem {
        StudySavedItem(
            kind: .word,
            targetId: hit.id,
            headword: hit.displayHeadword,
            reading: hit.kanaHead,
            gloss: hit.primaryGloss,
            pitchAccent: hit.pitchAccent < 255 ? hit.pitchAccent : nil,
            metadata: hit.isName ? "Proper Name" : (hit.freqRank < 999_999 ? "Freq #\(hit.freqRank)" : "")
        )
    }

    func studyItem(for kanji: KanjiDetail) -> StudySavedItem {
        let readings = [kanji.onReadings.joined(separator: ", "), kanji.kunReadings.joined(separator: ", ")]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
        var meta: [String] = []
        if kanji.strokes > 0 { meta.append("\(kanji.strokes) strokes") }
        if kanji.jlpt > 0 { meta.append("N\(kanji.jlpt)") }
        if (1...6).contains(kanji.grade) { meta.append("G\(kanji.grade)") }
        else if kanji.grade == 8 { meta.append("Jōyō") }
        let ex = kanji.standaloneEntries.first?.sentences.first
        return StudySavedItem(
            kind: .kanji,
            targetId: kanji.codepoint,
            headword: kanji.glyph,
            reading: readings,
            gloss: kanji.meanings,
            pitchAccent: nil,
            metadata: meta.joined(separator: " • "),
            exampleJp: ex?.jpText ?? "",
            exampleEn: ex?.enText ?? ""
        )
    }

    func toggleSaveWord(_ entry: EntryDetail, insights: WordLexicalInsights? = nil) {
        studyStore.toggleStar(studyItem(for: entry, insights: insights))
    }

    func toggleSaveWordHit(_ hit: WordHit) {
        if let cached = entryDetailCache[hit.id] {
            studyStore.toggleStar(studyItem(for: cached, insights: wordInsightsCache["\(hit.id)-\(hit.displayHeadword)-\(includeNames)"]))
        } else {
            studyStore.toggleStar(studyItem(for: hit))
        }
    }

    func toggleSaveKanji(_ kanji: KanjiDetail) {
        studyStore.toggleStar(studyItem(for: kanji))
    }

    func toggleSaveCurrentScreen() {
        switch activeScreen {
        case .wordEntry:
            if let entry = activeEntry {
                toggleSaveWord(entry, insights: activeWordInsights)
            }
        case .kanjiDetail, .fisheye:
            if let kanji = activeKanji {
                toggleSaveKanji(kanji)
            }
        default:
            break
        }
    }

    func openStudyLibrary(recordHistory: Bool = true) {
        self.activeScreen = .studyLibrary
        persistLastScreen(.studyLibrary, targetId: 0)
        if recordHistory {
            recordNavigation(NavBreadcrumb(
                kind: .studyLibrary,
                targetId: 0,
                label: "Saved Decks",
                subtitle: "\(studyStore.totalSavedCount) saved items"
            ))
        }
    }

    private func persistLastScreen(_ kind: ActiveScreenKind, targetId: UInt32) {
        guard isBootstrapped else { return }
        UserDefaults.standard.set(kind.rawValue, forKey: Self.lastScreenKey)
        UserDefaults.standard.set(Int(targetId), forKey: Self.lastTargetIdKey)
    }

    // MARK: - Word Cockpit Lexical Insights Builder (<1ms from Indexed Data)

    func ensureWordInsights(for entry: EntryDetail) -> WordLexicalInsights {
        let cacheKey = "\(entry.header.id)-\(entry.header.displayHeadword)-\(includeNames)"
        if let cached = wordInsightsCache[cacheKey] {
            if activeEntry?.header.id == entry.header.id {
                self.activeWordInsights = cached
            }
            return cached
        }

        ensureKanjiCatalogLoaded()
        let insights = buildWordInsights(for: entry)
        wordInsightsCache[cacheKey] = insights
        if activeEntry?.header.id == entry.header.id {
            self.activeWordInsights = insights
        }
        return insights
    }

    private func buildWordInsights(for entry: EntryDetail) -> WordLexicalInsights {
        let headword = entry.header.displayHeadword
        let kana = entry.header.kanaHead

        // 1. Kanji DNA + Telemetry Rollup
        var dnaList: [WordKanjiDNA] = []
        var totalStrokes = 0
        var highestGrade = 0
        var hardestJlpt = 6 // 5 is easiest, 1 is hardest

        var cellIdx = 0
        for cell in entry.rubyCells {
            let cellKanjiScalars = cell.surface.unicodeScalars.filter { isKanjiScalar($0.value) }
            guard !cellKanjiScalars.isEmpty else { continue }

            let isMultiKanjiCell = cellKanjiScalars.count > 1
            let normFuri = KanaNormalizer.cleanReadingToken(cell.furigana)

            for scalar in cellKanjiScalars {
                let cp = scalar.value
                let glyph = String(scalar)
                let meta = cachedKanjiByCodepoint?[cp]
                let strokes = meta?.strokes ?? 0
                totalStrokes += strokes

                if let g = meta?.grade, (1...10).contains(g) {
                    highestGrade = max(highestGrade, g)
                }
                if let j = meta?.jlpt, (1...5).contains(j) {
                    hardestJlpt = min(hardestJlpt, j)
                }

                let onList = meta?.onReadings ?? []
                let kunList = meta?.kunReadings ?? []

                var matchedNorm: String?
                if !isMultiKanjiCell && !normFuri.isEmpty {
                    let candidates = (onList + kunList).map { KanaNormalizer.stemBeforeDot($0) }.filter { !$0.isEmpty }
                    matchedNorm = Self.matchReadingToken(furigana: normFuri, candidates: candidates)
                }

                dnaList.append(WordKanjiDNA(
                    id: cellIdx,
                    codepoint: cp,
                    glyph: glyph,
                    strokes: strokes,
                    gradeLabel: meta?.gradeLabel ?? "",
                    jlptLabel: meta?.jlptLabel ?? "",
                    meanings: meta?.meanings ?? "",
                    onReadings: onList,
                    kunReadings: kunList,
                    matchedReadingNormalized: matchedNorm,
                    // Jukujikun is a *single-kanji* phenomenon: one kanji read with a
                    // meaning-based reading that isn't in its own on/kun set. A multi-kanji
                    // cell (e.g. 日本→にほん, on-readings with 連音) is NOT jukujikun, so
                    // only flag a single-kanji cell whose furigana matched none of its readings.
                    isJukujikun: !isMultiKanjiCell && !normFuri.isEmpty && matchedNorm == nil
                ))
                cellIdx += 1
            }
        }

        let rank = entry.header.freqRank
        let tierInfo: (label: String, ratio: Double, color: Color, rankStr: String) = {
            if entry.header.isName {
                return ("Proper Name", 0.35, Color.purple, rank < 999_999 ? "#\(rank)" : "Name")
            } else if rank <= 500 {
                return ("Core Top 500", 1.0, Color(red: 0.22, green: 0.74, blue: 0.97), "#\(rank)")
            } else if rank <= 2500 {
                return ("Core Top 2,500", 0.84, Color(red: 0.22, green: 0.74, blue: 0.97), "#\(rank)")
            } else if rank <= 10000 {
                return ("Jōyō Common", 0.66, Color(red: 0.20, green: 0.83, blue: 0.60), "#\(rank)")
            } else if rank <= 35000 {
                return ("Standard", 0.45, Color(red: 0.98, green: 0.75, blue: 0.14), "#\(rank)")
            } else if rank < 999_999 {
                return ("Literary", 0.26, Color(red: 0.65, green: 0.55, blue: 0.98), "#\(rank)")
            } else {
                return ("Unranked", 0.16, Color.white.opacity(0.55), "—")
            }
        }()

        let gradeText: String? = {
            switch highestGrade {
            case 1...6: return "Grade \(highestGrade)"
            case 8: return "Secondary Jōyō"
            case 9, 10: return "Jinmeiyō"
            default: return nil
            }
        }()
        let jlptText: String? = (1...5).contains(hardestJlpt) ? "JLPT N\(hardestJlpt)" : nil

        let telemetry = WordTelemetry(
            frequencyTier: tierInfo.label,
            frequencyRankText: tierInfo.rankStr,
            popularityRatio: tierInfo.ratio,
            tierColor: tierInfo.color,
            gradeLabel: gradeText,
            jlptLabel: jlptText,
            totalStrokes: totalStrokes
        )

        // 2. Per-Sense Part-of-Speech / Grammatical Tags
        var senseTags: [UInt32: [String]] = [:]
        for sense in entry.senses {
            // POS / grammatical tags now come from the pure, unit-tested
            // DaiJishowMorph core; the engine adapts its sense/entry into its flat
            // parameters.
            senseTags[sense.id] = Morph.senseTags(
                kana: entry.header.kanaHead,
                posMask: sense.posMask,
                glosses: sense.enGlosses
            )
        }

        // 3. Homonyms (同音異義語) via exact kana match
        var homonyms: [WordHit] = []
        if let h = handle, !kana.isEmpty {
            var exactPtr: UnsafePointer<dj_word_hit_t>?
            let exactCount = kana.withCString { cStr in
                dj_dict_search(h, cStr, DJ_SEARCH_EXACT, includeNames, 48, &exactPtr)
            }
            if let ptr = exactPtr, exactCount > 0 {
                for i in 0..<exactCount {
                    let item = ptr[i]
                    if item.entry_id == entry.header.id { continue }
                    let hitKana = String(cString: item.kana_head)
                    guard hitKana == kana else { continue }
                    homonyms.append(WordHit(
                        id: item.entry_id,
                        kanjiHead: String(cString: item.kanji_head),
                        kanaHead: hitKana,
                        altForms: String(cString: item.alt_forms),
                        primaryGloss: String(cString: item.primary_gloss),
                        posMask: item.pos_mask,
                        pitchAccent: item.pitch_accent,
                        freqRank: item.freq_rank,
                        pairEntryId: item.pair_entry_id,
                        isName: item.is_name
                    ))
                }
            }
            homonyms.sort { a, b in
                if a.isName != b.isName { return !a.isName }
                if a.freqRank != b.freqRank { return a.freqRank < b.freqRank }
                return a.id < b.id
            }
            if homonyms.count > 24 {
                homonyms = Array(homonyms.prefix(24))
            }
        }

        // 4. Word Family (Prefix & Suffix Compounds)
        var prefixList: [WordHit] = []
        var suffixList: [WordHit] = []
        if let h = handle, !headword.isEmpty {
            var candidateMap: [UInt32: WordHit] = [:]

            var autoPtr: UnsafePointer<dj_word_hit_t>?
            let autoCount = headword.withCString { cStr in
                dj_dict_search(h, cStr, DJ_SEARCH_AUTO, includeNames, 180, &autoPtr)
            }
            if let ptr = autoPtr, autoCount > 0 {
                for i in 0..<autoCount {
                    let item = ptr[i]
                    if item.entry_id == entry.header.id { continue }
                    let kHead = String(cString: item.kanji_head)
                    guard !kHead.isEmpty, kHead != headword, kHead.contains(headword) else { continue }
                    candidateMap[item.entry_id] = WordHit(
                        id: item.entry_id,
                        kanjiHead: kHead,
                        kanaHead: String(cString: item.kana_head),
                        altForms: String(cString: item.alt_forms),
                        primaryGloss: String(cString: item.primary_gloss),
                        posMask: item.pos_mask,
                        pitchAccent: item.pitch_accent,
                        freqRank: item.freq_rank,
                        pairEntryId: item.pair_entry_id,
                        isName: item.is_name
                    )
                }
            }

            // For single-kanji entries, also harvest top graph compounds from Fisheye
            if headword.unicodeScalars.count == 1,
               let sc = headword.unicodeScalars.first,
               isKanjiScalar(sc.value) {
                var graphPtr: UnsafePointer<dj_fisheye_node_t>?
                var lOv = 0
                var rOv = 0
                let gCount = dj_graph_solve_fisheye(
                    h, sc.value, DJ_EDGE_COMPOUNDS, includeNames, false, 0, 0, 1.85,
                    24, &lOv, &rOv, &graphPtr
                )
                var topIds: [UInt32] = []
                if let ptr = graphPtr, gCount > 0 {
                    for i in 0..<gCount {
                        let eid = ptr[i].top_entry_id
                        if eid > 0 && eid != entry.header.id && candidateMap[eid] == nil {
                            topIds.append(eid)
                        }
                    }
                }
                for eid in topIds.prefix(32) {
                    var det = dj_entry_detail_t()
                    if dj_dict_get_entry_detail(h, eid, &det) {
                        let hdr = det.header
                        let kHead = String(cString: hdr.kanji_head)
                        if kHead.contains(headword) && kHead != headword {
                            candidateMap[eid] = WordHit(
                                id: hdr.entry_id,
                                kanjiHead: kHead,
                                kanaHead: String(cString: hdr.kana_head),
                                altForms: String(cString: hdr.alt_forms),
                                primaryGloss: String(cString: hdr.primary_gloss),
                                posMask: hdr.pos_mask,
                                pitchAccent: hdr.pitch_accent,
                                freqRank: hdr.freq_rank,
                                pairEntryId: hdr.pair_entry_id,
                                isName: hdr.is_name
                            )
                        }
                    }
                }
            }

            let allFamily = candidateMap.values.sorted { a, b in
                if a.isName != b.isName { return !a.isName }
                if a.freqRank != b.freqRank { return a.freqRank < b.freqRank }
                return a.displayHeadword.count < b.displayHeadword.count
            }

            prefixList = Array(allFamily.filter { $0.displayHeadword.hasPrefix(headword) }.prefix(16))
            suffixList = Array(allFamily.filter { $0.displayHeadword.hasSuffix(headword) && !$0.displayHeadword.hasPrefix(headword) }.prefix(16))
        }

        // 5. Fallback Sentences (if direct entry has 0 sentences) & Corpus Collocations
        var activeSentences = entry.sentences
        var fallbackSource: String? = nil
        var fallbackSourceId: UInt32? = nil

        if activeSentences.isEmpty, let h = handle {
            let relatedPool = (prefixList + suffixList).sorted { $0.freqRank < $1.freqRank }
            for candidate in relatedPool.prefix(4) {
                var det = dj_entry_detail_t()
                if dj_dict_get_entry_detail(h, candidate.id, &det) {
                    let parsed = parseEntryDetail(det)
                    if !parsed.sentences.isEmpty {
                        activeSentences = Array(parsed.sentences.prefix(5))
                        fallbackSource = candidate.displayHeadword
                        fallbackSourceId = candidate.id
                        break
                    }
                }
            }
        }

        let collocations = Self.extractCollocations(
            headword: fallbackSource ?? headword,
            entryId: entry.header.id,
            sentences: activeSentences
        )

        // 6. Conjugation / Inflection Matrix (Verbs & Adjectives)
        // Conjugation matrix now comes from the pure, unit-tested DaiJishowMorph
        // core; the engine adapts its entry into the morpher's flat parameters.
        let (inflections, inflectionHeader) = Morph.inflections(
            surface: entry.header.displayHeadword,
            kana: entry.header.kanaHead,
            posMask: entry.header.posMask
        )

        // 7. Idioms, Yojijukugo, and Proverbs linked to this entry or its kanji
        let idioms = fetchEntryIdioms(entryId: entry.header.id, limit: 10)

        return WordLexicalInsights(
            entryId: entry.header.id,
            telemetry: telemetry,
            senseTags: senseTags,
            kanjiDNA: dnaList,
            homonyms: homonyms,
            prefixCompounds: prefixList,
            suffixCompounds: suffixList,
            collocations: collocations,
            fallbackSentences: entry.sentences.isEmpty ? activeSentences : [],
            fallbackSourceWord: fallbackSource,
            fallbackSourceEntryId: fallbackSourceId,
            inflections: inflections,
            inflectionHeader: inflectionHeader,
            idioms: idioms
        )
    }

    private func parseIdiomList(_ ptr: UnsafePointer<dj_idiom_t>?, count: Int) -> [IdiomItem] {
        guard let ptr, count > 0 else { return [] }
        var out: [IdiomItem] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let raw = ptr[i]
            out.append(IdiomItem(
                entryId: raw.entry_id,
                idiomKind: raw.idiom_kind,
                kanjiHead: String(cString: raw.kanji_head),
                kanaHead: String(cString: raw.kana_head),
                figurativeGloss: String(cString: raw.figurative_gloss),
                anchorLemmas: String(cString: raw.anchor_lemmas)
            ))
        }
        return out
    }

    private func fetchEntryIdioms(entryId: UInt32, limit: Int) -> [IdiomItem] {
        guard let h = handle else { return [] }
        var rawPtr: UnsafePointer<dj_idiom_t>?
        let count = dj_dict_get_entry_idioms(h, entryId, limit, &rawPtr)
        return parseIdiomList(rawPtr, count: count)
    }

    private func fetchKanjiIdioms(codepoint: UInt32, limit: Int) -> [IdiomItem] {
        guard let h = handle else { return [] }
        var rawPtr: UnsafePointer<dj_idiom_t>?
        let count = dj_dict_get_kanji_idioms(h, codepoint, limit, &rawPtr)
        return parseIdiomList(rawPtr, count: count)
    }

    private static func matchReadingToken(furigana: String, candidates: [String]) -> String? {
        if candidates.contains(furigana) { return furigana }
        // Rendaku / voicing & sokuon equivalence check
        let unvoiced = unvoiceInitialKana(furigana)
        for cand in candidates {
            if cand == unvoiced { return cand }
            if furigana.hasSuffix("っ") && cand.dropLast() == furigana.dropLast() {
                return cand
            }
        }
        return nil
    }

    private static func unvoiceInitialKana(_ s: String) -> String {
        guard let first = s.first else { return s }
        let map: [Character: Character] = [
            "が": "か", "ぎ": "き", "ぐ": "く", "げ": "け", "ご": "こ",
            "ざ": "さ", "じ": "し", "ず": "す", "ぜ": "せ", "ぞ": "そ",
            "だ": "た", "ぢ": "ち", "づ": "つ", "で": "て", "ど": "と",
            "ば": "は", "び": "ひ", "ぶ": "ふ", "べ": "へ", "ぼ": "ほ",
            "ぱ": "は", "ぴ": "ひ", "ぷ": "ふ", "ぺ": "へ", "ぽ": "ほ"
        ]
        if let mapped = map[first] {
            return String(mapped) + s.dropFirst()
        }
        return s
    }

    private static func extractCollocations(headword: String, entryId: UInt32, sentences: [SentenceItem]) -> [CollocationPattern] {
        guard !sentences.isEmpty else { return [] }
        let particles: Set<String> = ["が", "を", "に", "へ", "で", "と", "から", "まで", "より", "の", "な", "も", "は"]
        var counts: [String: (role: String, count: Int)] = [:]

        for sent in sentences {
            let segs = sent.segments
            for (idx, seg) in segs.enumerated() {
                let isTarget = (seg.entryId == entryId) || seg.text.contains(headword)
                guard isTarget else { continue }

                if idx > 0 {
                    let prev = segs[idx - 1].text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let lastCh = prev.last, particles.contains(String(lastCh)) {
                        let p = String(lastCh)
                        let key = "〜\(p) \(headword)"
                        let role = (p == "な" || p == "の") ? "Modifier" : "Preceding Particle"
                        counts[key] = (role, (counts[key]?.count ?? 0) + 1)
                    }
                }
                if idx + 1 < segs.count {
                    let next = segs[idx + 1].text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let firstCh = next.first, particles.contains(String(firstCh)) {
                        let p = String(firstCh)
                        let key = "\(headword)\(p)〜"
                        let role = (p == "な" || p == "に") ? "Adjectival / Adverbial" : "Following Particle"
                        counts[key] = (role, (counts[key]?.count ?? 0) + 1)
                    }
                }
            }
        }

        return counts.map { key, val in
            CollocationPattern(id: key, pattern: key, roleLabel: val.role, count: val.count)
        }
        .sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return a.pattern < b.pattern
        }
        .prefix(6)
        .map { $0 }
    }

    // MARK: - Fast In-Memory Kanji Catalog (Lazy-Built from Engine)

    func ensureKanjiCatalogLoaded() {
        if cachedKanjiCatalog != nil { return }
        guard let h = handle else { return }

        var list: [KanjiIndexItem] = []
        list.reserveCapacity(7000)
        var byCp: [UInt32: KanjiIndexItem] = [:]
        byCp.reserveCapacity(7000)

        for cp in UInt32(0x4E00)...UInt32(0x9FFF) {
            var raw = dj_kanji_detail_t()
            guard dj_kanji_get_detail(h, cp, &raw) else { continue }
            let meanings = String(cString: raw.meanings)
            let onRaw = String(cString: raw.on_readings)
            let kunRaw = String(cString: raw.kun_readings)
            let strokes = Int(raw.strokes)
            if strokes == 0 && meanings.isEmpty && onRaw.isEmpty && kunRaw.isEmpty {
                continue
            }

            let onList = onRaw.split(separator: ",").map(String.init)
            let kunList = kunRaw.split(separator: ",").map(String.init)
            let normOn = onList.map { KanaNormalizer.cleanReadingToken($0) }.filter { !$0.isEmpty }
            let normKun = kunList.map { KanaNormalizer.cleanReadingToken($0) }.filter { !$0.isEmpty }

            let (sp, sp1, sp2) = Self.decodeSkipCode(raw.skip_code)
            let fcStr = Self.decodeFourCorner(raw.four_corner)

            let item = KanjiIndexItem(
                codepoint: cp,
                glyph: String(UnicodeScalar(cp)!),
                strokes: strokes,
                grade: Int(raw.grade),
                jlpt: Int(raw.jlpt),
                freqRank: raw.freq_rank,
                radicalId: Int(raw.radical_id),
                skipPattern: sp,
                skipPart1: sp1,
                skipPart2: sp2,
                fourCornerCode: fcStr,
                onReadings: onList,
                kunReadings: kunList,
                normalizedOn: normOn,
                normalizedKun: normKun,
                meanings: meanings,
                meaningsLower: meanings.lowercased()
            )
            list.append(item)
            byCp[cp] = item
        }

        self.cachedKanjiCatalog = list
        self.cachedKanjiByCodepoint = byCp
    }

    func kanjiIndexItem(for codepoint: UInt32) -> KanjiIndexItem? {
        ensureKanjiCatalogLoaded()
        return cachedKanjiByCodepoint?[codepoint]
    }

    private static func decodeSkipCode(_ code: UInt32) -> (Int, Int, Int) {
        guard code > 0 else { return (0, 0, 0) }
        let hiPattern = Int((code >> 16) & 0xFF)
        let hiP1 = Int((code >> 8) & 0xFF)
        let hiP2 = Int(code & 0xFF)
        if (1...4).contains(hiPattern) && (1...35).contains(hiP1) && (1...35).contains(hiP2) {
            return (hiPattern, hiP1, hiP2)
        }
        if code >= 10101 && code <= 49999 {
            let p = Int(code / 10000)
            let p1 = Int((code / 100) % 100)
            let p2 = Int(code % 100)
            if (1...4).contains(p) {
                return (p, p1, p2)
            }
        }
        return (0, 0, 0)
    }

    private static func decodeFourCorner(_ code: UInt32) -> String {
        guard code > 0 else { return "" }
        if code <= 9999 {
            return String(format: "%04d", code)
        }
        if code <= 99999 {
            return String(format: "%04d", code / 10)
        }
        return ""
    }

    // MARK: - Kanji Lookup Execution

    func openKanjiLookup() {
        ensureKanjiCatalogLoaded()
        self.activeScreen = .kanjiLookup
        runKanjiLookup()
        recordNavigation(NavBreadcrumb(
            kind: .kanjiLookup,
            targetId: 0,
            label: "Kanji Index",
            subtitle: "Multi-Mode Kanji Lookup"
        ))
    }

    func runKanjiLookup() {
        ensureKanjiCatalogLoaded()
        guard let catalog = cachedKanjiCatalog else { return }

        var filtered: [KanjiIndexItem] = []

        switch kanjiLookupMode {
        case .strokes:
            let target = kanjiLookupStrokeCount
            let tol = kanjiLookupStrokeTolerance
            filtered = catalog.filter { item in
                guard item.strokes > 0 && abs(item.strokes - target) <= tol else { return false }
                switch kanjiLookupLevelFilter {
                case 1: return item.grade >= 1 && item.grade <= 8
                case 2: return item.grade >= 1 && item.grade <= 6
                case 3: return item.jlpt >= 1 && item.jlpt <= 5
                default: return true
                }
            }

        case .reading:
            let rawQ = kanjiLookupReadingQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if rawQ.isEmpty {
                filtered = catalog.filter { $0.freqRank <= 2500 }
            } else {
                let hiraQ = KanaNormalizer.cleanReadingToken(KanaNormalizer.romajiToHiragana(rawQ))
                filtered = catalog.filter { item in
                    let pool: [String]
                    switch kanjiLookupReadingScope {
                    case 1: pool = item.normalizedOn
                    case 2: pool = item.normalizedKun
                    default: pool = item.normalizedOn + item.normalizedKun
                    }
                    if kanjiLookupReadingExact {
                        return pool.contains(hiraQ)
                    } else {
                        return pool.contains { $0.hasPrefix(hiraQ) }
                    }
                }
            }

        case .skip:
            filtered = catalog.filter { item in
                guard item.skipPattern == kanjiLookupSkipPattern else { return false }
                if kanjiLookupSkipPart1 > 0 && item.skipPart1 != kanjiLookupSkipPart1 { return false }
                if kanjiLookupSkipPart2 > 0 && item.skipPart2 != kanjiLookupSkipPart2 { return false }
                return true
            }

        case .fourCorner:
            let digits = kanjiLookupFourCorner.filter(\.isNumber)
            if digits.isEmpty {
                filtered = catalog.filter { !$0.fourCornerCode.isEmpty && $0.freqRank <= 2500 }
            } else {
                let prefix = String(digits.prefix(4))
                filtered = catalog.filter { !$0.fourCornerCode.isEmpty && $0.fourCornerCode.hasPrefix(prefix) }
            }

        case .gradeJlpt:
            let g = kanjiLookupGradeFilter
            if g > 0 {
                filtered = catalog.filter { $0.grade == g }
            } else if g < 0 {
                let targetJlpt = -g
                filtered = catalog.filter { $0.jlpt == targetJlpt }
            } else {
                filtered = catalog
            }

        case .meaning:
            let q = kanjiLookupMeaningQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty {
                filtered = catalog.filter { $0.freqRank <= 2500 }
            } else {
                filtered = catalog.filter { item in
                    item.meaningsLower.contains(q)
                }
            }
        }

        filtered.sort { a, b in
            switch kanjiLookupSort {
            case .popularity:
                if a.freqRank != b.freqRank { return a.freqRank < b.freqRank }
                if a.strokes != b.strokes { return a.strokes < b.strokes }
                return a.codepoint < b.codepoint

            case .grade:
                let ga = (1...10).contains(a.grade) ? a.grade : 99
                let gb = (1...10).contains(b.grade) ? b.grade : 99
                if ga != gb { return ga < gb }
                if a.freqRank != b.freqRank { return a.freqRank < b.freqRank }
                return a.strokes < b.strokes

            case .jlpt:
                let ja = (1...5).contains(a.jlpt) ? (6 - a.jlpt) : 99
                let jb = (1...5).contains(b.jlpt) ? (6 - b.jlpt) : 99
                if ja != jb { return ja < jb }
                if a.freqRank != b.freqRank { return a.freqRank < b.freqRank }
                return a.strokes < b.strokes

            case .strokes:
                if a.strokes != b.strokes { return a.strokes < b.strokes }
                if a.freqRank != b.freqRank { return a.freqRank < b.freqRank }
                return a.codepoint < b.codepoint

            case .radical:
                let ra = (1...214).contains(a.radicalId) ? a.radicalId : 999
                let rb = (1...214).contains(b.radicalId) ? b.radicalId : 999
                if ra != rb { return ra < rb }
                if a.strokes != b.strokes { return a.strokes < b.strokes }
                return a.freqRank < b.freqRank
            }
        }

        self.kanjiLookupResults = Array(filtered.prefix(360))
        if historyIndex >= 0 && historyIndex < history.count && history[historyIndex].kind == .kanjiLookup {
            captureCurrentSnapshot(for: history[historyIndex])
        }
    }

    // MARK: - History Snapshots & Navigation

    private func captureCurrentSnapshot(for item: NavBreadcrumb) {
        switch item.kind {
        case .wordEntry:
            if let entry = activeEntry, entry.header.id == item.targetId {
                historySnapshots[item.id] = .wordEntry(entry)
            }
        case .kanjiDetail:
            if let k = activeKanji, k.codepoint == item.targetId {
                historySnapshots[item.id] = .kanjiDetail(k)
            }
        case .fisheye:
            if let k = activeKanji, k.codepoint == item.targetId {
                historySnapshots[item.id] = .fisheye(
                    kanji: k,
                    nodes: fisheyeNodes,
                    leftOverflow: leftOverflowCount,
                    rightOverflow: rightOverflowCount
                )
            }
        case .radicalBuilder:
            historySnapshots[item.id] = .radicalBuilder(
                selectedIds: radicalSelectedIds,
                targetStrokes: radicalTargetStrokes,
                matches: radicalMatches
            )
        case .kanjiLookup:
            historySnapshots[item.id] = .kanjiLookup(
                mode: kanjiLookupMode,
                strokeCount: kanjiLookupStrokeCount,
                sortOrder: kanjiLookupSort,
                results: kanjiLookupResults
            )
        case .wordCosmos:
            historySnapshots[item.id] = .wordCosmos(
                words: wordCosmosWords,
                tier: wordCosmosTier,
                layout: wordCosmosLayout,
                colorMode: wordCosmosColorMode
            )
        case .compoundKanji:
            // The screen's state is which word it is decomposing; record it so a
            // breadcrumb can restore the same decomposition.
            if let id = compoundEntry?.header.id {
                historySnapshots[item.id] = .compoundWord(entryId: id)
            }
        case .studyLibrary:
            historySnapshots[item.id] = .studyLibrary(
                deckCount: studyStore.decks.count,
                itemCount: studyStore.totalSavedCount
            )
        }
    }

    func snapshot(for item: NavBreadcrumb) -> HistorySnapshot? {
        historySnapshots[item.id]
    }

    func invalidateFisheyeSnapshots() {
        wordInsightsCache.removeAll()
        entryDetailCache.removeAll()
        if let entry = activeEntry {
            _ = ensureWordInsights(for: entry)
        }
        for item in history where item.kind == .fisheye || item.kind == .kanjiDetail {
            historySnapshots.removeValue(forKey: item.id)
        }
    }

    func openHistoryStack() {
        guard !history.isEmpty else {
            isZStackOpen = true
            return
        }
        if historyIndex >= 0 && historyIndex < history.count {
            captureCurrentSnapshot(for: history[historyIndex])
        }
        zStackFocusedIndex = min(max(0, historyIndex), history.count - 1)
        let start = max(0, zStackFocusedIndex - 4)
        let end = min(history.count - 1, zStackFocusedIndex + 4)
        for idx in start...end {
            ensureHistorySnapshot(at: idx)
        }
        isZStackOpen = true
    }

    func stepZStack(by delta: Int) {
        guard !history.isEmpty else { return }
        let next = min(max(0, zStackFocusedIndex + delta), history.count - 1)
        guard next != zStackFocusedIndex else { return }
        zStackFocusedIndex = next
        ensureHistorySnapshot(at: next)
        if next - 1 >= 0 { ensureHistorySnapshot(at: next - 1) }
        if next + 1 < history.count { ensureHistorySnapshot(at: next + 1) }
    }

    func ensureHistorySnapshot(at index: Int) {
        guard index >= 0 && index < history.count else { return }
        let item = history[index]
        if historySnapshots[item.id] != nil { return }
        guard let h = handle else { return }

        switch item.kind {
        case .wordEntry:
            var raw = dj_entry_detail_t()
            if dj_dict_get_entry_detail(h, item.targetId, &raw) {
                historySnapshots[item.id] = .wordEntry(parseEntryDetail(raw))
            }
        case .kanjiDetail:
            if let k = fetchKanjiDetail(codepoint: item.targetId, includeLexicalLists: true) {
                historySnapshots[item.id] = .kanjiDetail(k)
            }
        case .fisheye:
            if let k = fetchKanjiDetail(codepoint: item.targetId, includeLexicalLists: false) {
                var rawPtr: UnsafePointer<dj_fisheye_node_t>?
                var leftOv = 0
                var rightOv = 0
                let count = dj_graph_solve_fisheye(
                    h, item.targetId, fisheyeMode, includeNames, false, 0, 0, 1.85,
                    maxFisheyePerSide, &leftOv, &rightOv, &rawPtr
                )
                var mainList: [FisheyeNode] = []
                if let ptr = rawPtr, count > 0 {
                    for i in 0..<count {
                        let node = makeFisheyeNode(from: ptr[i])
                        if !node.isOverflowPreview {
                            mainList.append(node)
                        }
                    }
                }
                historySnapshots[item.id] = .fisheye(
                    kanji: k,
                    nodes: mainList,
                    leftOverflow: leftOv,
                    rightOverflow: rightOv
                )
            }
        case .radicalBuilder:
            historySnapshots[item.id] = .radicalBuilder(
                selectedIds: radicalSelectedIds,
                targetStrokes: radicalTargetStrokes,
                matches: radicalMatches
            )
        case .kanjiLookup:
            historySnapshots[item.id] = .kanjiLookup(
                mode: kanjiLookupMode,
                strokeCount: kanjiLookupStrokeCount,
                sortOrder: kanjiLookupSort,
                results: kanjiLookupResults
            )
        case .wordCosmos:
            historySnapshots[item.id] = .wordCosmos(
                words: wordCosmosWords,
                tier: wordCosmosTier,
                layout: wordCosmosLayout,
                colorMode: wordCosmosColorMode
            )
        case .compoundKanji:
            if let id = compoundEntry?.header.id {
                historySnapshots[item.id] = .compoundWord(entryId: id)
            }
        case .studyLibrary:
            historySnapshots[item.id] = .studyLibrary(
                deckCount: studyStore.decks.count,
                itemCount: studyStore.totalSavedCount
            )
        }
    }

    private func recordNavigation(_ item: NavBreadcrumb) {
        persistLastScreen(item.kind, targetId: item.targetId)
        if historyIndex >= 0 && historyIndex < history.count {
            let current = history[historyIndex]
            if current.kind == item.kind && current.targetId == item.targetId {
                if current.subtitle != item.subtitle {
                    historySnapshots.removeValue(forKey: current.id)
                    history[historyIndex] = item
                }
                captureCurrentSnapshot(for: history[historyIndex])
                return
            }
            if historyIndex + 1 < history.count {
                let dropped = history[(historyIndex + 1)..<history.count]
                for d in dropped {
                    historySnapshots.removeValue(forKey: d.id)
                }
                history.removeSubrange((historyIndex + 1)..<history.count)
            }
        }
        history.append(item)
        captureCurrentSnapshot(for: item)
        if history.count > 24 {
            let removed = history.removeFirst()
            historySnapshots.removeValue(forKey: removed.id)
        }
        historyIndex = history.count - 1
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        restoreBreadcrumb(history[historyIndex])
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        restoreBreadcrumb(history[historyIndex])
    }

    func jumpToHistory(index: Int) {
        guard index >= 0 && index < history.count else { return }
        historyIndex = index
        isZStackOpen = false
        restoreBreadcrumb(history[index])
    }

    private func restoreBreadcrumb(_ item: NavBreadcrumb) {
        persistLastScreen(item.kind, targetId: item.targetId)
        switch item.kind {
        case .fisheye:
            openFisheye(codepoint: item.targetId, recordHistory: false)
        case .wordEntry:
            openWordEntry(entryId: item.targetId, recordHistory: false)
        case .kanjiDetail:
            openKanjiDetail(codepoint: item.targetId, recordHistory: false)
        case .radicalBuilder:
            if case .radicalBuilder(let sel, let strokes, let matches) = historySnapshots[item.id] {
                self.radicalSelectedIds = sel
                self.radicalTargetStrokes = strokes
                self.radicalMatches = matches
            }
            activeScreen = .radicalBuilder
        case .kanjiLookup:
            if case .kanjiLookup(let mode, let strokes, let sort, let results) = historySnapshots[item.id] {
                self.kanjiLookupMode = mode
                self.kanjiLookupStrokeCount = strokes
                self.kanjiLookupSort = sort
                self.kanjiLookupResults = results
            }
            activeScreen = .kanjiLookup
        case .wordCosmos:
            if case .wordCosmos(let words, let tier, let layout, let colorMode) = historySnapshots[item.id], !words.isEmpty {
                self.wordCosmosTier = tier
                self.wordCosmosLayout = layout
                self.wordCosmosColorMode = colorMode
                self.wordCosmosWords = words
                activeScreen = .wordCosmos
            } else {
                openWordCosmos(recordHistory: false)
            }
        case .compoundKanji:
            // Restore to the same decomposition: prefer the snapshot's entryId, fall
            // back to the breadcrumb's target, else the empty (example) state.
            let seed: UInt32?
            if case .compoundWord(let id) = historySnapshots[item.id] {
                seed = id
            } else {
                seed = (item.targetId == 0 ? nil : item.targetId)
            }
            openCompoundKanji(seedEntryId: seed, recordHistory: false)
        case .studyLibrary:
            openStudyLibrary(recordHistory: false)
        }
    }

    // MARK: - Dictionary Search & Entry Navigation

    func performSearch() {
        searchDebounceTask?.cancel()
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = []
            englishMatches = []
            return
        }

        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(75))
            guard !Task.isCancelled, let self else { return }
            self.executeSearchNow(trimmed: trimmed)
        }
    }

    private func executeSearchNow(trimmed: String) {
        guard let h = handle else { return }

        // A *new* query (different from the one that raised the current nudge)
        // supersedes a stale "hidden proper name" nudge. The auto-enable's re-search
        // of the *same* query must **not** clear it, or the banner would vanish the
        // instant Names flips on.
        if trimmed != nudgeSourceQuery {
            nameNudgeDismissal?.cancel()
            nameNudge = nil
        }

        if trimmed.unicodeScalars.count == 1, let scalar = trimmed.unicodeScalars.first, isKanjiScalar(scalar.value) {
            pushRecentKanji(scalar.value)
        }

        var rawPtr: UnsafePointer<dj_word_hit_t>?
        let mode: dj_search_mode_t = searchContainsMode ? DJ_SEARCH_ANY : DJ_SEARCH_AUTO
        let count = trimmed.withCString { cStr in
            dj_dict_search(h, cStr, mode, includeNames, 40, &rawPtr)
        }

        var hits: [WordHit] = []
        if let ptr = rawPtr, count > 0 {
            hits.reserveCapacity(count)
            for i in 0..<count {
                let item = ptr[i]
                hits.append(WordHit(
                    id: item.entry_id,
                    kanjiHead: String(cString: item.kanji_head),
                    kanaHead: String(cString: item.kana_head),
                    altForms: String(cString: item.alt_forms),
                    primaryGloss: String(cString: item.primary_gloss),
                    posMask: item.pos_mask,
                    pitchAccent: item.pitch_accent,
                    freqRank: item.freq_rank,
                    pairEntryId: item.pair_entry_id,
                    isName: item.is_name
                ))
            }
        }
        self.searchResults = hits

        // With Names off, peek at what Names-on would return and, if its #1 hit is a
        // proper name the names-off view is hiding, surface a nudge. Runs *before*
        // the English-gloss search below so that call cannot invalidate the engine
        // arena holding the nudge's hit (already copied out into a Swift WordHit).
        if !includeNames {
            checkHiddenProperName(for: trimmed, handle: h)
        }

        self.englishMatches = fetchEnglishMatches(for: trimmed, exclude: Set(hits.map { $0.id }))
    }

    /// Run the English-gloss FTS index against a romaji-looking query and return
    /// the top matches not already present in `exclude` (the main result set).
    /// Returns `[]` for kanji/kana queries, so the "Also in English glosses"
    /// section stays clean and never appears for a Japanese search.
    private func fetchEnglishMatches(for trimmed: String, exclude: Set<UInt32>) -> [WordHit] {
        guard let h = handle else { return [] }
        // Only ASCII-letter (romaji-looking) queries can name an English word; a
        // floor of 2 letters keeps single-character queries from fanning out the
        // FTS index into noise.
        guard trimmed.count >= 2 else { return [] }
        guard trimmed.unicodeScalars.allSatisfy({ $0.value >= 65 && $0.value <= 122 }) else { return [] }

        var rawPtr: UnsafePointer<dj_word_hit_t>?
        let count = trimmed.withCString { cStr in
            dj_dict_search(h, cStr, DJ_SEARCH_ENGLISH, includeNames, 8, &rawPtr)
        }
        guard let ptr = rawPtr, count > 0 else { return [] }

        var out: [WordHit] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let hit = Self.wordHit(from: ptr[i])
            if !exclude.contains(hit.id) {
                out.append(hit)
            }
        }
        return out
    }

    func moveSearchSelection(by delta: Int) {
        let filtered = filteredSearchResults
        let total = filtered.count + (searchFilters.isEmpty ? englishMatches.count : 0)
        guard total > 0 else {
            selectedSearchIndex = 0
            return
        }
        selectedSearchIndex = max(0, min(total - 1, selectedSearchIndex + delta))
    }

    func submitSearchQuery() {
        searchDebounceTask?.cancel()
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if searchResults.isEmpty && !trimmed.isEmpty {
            executeSearchNow(trimmed: trimmed)
        }
        let filtered = filteredSearchResults
        let combined = filtered + (searchFilters.isEmpty ? englishMatches : [])
        guard !combined.isEmpty else { return }
        let idx = (0..<combined.count).contains(selectedSearchIndex) ? selectedSearchIndex : 0
        openWordEntry(entryId: combined[idx].id)
        searchResults = []
        englishMatches = []
    }

    func openVariantForm(_ variant: String) {
        guard let h = handle else { return }
        var rawPtr: UnsafePointer<dj_word_hit_t>?
        let count = variant.withCString { cStr in
            dj_dict_search(h, cStr, DJ_SEARCH_EXACT, true, 5, &rawPtr)
        }
        if let ptr = rawPtr, count > 0 {
            for i in 0..<count {
                let eid = ptr[i].entry_id
                if eid != activeEntry?.header.id {
                    openWordEntry(entryId: eid)
                    return
                }
            }
        }
        if let cur = activeEntry {
            var newAlts = cur.header.variantList.filter { $0 != variant }
            if !cur.header.kanjiHead.isEmpty && cur.header.kanjiHead != variant {
                newAlts.insert(cur.header.kanjiHead, at: 0)
            }
            let promotedHeader = WordHit(
                id: cur.header.id,
                kanjiHead: variant,
                kanaHead: cur.header.kanaHead,
                altForms: newAlts.joined(separator: "; "),
                primaryGloss: cur.header.primaryGloss,
                posMask: cur.header.posMask,
                pitchAccent: cur.header.pitchAccent,
                freqRank: cur.header.freqRank,
                pairEntryId: cur.header.pairEntryId,
                isName: cur.header.isName
            )
            let newCells = variant.unicodeScalars.enumerated().map { idx, sc in
                RubyCell(id: idx, surface: String(sc), furigana: "", kanjiCodepoint: isKanjiScalar(sc.value) ? sc.value : 0)
            }
            let updated = EntryDetail(
                header: promotedHeader,
                pairedKanji: cur.pairedKanji,
                pairedKana: cur.pairedKana,
                rubyCells: newCells.isEmpty ? cur.rubyCells : newCells,
                senses: cur.senses,
                sentences: cur.sentences
            )
            self.activeEntry = updated
            _ = ensureWordInsights(for: updated)
            recordNavigation(NavBreadcrumb(kind: .wordEntry, targetId: cur.header.id, label: variant, subtitle: cur.header.primaryGloss))
        }
    }

    private func parseEntryDetail(_ raw: dj_entry_detail_t) -> EntryDetail {
        let header = WordHit(
            id: raw.header.entry_id,
            kanjiHead: String(cString: raw.header.kanji_head),
            kanaHead: String(cString: raw.header.kana_head),
            altForms: String(cString: raw.header.alt_forms),
            primaryGloss: String(cString: raw.header.primary_gloss),
            posMask: raw.header.pos_mask,
            pitchAccent: raw.header.pitch_accent,
            freqRank: raw.header.freq_rank,
            pairEntryId: raw.header.pair_entry_id,
            isName: raw.header.is_name
        )

        var rubyCells: [RubyCell] = []
        if let rPtr = raw.ruby_cells {
            for i in 0..<raw.ruby_cell_count {
                let c = rPtr[i]
                rubyCells.append(RubyCell(
                    id: i,
                    surface: String(cString: c.surface),
                    furigana: String(cString: c.furigana),
                    kanjiCodepoint: c.kanji_cp
                ))
            }
        }

        var senses: [SenseItem] = []
        if let sPtr = raw.senses {
            for i in 0..<raw.sense_count {
                let s = sPtr[i]
                senses.append(SenseItem(
                    id: s.sense_idx,
                    posMask: s.pos_mask,
                    enGlosses: String(cString: s.en_glosses),
                    jaGlosses: String(cString: s.ja_glosses)
                ))
            }
        }

        var sentences: [SentenceItem] = []
        if let sentPtr = raw.sentences {
            for i in 0..<raw.sentence_count {
                let st = sentPtr[i]
                let jp = String(cString: st.jp_text)
                let en = String(cString: st.en_text)
                let nsJp = jp as NSString

                var segments: [SentenceSegment] = []
                var cursor = 0
                var segIdx = 0

                if let tokPtr = st.tokens, st.token_count > 0 {
                    for t in 0..<st.token_count {
                        let tok = tokPtr[t]
                        let off = Int(tok.utf16_offset)
                        let len = Int(tok.utf16_length)
                        guard off >= cursor, off + len <= nsJp.length else { continue }

                        if off > cursor {
                            let plain = nsJp.substring(with: NSRange(location: cursor, length: off - cursor))
                            segments.append(SentenceSegment(id: segIdx, text: plain, furigana: nil, entryId: nil))
                            segIdx += 1
                        }
                        let surface = nsJp.substring(with: NSRange(location: off, length: len))
                        let kana = String(cString: tok.kana_reading)
                        segments.append(SentenceSegment(
                            id: segIdx,
                            text: surface,
                            furigana: (kana.isEmpty || kana == surface) ? nil : kana,
                            entryId: tok.entry_id
                        ))
                        segIdx += 1
                        cursor = off + len
                    }
                }
                if cursor < nsJp.length {
                    let tail = nsJp.substring(with: NSRange(location: cursor, length: nsJp.length - cursor))
                    segments.append(SentenceSegment(id: segIdx, text: tail, furigana: nil, entryId: nil))
                }

                sentences.append(SentenceItem(id: st.sent_id, jpText: jp, enText: en, segments: segments))
            }
        }

        return EntryDetail(
            header: header,
            pairedKanji: String(cString: raw.paired_kanji),
            pairedKana: String(cString: raw.paired_kana),
            rubyCells: rubyCells,
            senses: senses,
            sentences: sentences
        )
    }

    /// Resolve an `EntryDetail` for `entryId`, memoised in `entryDetailCache`.
    /// Shared by the word-detail, compound-kanji, and Z-Stack snapshot views.
    func fetchEntryDetail(_ entryId: UInt32) -> EntryDetail? {
        if let cached = entryDetailCache[entryId] {
            return cached
        }
        guard let h = handle else { return nil }
        var raw = dj_entry_detail_t()
        guard dj_dict_get_entry_detail(h, entryId, &raw) else { return nil }
        let detail = parseEntryDetail(raw)
        entryDetailCache[entryId] = detail
        return detail
    }

    func openWordEntry(entryId: UInt32, recordHistory: Bool = true) {
        guard let detail = fetchEntryDetail(entryId) else { return }
        self.activeEntry = detail
        if !detail.hasJapaneseGlosses && glossLanguageMode != .english {
            self.glossLanguageMode = .english
        }
        _ = ensureWordInsights(for: detail)
        self.activeScreen = .wordEntry

        for scalar in detail.header.displayHeadword.unicodeScalars where isKanjiScalar(scalar.value) {
            pushRecentKanji(scalar.value)
        }

        if recordHistory {
            recordNavigation(NavBreadcrumb(
                kind: .wordEntry,
                targetId: entryId,
                label: detail.header.displayHeadword,
                subtitle: detail.header.primaryGloss
            ))
        }
    }

    // MARK: - Compound Kanji screen

    /// Open the Compound Kanji screen, decomposing a word into its per-kanji parts.
    ///
    /// The target word is resolved in this order:
    ///   1. an explicit `seedEntryId` (e.g. the "Open compound breakdown" button on
    ///      a word-detail's Kanji DNA strip), or
    ///   2. the currently open word, when it is itself a multi-kanji word, or
    ///   3. a sensible built-in default compound.
    ///
    /// If nothing resolves, the screen still opens to its empty state (a word search
    /// plus example chips), so the top-bar entry point always navigates somewhere.
    func openCompoundKanji(seedEntryId: UInt32? = nil, recordHistory: Bool = true) {
        ensureKanjiCatalogLoaded()

        var entryId = seedEntryId
        if entryId == nil,
           let active = activeEntry,
           active.header.displayHeadword.unicodeScalars.filter({ isKanjiScalar($0.value) }).count >= 2 {
            entryId = active.header.id
        }
        if entryId == nil {
            entryId = Self.defaultCompoundEntryId(handle: handle)
        }

        guard let id = entryId, let detail = fetchEntryDetail(id) else {
            self.compoundEntry = nil
            self.compoundInsights = nil
            self.recentCompoundExamples = buildRecentCompoundExamples()
            self.activeScreen = .compoundKanji
            return
        }

        for scalar in detail.header.displayHeadword.unicodeScalars where isKanjiScalar(scalar.value) {
            pushRecentKanji(scalar.value)
        }
        self.compoundEntry = detail
        self.compoundInsights = ensureWordInsights(for: detail)
        self.compoundSearchNotice = nil
        self.recentCompoundExamples = buildRecentCompoundExamples()
        self.activeScreen = .compoundKanji

        if recordHistory {
            recordNavigation(NavBreadcrumb(
                kind: .compoundKanji,
                targetId: id,
                label: detail.header.displayHeadword,
                subtitle: "Compound Kanji"
            ))
        }
    }

    /// Resolve a typed word to its entry and decompose it on the compound screen,
    /// preferring a multi-kanji exact hit so a kana query lands on the kanji form.
    ///
    /// Name-resilient, mirroring the main omni-search: a typed word may be a proper
    /// name, which the exact search skips unless "Names" is on. So we try with the
    /// user's current preference first, then retry with names forced on, and only if
    /// both come up empty do we surface a "no compound found" notice rather than
    /// silently dropping the word.
    func decomposeWordQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let h = handle else { return }

        let modes: [(dj_search_mode_t, Bool)] = [
            (DJ_SEARCH_EXACT, includeNames),
            (DJ_SEARCH_EXACT, true),
            (DJ_SEARCH_AUTO, includeNames),
            (DJ_SEARCH_AUTO, true),
            (DJ_SEARCH_ENGLISH, includeNames)
        ]

        var matchedHits: [WordHit] = []
        for (mode, allowNames) in modes {
            var rawPtr: UnsafePointer<dj_word_hit_t>?
            let count = trimmed.withCString { cStr in
                dj_dict_search(h, cStr, mode, allowNames, 12, &rawPtr)
            }
            if let ptr = rawPtr, count > 0 {
                var hits: [WordHit] = []
                hits.reserveCapacity(count)
                for i in 0..<count {
                    hits.append(Self.wordHit(from: ptr[i]))
                }
                if hits.contains(where: { $0.kanjiHead.unicodeScalars.filter({ isKanjiScalar($0.value) }).count >= 2 }) {
                    matchedHits = hits
                    break
                } else if matchedHits.isEmpty {
                    matchedHits = hits
                }
            }
        }

        guard !matchedHits.isEmpty else {
            // Nothing matched across exact, auto (romaji/kana prefix), or English FTS:
            // clear any stale decomposition and inform the user cleanly.
            self.compoundEntry = nil
            self.compoundInsights = nil
            self.compoundSearchNotice = "No compound found for “\(trimmed)”. Try a kanji, kana, romaji, or English term."
            self.recentCompoundExamples = buildRecentCompoundExamples()
            self.activeScreen = .compoundKanji
            return
        }

        var resolvedId: UInt32?
        for hit in matchedHits {
            let kanjiCount = hit.kanjiHead.unicodeScalars.filter { isKanjiScalar($0.value) }.count
            if kanjiCount >= 2 { resolvedId = hit.id; break }
        }
        if resolvedId == nil {
            resolvedId = matchedHits.first?.id
        }
        if let id = resolvedId {
            openCompoundKanji(seedEntryId: id, recordHistory: true)
        }
    }

    /// A curated fallback word for the compound screen when the user opens it with no
    /// current word: a few canonical two-kanji compounds, first one that resolves.
    private static func defaultCompoundEntryId(handle: OpaquePointer?) -> UInt32? {
        guard let h = handle else { return nil }
        for head in ["漢字", "日本語", "勉強", "日本", "言葉"] {
            var rawPtr: UnsafePointer<dj_word_hit_t>?
            let count = head.withCString { cStr in
                dj_dict_search(h, cStr, DJ_SEARCH_EXACT, true, 5, &rawPtr)
            }
            if let ptr = rawPtr, count > 0 {
                return ptr[0].entry_id
            }
        }
        return nil
    }

    /// The single most frequent compound containing `cp`, read off both sides of the
    /// kanji graph as a `CompoundExample` chip. `maxPerSide` of 1 yields at most one
    /// bubble per side; we pick the higher-share of the two so the example is the
    /// kanji's top compound overall. Returns nil when the kanji has no compounds in
    /// the corpus (so the caller can skip it and try the next recent kanji).
    private func topCompoundForKanji(_ cp: UInt32) -> CompoundExample? {
        guard let h = handle else { return nil }
        var rawPtr: UnsafePointer<dj_fisheye_node_t>?
        var leftOv = 0
        var rightOv = 0
        let count = dj_graph_solve_fisheye(
            h, cp, DJ_EDGE_COMPOUNDS, includeNames, false, 0, 0, 1.85,
            1, &leftOv, &rightOv, &rawPtr
        )
        guard let ptr = rawPtr, count > 0 else { return nil }
        var best: dj_fisheye_node_t?
        var bestShare: Float = -1.0
        for i in 0..<count {
            let node = ptr[i]
            if node.is_overflow_preview != 0 { continue }
            if node.share_pct > bestShare {
                bestShare = node.share_pct
                best = node
            }
        }
        guard let n = best else { return nil }
        let word = String(cString: n.compound_word)
        guard !word.isEmpty else { return nil }
        let kana = String(cString: n.compound_kana)
        let seedGlyph = UnicodeScalar(cp).map { String($0) } ?? "?"
        return CompoundExample(
            entryId: n.top_entry_id,
            word: word,
            kana: kana,
            seedGlyph: seedGlyph
        )
    }

    /// Build the "Try:" example chips for the compound screen from the recent-kanji
    /// ring: for each recently inspected kanji, its top compound, de-duplicated by
    /// compound word and capped so the row stays tidy.
    private func buildRecentCompoundExamples() -> [CompoundExample] {
        var out: [CompoundExample] = []
        var seen = Set<String>()
        for cp in recentKanji {
            if let ex = topCompoundForKanji(cp), seen.insert(ex.word).inserted {
                out.append(ex)
            }
            if out.count >= 4 { break }
        }
        return out
    }

    func openKanjiDetail(codepoint: UInt32, recordHistory: Bool = true) {
        guard let detail = fetchKanjiDetail(codepoint: codepoint, includeLexicalLists: true) else { return }
        self.activeKanji = detail
        pushRecentKanji(codepoint)
        self.activeScreen = .kanjiDetail
        if recordHistory, let sc = UnicodeScalar(codepoint) {
            let sub = detail.meanings.isEmpty
                ? (detail.standaloneEntries.first?.header.primaryGloss ?? detail.unicodeBlockLabel)
                : detail.meanings
            recordNavigation(NavBreadcrumb(
                kind: .kanjiDetail,
                targetId: codepoint,
                label: "\(String(sc)) (Kanji)",
                subtitle: sub
            ))
        }
    }

    func refreshActiveKanjiDetail() {
        guard activeScreen == .kanjiDetail, let cp = activeKanji?.codepoint else { return }
        if let detail = fetchKanjiDetail(codepoint: cp, includeLexicalLists: true) {
            self.activeKanji = detail
            if historyIndex >= 0 && historyIndex < history.count && history[historyIndex].kind == .kanjiDetail {
                captureCurrentSnapshot(for: history[historyIndex])
            }
        }
    }

    func openFisheye(codepoint: UInt32, recordHistory: Bool = true) {
        if let detail = fetchKanjiDetail(codepoint: codepoint, includeLexicalLists: false) {
            self.activeKanji = detail
        }
        self.selectedFisheyeNode = nil
        self.hoveredFisheyeNode = nil
        self.activeScreen = .fisheye
        solveFisheye(center: codepoint, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: 1.85, animated: false)
        pushRecentKanji(codepoint)

        if recordHistory, let sc = UnicodeScalar(codepoint) {
            recordNavigation(NavBreadcrumb(
                kind: .fisheye,
                targetId: codepoint,
                label: String(sc),
                subtitle: activeKanji?.meanings.isEmpty == false ? (activeKanji?.meanings ?? "Compound Explorer") : "Compound Explorer"
            ))
        }
    }

    // MARK: - Word Cosmos (Randomized Prevalence Bubble Cloud)

    /// Map one raw C ABI hit into a Swift `WordHit`, copying every string out of
    /// the engine arena before the next call invalidates it.
    static func wordHit(from abi: dj_word_hit_t) -> WordHit {
        WordHit(
            id: abi.entry_id,
            kanjiHead: String(cString: abi.kanji_head),
            kanaHead: String(cString: abi.kana_head),
            altForms: String(cString: abi.alt_forms),
            primaryGloss: String(cString: abi.primary_gloss),
            posMask: abi.pos_mask,
            pitchAccent: abi.pitch_accent,
            freqRank: abi.freq_rank,
            pairEntryId: abi.pair_entry_id,
            isName: abi.is_name
        )
    }

    /// Draw a fresh randomized sample of words bounded by a prevalence-tier
    /// ceiling. Replaces the current sample and rolls a new layout seed so the
    /// cloud re-flows with a spring rather than snapping to new positions.
    func sampleWordCosmos(
        tier: WordCosmosTier? = nil,
        includeNames: Bool? = nil,
        count: Int? = nil
    ) {
        guard let h = handle else { return }
        let t = tier ?? wordCosmosTier
        let names = includeNames ?? self.includeNames
        let n = max(6, min(300, count ?? wordCosmosCount))

        var rawPtr: UnsafePointer<dj_word_hit_t>?
        let count = dj_dict_get_random_words(h, t.maxFreqRank, names, n, &rawPtr)

        var words: [WordHit] = []
        if let ptr = rawPtr, count > 0 {
            words.reserveCapacity(count)
            for i in 0..<count {
                words.append(Self.wordHit(from: ptr[i]))
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.wordCosmosTier = t
            if let explicitNames = includeNames, explicitNames != self.includeNames {
                self.setNamesIncluded(explicitNames, userInitiated: true)
            }
            self.wordCosmosCount = n
            self.wordCosmosWords = words
            // A new seed per sample so the layout re-flows with a spring.
            self.wordCosmosSeed = UInt64.random(in: 0...UInt64.max)
        }
    }

    func openWordCosmos(recordHistory: Bool = true) {
        if wordCosmosWords.isEmpty {
            sampleWordCosmos()
        }
        activeScreen = .wordCosmos
        if recordHistory {
            recordNavigation(NavBreadcrumb(
                kind: .wordCosmos,
                targetId: 0,
                label: "Word Cloud",
                subtitle: "Randomized \(wordCosmosTier.label) · \(wordCosmosWords.count) words"
            ))
        }
    }

    /// Dice-roll: re-sample the current tier and re-flow the cloud.
    func diceRollWordCosmos() {
        sampleWordCosmos()
    }

    /// Switch the prevalence ceiling and draw a fresh sample for it.
    func setWordCosmosTier(_ tier: WordCosmosTier) {
        sampleWordCosmos(tier: tier)
    }

    /// Open the Word Cockpit for a bubble.
    func openWordFromCosmos(_ word: WordHit) {
        openWordEntry(entryId: word.id)
    }

    /// Pivot a kanji-bearing word into the Kanji Fisheye of its first kanji
    /// (the fisheye two-tap rule); kana-only words fall back to the Cockpit.
    func pivotCosmosToKanjiFisheye(_ word: WordHit) {
        if let cp = word.firstKanjiCodepoint {
            openFisheye(codepoint: cp, recordHistory: true)
        } else {
            openWordEntry(entryId: word.id)
        }
    }

    private func fetchKanjiDetail(codepoint: UInt32, includeLexicalLists: Bool) -> KanjiDetail? {
        guard let h = handle else { return nil }
        var raw = dj_kanji_detail_t()
        guard dj_kanji_get_detail(h, codepoint, &raw) else { return nil }
        var polylines: [[CGPoint]] = []
        if let polyPtr = raw.stroke_polylines {
            for i in 0..<raw.polyline_count {
                let pl = polyPtr[i]
                var pts: [CGPoint] = []
                if let ptPtr = pl.points {
                    pts.reserveCapacity(pl.point_count)
                    for j in 0..<pl.point_count {
                        pts.append(CGPoint(x: CGFloat(ptPtr[j].x), y: CGFloat(ptPtr[j].y)))
                    }
                }
                polylines.append(pts)
            }
        }
        let glyph = String(UnicodeScalar(codepoint)!)

        var standaloneEntries: [EntryDetail] = []
        var relatedWords: [WordHit] = []

        if includeLexicalLists {
            var exactPtr: UnsafePointer<dj_word_hit_t>?
            let exactCount = glyph.withCString { cStr in
                dj_dict_search(h, cStr, DJ_SEARCH_EXACT, includeNames, 16, &exactPtr)
            }
            var standaloneHits: [WordHit] = []
            if let ptr = exactPtr, exactCount > 0 {
                for i in 0..<exactCount {
                    let item = ptr[i]
                    let kHead = String(cString: item.kanji_head)
                    if kHead == glyph {
                        standaloneHits.append(WordHit(
                            id: item.entry_id,
                            kanjiHead: kHead,
                            kanaHead: String(cString: item.kana_head),
                            altForms: String(cString: item.alt_forms),
                            primaryGloss: String(cString: item.primary_gloss),
                            posMask: item.pos_mask,
                            pitchAccent: item.pitch_accent,
                            freqRank: item.freq_rank,
                            pairEntryId: item.pair_entry_id,
                            isName: item.is_name
                        ))
                    }
                }
            }
            standaloneHits.sort { a, b in
                if a.isName != b.isName { return !a.isName }
                return a.freqRank < b.freqRank
            }
            let standaloneIds = Set(standaloneHits.map(\.id))
            for hit in standaloneHits.prefix(4) {
                var detailRaw = dj_entry_detail_t()
                if dj_dict_get_entry_detail(h, hit.id, &detailRaw) {
                    standaloneEntries.append(parseEntryDetail(detailRaw))
                }
            }

            var candidateById: [UInt32: WordHit] = [:]

            var autoPtr: UnsafePointer<dj_word_hit_t>?
            let autoCount = glyph.withCString { cStr in
                dj_dict_search(h, cStr, DJ_SEARCH_AUTO, includeNames, 80, &autoPtr)
            }
            if let ptr = autoPtr, autoCount > 0 {
                for i in 0..<autoCount {
                    let item = ptr[i]
                    let eid = item.entry_id
                    if standaloneIds.contains(eid) { continue }
                    let kHead = String(cString: item.kanji_head)
                    guard kHead.contains(glyph) else { continue }
                    candidateById[eid] = WordHit(
                        id: eid,
                        kanjiHead: kHead,
                        kanaHead: String(cString: item.kana_head),
                        altForms: String(cString: item.alt_forms),
                        primaryGloss: String(cString: item.primary_gloss),
                        posMask: item.pos_mask,
                        pitchAccent: item.pitch_accent,
                        freqRank: item.freq_rank,
                        pairEntryId: item.pair_entry_id,
                        isName: item.is_name
                    )
                }
            }

            for edgeMode in [DJ_EDGE_COMPOUNDS, DJ_EDGE_YOJIJUKUGO] {
                var edgePtr: UnsafePointer<dj_fisheye_node_t>?
                var leftOv = 0
                var rightOv = 0
                let edgeCount = dj_graph_solve_fisheye(
                    h, codepoint, edgeMode, includeNames, false, 0, 0, 1.85,
                    60, &leftOv, &rightOv, &edgePtr
                )
                var edgeEntryIds: [UInt32] = []
                if let ptr = edgePtr, edgeCount > 0 {
                    for i in 0..<edgeCount {
                        let eid = ptr[i].top_entry_id
                        if eid > 0 && !standaloneIds.contains(eid) && candidateById[eid] == nil {
                            edgeEntryIds.append(eid)
                        }
                    }
                }
                for eid in edgeEntryIds {
                    var detailRaw = dj_entry_detail_t()
                    if dj_dict_get_entry_detail(h, eid, &detailRaw) {
                        let hdr = detailRaw.header
                        let kHead = String(cString: hdr.kanji_head)
                        if kHead.contains(glyph) {
                            candidateById[eid] = WordHit(
                                id: hdr.entry_id,
                                kanjiHead: kHead,
                                kanaHead: String(cString: hdr.kana_head),
                                altForms: String(cString: hdr.alt_forms),
                                primaryGloss: String(cString: hdr.primary_gloss),
                                posMask: hdr.pos_mask,
                                pitchAccent: hdr.pitch_accent,
                                freqRank: hdr.freq_rank,
                                pairEntryId: hdr.pair_entry_id,
                                isName: hdr.is_name
                            )
                        }
                    }
                }
            }

            relatedWords = candidateById.values
                .sorted { a, b in
                    if a.isName != b.isName { return !a.isName }
                    if a.freqRank != b.freqRank { return a.freqRank < b.freqRank }
                    if a.displayHeadword.count != b.displayHeadword.count {
                        return a.displayHeadword.count < b.displayHeadword.count
                    }
                    return a.id < b.id
                }
                .prefix(120)
                .map { $0 }
        }

        let (sp, sp1, sp2) = Self.decodeSkipCode(raw.skip_code)
        let skipLabel = sp > 0 ? "\(sp)-\(sp1)-\(sp2)" : ""
        let fcLabel = Self.decodeFourCorner(raw.four_corner)
        let kyujitai = raw.kyujitai_cp > 0 ? UnicodeScalar(raw.kyujitai_cp).map(String.init) : nil
        let kanjiIdioms = includeLexicalLists ? fetchKanjiIdioms(codepoint: codepoint, limit: 16) : []

        return KanjiDetail(
            codepoint: codepoint,
            glyph: glyph,
            strokes: Int(raw.strokes),
            grade: Int(raw.grade),
            jlpt: Int(raw.jlpt),
            freqRank: raw.freq_rank,
            radicalId: Int(raw.radical_id),
            skipCode: raw.skip_code,
            fourCorner: raw.four_corner,
            skipCodeLabel: skipLabel,
            fourCornerLabel: fcLabel,
            kyujitaiGlyph: kyujitai,
            onReadings: String(cString: raw.on_readings).split(separator: ",").map(String.init),
            kunReadings: String(cString: raw.kun_readings).split(separator: ",").map(String.init),
            meanings: String(cString: raw.meanings),
            componentRadicals: String(cString: raw.component_radicals),
            strokePolylines: polylines,
            standaloneEntries: standaloneEntries,
            relatedWords: relatedWords,
            idioms: kanjiIdioms
        )
    }

    private func makeFisheyeNode(from n: dj_fisheye_node_t) -> FisheyeNode {
        let scalar = UnicodeScalar(n.codepoint) ?? UnicodeScalar(0x3000)!
        return FisheyeNode(
            codepoint: n.codepoint,
            glyph: String(scalar),
            side: n.side,
            commonalityTier: n.commonality_tier,
            isOverflowPreview: n.is_overflow_preview != 0,
            topEntryId: n.top_entry_id,
            compoundWord: String(cString: n.compound_word),
            compoundKana: String(cString: n.compound_kana),
            compoundGloss: String(cString: n.compound_gloss),
            sharePct: n.share_pct,
            normX: CGFloat(n.norm_x),
            normY: CGFloat(n.norm_y),
            scale: CGFloat(n.scale),
            opacity: Double(n.opacity)
        )
    }

    func solveFisheye(center: UInt32, hasFocus: Bool, focusX: Float, focusY: Float, aspectRatio: Float, animated: Bool = true) {
        guard let h = handle else { return }
        var rawPtr: UnsafePointer<dj_fisheye_node_t>?
        var leftOv: Int = 0
        var rightOv: Int = 0
        let count = dj_graph_solve_fisheye(
            h, center, fisheyeMode, includeNames, hasFocus, focusX, focusY, aspectRatio,
            maxFisheyePerSide, &leftOv, &rightOv, &rawPtr
        )
        var mainList: [FisheyeNode] = []
        var previewList: [FisheyeNode] = []
        if let ptr = rawPtr, count > 0 {
            for i in 0..<count {
                let node = makeFisheyeNode(from: ptr[i])
                if node.isOverflowPreview {
                    previewList.append(node)
                } else {
                    mainList.append(node)
                }
            }
        }
        let apply = {
            self.leftOverflowCount = leftOv
            self.rightOverflowCount = rightOv
            self.fisheyeNodes = mainList
            self.overflowPreviewNodes = previewList

            // Pre-cache entries for all visible fisheye nodes in RAM to avoid DB queries on word lookup
            if let h = self.handle {
                for node in mainList where node.topEntryId > 0 && self.entryDetailCache[node.topEntryId] == nil {
                    var raw = dj_entry_detail_t()
                    if dj_dict_get_entry_detail(h, node.topEntryId, &raw) {
                        self.entryDetailCache[node.topEntryId] = self.parseEntryDetail(raw)
                    }
                }
            }
        }
        if animated {
            withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.80, blendDuration: 0.10)) {
                apply()
            }
        } else {
            apply()
        }
    }

    // MARK: - 7-Slot Multi-Radical Search (With Deterministic Stroke Filtering)

    func openRadicalBuilder(withRadicals initialIds: [UInt8] = [], targetStrokes: Int = 0) {
        ensureKanjiCatalogLoaded()
        self.activeScreen = .radicalBuilder
        let uniqueIds = initialIds.reduce(into: [UInt8]()) { acc, id in
            if id >= 1 && id <= 214 && !acc.contains(id) && acc.count < 7 {
                acc.append(id)
            }
        }
        if !uniqueIds.isEmpty {
            self.radicalSelectedIds = uniqueIds
            self.radicalTargetStrokes = targetStrokes
            searchRadicals(selectedIds: uniqueIds, targetStrokes: Int16(targetStrokes), tolerance: radicalStrokeTolerance)
        } else if !radicalSelectedIds.isEmpty || radicalTargetStrokes > 0 {
            searchRadicals(selectedIds: radicalSelectedIds, targetStrokes: Int16(radicalTargetStrokes), tolerance: radicalStrokeTolerance)
        }
        let subtitle = uniqueIds.isEmpty
            ? "7-Slot Radical Builder"
            : "Radicals: " + uniqueIds.map { RadicalCatalog.glyph(for: $0) }.joined(separator: " + ")
        recordNavigation(NavBreadcrumb(kind: .radicalBuilder, targetId: 0, label: "Radicals", subtitle: subtitle))
    }

    func searchRadicals(selectedIds: [UInt8], targetStrokes: Int16, tolerance: Int8) {
        self.radicalSelectedIds = selectedIds
        self.radicalTargetStrokes = Int(targetStrokes)
        self.radicalStrokeTolerance = tolerance
        guard let h = handle else { return }

        ensureKanjiCatalogLoaded()
        let tStrokes = Int(targetStrokes)
        let tol = Int(tolerance)

        if selectedIds.isEmpty {
            if tStrokes > 0, let catalog = cachedKanjiCatalog {
                let matches = catalog
                    .filter { $0.strokes > 0 && abs($0.strokes - tStrokes) <= tol }
                    .sorted { a, b in
                        if a.strokes != b.strokes { return a.strokes < b.strokes }
                        if a.freqRank != b.freqRank { return a.freqRank < b.freqRank }
                        return a.codepoint < b.codepoint
                    }
                    .prefix(300)
                    .map(\.codepoint)
                self.radicalMatches = Array(matches)
            } else {
                self.radicalMatches = []
            }
            if historyIndex >= 0 && historyIndex < history.count && history[historyIndex].kind == .radicalBuilder {
                captureCurrentSnapshot(for: history[historyIndex])
            }
            return
        }

        var rawPtr: UnsafePointer<UInt32>?
        let count = selectedIds.withUnsafeBufferPointer { buf in
            dj_kanji_search_radicals(h, buf.baseAddress, buf.count, 0, 0, &rawPtr)
        }
        var cps: [UInt32] = []
        if let ptr = rawPtr, count > 0 {
            cps.reserveCapacity(count)
            for i in 0..<count {
                let cp = ptr[i]
                if tStrokes > 0 {
                    if let meta = cachedKanjiByCodepoint?[cp] {
                        if meta.strokes > 0 && abs(meta.strokes - tStrokes) <= tol {
                            cps.append(cp)
                        }
                    } else {
                        var rawDetail = dj_kanji_detail_t()
                        if dj_kanji_get_detail(h, cp, &rawDetail) {
                            let st = Int(rawDetail.strokes)
                            if st > 0 && abs(st - tStrokes) <= tol {
                                cps.append(cp)
                            }
                        }
                    }
                } else {
                    cps.append(cp)
                }
            }
        }

        cps.sort { a, b in
            let ma = cachedKanjiByCodepoint?[a]
            let mb = cachedKanjiByCodepoint?[b]
            let sa = ma?.strokes ?? 99
            let sb = mb?.strokes ?? 99
            if sa != sb { return sa < sb }
            let fa = ma?.freqRank ?? 999_999
            let fb = mb?.freqRank ?? 999_999
            if fa != fb { return fa < fb }
            return a < b
        }

        self.radicalMatches = cps
        if historyIndex >= 0 && historyIndex < history.count && history[historyIndex].kind == .radicalBuilder {
            captureCurrentSnapshot(for: history[historyIndex])
        }
    }

    func pushRecentKanji(_ cp: UInt32) {
        guard let h = handle else { return }
        dj_state_push_recent_kanji(h, cp)
        var buf = [UInt32](repeating: 0, count: 6)
        let cnt = buf.withUnsafeMutableBufferPointer { ptr in
            dj_state_get_recent_kanji(h, ptr.baseAddress)
        }
        let next = Array(buf.prefix(cnt))
        self.recentKanji = next
        if isBootstrapped {
            UserDefaults.standard.set(next.map(Int.init), forKey: Self.recentKanjiKey)
        }
    }

    func isKanjiScalar(_ cp: UInt32) -> Bool {
        (0x4E00...0x9FFF).contains(cp) || (0x3400...0x4DBF).contains(cp)
    }
}
