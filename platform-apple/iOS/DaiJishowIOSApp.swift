import SwiftUI
import DaiJishowCore
import DaiJishowMorph

@main
struct DaiJishowIOSApp: App {
    @StateObject private var engine: DaiJishowEngine

    init() {
        let resolvedPath = DatabaseLocator.locateDatabasePath()
        _engine = StateObject(wrappedValue: DaiJishowEngine(dbPath: resolvedPath))
    }

    var body: some Scene {
        WindowGroup {
            IOSRootView(engine: engine)
                .preferredColorScheme(engine.appearanceMode.colorScheme)
        }
    }
}

private enum IOSTab: Hashable {
    case search
    case explore
    case decks
    case settings
}

struct IOSRootView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var selectedTab: IOSTab = .search
    @State private var searchPath: [IOSDetailDestination] = []

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            DJTheme.workspaceBackground(
                for: colorScheme,
                reduceTransparency: reduceTransparency,
                highContrast: contrast == .increased
            )
            .ignoresSafeArea()

            if !engine.isReady {
                missingDatabaseBanner
            } else {
                TabView(selection: $selectedTab) {
                    IOSSearchTab(engine: engine, path: $searchPath)
                        .tabItem {
                            Label("Dictionary", systemImage: "magnifyingglass")
                        }
                        .tag(IOSTab.search)

                    IOSExploreHubView(
                        engine: engine,
                        onOpenWord: { entryId in
                            engine.openWordEntry(entryId: entryId)
                            searchPath.append(.word(entryId))
                            selectedTab = .search
                        },
                        onOpenKanji: { codepoint in
                            engine.openKanjiDetail(codepoint: codepoint)
                            searchPath.append(.kanji(codepoint))
                            selectedTab = .search
                        }
                    )
                    .tabItem {
                        Label("Explore", systemImage: "circle.hexagongrid")
                    }
                    .tag(IOSTab.explore)

                    IOSStudyDecksTab(
                        engine: engine,
                        onOpenItem: { item in
                            switch item.kind {
                            case .word:
                                engine.openWordEntry(entryId: item.targetId)
                                searchPath.append(.word(item.targetId))
                            case .kanji:
                                engine.openKanjiDetail(codepoint: item.targetId)
                                searchPath.append(.kanji(item.targetId))
                            }
                            selectedTab = .search
                        }
                    )
                    .tabItem {
                        Label("Decks", systemImage: "books.vertical")
                    }
                    .tag(IOSTab.decks)

                    IOSSettingsTab(engine: engine)
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .tag(IOSTab.settings)
                }
            }
        }
    }

    private var missingDatabaseBanner: some View {
        VStack(spacing: 14) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text("Offline Corpus Not Found")
                .font(.title3.bold())
            Text("Build daijishow.db with tools/corpus-builder/build_corpus.py and bundle it with the app target.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding()
    }
}

enum IOSDetailDestination: Hashable {
    case word(UInt32)
    case kanji(UInt32)
}

// MARK: - Search Tab

private struct IOSSearchTab: View {
    @ObservedObject var engine: DaiJishowEngine
    @Binding var path: [IOSDetailDestination]

    private var hasQuery: Bool {
        !engine.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !engine.recentKanji.isEmpty {
                    Section("Recent Kanji") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(engine.recentKanji, id: \.self) { cp in
                                    if let scalar = UnicodeScalar(cp) {
                                        Button {
                                            engine.openKanjiDetail(codepoint: cp)
                                            path.append(.kanji(cp))
                                        } label: {
                                            Text(String(Character(scalar)))
                                                .font(.title2.weight(.medium))
                                                .frame(width: 44, height: 44)
                                                .background(Circle().fill(Color.accentColor.opacity(0.14)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    Toggle("Include Proper Names (人名)", isOn: Binding(
                        get: { engine.includeNames },
                        set: { engine.setNamesIncluded($0, userInitiated: true) }
                    ))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SearchFilter.allCases) { filter in
                                let active = engine.searchFilters.contains(filter)
                                Button {
                                    if active {
                                        engine.searchFilters.remove(filter)
                                    } else {
                                        engine.searchFilters.insert(filter)
                                    }
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(active ? Color.accentColor : Color.secondary.opacity(0.16))
                                        )
                                        .foregroundStyle(active ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if hasQuery {
                    let results = engine.filteredSearchResults
                    Section("Matches (\(results.count))") {
                        if results.isEmpty {
                            Text("No Japanese entries matched \"\(engine.searchQuery)\".")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(results) { hit in
                                Button {
                                    engine.openWordEntry(entryId: hit.id)
                                    path.append(.word(hit.id))
                                } label: {
                                    IOSWordHitRow(hit: hit, engine: engine)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !engine.englishMatches.isEmpty {
                        Section("Also in English Glosses") {
                            ForEach(engine.englishMatches) { hit in
                                Button {
                                    engine.openWordEntry(entryId: hit.id)
                                    path.append(.word(hit.id))
                                } label: {
                                    IOSWordHitRow(hit: hit, engine: engine)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Section("Explore") {
                        Text("Search by kanji, hiragana, katakana, romaji, or English gloss above.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Dai-Jishow")
            .searchable(text: $engine.searchQuery, prompt: "Kanji, kana, romaji, or English")
            .onChange(of: engine.searchQuery) { _, _ in
                engine.performSearch()
            }
            .navigationDestination(for: IOSDetailDestination.self) { dest in
                switch dest {
                case .word(let entryId):
                    IOSWordEntryView(
                        engine: engine,
                        entryId: entryId,
                        onOpenWord: { nextId in
                            engine.openWordEntry(entryId: nextId)
                            path.append(.word(nextId))
                        },
                        onOpenKanji: { cp in
                            engine.openKanjiDetail(codepoint: cp)
                            path.append(.kanji(cp))
                        }
                    )
                case .kanji(let codepoint):
                    IOSKanjiDetailView(
                        engine: engine,
                        codepoint: codepoint,
                        onOpenWord: { nextId in
                            engine.openWordEntry(entryId: nextId)
                            path.append(.word(nextId))
                        },
                        onOpenFisheye: { cp in
                            engine.openFisheye(codepoint: cp)
                        }
                    )
                }
            }
        }
    }
}

struct IOSWordHitRow: View {
    let hit: WordHit
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(hit.displayHeadword)
                    .font(.headline)
                if !hit.kanaHead.isEmpty && hit.kanaHead != hit.displayHeadword {
                    Text(hit.kanaHead)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if engine.studyStore.isWordSaved(hit.id) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                if hit.isName {
                    Text("Name")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                }
            }
            Text(hit.primaryGloss)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Study Decks Tab

private struct IOSStudyDecksTab: View {
    @ObservedObject var engine: DaiJishowEngine
    let onOpenItem: (StudySavedItem) -> Void

    @State private var newDeckName = ""
    @State private var showNewDeckAlert = false

    private var selectedDeck: StudyDeck {
        if let id = engine.studyStore.selectedDeckId,
           let deck = engine.studyStore.decks.first(where: { $0.id == id }) {
            return deck
        }
        return engine.studyStore.defaultDeck
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Decks") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(engine.studyStore.decks) { deck in
                                let active = deck.id == selectedDeck.id
                                Button {
                                    engine.studyStore.selectedDeckId = deck.id
                                } label: {
                                    Text("\(deck.name) (\(deck.items.count))")
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule().fill(active ? Color.accentColor : Color.secondary.opacity(0.16))
                                        )
                                        .foregroundStyle(active ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Export \(selectedDeck.name)") {
                    let tsv = engine.studyStore.exportDeckText(deckId: selectedDeck.id, format: .ankiTSV)
                    let csv = engine.studyStore.exportDeckText(deckId: selectedDeck.id, format: .csv)

                    ShareLink(
                        item: tsv,
                        preview: SharePreview("\(selectedDeck.name).tsv", icon: Image(systemName: "square.and.arrow.up"))
                    ) {
                        Label("Share Flashcard TSV (Anki-compatible)", systemImage: "doc.plaintext")
                    }
                    .disabled(selectedDeck.items.isEmpty)

                    ShareLink(
                        item: csv,
                        preview: SharePreview("\(selectedDeck.name).csv", icon: Image(systemName: "tablecells"))
                    ) {
                        Label("Share CSV (RFC-4180)", systemImage: "tablecells")
                    }
                    .disabled(selectedDeck.items.isEmpty)
                }

                Section("Saved Items (\(selectedDeck.items.count))") {
                    if selectedDeck.items.isEmpty {
                        Text("Tap the star button on any word or kanji to add it to this deck.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedDeck.items) { item in
                            Button {
                                onOpenItem(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(item.headword)
                                            .font(.headline)
                                        if !item.reading.isEmpty {
                                            Text(item.reading)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(item.kind == .word ? "Word" : "Kanji")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(item.gloss)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for idx in offsets {
                                let item = selectedDeck.items[idx]
                                engine.studyStore.removeItem(id: item.id, fromDeck: selectedDeck.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Study Decks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewDeckAlert = true
                    } label: {
                        Label("New Deck", systemImage: "plus")
                    }
                }
            }
            .alert("Create Deck", isPresented: $showNewDeckAlert) {
                TextField("Deck name", text: $newDeckName)
                Button("Create") {
                    engine.studyStore.createDeck(named: newDeckName)
                    newDeckName = ""
                }
                Button("Cancel", role: .cancel) {
                    newDeckName = ""
                }
            }
        }
    }
}

// MARK: - Settings & About Tab

private struct IOSSettingsTab: View {
    @ObservedObject var engine: DaiJishowEngine

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, let build, short != build {
            return "\(short) (build \(build))"
        }
        return short ?? build ?? "0.2.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance & Recall") {
                    Picker("Appearance", selection: $engine.appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    Picker("Recall Mode", selection: $engine.recallMode) {
                        ForEach(RecallMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                Section("Spatial Fisheye") {
                    Stepper("Max per hemisphere: \(engine.maxFisheyePerSide)", value: $engine.maxFisheyePerSide, in: 4...30)
                    Toggle("Show compound share percentages", isOn: $engine.showFisheyePercentages)
                }

                Section("About Dai-Jishow") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    Text("App code is licensed under MIT. The bundled offline corpus (daijishow.db) is separately licensed under Creative Commons BY-SA / BY licenses.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Corpus Attributions & Licenses") {
                    ForEach(DaiJishowCredits.sources) { credit in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(credit.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                if let licenseURL = URL(string: credit.licenseURL) {
                                    Link(credit.license, destination: licenseURL)
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            Text(credit.attribution)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(credit.role)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let siteURL = URL(string: credit.url) {
                                Link("Upstream notice & documentation", destination: siteURL)
                                    .font(.caption2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
