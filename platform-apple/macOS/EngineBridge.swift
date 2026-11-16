import Foundation
import SwiftUI
import DaiJishowCore

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
}

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
    let kyujitaiGlyph: String?
    let onReadings: [String]
    let kunReadings: [String]
    let meanings: String
    let componentRadicals: String
    let strokePolylines: [[CGPoint]]
    let standaloneEntries: [EntryDetail]
    let relatedWords: [WordHit]

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

enum ActiveScreenKind {
    case fisheye
    case wordEntry
    case kanjiDetail
    case radicalBuilder
    case kanjiLookup
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
}

enum RecallMode: String, CaseIterable, Identifiable {
    case full = "Full"
    case hideKana = "Hide Kana"
    case hideGloss = "Hide Defn."
    var id: String { rawValue }
}

// MARK: - Kana & Romaji Normalization Helpers

enum KanaNormalizer {
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

    static func katakanaToHiragana(_ input: String) -> String {
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

    static func cleanReadingToken(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return katakanaToHiragana(stripped)
    }

    static func romajiToHiragana(_ input: String) -> String {
        let s = katakanaToHiragana(input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        var result = ""
        var idx = s.startIndex

        while idx < s.endIndex {
            let rem = s[idx...]
            // Double consonant -> っ (except 'n')
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

@MainActor
final class DaiJishowEngine: ObservableObject {
    private var handle: OpaquePointer?
    private var searchDebounceTask: Task<Void, Never>?
    private var historySnapshots: [UUID: HistorySnapshot] = [:]
    private var cachedKanjiCatalog: [KanjiIndexItem]?
    private var cachedKanjiByCodepoint: [UInt32: KanjiIndexItem]?

    @Published var searchQuery: String = ""
    @Published var includeNames: Bool = false
    @Published var recallMode: RecallMode = .full
    @Published var searchResults: [WordHit] = []

    @Published var activeScreen: ActiveScreenKind = .fisheye
    @Published var history: [NavBreadcrumb] = []
    @Published var historyIndex: Int = -1
    @Published var isZStackOpen: Bool = false
    @Published var zStackFocusedIndex: Int = 0
    @Published var recentKanji: [UInt32] = []

    @Published var activeEntry: EntryDetail?
    @Published var activeKanji: KanjiDetail?
    @Published var fisheyeNodes: [FisheyeNode] = []
    @Published var overflowPreviewNodes: [FisheyeNode] = []
    @Published var leftOverflowCount: Int = 0
    @Published var rightOverflowCount: Int = 0
    @Published var maxFisheyePerSide: Int = 12
    @Published var showFisheyePercentages: Bool = true
    @Published var fisheyeMode: dj_fisheye_mode_t = DJ_EDGE_COMPOUNDS
    @Published var selectedFisheyeNode: FisheyeNode?
    @Published var hoveredFisheyeNode: FisheyeNode?

    @Published var radicalSelectedIds: [UInt8] = []
    @Published var radicalTargetStrokes: Int = 0
    @Published var radicalStrokeTolerance: Int8 = 0
    @Published var radicalMatches: [UInt32] = []

    @Published var kanjiLookupMode: KanjiLookupMode = .strokes
    @Published var kanjiLookupSort: KanjiSortOrder = .popularity
    @Published var kanjiLookupStrokeCount: Int = 8
    @Published var kanjiLookupStrokeTolerance: Int = 0
    @Published var kanjiLookupLevelFilter: Int = 0 // 0=All, 1=Joyo, 2=G1..6, 3=JLPT
    @Published var kanjiLookupReadingQuery: String = ""
    @Published var kanjiLookupReadingScope: Int = 0 // 0=All, 1=On, 2=Kun
    @Published var kanjiLookupReadingExact: Bool = false
    @Published var kanjiLookupSkipPattern: Int = 1 // 1..4
    @Published var kanjiLookupSkipPart1: Int = 0 // 0=Any
    @Published var kanjiLookupSkipPart2: Int = 0 // 0=Any
    @Published var kanjiLookupFourCorner: String = ""
    @Published var kanjiLookupGradeFilter: Int = 1 // 1..6, 8=Secondary Joyo, -5..-1=JLPT N5..N1
    @Published var kanjiLookupMeaningQuery: String = ""
    @Published var kanjiLookupResults: [KanjiIndexItem] = []

    init(dbPath: String) {
        self.handle = dj_engine_create(dbPath)
        if self.handle != nil {
            pushRecentKanji(0x96FB) // 電
            openFisheye(codepoint: 0x96FB, recordHistory: true)
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

    // MARK: - Wordtank Kanji Lookup Execution

    func openKanjiLookup() {
        ensureKanjiCatalogLoaded()
        self.activeScreen = .kanjiLookup
        runKanjiLookup()
        recordNavigation(NavBreadcrumb(
            kind: .kanjiLookup,
            targetId: 0,
            label: "Kanji Index",
            subtitle: "Wordtank Multi-Mode Lookup"
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

        // Apply chosen sort order
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
                let ja = (1...5).contains(a.jlpt) ? (6 - a.jlpt) : 99 // N5 (1) -> N1 (5)
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
        }
    }

    func snapshot(for item: NavBreadcrumb) -> HistorySnapshot? {
        historySnapshots[item.id]
    }

    func invalidateFisheyeSnapshots() {
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
        }
    }

    private func recordNavigation(_ item: NavBreadcrumb) {
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
        }
    }

    // MARK: - Dictionary Search & Entry Navigation

    func performSearch() {
        searchDebounceTask?.cancel()
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = []
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
        if trimmed.unicodeScalars.count == 1, let scalar = trimmed.unicodeScalars.first, isKanjiScalar(scalar.value) {
            pushRecentKanji(scalar.value)
        }

        var rawPtr: UnsafePointer<dj_word_hit_t>?
        let count = trimmed.withCString { cStr in
            dj_dict_search(h, cStr, DJ_SEARCH_AUTO, includeNames, 40, &rawPtr)
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
    }

    func submitSearchQuery() {
        searchDebounceTask?.cancel()
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if searchResults.isEmpty && !trimmed.isEmpty {
            executeSearchNow(trimmed: trimmed)
        }
        if let first = searchResults.first {
            openWordEntry(entryId: first.id)
            searchResults = []
        }
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
            self.activeEntry = EntryDetail(
                header: promotedHeader,
                pairedKanji: cur.pairedKanji,
                pairedKana: cur.pairedKana,
                rubyCells: newCells.isEmpty ? cur.rubyCells : newCells,
                senses: cur.senses,
                sentences: cur.sentences
            )
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

    func openWordEntry(entryId: UInt32, recordHistory: Bool = true) {
        guard let h = handle else { return }
        var raw = dj_entry_detail_t()
        guard dj_dict_get_entry_detail(h, entryId, &raw) else { return }

        let detail = parseEntryDetail(raw)
        self.activeEntry = detail
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
                if let ptr = edgePtr, edgeCount > 0 {
                    for i in 0..<edgeCount {
                        let eid = ptr[i].top_entry_id
                        if eid == 0 || standaloneIds.contains(eid) || candidateById[eid] != nil { continue }
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
                .prefix(60)
                .map { $0 }
        }

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
            kyujitaiGlyph: nil,
            onReadings: String(cString: raw.on_readings).split(separator: ",").map(String.init),
            kunReadings: String(cString: raw.kun_readings).split(separator: ",").map(String.init),
            meanings: String(cString: raw.meanings),
            componentRadicals: String(cString: raw.component_radicals),
            strokePolylines: polylines,
            standaloneEntries: standaloneEntries,
            relatedWords: relatedWords
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

        // Allow browsing by stroke count alone if no radical is selected yet
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

        // Pass 0 for targetStrokes to C core so we can apply exact/±1 filtering reliably in Swift
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

        // Sort matched kanji by stroke count (when unconstrained) and prevalence
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
        self.recentKanji = Array(buf.prefix(cnt))
    }

    func isKanjiScalar(_ cp: UInt32) -> Bool {
        (0x4E00...0x9FFF).contains(cp) || (0x3400...0x4DBF).contains(cp)
    }
}
