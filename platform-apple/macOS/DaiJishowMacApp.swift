import SwiftUI
#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // Adopt the app's own icon (bundled AppIcon.icns) so the Dock and the
        // window controls show the Dai-Jishow mark instead of the generic
        // executable icon. No-op when running the bare dev binary (no bundle).
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }

        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
import DaiJishowCore

@main
struct DaiJishowMacApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var engine: DaiJishowEngine

    init() {
        let resolvedPath = Self.locateDatabasePath()
        _engine = StateObject(wrappedValue: DaiJishowEngine(dbPath: resolvedPath))
    }

    var body: some Scene {
        // A single, non-tabbing window. `Window` (not `WindowGroup`) stops ⌘N
        // from spawning mirror windows ("double vision") and removes the native
        // tab bar — the engine is a single shared instance, so one window is
        // all this app needs.
        Window("Dai-Jishow", id: "main") {
            MainWorkspaceView(engine: engine)
                .frame(minWidth: 820, minHeight: 560)
                .preferredColorScheme(.dark)
                .sheet(isPresented: $engine.showAbout) {
                    AboutView(engine: engine)
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 880)
        #endif
        .commands {
            // Standard Mac "About" chrome — replace the empty default panel with
            // our credits / source-license sheet.
            CommandGroup(replacing: .appInfo) {
                Button("About Dai-Jishow") {
                    engine.showAbout = true
                }
            }

            CommandGroup(after: .toolbar) {
                Button("Open Navigation Deck (Z-Stack)") {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                        if engine.isZStackOpen {
                            engine.isZStackOpen = false
                        } else {
                            engine.openHistoryStack()
                        }
                    }
                }
                .keyboardShortcut("\\", modifiers: [.command])

                Button("Toggle Detailed / Reader Mode") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        engine.isWordCockpitExpanded.toggle()
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(engine.activeScreen != .wordEntry)

                Button("Focus Search") {
                    NotificationCenter.default.post(name: .daiJishowFocusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button("Toggle Bookmark") {
                    engine.toggleSaveCurrentScreen()
                }
                .keyboardShortcut("b", modifiers: [.command])
                .disabled(engine.activeScreen != .wordEntry && engine.activeScreen != .kanjiDetail && engine.activeScreen != .fisheye)

                Divider()

                Button("Recall Mode: Full") {
                    engine.recallMode = .full
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Recall Mode: Hide Kana") {
                    engine.recallMode = .hideKana
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Recall Mode: Hide Defn.") {
                    engine.recallMode = .hideGloss
                }
                .keyboardShortcut("3", modifiers: [.command])

                Divider()

                Button("Open Kanji Fisheye") {
                    let cp = engine.activeKanji?.codepoint ?? engine.recentKanji.first ?? 0x5927
                    engine.openFisheye(codepoint: cp)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Open Saved Decks") {
                    engine.openStudyLibrary()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Open Kanji Index") {
                    engine.openKanjiLookup()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Open 7-Slot Radical Builder") {
                    engine.openRadicalBuilder()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Open Word Cloud") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        engine.openWordCosmos()
                    }
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])

                // "Open Compounds" opens the Compound Kanji screen (decompose a word into
                // its kanji). ⌘⇧D — mnemonic for "Decompose" — since ⌘⇧C is the
                // Detailed/Reader toggle and ⌘⌥C is Copy Entry, both C-shortcuts taken.
                Button("Open Compounds") {
                    engine.openCompoundKanji()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Navigate Back") {
                    engine.goBack()
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!engine.canGoBack)

                Button("Navigate Forward") {
                    engine.goForward()
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!engine.canGoForward)

                Divider()

                // ⌘⇧C is the Cockpit toggle, so "Copy Entry" takes ⌘⌥C instead.
                // Native ⌘C still copies any text the user has selected.
                Button("Copy Entry") {
                    engine.copyActiveEntry()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(engine.activeEntry == nil && engine.activeKanji == nil)
            }
        }

        // Preferences (⌘,). Shares the single engine instance, so edits apply
        // live across the whole app.
        Settings {
            SettingsView(engine: engine)
                .preferredColorScheme(.dark)
        }
    }

    private static func locateDatabasePath() -> String {
        if let bundlePath = Bundle.main.path(forResource: "daijishow", ofType: "db") {
            return bundlePath
        }
        let candidates = [
            "daijishow.db",
            "build/daijishow.db",
            "../data/daijishow.db",
            "../../data/daijishow.db"
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return "daijishow.db"
    }
}

extension Notification.Name {
    static let daiJishowFocusSearch = Notification.Name("DaiJishowFocusSearch")
}

// MARK: - Main Workspace & Persistent Glass Top Bar

struct MainWorkspaceView: View {
    @ObservedObject var engine: DaiJishowEngine
    @FocusState private var isSearchFocused: Bool

    /// Measured width of the top nav bar; drives `navCompact` so the screen
    /// buttons drop to icon-only when the window is too narrow to show labels on one line.
    @State private var navBarWidth: CGFloat = 0

    /// Below this bar width the screen buttons crunch to icons (a tooltip keeps
    /// each one self-documenting). Tunable; sized for the top-bar navigation buttons.
    private var navCompact: Bool { isRowCompact(navBarWidth, threshold: 1560) }

    private var isSearchDropdownOpen: Bool {
        (!engine.searchResults.isEmpty || !engine.englishMatches.isEmpty)
            && !engine.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.12),
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.07, green: 0.09, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topNavigationBar
                    .zIndex(20)

                ZStack {
                    if !engine.isReady {
                        databaseMissingBanner
                    } else {
                        switch engine.activeScreen {
                        case .fisheye:
                            FisheyeGraphView(engine: engine)
                        case .wordEntry:
                            if let entry = engine.activeEntry {
                                WordEntryView(engine: engine, entry: entry)
                            }
                        case .kanjiDetail:
                            if let kanji = engine.activeKanji {
                                KanjiDetailView(engine: engine, kanji: kanji)
                            }
                        case .radicalBuilder:
                            RadicalBuilderView(engine: engine)
                        case .kanjiLookup:
                            KanjiLookupView(engine: engine)
                        case .wordCosmos:
                            WordCosmosView(engine: engine)
                        case .compoundKanji:
                            CompoundKanjiView(engine: engine)
                        case .studyLibrary:
                            StudyLibraryView(engine: engine, studyStore: engine.studyStore)
                        }
                    }

                    if isSearchDropdownOpen {
                        searchResultsDropdown
                    }
                }

                if !engine.history.isEmpty {
                    breadcrumbViewer
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .zIndex(10)
                }
            }

            if engine.isZStackOpen {
                ZStackHistoryOverlay(engine: engine)
                    .zIndex(50)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .daiJishowFocusSearch)) { _ in
            if engine.activeScreen != .compoundKanji {
                isSearchFocused = true
            }
        }
        // The omni-search field's field editor swallows the Escape key while it
        // holds focus, so the Navigation Deck's ⌘\ / arrow handlers never see it.
        // Release search focus while the deck is open (so Esc / ← / → / Enter reach
        // the deck below), and return focus to the search field when it closes.
        .onChange(of: engine.isZStackOpen) { _, isOpen in
            isSearchFocused = !isOpen
        }
        .onKeyPress(.escape) {
            if engine.isZStackOpen {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    engine.isZStackOpen = false
                }
                return .handled
            }
            if isSearchDropdownOpen {
                engine.searchResults = []
                engine.englishMatches = []
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow) {
            if isSearchDropdownOpen && !engine.isZStackOpen {
                engine.moveSearchSelection(by: 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            if isSearchDropdownOpen && !engine.isZStackOpen {
                engine.moveSearchSelection(by: -1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.leftArrow) {
            if engine.isZStackOpen {
                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.82)) {
                    engine.stepZStack(by: -1)
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.rightArrow) {
            if engine.isZStackOpen {
                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.82)) {
                    engine.stepZStack(by: 1)
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if engine.isZStackOpen {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                    engine.jumpToHistory(index: engine.zStackFocusedIndex)
                }
                return .handled
            }
            return .ignored
        }
        #endif
    }

    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Button { engine.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .disabled(!engine.canGoBack)
                .help("Go back to the previous lookup")

                Button { engine.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .disabled(!engine.canGoForward)
                .help("Go forward in your lookup history")

                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                        if engine.isZStackOpen {
                            engine.isZStackOpen = false
                        } else {
                            engine.openHistoryStack()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.down.right")
                            .font(.body.weight(.semibold))
                        if !engine.history.isEmpty {
                            Text("\(engine.history.count)")
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .frame(minWidth: 18, alignment: .center)
                        }
                    }
                    // Reserve room for a 2-digit count so the badge doesn't squash
                    // when the history ring fills past 9 entries.
                    .frame(minWidth: 46, alignment: .center)
                    .padding(.horizontal, 6)
                    .frame(height: 28)
                }
                .help("Open Z-Stack Navigation Deck (⌘\\)")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(.ultraThinMaterial))

            // The Compound Kanji screen owns its own (autofocused, prominent) search
            // field, so we hide this top omni-search there — the two are what the
            // user kept confusing, and showing only one removes the ambiguity.
            if engine.activeScreen != .compoundKanji {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search Kanji, Kana, Romaji, or English (⌘F)...", text: $engine.searchQuery)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onChange(of: engine.searchQuery) { _, _ in
                            engine.performSearch()
                        }
                        .onSubmit {
                            engine.submitSearchQuery()
                        }

                    Button {
                        engine.searchContainsMode.toggle()
                    } label: {
                        Text(engine.searchContainsMode ? "Contains" : "Prefix")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(engine.searchContainsMode ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.08)))
                            .foregroundStyle(engine.searchContainsMode ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(engine.searchContainsMode
                          ? "Contains mode: matching substrings anywhere in a headword or reading. Click for Prefix ranking."
                          : "Prefix mode: matching exact and prefix forms first. Click to search anywhere inside a word (Contains).")

                    if !engine.searchQuery.isEmpty {
                        Button {
                            engine.searchQuery = ""
                            engine.searchResults = []
                            engine.englishMatches = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear the search")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                }
                .frame(minWidth: 180, maxWidth: 320)
                .help("Search by kanji, kana, romaji, or English — results appear live; use ↑/↓ and Enter to open.")
            }

            HStack(spacing: 6) {
                navScreenButton(
                    title: "Fisheye",
                    systemImage: "circle.hexagongrid.fill",
                    isActive: engine.activeScreen == .fisheye,
                    compact: navCompact,
                    help: "Open the Kanji Fisheye compound explorer (⌘⇧F)",
                    action: {
                        let cp = engine.activeKanji?.codepoint ?? engine.recentKanji.first ?? 0x5927
                        engine.openFisheye(codepoint: cp)
                    }
                )

                navScreenButton(
                    title: "Kanji Index",
                    systemImage: "character.book.closed.fill",
                    isActive: engine.activeScreen == .kanjiLookup,
                    compact: navCompact,
                    help: "Open the Kanji Index — browse kanji by stroke count, radical, or reading (⌘⇧K)",
                    action: { engine.openKanjiLookup() }
                )

                navScreenButton(
                    title: "Radicals",
                    systemImage: "puzzlepiece.extension.fill",
                    isActive: engine.activeScreen == .radicalBuilder,
                    compact: navCompact,
                    help: "Open the Radical Builder — assemble kanji from their component radicals (⌘⇧R)",
                    action: { engine.openRadicalBuilder() }
                )

                navScreenButton(
                    title: "Word Cloud",
                    systemImage: "sparkles",
                    isActive: engine.activeScreen == .wordCosmos,
                    compact: navCompact,
                    help: "Open the Word Cloud — a randomized prevalence bubble cloud (⌘⇧W)",
                    action: { engine.openWordCosmos() }
                )

                navScreenButton(
                    title: "Compounds",
                    systemImage: "square.split.2x2.fill",
                    isActive: engine.activeScreen == .compoundKanji,
                    compact: navCompact,
                    help: "Open the Compound Kanji screen — decompose a word into its kanji, inspect each part's readings & meaning, and see how the compound reading assembles from them (⌘⇧D)",
                    action: { engine.openCompoundKanji() }
                )

                Button {
                    engine.openStudyLibrary()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "star.square.on.square.fill")
                        if !navCompact {
                            Text("Decks")
                        }
                        if engine.studyStore.totalSavedCount > 0 {
                            Text("\(engine.studyStore.totalSavedCount)")
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.white.opacity(0.18)))
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(engine.activeScreen == .studyLibrary ? Color.accentColor : Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .help("Open Saved Study Decks & Anki Export (⌘⇧L)")
            }

            Toggle("Names", isOn: Binding(
                get: { engine.includeNames },
                set: { engine.setNamesIncluded($0, userInitiated: true) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .fixedSize()
            // Flash the toggle when the engine auto-enables Names, so the result
            // shift reads as "this control just changed" rather than a silent flip.
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(engine.namesToggleFlash ? Color.accentColor.opacity(0.28) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.45), value: engine.namesToggleFlash)
            .help("Include proper names (人名) in search and related-word lists. Auto-turned on when a proper name is the best match for your search — the toggle flashes and you can undo it from the results.")
            .onChange(of: engine.includeNames) { _, _ in
                engine.performSearch()
                engine.invalidateFisheyeSnapshots()
                if engine.activeScreen == .fisheye, let cp = engine.activeKanji?.codepoint {
                    engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: 1.85)
                } else if engine.activeScreen == .kanjiDetail {
                    engine.refreshActiveKanjiDetail()
                } else if engine.activeScreen == .wordCosmos {
                    engine.sampleWordCosmos(includeNames: engine.includeNames)
                }
            }

            Picker("Recall", selection: $engine.recallMode) {
                ForEach(RecallMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Recall Mode — Full shows everything, Hide Kana hides readings, Hide Defn. hides the English (for self-quizzing)")

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ForEach(engine.recentKanji, id: \.self) { cp in
                    Button {
                        engine.openFisheye(codepoint: cp)
                    } label: {
                        Text(String(UnicodeScalar(cp)!))
                            .font(.headline.weight(.bold))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    .help("Recently viewed kanji — open \(String(UnicodeScalar(cp)!))")
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        // The title bar is hidden, so this transparent handle re-installs the
        // usual macOS affordances on the (otherwise-dead) top band: drag the
        // window from empty space here, and double-click it to zoom/restore.
        //
        // `.ignoresSafeArea(.container, edges: .top)` extends the handle *up into*
        // the hidden title bar's safe-area inset — the thin "window shade" band
        // above the widget row. Without it the handle stops below that band, so
        // double-clicking the very top of the window did nothing. The widgets
        // themselves stay put (they're the foreground content, not the background).
        .background {
            WindowZoomHandle()
                .ignoresSafeArea(.container, edges: .top)
        }
        .help("Drag the window by its empty top bar; double-click it to zoom/restore between a typical size and your last size.")
        // Measure the bar so the screen buttons can crunch to icon-only when the
        // window is too narrow to show their labels on a single line.
        .measureWidth(into: $navBarWidth)
    }

    /// A top-bar screen button that keeps its full `Label` when there is room
    /// and drops to an icon-only `Image` when `compact`, so it never spills onto
    /// a second line. The active screen gets the accent fill; the tooltip is
    /// always attached, keeping the icon-only state self-documenting.
    @ViewBuilder
    private func navScreenButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        compact: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if compact {
                    Image(systemName: systemImage)
                } else {
                    Label(title, systemImage: systemImage)
                }
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, compact ? 10 : 11)
            .padding(.vertical, 7)
            .background(Capsule().fill(isActive ? Color.accentColor : Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var searchResultsDropdown: some View {
        VStack {
            HStack {
                GlassCard(cornerRadius: 18, highlightOpacity: 0.35) {
                    VStack(spacing: 0) {
                        if engine.nameNudge != nil {
                            nameNudgeBanner
                            Divider().opacity(0.4)
                        }
                        filterChipRow
                        Divider().opacity(0.4)
                        resultsBody
                    }
                    .animation(.easeInOut(duration: 0.25), value: engine.nameNudge?.id)
                }
                .padding(.leading, 118)
                Spacer()
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    /// A transient banner above the search results, raised when the engine's best
    /// match is a proper name the (Names-off) search is hiding. Two flavours:
    ///  • autoEnabled — we flipped Names on for the user; offer an Undo.
    ///  • suggest     — the user turned Names off themselves; only *suggest* turning
    ///                  it back on, without flipping the toggle.
    @ViewBuilder
    private var nameNudgeBanner: some View {
        if let nudge = engine.nameNudge {
            HStack(spacing: 8) {
                Image(systemName: nudge.autoEnabled
                      ? "person.crop.circle.badge.plus"
                      : "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    if nudge.autoEnabled {
                        Text("Found the name \(nudge.hit.displayHeadword)")
                            .font(.subheadline.weight(.semibold))
                        Text("\(nudge.hit.kanaHead)  ·  \(nudge.hit.primaryGloss)  ·  Names turned on")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Names are off — \(nudge.hit.displayHeadword) looks like what you meant")
                            .font(.subheadline.weight(.semibold))
                        Text("\(nudge.hit.kanaHead)  ·  \(nudge.hit.primaryGloss)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if nudge.autoEnabled {
                    Button("Undo") { engine.undoNamesAutoEnable() }
                        .help("Turn Names back off")
                } else {
                    Button("Turn on Names") { engine.turnOnNamesFromNudge() }
                        .help("Include proper names so \(nudge.hit.displayHeadword) shows")
                }

                Button {
                    engine.dismissNameNudge()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.10))
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// The dropdown body. The main (Japanese) results always occupy the left;
    /// when the query is a romaji that *also* names an English word, the "Also in
    /// English glosses" section renders *beside* them as a narrower right-hand
    /// column rather than stacked beneath — the card widens to fit so neither
    /// column is cramped.
    @ViewBuilder
    private var resultsBody: some View {
        if engine.englishMatches.isEmpty {
            mainResultsColumn
                .frame(maxWidth: 640, maxHeight: 420)
        } else {
            HStack(alignment: .top, spacing: 0) {
                mainResultsColumn
                    .frame(maxWidth: .infinity, maxHeight: 420)
                Divider().opacity(0.5)
                englishResultsColumn
                    .frame(maxWidth: 300, maxHeight: 420)
            }
            .frame(maxWidth: 920, maxHeight: 420)
        }
    }

    @ViewBuilder
    private var mainResultsColumn: some View {
        let filtered = engine.filteredSearchResults
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if filtered.isEmpty {
                        noFilterMatchRow
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, hit in
                            searchResultRow(for: hit, isSelected: engine.selectedSearchIndex == idx)
                                .id(idx)
                        }
                    }
                }
                .padding(8)
            }
            .onChange(of: engine.selectedSearchIndex) { _, newIdx in
                if newIdx < filtered.count {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newIdx)
                    }
                }
            }
        }
    }

    /// The right-hand "Also in English glosses" column: a header plus the deduped
    /// English-gloss matches for the current romaji query.
    @ViewBuilder
    private var englishResultsColumn: some View {
        let baseIdx = engine.searchFilters.isEmpty ? engine.filteredSearchResults.count : Int.max
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    englishMatchesHeader
                    ForEach(Array(engine.englishMatches.enumerated()), id: \.element.id) { offset, hit in
                        let combinedIdx = baseIdx + offset
                        searchResultRow(for: hit, isSelected: engine.selectedSearchIndex == combinedIdx)
                            .id(combinedIdx)
                    }
                }
                .padding(8)
            }
            .onChange(of: engine.selectedSearchIndex) { _, newIdx in
                if newIdx >= baseIdx {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newIdx)
                    }
                }
            }
        }
    }

    // MARK: - Search result row + quick-filter chips

    private func searchResultRow(for hit: WordHit, isSelected: Bool = false) -> some View {
        Button {
            engine.openWordEntry(entryId: hit.id)
            engine.searchResults = []
            engine.englishMatches = []
            isSearchFocused = false
        } label: {
            HStack(spacing: 12) {
                Text(hit.displayHeadword)
                    .font(.title3.weight(.bold))
                    .frame(minWidth: 74, alignment: .leading)

                if engine.recallMode != .hideKana {
                    Text(hit.kanaHead)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 86, alignment: .leading)
                }

                if engine.recallMode != .hideGloss {
                    Text(hit.primaryGloss)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if hit.isName {
                    Text("Name")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.25)))
                        .foregroundStyle(.purple)
                }

                if isSelected {
                    Image(systemName: "return")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy") {
                engine.copyText("\(hit.displayHeadword)  \(hit.kanaHead)  \(hit.primaryGloss)")
            }
            Button(engine.studyStore.isWordSaved(hit.id) ? "Remove Bookmark" : "Save to Favorites") {
                engine.toggleSaveWordHit(hit)
            }
        }
    }

    private var filterChipRow: some View {
        WrappingHStack(alignment: .top, horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(SearchFilter.allCases) { filter in
                let active = engine.searchFilters.contains(filter)
                let tint = filter.tint
                Button {
                    engine.toggleSearchFilter(filter)
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                        Text(filter.rawValue)
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(active ? tint : tint.opacity(0.13))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(tint.opacity(active ? 0.55 : 0.28), lineWidth: 1)
                    )
                    .foregroundStyle(active ? .white : tint)
                    .help(searchFilterTooltip(for: filter))
                }
                .buttonStyle(.plain)
            }
            if !engine.searchFilters.isEmpty {
                Button {
                    engine.searchFilters = []
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var noFilterMatchRow: some View {
        VStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No results match these filters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Try removing a chip, or clear filters.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    /// Header above the "Also in English glosses" section — a small secondary
    /// label that explains the supplementary English-gloss matches the engine
    /// surfaced for a romaji query that also names an English word.
    private var englishMatchesHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "character.bubble")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Also in English glosses")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }

    private func searchFilterTooltip(for filter: SearchFilter) -> String {
        switch filter {
        case .common:       return "Common only — overall frequency rank ≤ 12,000 (Jōyō-grade words)."
        case .nouns:        return "Nouns."
        case .verbs:        return "Verbs — ichidan, godan, and other verb forms."
        case .adjectives:   return "Adjectives — i- (keiyoushi) and na- (keiyogo / adjectival nouns)."
        case .adverbs:      return "Adverbs."
        case .particles:    return "Particles."
        case .onomatopoeia: return "Onomatopoeia & mimetic expressions (擬音語・擬態語)."
        case .yojijukugo:   return "Yojijukugo — four-character idiomatic compounds (四字熟語)."
        case .idioms:       return "Idiomatic expressions (慣用句)."
        case .proverbs:     return "Proverbs & sayings (諺)."
        case .keigo:        return "Honorific, humble, and polite language (敬語)."
        case .colloquial:   return "Colloquial and slang expressions."
        case .jlpt5:        return "JLPT N5 — \(DaiJishowEngine.jlptLevelDescription(5)) Filter matches words whose hardest head kanji is N5."
        case .jlpt4:        return "JLPT N4 — \(DaiJishowEngine.jlptLevelDescription(4)) Filter matches words whose hardest head kanji is N4."
        case .jlpt3:        return "JLPT N3 — \(DaiJishowEngine.jlptLevelDescription(3)) Filter matches words whose hardest head kanji is N3."
        case .jlpt2:        return "JLPT N2 — \(DaiJishowEngine.jlptLevelDescription(2)) Filter matches words whose hardest head kanji is N2."
        case .jlpt1:        return "JLPT N1 — \(DaiJishowEngine.jlptLevelDescription(1)) Filter matches words whose hardest head kanji is N1."
        case .grade1:       return "Words whose highest school-grade head kanji is Grade 1 (小学 1年生)."
        case .grade2:       return "Words whose highest school-grade head kanji is Grade 2 (小学 2年生)."
        case .grade3:       return "Words whose highest school-grade head kanji is Grade 3 (小学 3年生)."
        }
    }

    private var databaseMissingBanner: some View {
        VStack(spacing: 16) {
            Image(systemName: "cylinder.split.1x2.fill")
                .font(.system(size: 54))
                .foregroundStyle(.secondary)
            Text("daijishow.db Not Found")
                .font(.title.weight(.bold))
            Text("Run the C++ ingest compiler (`daijishow_ingest`) to generate `data/daijishow.db`, then relaunch DaiJiShow.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var breadcrumbViewer: some View {
        HStack(spacing: 8) {
            if engine.history.count > 6 {
                Menu {
                    ForEach(Array(engine.history.enumerated()), id: \.element.id) { idx, crumb in
                        Button("\(idx + 1). \(crumb.label)") {
                            engine.jumpToHistory(index: idx)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(engine.history.enumerated()), id: \.element.id) { idx, crumb in
                            if idx > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.35))
                            }

                            Button {
                                engine.jumpToHistory(index: idx)
                            } label: {
                                Text(crumb.label)
                                    .font(.caption.weight(idx == engine.historyIndex ? .bold : .medium))
                                    .foregroundStyle(idx == engine.historyIndex ? Color.accentColor : Color.white.opacity(0.85))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(idx == engine.historyIndex ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.08))
                                    )
                                    .overlay(
                                        Capsule().strokeBorder(idx == engine.historyIndex ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .fixedSize()
                            .id(idx)
                        }
                    }
                }
                .onChange(of: engine.historyIndex) { _, newIdx in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(newIdx, anchor: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}
