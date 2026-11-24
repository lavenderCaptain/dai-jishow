import SwiftUI
import WatchKit
import DaiJishowCore
import DaiJishowMorph

@main
struct DaiJishowWatchApp: App {
    @StateObject private var engine: DaiJishowEngine

    init() {
        let resolvedPath = DatabaseLocator.locateDatabasePath()
        _engine = StateObject(wrappedValue: DaiJishowEngine(dbPath: resolvedPath))
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(engine: engine)
                .preferredColorScheme(engine.appearanceMode.colorScheme)
        }
    }
}

private enum WatchPage: Hashable {
    case search
    case fisheye
    case decks
}

private enum WatchDestination: Hashable {
    case word(UInt32)
    case kanji(UInt32)
    case flashcards(title: String, items: [StudySavedItem])
}

private func isWatchKanjiScalar(_ v: UInt32) -> Bool {
    (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v)
}

struct WatchRootView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var selectedPage: WatchPage = .search
    @State private var searchPath: [WatchDestination] = []
    @State private var fisheyePath: [WatchDestination] = []
    @State private var decksPath: [WatchDestination] = []

    private func focusInFisheye(_ codepoint: UInt32) {
        if engine.activeKanji?.codepoint != codepoint {
            engine.openFisheye(codepoint: codepoint, recordHistory: true)
        } else {
            engine.solveFisheye(
                center: codepoint,
                hasFocus: false,
                focusX: 0,
                focusY: 0,
                aspectRatio: 1.35,
                animated: false
            )
        }
        fisheyePath = []
        selectedPage = .fisheye
    }

    var body: some View {
        if !engine.isReady {
            VStack(spacing: 8) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Corpus Missing")
                    .font(.headline)
                Text("Bundle daijishow.db to use offline search.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else {
            TabView(selection: $selectedPage) {
                WatchSearchView(
                    engine: engine,
                    path: $searchPath,
                    onFocusInFisheye: focusInFisheye
                )
                .tag(WatchPage.search)

                WatchCrownFisheyeView(
                    engine: engine,
                    path: $fisheyePath,
                    onFocusInFisheye: focusInFisheye
                )
                .tag(WatchPage.fisheye)

                WatchDecksView(
                    engine: engine,
                    path: $decksPath,
                    onFocusInFisheye: focusInFisheye
                )
                .tag(WatchPage.decks)
            }
            .tabViewStyle(.page)
        }
    }
}

@ViewBuilder
private func watchDestinationView(
    for dest: WatchDestination,
    engine: DaiJishowEngine,
    path: Binding<[WatchDestination]>,
    onFocusInFisheye: @escaping (UInt32) -> Void
) -> some View {
    switch dest {
    case .word(let entryId):
        WatchWordDetailView(
            engine: engine,
            entryId: entryId,
            path: path,
            onFocusInFisheye: onFocusInFisheye
        )
    case .kanji(let codepoint):
        WatchKanjiDetailView(
            engine: engine,
            codepoint: codepoint,
            path: path,
            onFocusInFisheye: onFocusInFisheye
        )
    case .flashcards(let title, let items):
        WatchDeckFlashcardsView(
            engine: engine,
            deckTitle: title,
            initialItems: items,
            path: path
        )
    }
}

// MARK: - Search & Detail Stack

private struct WatchSearchView: View {
    @ObservedObject var engine: DaiJishowEngine
    @Binding var path: [WatchDestination]
    let onFocusInFisheye: (UInt32) -> Void

    @State private var randomWord: WordHit?

    private var hasQuery: Bool {
        !engine.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var contextKanjiCodepoint: UInt32 {
        engine.activeKanji?.codepoint ?? (engine.recentKanji.first ?? 0x5927)
    }

    private var contextKanjiGlyph: String {
        UnicodeScalar(contextKanjiCodepoint).map(String.init) ?? "大"
    }

    private var matchingKanjiCodepoints: [UInt32] {
        var seen = Set<UInt32>()
        var out: [UInt32] = []
        let sources = [engine.searchQuery] + engine.searchResults.prefix(14).map(\.kanjiHead)
        for text in sources {
            for scalar in text.unicodeScalars where isWatchKanjiScalar(scalar.value) {
                if seen.insert(scalar.value).inserted {
                    out.append(scalar.value)
                    if out.count >= 8 { return out }
                }
            }
        }
        return out
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if hasQuery {
                    if !matchingKanjiCodepoints.isEmpty {
                        Section("Kanji") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(matchingKanjiCodepoints, id: \.self) { cp in
                                        if let scalar = UnicodeScalar(cp) {
                                            let isContext = (cp == contextKanjiCodepoint)
                                            Button {
                                                WKInterfaceDevice.current().play(.click)
                                                engine.openKanjiDetail(codepoint: cp)
                                                path.append(.kanji(cp))
                                            } label: {
                                                Text(String(Character(scalar)))
                                                    .font(.title3.bold())
                                                    .frame(width: 36, height: 36)
                                                    .background(
                                                        Circle()
                                                            .fill(isContext ? Color.accentColor.opacity(0.32) : Color.accentColor.opacity(0.18))
                                                            .overlay(
                                                                Circle().strokeBorder(
                                                                    isContext ? Color.accentColor : Color.clear,
                                                                    lineWidth: 1.5
                                                                )
                                                            )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    if engine.searchResults.isEmpty {
                        Text("No matches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Section("Words") {
                            ForEach(engine.searchResults.prefix(20)) { hit in
                                Button {
                                    engine.openWordEntry(entryId: hit.id)
                                    path.append(.word(hit.id))
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(hit.displayHeadword)
                                            .font(.headline)
                                        if !hit.kanaHead.isEmpty && hit.kanaHead != hit.displayHeadword {
                                            Text(hit.kanaHead)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(hit.primaryGloss)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section("In Context") {
                        HStack(spacing: 8) {
                            Button {
                                engine.openKanjiDetail(codepoint: contextKanjiCodepoint)
                                path.append(.kanji(contextKanjiCodepoint))
                            } label: {
                                HStack(spacing: 8) {
                                    Text(contextKanjiGlyph)
                                        .font(.title3.bold())
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(Color.accentColor.opacity(0.24))
                                                .overlay(Circle().strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1.5))
                                        )
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Active Kanji")
                                            .font(.caption.weight(.semibold))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                        if let active = engine.activeKanji,
                                           active.codepoint == contextKanjiCodepoint,
                                           !active.meanings.isEmpty {
                                            Text(active.meanings)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        } else {
                                            Text("Tap to inspect")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                WKInterfaceDevice.current().play(.click)
                                onFocusInFisheye(contextKanjiCodepoint)
                            } label: {
                                Image(systemName: "circle.hexagongrid.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.accentColor.opacity(0.16)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(contextKanjiGlyph) in Fisheye")
                        }
                    }

                    if !engine.recentKanji.isEmpty {
                        Section("Recent Kanji") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(engine.recentKanji, id: \.self) { cp in
                                        if let scalar = UnicodeScalar(cp) {
                                            let isContext = (cp == contextKanjiCodepoint)
                                            Button {
                                                engine.openKanjiDetail(codepoint: cp)
                                                path.append(.kanji(cp))
                                            } label: {
                                                Text(String(Character(scalar)))
                                                    .font(.title3.bold())
                                                    .frame(width: 36, height: 36)
                                                    .background(
                                                        Circle()
                                                            .fill(isContext ? Color.accentColor.opacity(0.32) : Color.accentColor.opacity(0.16))
                                                            .overlay(
                                                                Circle().strokeBorder(
                                                                    isContext ? Color.accentColor : Color.clear,
                                                                    lineWidth: 1.5
                                                                )
                                                            )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    Section("Discover") {
                        HStack(spacing: 8) {
                            Button {
                                let target = randomWord ?? engine.fetchRandomWords(count: 1, maxFreqRank: 12_000).first
                                if let target {
                                    randomWord = target
                                    engine.openWordEntry(entryId: target.id)
                                    path.append(.word(target.id))
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 5) {
                                        Text(randomWord?.displayHeadword ?? "Random Word")
                                            .font(.headline)
                                            .lineLimit(1)
                                        if let kana = randomWord?.kanaHead,
                                           !kana.isEmpty,
                                           kana != randomWord?.displayHeadword {
                                            Text(kana)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Text(randomWord?.primaryGloss ?? "Tap to explore a word")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                WKInterfaceDevice.current().play(.click)
                                randomWord = engine.fetchRandomWords(count: 1, maxFreqRank: 12_000).first
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.accentColor.opacity(0.16)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Roll another random word")
                        }
                    }
                }
            }
            .navigationTitle("Dai-Jishow")
            .searchable(text: $engine.searchQuery, prompt: "Search")
            .onAppear {
                if randomWord == nil {
                    randomWord = engine.fetchRandomWords(count: 1, maxFreqRank: 12_000).first
                }
            }
            .onChange(of: engine.searchQuery) { _, _ in
                engine.performSearch()
            }
            .navigationDestination(for: WatchDestination.self) { dest in
                watchDestinationView(
                    for: dest,
                    engine: engine,
                    path: $path,
                    onFocusInFisheye: onFocusInFisheye
                )
            }
        }
    }
}

// MARK: - Word Detail with Pitch Sparkline & Example Sentence

private struct WatchPitchSparkline: View {
    let contour: PitchAccentContour

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(contour.patternName) • \(contour.patternSublabel)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Canvas { ctx, size in
                let totalCount = contour.morae.count + (contour.showParticle ? 1 : 0)
                guard totalCount > 0 else { return }
                let stepX = size.width / CGFloat(totalCount)
                let highY = size.height * 0.25
                let lowY = size.height * 0.75

                var points: [CGPoint] = []
                var filled: [Bool] = []
                for idx in contour.morae.indices {
                    let x = stepX * (CGFloat(idx) + 0.5)
                    let y = contour.highStates[idx] ? highY : lowY
                    points.append(CGPoint(x: x, y: y))
                    filled.append(true)
                }
                if contour.showParticle {
                    let x = stepX * (CGFloat(contour.morae.count) + 0.5)
                    let y = contour.particleHigh ? highY : lowY
                    points.append(CGPoint(x: x, y: y))
                    filled.append(false)
                }

                if points.count >= 2 {
                    var line = Path()
                    line.move(to: points[0])
                    for p in points.dropFirst() {
                        line.addLine(to: p)
                    }
                    ctx.stroke(
                        line,
                        with: .color(.accentColor),
                        style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
                    )
                }

                for (idx, pt) in points.enumerated() {
                    let rect = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                    if filled[idx] {
                        ctx.fill(Path(ellipseIn: rect), with: .color(.accentColor))
                    } else {
                        ctx.stroke(Path(ellipseIn: rect), with: .color(.accentColor), lineWidth: 1.5)
                    }
                }
            }
            .frame(height: 22)

            HStack(spacing: 0) {
                ForEach(Array(contour.morae.enumerated()), id: \.offset) { _, mora in
                    Text(mora)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
                if contour.showParticle {
                    Text("が")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.08)))
    }
}

private struct WatchWordDetailView: View {
    @ObservedObject var engine: DaiJishowEngine
    let entryId: UInt32
    @Binding var path: [WatchDestination]
    let onFocusInFisheye: (UInt32) -> Void

    private var entry: EntryDetail? {
        if let active = engine.activeEntry, active.header.id == entryId {
            return active
        }
        return engine.fetchEntryDetail(entryId)
    }

    var body: some View {
        ScrollView {
            if let entry {
                let insights = engine.activeWordInsights?.entryId == entry.header.id
                    ? engine.activeWordInsights
                    : nil
                let isSaved = engine.studyStore.isWordSaved(entry.header.id)
                let isNoun = (entry.header.posMask & (1 << 0)) != 0
                let exampleSentence = entry.sentences.first ?? insights?.fallbackSentences.first

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        if !entry.header.kanaHead.isEmpty && entry.header.kanaHead != entry.header.displayHeadword {
                            Text(entry.header.kanaHead)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.header.displayHeadword)
                            .font(.title2.bold())
                    }

                    ForEach(Array(entry.senses.prefix(4).enumerated()), id: \.element.id) { idx, sense in
                        if !sense.enGlosses.isEmpty {
                            Text("\(idx + 1). \(sense.enGlosses)")
                                .font(.footnote)
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            let text = entry.header.kanaHead.isEmpty ? entry.header.displayHeadword : entry.header.kanaHead
                            SpeechEngine.shared.speak(text)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                        }
                        .controlSize(.small)
                        .disabled(!SpeechEngine.shared.japaneseVoiceAvailable)

                        Button {
                            engine.toggleSaveWord(entry, insights: insights)
                        } label: {
                            Image(systemName: isSaved ? "star.fill" : "star")
                                .foregroundStyle(isSaved ? .yellow : .primary)
                        }
                        .controlSize(.small)
                    }

                    if let sentence = exampleSentence {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Example")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if SpeechEngine.shared.japaneseVoiceAvailable {
                                    Button {
                                        SpeechEngine.shared.speak(sentence.jpText)
                                    } label: {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Text(sentence.jpText)
                                .font(.caption)
                            if !sentence.enText.isEmpty {
                                Text(sentence.enText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
                    }

                    if let insights, !insights.kanjiDNA.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Select Kanji")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(insights.kanjiDNA) { dna in
                                        let isContext = (engine.activeKanji?.codepoint == dna.codepoint)
                                        Button {
                                            WKInterfaceDevice.current().play(.click)
                                            engine.openKanjiDetail(codepoint: dna.codepoint)
                                            path.append(.kanji(dna.codepoint))
                                        } label: {
                                            VStack(spacing: 1) {
                                                Text(dna.glyph)
                                                    .font(.title3.bold())
                                                if let reading = dna.intermediateReading, !reading.isEmpty {
                                                    Text(reading)
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(isContext ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.10))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                            .strokeBorder(isContext ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    if let contour = PitchAccentContour.build(
                        kana: entry.header.kanaHead,
                        pitchAccent: entry.header.pitchAccent,
                        showParticle: isNoun
                    ) {
                        Divider()
                        WatchPitchSparkline(contour: contour)
                    }

                    if let insights, !insights.inflections.isEmpty {
                        Divider()
                        Text(insights.inflectionHeader ?? "Forms")
                            .font(.caption.weight(.semibold))
                        ForEach(insights.inflections.prefix(5)) { form in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(form.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(form.surface)
                                    .font(.footnote.weight(.medium))
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(entry?.header.displayHeadword ?? "Word")
        .onAppear {
            if engine.activeEntry?.header.id != entryId {
                engine.openWordEntry(entryId: entryId, recordHistory: false)
            }
        }
    }
}

// MARK: - Interactive Kanji Stroke Diagram & Detail

private struct WatchKanjiStrokeShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        path.move(to: CGPoint(x: points[0].x * rect.width, y: points[0].y * rect.height))
        for pt in points.dropFirst() {
            path.addLine(to: CGPoint(x: pt.x * rect.width, y: pt.y * rect.height))
        }
        return path
    }
}

private struct WatchKanjiStrokeDiagram: View {
    let glyph: String
    let polylines: [[CGPoint]]
    let completedStrokes: Int
    let activeStrokeIndex: Int?
    let activeStrokeProgress: CGFloat
    let isAnimating: Bool
    var boxSize: CGFloat = 74

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isAnimating ? Color.accentColor.opacity(0.75) : Color.primary.opacity(0.14),
                            lineWidth: isAnimating ? 1.5 : 1
                        )
                )

            if polylines.isEmpty {
                Text(glyph)
                    .font(.system(size: 38, weight: .bold))
            } else {
                GeometryReader { _ in
                    ZStack {
                        Canvas { ctx, size in
                            let w = size.width
                            let h = size.height

                            var grid = Path()
                            grid.move(to: CGPoint(x: w * 0.5, y: 0))
                            grid.addLine(to: CGPoint(x: w * 0.5, y: h))
                            grid.move(to: CGPoint(x: 0, y: h * 0.5))
                            grid.addLine(to: CGPoint(x: w, y: h * 0.5))
                            ctx.stroke(
                                grid,
                                with: .color(.primary.opacity(0.14)),
                                style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
                            )

                            if isAnimating {
                                for pts in polylines where pts.count >= 2 {
                                    var ghost = Path()
                                    ghost.move(to: CGPoint(x: pts[0].x * w, y: pts[0].y * h))
                                    for pt in pts.dropFirst() {
                                        ghost.addLine(to: CGPoint(x: pt.x * w, y: pt.y * h))
                                    }
                                    ctx.stroke(
                                        ghost,
                                        with: .color(.primary.opacity(0.14)),
                                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                                    )
                                }
                            }
                        }

                        let doneCount = min(completedStrokes, polylines.count)
                        ForEach(0..<doneCount, id: \.self) { idx in
                            let pts = polylines[idx]
                            if pts.count >= 2 {
                                WatchKanjiStrokeShape(points: pts)
                                    .stroke(
                                        Color.primary,
                                        style: StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round)
                                    )
                            }
                        }

                        if let activeIdx = activeStrokeIndex,
                           activeIdx >= 0,
                           activeIdx < polylines.count,
                           polylines[activeIdx].count >= 2 {
                            WatchKanjiStrokeShape(points: polylines[activeIdx])
                                .trim(from: 0, to: activeStrokeProgress)
                                .stroke(
                                    Color.accentColor,
                                    style: StrokeStyle(lineWidth: 3.3, lineCap: .round, lineJoin: .round)
                                )
                        }
                    }
                }
                .padding(8)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if isAnimating, let activeIdx = activeStrokeIndex {
                            Text("\(min(activeIdx + 1, polylines.count))/\(polylines.count)")
                                .font(.system(size: 9, weight: .bold).monospacedDigit())
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(.ultraThinMaterial))
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .padding(4)
                        }
                    }
                }
                .padding(3)
            }
        }
        .frame(width: boxSize, height: boxSize)
    }
}

private struct WatchKanjiDetailView: View {
    @ObservedObject var engine: DaiJishowEngine
    let codepoint: UInt32
    @Binding var path: [WatchDestination]
    let onFocusInFisheye: (UInt32) -> Void

    @State private var hasLoadedFullDetail = false
    @State private var completedStrokes: Int = Int.max
    @State private var activeStrokeIndex: Int?
    @State private var activeStrokeProgress: CGFloat = 1
    @State private var isAnimatingStrokes = false
    @State private var playbackTask: Task<Void, Never>?

    private var kanji: KanjiDetail? {
        if let active = engine.activeKanji, active.codepoint == codepoint {
            return active
        }
        return nil
    }

    var body: some View {
        ScrollView {
            if let kanji {
                let total = kanji.strokePolylines.count
                let isSaved = engine.studyStore.isKanjiSaved(kanji.codepoint)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button {
                            if total > 0 {
                                triggerStrokeAnimation(total: total)
                            }
                        } label: {
                            WatchKanjiStrokeDiagram(
                                glyph: kanji.glyph,
                                polylines: kanji.strokePolylines,
                                completedStrokes: completedStrokes,
                                activeStrokeIndex: activeStrokeIndex,
                                activeStrokeProgress: activeStrokeProgress,
                                isAnimating: isAnimatingStrokes,
                                boxSize: WKInterfaceDevice.current().screenBounds.width < 175 ? 64 : 74
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Animate \(kanji.glyph) strokes")
                        .accessibilityHint("Tap to draw each stroke in order")

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(kanji.glyph)
                                    .font(.title2.bold())
                                Spacer(minLength: 0)
                                Button {
                                    engine.toggleSaveKanji(kanji)
                                } label: {
                                    Image(systemName: isSaved ? "star.fill" : "star")
                                        .foregroundStyle(isSaved ? .yellow : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                            if kanji.strokes > 0 {
                                Text("\(kanji.strokes) strokes")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if kanji.jlpt > 0 {
                                Text("N\(kanji.jlpt)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if total > 0 {
                                Text(isAnimatingStrokes ? "Drawing…" : "Tap box to draw")
                                    .font(.system(size: 10))
                                    .foregroundStyle(isAnimatingStrokes ? Color.accentColor : .secondary)
                            }
                        }
                    }

                    Button {
                        WKInterfaceDevice.current().play(.click)
                        onFocusInFisheye(kanji.codepoint)
                    } label: {
                        Label("Explore in Fisheye", systemImage: "circle.hexagongrid")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    if !kanji.meanings.isEmpty {
                        Text(kanji.meanings)
                            .font(.footnote)
                    }
                    if !kanji.onReadings.isEmpty {
                        Text("On: \(kanji.onReadings.joined(separator: "・"))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !kanji.kunReadings.isEmpty {
                        Text("Kun: \(kanji.kunReadings.joined(separator: "・"))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if !kanji.relatedWords.isEmpty {
                        Divider()
                        Text("Compounds")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(kanji.relatedWords.prefix(8)) { hit in
                            Button {
                                engine.openWordEntry(entryId: hit.id)
                                path.append(.word(hit.id))
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(hit.displayHeadword) (\(hit.kanaHead))")
                                        .font(.caption.weight(.semibold))
                                    Text(hit.primaryGloss)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(kanji?.glyph ?? "Kanji")
        .onAppear {
            if !hasLoadedFullDetail || engine.activeKanji?.codepoint != codepoint {
                hasLoadedFullDetail = true
                engine.openKanjiDetail(codepoint: codepoint, recordHistory: true)
            }
        }
        .onChange(of: codepoint) { _, _ in
            playbackTask?.cancel()
            isAnimatingStrokes = false
            activeStrokeIndex = nil
            activeStrokeProgress = 1
            completedStrokes = Int.max
        }
        .onDisappear {
            playbackTask?.cancel()
            isAnimatingStrokes = false
        }
    }

    private func triggerStrokeAnimation(total: Int) {
        guard total > 0 else { return }
        WKInterfaceDevice.current().play(.click)
        playbackTask?.cancel()
        isAnimatingStrokes = true
        completedStrokes = 0
        activeStrokeIndex = 0
        activeStrokeProgress = 0

        playbackTask = Task {
            let strokeDrawSeconds = total > 12 ? 0.17 : 0.24
            let pauseMs: UInt64 = total > 12 ? 200 : 270
            for idx in 0..<total {
                guard !Task.isCancelled else { return }
                activeStrokeIndex = idx
                activeStrokeProgress = 0
                withAnimation(.easeOut(duration: strokeDrawSeconds)) {
                    activeStrokeProgress = 1
                }
                try? await Task.sleep(for: .milliseconds(pauseMs))
                guard !Task.isCancelled else { return }
                completedStrokes = idx + 1
            }
            activeStrokeIndex = nil
            activeStrokeProgress = 1
            isAnimatingStrokes = false
        }
    }
}

// MARK: - Spatial Digital Crown Fisheye (Mode Cycle + Paging)



private struct WatchMarqueeText: View {
    let text: String
    let font: Font

    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var offsetX: CGFloat = 0

    private struct TaskKey: Equatable {
        let text: String
        let overflowRounded: Int
    }

    private var overflow: CGFloat {
        max(0, textWidth - containerWidth)
    }

    var body: some View {
        Text(" ")
            .font(font)
            .lineLimit(1)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { containerGeo in
                    Color.clear
                        .onAppear { containerWidth = containerGeo.size.width }
                        .onChange(of: containerGeo.size.width) { _, w in containerWidth = w }
                }
            )
            .overlay(alignment: .leading) {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textGeo in
                            Color.clear
                                .onAppear { textWidth = textGeo.size.width }
                                .onChange(of: textGeo.size.width) { _, w in textWidth = w }
                        }
                    )
                    .offset(x: overflow > 1 ? offsetX : 0)
            }
            .clipped()
            .contentShape(Rectangle())
            .task(id: TaskKey(text: text, overflowRounded: Int(overflow.rounded()))) {
                offsetX = 0
                guard overflow > 1 else { return }
                let duration = max(1.6, Double(overflow) / 26.0)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.2))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: duration)) {
                        offsetX = -overflow
                    }
                    try? await Task.sleep(for: .seconds(duration + 1.2))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: duration)) {
                        offsetX = 0
                    }
                    try? await Task.sleep(for: .seconds(duration))
                }
            }
    }
}

private struct WatchCrownFisheyeView: View {
    @ObservedObject var engine: DaiJishowEngine
    @Binding var path: [WatchDestination]
    let onFocusInFisheye: (UInt32) -> Void

    @State private var crownIndex: Double = 0
    @State private var lastCenteredCodepoint: UInt32 = 0
    @State private var pageIndex: Int = 0

    private let pageCapacityPerSide = 5

    private var fisheyeModeLabel: String {
        switch engine.fisheyeMode {
        case DJ_EDGE_COMPONENTS: return "Parts"
        case DJ_EDGE_YOJIJUKUGO: return "Idioms"
        default:                 return "Compounds"
        }
    }

    private var totalPages: Int {
        let rightCount = engine.fisheyeNodes.filter { $0.side == 1 }.count
        let leftCount = engine.fisheyeNodes.filter { $0.side == 0 }.count
        let maxSide = max(rightCount, leftCount)
        return max(1, (maxSide + pageCapacityPerSide - 1) / pageCapacityPerSide)
    }

    private var safePageIndex: Int {
        min(max(pageIndex, 0), max(totalPages - 1, 0))
    }

    /// Clockwise radial ordering for the current page of up to 10 neighbors.
    private var visibleNodes: [FisheyeNode] {
        let allRight = engine.fisheyeNodes.filter { $0.side == 1 }
        let allLeft = engine.fisheyeNodes.filter { $0.side == 0 }
        let start = safePageIndex * pageCapacityPerSide

        let rightSlice = start < allRight.count
            ? Array(allRight[start..<min(start + pageCapacityPerSide, allRight.count)])
            : []
        let leftSlice = start < allLeft.count
            ? Array(allLeft[start..<min(start + pageCapacityPerSide, allLeft.count)].reversed())
            : []
        return rightSlice + leftSlice
    }

    private func normalizedFocusIndex(count: Int) -> Int {
        guard count > 0 else { return 0 }
        let raw = Int(crownIndex.rounded())
        return ((raw % count) + count) % count
    }

    private func cycleFisheyeMode() {
        WKInterfaceDevice.current().play(.click)
        let next: dj_fisheye_mode_t
        switch engine.fisheyeMode {
        case DJ_EDGE_COMPOUNDS:  next = DJ_EDGE_COMPONENTS
        case DJ_EDGE_COMPONENTS: next = DJ_EDGE_YOJIJUKUGO
        default:                 next = DJ_EDGE_COMPOUNDS
        }
        engine.fisheyeMode = next
        pageIndex = 0
        crownIndex = 0
        let cp = engine.activeKanji?.codepoint ?? (engine.recentKanji.first ?? 0x5927)
        engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: 1.35, animated: true)
    }

    private func syncFisheyeIfNeeded() {
        let targetCp = engine.activeKanji?.codepoint ?? (engine.recentKanji.first ?? 0x5927)
        if lastCenteredCodepoint != targetCp || engine.fisheyeNodes.isEmpty {
            lastCenteredCodepoint = targetCp
            pageIndex = 0
            crownIndex = 0
            if engine.activeKanji?.codepoint == targetCp {
                engine.solveFisheye(
                    center: targetCp,
                    hasFocus: false,
                    focusX: 0,
                    focusY: 0,
                    aspectRatio: 1.35,
                    animated: false
                )
            } else {
                engine.openFisheye(codepoint: targetCp, recordHistory: false)
            }
        }
    }

    private var isCompactWatch: Bool {
        WKInterfaceDevice.current().screenBounds.width < 175
    }

    private func layoutMetrics(in size: CGSize) -> (
        rx: CGFloat,
        ry: CGFloat,
        centerDiameter: CGFloat,
        baseNodeDiameter: CGFloat,
        hitMinDiameter: CGFloat,
        isCompactCanvas: Bool
    ) {
        let isCompactCanvas = size.height < 98 || size.width < 175
        let minDim = min(size.width, size.height)
        let centerDiameter = isCompactCanvas
            ? min(36, max(28, size.height * 0.38))
            : min(46, max(36, minDim * 0.30))
        let baseNodeDiameter = isCompactCanvas
            ? min(24, max(19, size.height * 0.25))
            : min(29, max(23, minDim * 0.19))
        let hitMinDiameter: CGFloat = isCompactCanvas ? 26 : 32
        let maxFocusedDiameter = baseNodeDiameter * 1.24
        let safeMaxRx = max(30, ((size.width - maxFocusedDiameter) * 0.5 - 2) / 1.06)
        let safeMaxRy = max(18, ((size.height - maxFocusedDiameter) * 0.5 - 1) / 1.06)
        let rx = min(safeMaxRx, max(isCompactCanvas ? 48 : 44, size.width * 0.38))
        let ry = min(safeMaxRy, max(isCompactCanvas ? 22 : 34, size.height * 0.36))
        return (rx, ry, centerDiameter, baseNodeDiameter, hitMinDiameter, isCompactCanvas)
    }

    private func nodeLayoutPositions(
        in size: CGSize,
        rx: CGFloat,
        ry: CGFloat,
        nodes: [FisheyeNode],
        focusedIndex: Int
    ) -> [CGPoint] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        let rightIndices = nodes.indices.filter { nodes[$0].side == 1 }
        let leftIndices = nodes.indices.filter { nodes[$0].side == 0 }

        var result = Array(repeating: center, count: nodes.count)

        func assignHemisphere(indices: [Int], isRight: Bool) {
            let count = indices.count
            guard count > 0 else { return }
            let span = min(0.78, 0.24 + 0.14 * CGFloat(max(count - 1, 0)))

            let visualOrder = isRight ? indices : Array(indices.reversed())
            let focusedSlot = visualOrder.firstIndex(of: focusedIndex)

            for (slot, globalIdx) in visualOrder.enumerated() {
                let t = count == 1 ? 0.5 : CGFloat(slot) / CGFloat(count - 1)
                var theta = (t - 0.5) * .pi * span

                if let fSlot = focusedSlot, fSlot != slot {
                    let delta = slot - fSlot
                    let sign: CGFloat = delta > 0 ? 1 : -1
                    let proximity = max(0, 1.0 - CGFloat(abs(delta) - 1) * 0.45)
                    theta += sign * 0.085 * proximity
                }

                let dirX: CGFloat = isRight ? cos(theta) : -cos(theta)
                let dirY: CGFloat = sin(theta)
                let radialBoost: CGFloat = (globalIdx == focusedIndex) ? 1.06 : 0.98
                let pt = CGPoint(
                    x: center.x + dirX * rx * radialBoost,
                    y: center.y + dirY * ry * radialBoost
                )
                result[globalIdx] = pt
            }
        }

        assignHemisphere(indices: rightIndices, isRight: true)
        assignHemisphere(indices: leftIndices, isRight: false)
        return result
    }

    var body: some View {
        NavigationStack(path: $path) {
            let nodes = visibleNodes
            let focusedIdx = normalizedFocusIndex(count: nodes.count)
            let focusedNode: FisheyeNode? = nodes.isEmpty ? nil : nodes[focusedIdx]

            ZStack(alignment: .topLeading) {
                Button {
                    cycleFisheyeMode()
                } label: {
                    Text(fisheyeModeLabel)
                        .font(.system(size: isCompactWatch ? 9.5 : 10, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, isCompactWatch ? 5 : 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.22)))
                }
                .buttonStyle(.plain)
                .fixedSize()
                .padding(.leading, isCompactWatch ? 14 : 16)
                .padding(.top, isCompactWatch ? 10 : 12)
                .ignoresSafeArea(.container, edges: .top)
                .zIndex(30)
                .accessibilityLabel("Fisheye mode: \(fisheyeModeLabel)")
                .accessibilityHint("Tap to switch between Compounds, Parts, and Idioms")

                VStack(spacing: isCompactWatch ? 2 : 4) {
                HStack(spacing: 4) {
                    if let center = engine.activeKanji {
                        Button {
                            engine.openKanjiDetail(codepoint: center.codepoint)
                            path.append(.kanji(center.codepoint))
                        } label: {
                            HStack(spacing: 4) {
                                Text(center.glyph)
                                    .font(.caption.bold())
                                    .fixedSize()
                                if !center.meanings.isEmpty {
                                    WatchMarqueeText(
                                        text: center.meanings,
                                        font: .system(size: isCompactWatch ? 11 : 12)
                                    )
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .layoutPriority(0)
                    } else {
                        Spacer(minLength: 0)
                    }

                    if totalPages > 1 {
                        Button {
                            WKInterfaceDevice.current().play(.click)
                            pageIndex = (safePageIndex + 1) % totalPages
                            crownIndex = 0
                        } label: {
                            Text("P\(safePageIndex + 1)/\(totalPages)")
                                .font(.system(size: isCompactWatch ? 9.5 : 10, weight: .medium).monospacedDigit())
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.primary.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .accessibilityLabel("Page \(safePageIndex + 1) of \(totalPages)")
                    } else if !nodes.isEmpty {
                        Text("\(focusedIdx + 1)/\(nodes.count)")
                            .font(.system(size: isCompactWatch ? 9.5 : 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, isCompactWatch ? 5 : 7)

                if nodes.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("No \(fisheyeModeLabel.lowercased())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Switch Mode") {
                            cycleFisheyeMode()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer()
                } else {
                    GeometryReader { geo in
                        let metrics = layoutMetrics(in: geo.size)
                        let centerPt = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        let positions = nodeLayoutPositions(
                            in: geo.size,
                            rx: metrics.rx,
                            ry: metrics.ry,
                            nodes: nodes,
                            focusedIndex: focusedIdx
                        )
                        let centerDiameter = metrics.centerDiameter
                        let baseNodeDiameter = metrics.baseNodeDiameter

                        ZStack {
                            Canvas { ctx, _ in
                                let ovalRect = CGRect(
                                    x: centerPt.x - metrics.rx,
                                    y: centerPt.y - metrics.ry,
                                    width: metrics.rx * 2,
                                    height: metrics.ry * 2
                                )
                                ctx.stroke(
                                    Path(ellipseIn: ovalRect),
                                    with: .color(.primary.opacity(0.08)),
                                    style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
                                )

                                for idx in nodes.indices {
                                    let isFocused = (idx == focusedIdx)
                                    var spoke = Path()
                                    spoke.move(to: centerPt)
                                    spoke.addLine(to: positions[idx])
                                    ctx.stroke(
                                        spoke,
                                        with: .color(nodes[idx].tierColor.opacity(isFocused ? 0.72 : 0.18)),
                                        style: StrokeStyle(lineWidth: isFocused ? 2.0 : 0.9, lineCap: .round)
                                    )
                                }
                            }

                            ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                                let isFocused = (idx == focusedIdx)
                                let diameter = isFocused ? baseNodeDiameter * 1.24 : baseNodeDiameter * 0.92
                                let glyphSize: CGFloat = metrics.isCompactCanvas
                                    ? (isFocused ? 14 : 11)
                                    : (isFocused ? 17 : 13)
                                let hitSize = max(diameter, metrics.hitMinDiameter)
                                Button {
                                    WKInterfaceDevice.current().play(.click)
                                    if isFocused {
                                        crownIndex = 0
                                        pageIndex = 0
                                        lastCenteredCodepoint = node.codepoint
                                        engine.openFisheye(codepoint: node.codepoint)
                                    } else {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            crownIndex = Double(idx)
                                        }
                                    }
                                } label: {
                                    Text(node.glyph)
                                        .font(.system(size: glyphSize, weight: isFocused ? .bold : .semibold))
                                        .foregroundStyle(.primary)
                                        .frame(width: diameter, height: diameter)
                                        .background(
                                            Circle()
                                                .fill(node.tierColor.opacity(isFocused ? 0.42 : 0.18))
                                                .overlay(
                                                    Circle().strokeBorder(
                                                        isFocused ? node.tierColor : node.tierColor.opacity(0.48),
                                                        lineWidth: isFocused ? 2.0 : 1.0
                                                    )
                                                )
                                        )
                                        .shadow(
                                            color: isFocused ? node.tierColor.opacity(0.45) : .clear,
                                            radius: isFocused ? 5 : 0
                                        )
                                        .frame(width: hitSize, height: hitSize)
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .opacity(isFocused ? 1.0 : 0.82)
                                .zIndex(isFocused ? 10 : 1)
                                .position(positions[idx])
                                .accessibilityLabel("\(node.glyph), \(node.compoundWord)")
                                .accessibilityHint(isFocused ? "Tap again to center on \(node.glyph)" : "Tap to focus")
                            }

                            if let centerKanji = engine.activeKanji {
                                Button {
                                    WKInterfaceDevice.current().play(.click)
                                    engine.openKanjiDetail(codepoint: centerKanji.codepoint)
                                    path.append(.kanji(centerKanji.codepoint))
                                } label: {
                                    Text(centerKanji.glyph)
                                        .font(.system(size: centerDiameter < 34 ? 17 : 22, weight: .bold))
                                        .frame(width: centerDiameter, height: centerDiameter)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    Circle().strokeBorder(Color.accentColor.opacity(0.85), lineWidth: 1.75)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .zIndex(20)
                                .position(centerPt)
                                .accessibilityLabel("\(centerKanji.glyph), center kanji")
                                .accessibilityHint("Tap to open details and stroke order")
                            }
                        }
                    }
                    .focusable()
                    .digitalCrownRotation(
                        $crownIndex,
                        from: 0,
                        through: Double(max(nodes.count - 1, 1)),
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: nodes.count > 1,
                        isHapticFeedbackEnabled: true
                    )

                    if let node = focusedNode {
                        HStack(spacing: 6) {
                            Button {
                                if node.topEntryId > 0 {
                                    engine.openWordEntry(entryId: node.topEntryId)
                                    path.append(.word(node.topEntryId))
                                } else {
                                    crownIndex = 0
                                    pageIndex = 0
                                    lastCenteredCodepoint = node.codepoint
                                    engine.openFisheye(codepoint: node.codepoint)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 5) {
                                        Text(node.compoundWord)
                                            .font(.caption.weight(.bold))
                                            .lineLimit(1)
                                        if !node.compoundKana.isEmpty {
                                            Text(node.compoundKana)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 2)
                                        Text(node.shareText)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(node.tierColor)
                                    }
                                    if !node.compoundGloss.isEmpty {
                                        Text(node.compoundGloss)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, isCompactWatch ? 7 : 8)
                                .padding(.vertical, isCompactWatch ? 4 : 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(node.tierColor.opacity(0.16))
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                WKInterfaceDevice.current().play(.click)
                                crownIndex = 0
                                pageIndex = 0
                                lastCenteredCodepoint = node.codepoint
                                engine.openFisheye(codepoint: node.codepoint)
                            } label: {
                                Image(systemName: "scope")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(node.tierColor)
                                    .frame(width: isCompactWatch ? 28 : 30, height: isCompactWatch ? 32 : 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(node.tierColor.opacity(0.20))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Center Fisheye on \(node.glyph)")
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                syncFisheyeIfNeeded()
            }
            .onChange(of: engine.activeKanji?.codepoint) { _, _ in
                syncFisheyeIfNeeded()
            }
            .navigationDestination(for: WatchDestination.self) { dest in
                watchDestinationView(
                    for: dest,
                    engine: engine,
                    path: $path,
                    onFocusInFisheye: onFocusInFisheye
                )
            }
        }
    }
}

// MARK: - Decks, Flashcard Review & Credits

private struct WatchDecksView: View {
    @ObservedObject var engine: DaiJishowEngine
    @Binding var path: [WatchDestination]
    let onFocusInFisheye: (UInt32) -> Void

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Quick Study") {
                    Button {
                        let sample = engine.fetchRandomWords(count: 10, maxFreqRank: 2500)
                            .map { engine.studyItem(for: $0) }
                        if !sample.isEmpty {
                            WKInterfaceDevice.current().play(.click)
                            path.append(.flashcards(title: "Core 10", items: sample))
                        }
                    } label: {
                        Label("Core 10 Flashcards", systemImage: "rectangle.stack.fill")
                            .font(.caption.weight(.semibold))
                    }
                }

                ForEach(engine.studyStore.decks) { deck in
                    Section("\(deck.name) (\(deck.items.count))") {
                        if deck.items.isEmpty {
                            Text("Star words or kanji to add cards")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Button {
                                WKInterfaceDevice.current().play(.click)
                                path.append(.flashcards(title: deck.name, items: deck.items))
                            } label: {
                                Label("Study Cards (\(deck.items.count))", systemImage: "play.rectangle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            ForEach(deck.items.prefix(25)) { item in
                                Button {
                                    if item.kind == .word {
                                        engine.openWordEntry(entryId: item.targetId)
                                        path.append(.word(item.targetId))
                                    } else {
                                        engine.openKanjiDetail(codepoint: item.targetId)
                                        path.append(.kanji(item.targetId))
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.headword)
                                            .font(.headline)
                                        Text(item.gloss)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Credits & Licenses") {
                    Text("Code: MIT • Corpus: JMdict, JMnedict, KANJIDIC2, Kanjium (CC BY-SA 4.0), KanjiVG (CC BY-SA 3.0), Tatoeba (CC BY 2.0).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Decks")
            .navigationDestination(for: WatchDestination.self) { dest in
                watchDestinationView(
                    for: dest,
                    engine: engine,
                    path: $path,
                    onFocusInFisheye: onFocusInFisheye
                )
            }
        }
    }
}

private struct WatchDeckFlashcardsView: View {
    @ObservedObject var engine: DaiJishowEngine
    let deckTitle: String
    let initialItems: [StudySavedItem]
    @Binding var path: [WatchDestination]

    @State private var queue: [StudySavedItem]
    @State private var currentIndex: Int = 0
    @State private var isRevealed: Bool = false
    @State private var reviewedCount: Int = 0
    @State private var againCount: Int = 0

    init(
        engine: DaiJishowEngine,
        deckTitle: String,
        initialItems: [StudySavedItem],
        path: Binding<[WatchDestination]>
    ) {
        self.engine = engine
        self.deckTitle = deckTitle
        self.initialItems = initialItems
        self._path = path
        self._queue = State(initialValue: initialItems)
    }

    var body: some View {
        VStack(spacing: 8) {
            if queue.isEmpty {
                Text("No cards to review")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if currentIndex >= queue.count {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Session Complete")
                    .font(.headline)
                Text("\(reviewedCount) cards • \(againCount) repeated")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Study Again") {
                    WKInterfaceDevice.current().play(.click)
                    queue = initialItems
                    currentIndex = 0
                    isRevealed = false
                    reviewedCount = 0
                    againCount = 0
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Spacer()
            } else {
                let item = queue[currentIndex]

                HStack {
                    Text("\(currentIndex + 1)/\(queue.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if SpeechEngine.shared.japaneseVoiceAvailable {
                        Button {
                            let spoken = item.reading.isEmpty ? item.headword : item.reading
                            SpeechEngine.shared.speak(spoken)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        if item.kind == .word {
                            engine.openWordEntry(entryId: item.targetId)
                            path.append(.word(item.targetId))
                        } else {
                            engine.openKanjiDetail(codepoint: item.targetId)
                            path.append(.kanji(item.targetId))
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Inspect \(item.headword)")
                }
                .padding(.horizontal, 4)

                Button {
                    WKInterfaceDevice.current().play(.click)
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isRevealed.toggle()
                    }
                } label: {
                    ScrollView {
                        VStack(spacing: 6) {
                            Text(item.headword)
                                .font(.system(size: 28, weight: .bold))
                                .minimumScaleFactor(0.55)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            if isRevealed {
                                if !item.reading.isEmpty && item.reading != item.headword {
                                    Text(item.reading)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .multilineTextAlignment(.center)
                                }
                                if !item.formattedPitch.isEmpty {
                                    Text(item.formattedPitch)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                                }
                                if !item.gloss.isEmpty {
                                    Text(item.gloss)
                                        .font(.footnote)
                                        .multilineTextAlignment(.center)
                                }
                            } else {
                                Text("Tap to reveal")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isRevealed ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.09))
                    )
                }
                .buttonStyle(.plain)

                if isRevealed {
                    HStack(spacing: 6) {
                        Button {
                            WKInterfaceDevice.current().play(.directionDown)
                            queue.append(item)
                            againCount += 1
                            reviewedCount += 1
                            currentIndex += 1
                            isRevealed = false
                        } label: {
                            Text("Again")
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            WKInterfaceDevice.current().play(.success)
                            reviewedCount += 1
                            currentIndex += 1
                            isRevealed = false
                        } label: {
                            Text("Got It")
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .navigationTitle(deckTitle)
    }
}
