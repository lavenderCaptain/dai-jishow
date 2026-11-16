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
}

struct NavBreadcrumb: Identifiable, Equatable {
    let id = UUID()
    let kind: ActiveScreenKind
    let targetId: UInt32
    let label: String
    let subtitle: String
}

enum RecallMode: String, CaseIterable, Identifiable {
    case full = "Full"
    case hideKana = "Hide Kana"
    case hideGloss = "Hide Gloss"
    var id: String { rawValue }
}

@MainActor
final class DaiJishowEngine: ObservableObject {
    private var handle: OpaquePointer?

    @Published var searchQuery: String = ""
    @Published var includeNames: Bool = false
    @Published var recallMode: RecallMode = .full
    @Published var searchResults: [WordHit] = []

    @Published var activeScreen: ActiveScreenKind = .fisheye
    @Published var history: [NavBreadcrumb] = []
    @Published var historyIndex: Int = -1
    @Published var isZStackOpen: Bool = false
    @Published var recentKanji: [UInt32] = []

    @Published var activeEntry: EntryDetail?
    @Published var activeKanji: KanjiDetail?
    @Published var fisheyeNodes: [FisheyeNode] = []
    @Published var overflowPreviewNodes: [FisheyeNode] = []
    @Published var leftOverflowCount: Int = 0
    @Published var rightOverflowCount: Int = 0
    @Published var maxFisheyePerSide: Int = 12
    @Published var fisheyeMode: dj_fisheye_mode_t = DJ_EDGE_COMPOUNDS
    @Published var selectedFisheyeNode: FisheyeNode?
    @Published var hoveredFisheyeNode: FisheyeNode?
    @Published var radicalMatches: [UInt32] = []

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

    private func recordNavigation(_ item: NavBreadcrumb) {
        if historyIndex >= 0 && historyIndex < history.count {
            let current = history[historyIndex]
            if current.kind == item.kind && current.targetId == item.targetId {
                return
            }
            if historyIndex + 1 < history.count {
                history.removeSubrange((historyIndex + 1)..<history.count)
            }
        }
        history.append(item)
        if history.count > 24 {
            history.removeFirst()
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
            activeScreen = .radicalBuilder
        }
    }

    func performSearch() {
        guard let h = handle else { return }
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = []
            return
        }

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
        if searchResults.isEmpty {
            performSearch()
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
        guard openKanjiDetailSilently(codepoint: codepoint) else { return }
        pushRecentKanji(codepoint)
        self.activeScreen = .kanjiDetail
        if recordHistory, let sc = UnicodeScalar(codepoint) {
            recordNavigation(NavBreadcrumb(
                kind: .kanjiDetail,
                targetId: codepoint,
                label: "\(String(sc)) (Kanji)",
                subtitle: activeKanji?.meanings ?? "Kanji Detail"
            ))
        }
    }

    func openFisheye(codepoint: UInt32, recordHistory: Bool = true) {
        _ = openKanjiDetailSilently(codepoint: codepoint)
        self.selectedFisheyeNode = nil
        self.hoveredFisheyeNode = nil
        self.activeScreen = .fisheye
        solveFisheye(center: codepoint, focusX: 0, focusY: 0, aspectRatio: 1.5, animated: false)
        pushRecentKanji(codepoint)

        if recordHistory, let sc = UnicodeScalar(codepoint) {
            recordNavigation(NavBreadcrumb(
                kind: .fisheye,
                targetId: codepoint,
                label: String(sc),
                subtitle: activeKanji?.meanings ?? "Compound Explorer"
            ))
        }
    }

    private func openKanjiDetailSilently(codepoint: UInt32) -> Bool {
        guard let h = handle else { return false }
        var raw = dj_kanji_detail_t()
        guard dj_kanji_get_detail(h, codepoint, &raw) else { return false }
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
        self.activeKanji = KanjiDetail(
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
            strokePolylines: polylines
        )
        return true
    }

    func solveFisheye(center: UInt32, focusX: Float, focusY: Float, aspectRatio: Float, animated: Bool = true) {
        guard let h = handle else { return }
        var rawPtr: UnsafePointer<dj_fisheye_node_t>?
        var leftOv: Int = 0
        var rightOv: Int = 0
        let count = dj_graph_solve_fisheye(
            h, center, fisheyeMode, includeNames, focusX, focusY, aspectRatio,
            maxFisheyePerSide, &leftOv, &rightOv, &rawPtr
        )
        var mainList: [FisheyeNode] = []
        var previewList: [FisheyeNode] = []
        if let ptr = rawPtr, count > 0 {
            for i in 0..<count {
                let n = ptr[i]
                let node = FisheyeNode(
                    codepoint: n.codepoint,
                    glyph: String(UnicodeScalar(n.codepoint) ?? UnicodeScalar(0x3000)!),
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
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.78, blendDuration: 0.12)) {
                apply()
            }
        } else {
            apply()
        }
    }

    func openRadicalBuilder() {
        self.activeScreen = .radicalBuilder
        recordNavigation(NavBreadcrumb(kind: .radicalBuilder, targetId: 0, label: "Radicals", subtitle: "7-Slot Radical Builder"))
    }

    func searchRadicals(selectedIds: [UInt8], targetStrokes: Int16, tolerance: Int8) {
        guard let h = handle else { return }
        if selectedIds.isEmpty {
            radicalMatches = []
            return
        }
        var rawPtr: UnsafePointer<UInt32>?
        let count = selectedIds.withUnsafeBufferPointer { buf in
            dj_kanji_search_radicals(h, buf.baseAddress, buf.count, targetStrokes, tolerance, &rawPtr)
        }
        var cps: [UInt32] = []
        if let ptr = rawPtr, count > 0 {
            for i in 0..<count {
                cps.append(ptr[i])
            }
        }
        self.radicalMatches = cps
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
