import SwiftUI
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
}

struct WatchRootView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var selectedPage: WatchPage = .search
    @State private var path: [WatchDestination] = []

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
                WatchSearchView(engine: engine, path: $path)
                    .tag(WatchPage.search)

                WatchCrownFisheyeView(
                    engine: engine,
                    onOpenWord: { id in
                        engine.openWordEntry(entryId: id)
                        path.append(.word(id))
                        selectedPage = .search
                    },
                    onOpenKanji: { cp in
                        engine.openKanjiDetail(codepoint: cp)
                        path.append(.kanji(cp))
                        selectedPage = .search
                    }
                )
                .tag(WatchPage.fisheye)

                WatchDecksView(
                    engine: engine,
                    onOpenWord: { id in
                        engine.openWordEntry(entryId: id)
                        path.append(.word(id))
                        selectedPage = .search
                    },
                    onOpenKanji: { cp in
                        engine.openKanjiDetail(codepoint: cp)
                        path.append(.kanji(cp))
                        selectedPage = .search
                    }
                )
                .tag(WatchPage.decks)
            }
            .tabViewStyle(.page)
        }
    }
}

// MARK: - Search & Detail Stack

private struct WatchSearchView: View {
    @ObservedObject var engine: DaiJishowEngine
    @Binding var path: [WatchDestination]

    private var hasQuery: Bool {
        !engine.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !engine.recentKanji.isEmpty && !hasQuery {
                    Section("Recent Kanji") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(engine.recentKanji, id: \.self) { cp in
                                    if let scalar = UnicodeScalar(cp) {
                                        Button {
                                            engine.openKanjiDetail(codepoint: cp)
                                            path.append(.kanji(cp))
                                        } label: {
                                            Text(String(Character(scalar)))
                                                .font(.title3.bold())
                                                .frame(width: 36, height: 36)
                                                .background(Circle().fill(Color.accentColor.opacity(0.2)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }

                if hasQuery {
                    if engine.searchResults.isEmpty {
                        Text("No matches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
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
                } else {
                    Section("Quick Actions") {
                        NavigationLink(value: WatchDestination.kanji(engine.recentKanji.first ?? 0x5927)) {
                            Label("Current Kanji", systemImage: "character.ja")
                        }
                    }
                }
            }
            .navigationTitle("Dai-Jishow")
            .searchable(text: $engine.searchQuery, prompt: "Search")
            .onChange(of: engine.searchQuery) { _, _ in
                engine.performSearch()
            }
            .navigationDestination(for: WatchDestination.self) { dest in
                switch dest {
                case .word(let entryId):
                    WatchWordDetailView(engine: engine, entryId: entryId, path: $path)
                case .kanji(let codepoint):
                    WatchKanjiDetailView(engine: engine, codepoint: codepoint, path: $path)
                }
            }
        }
    }
}

private struct WatchWordDetailView: View {
    @ObservedObject var engine: DaiJishowEngine
    let entryId: UInt32
    @Binding var path: [WatchDestination]

    private var entry: EntryDetail? {
        if let active = engine.activeEntry, active.header.id == entryId {
            return active
        }
        return engine.fetchEntryDetail(entryId)
    }

    var body: some View {
        ScrollView {
            if let entry {
                let insights = engine.activeWordInsights?.entryId == entry.header.id ? engine.activeWordInsights : nil
                let isSaved = engine.studyStore.isWordSaved(entry.header.id)
                let isNoun = (entry.header.posMask & (1 << 0)) != 0

                VStack(alignment: .leading, spacing: 10) {
                    if !entry.header.kanaHead.isEmpty && entry.header.kanaHead != entry.header.displayHeadword {
                        Text(entry.header.kanaHead)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.header.displayHeadword)
                        .font(.title2.bold())

                    if let contour = PitchAccentContour.build(
                        kana: entry.header.kanaHead,
                        pitchAccent: entry.header.pitchAccent,
                        showParticle: isNoun
                    ) {
                        Text("\(contour.patternName) • \(contour.patternSublabel)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    HStack(spacing: 8) {
                        Button {
                            let text = entry.header.kanaHead.isEmpty ? entry.header.displayHeadword : entry.header.kanaHead
                            SpeechEngine.shared.speak(text)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                        }
                        .disabled(!SpeechEngine.shared.japaneseVoiceAvailable)

                        Button {
                            engine.toggleSaveWord(entry, insights: insights)
                        } label: {
                            Image(systemName: isSaved ? "star.fill" : "star")
                                .foregroundStyle(isSaved ? .yellow : .primary)
                        }
                    }

                    ForEach(Array(entry.senses.prefix(4).enumerated()), id: \.element.id) { idx, sense in
                        if !sense.enGlosses.isEmpty {
                            Text("\(idx + 1). \(sense.enGlosses)")
                                .font(.footnote)
                        }
                    }

                    if let insights, !insights.kanjiDNA.isEmpty {
                        Divider()
                        HStack(spacing: 6) {
                            ForEach(insights.kanjiDNA) { dna in
                                Button(dna.glyph) {
                                    engine.openKanjiDetail(codepoint: dna.codepoint)
                                    path.append(.kanji(dna.codepoint))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
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

private struct WatchKanjiDetailView: View {
    @ObservedObject var engine: DaiJishowEngine
    let codepoint: UInt32
    @Binding var path: [WatchDestination]

    private var kanji: KanjiDetail? {
        if let active = engine.activeKanji, active.codepoint == codepoint {
            return active
        }
        return nil
    }

    var body: some View {
        ScrollView {
            if let kanji {
                let isSaved = engine.studyStore.isKanjiSaved(kanji.codepoint)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Canvas { ctx, size in
                            let w = size.width
                            let h = size.height
                            for pts in kanji.strokePolylines where pts.count >= 2 {
                                var p = Path()
                                p.move(to: CGPoint(x: pts[0].x * w, y: pts[0].y * h))
                                for pt in pts.dropFirst() {
                                    p.addLine(to: CGPoint(x: pt.x * w, y: pt.y * h))
                                }
                                ctx.stroke(p, with: .color(.primary), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            }
                        }
                        .frame(width: 64, height: 64)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.08)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(kanji.glyph)
                                .font(.title2.bold())
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
                        }

                        Spacer()
                        Button {
                            engine.toggleSaveKanji(kanji)
                        } label: {
                            Image(systemName: isSaved ? "star.fill" : "star")
                                .foregroundStyle(isSaved ? .yellow : .primary)
                        }
                        .buttonStyle(.plain)
                    }

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
                .padding(.horizontal, 4)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(kanji?.glyph ?? "Kanji")
        .onAppear {
            if engine.activeKanji?.codepoint != codepoint {
                engine.openKanjiDetail(codepoint: codepoint, recordHistory: false)
            }
        }
    }
}

// MARK: - Digital Crown Fisheye Neighbor Dial

private struct WatchCrownFisheyeView: View {
    @ObservedObject var engine: DaiJishowEngine
    let onOpenWord: (UInt32) -> Void
    let onOpenKanji: (UInt32) -> Void

    @State private var crownIndex: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                if let center = engine.activeKanji {
                    Button {
                        onOpenKanji(center.codepoint)
                    } label: {
                        HStack(spacing: 6) {
                            Text(center.glyph)
                                .font(.title2.bold())
                            Text("Fisheye")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if engine.fisheyeNodes.isEmpty {
                    Text("No compound neighbors")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    let clampedIdx = min(max(Int(crownIndex.rounded()), 0), engine.fisheyeNodes.count - 1)
                    let node = engine.fisheyeNodes[clampedIdx]

                    VStack(spacing: 4) {
                        Text(node.compoundWord)
                            .font(.title3.bold())
                        Text(node.compoundKana)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(node.compoundGloss)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            if node.topEntryId > 0 {
                                Button("Word") {
                                    onOpenWord(node.topEntryId)
                                }
                                .buttonStyle(.borderedProminent)
                                .font(.caption2)
                            }
                            Button("Center \(node.glyph)") {
                                crownIndex = 0
                                engine.openFisheye(codepoint: node.codepoint)
                            }
                            .buttonStyle(.bordered)
                            .font(.caption2)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(node.tierColor.opacity(0.16)))
                    .focusable()
                    .digitalCrownRotation(
                        $crownIndex,
                        from: 0,
                        through: Double(max(engine.fisheyeNodes.count - 1, 0)),
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )

                    Text("\(clampedIdx + 1) / \(engine.fisheyeNodes.count) • Turn Crown")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .navigationTitle("Fisheye")
            .onAppear {
                if engine.fisheyeNodes.isEmpty {
                    let cp = engine.activeKanji?.codepoint ?? (engine.recentKanji.first ?? 0x5927)
                    engine.openFisheye(codepoint: cp, recordHistory: false)
                }
            }
        }
    }
}

// MARK: - Decks & Credits

private struct WatchDecksView: View {
    @ObservedObject var engine: DaiJishowEngine
    let onOpenWord: (UInt32) -> Void
    let onOpenKanji: (UInt32) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(engine.studyStore.decks) { deck in
                    Section("\(deck.name) (\(deck.items.count))") {
                        if deck.items.isEmpty {
                            Text("Empty deck")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(deck.items.prefix(25)) { item in
                                Button {
                                    if item.kind == .word {
                                        onOpenWord(item.targetId)
                                    } else {
                                        onOpenKanji(item.targetId)
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
        }
    }
}
