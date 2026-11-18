import SwiftUI
#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
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
        WindowGroup {
            MainWorkspaceView(engine: engine)
                .frame(minWidth: 1020, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
        .commands {
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

                Button("Toggle Word Cockpit / Reader Mode") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        engine.isWordCockpitExpanded.toggle()
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(engine.activeScreen != .wordEntry)

                Button("Open Kanji Index (Wordtank)") {
                    engine.openKanjiLookup()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Open 7-Slot Radical Builder") {
                    engine.openRadicalBuilder()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Open Word Cosmos") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        engine.openWordCosmos()
                    }
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])

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
            }
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
            "../../data/daijishow.db",
            "/Users/andrew/Code/DaiJiShow/data/daijishow.db"
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return "daijishow.db"
    }
}

// MARK: - Main Workspace & Persistent Glass Top Bar

struct MainWorkspaceView: View {
    @ObservedObject var engine: DaiJishowEngine
    @FocusState private var isSearchFocused: Bool

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
                        }
                    }

                    if !engine.searchResults.isEmpty && !engine.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
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
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isSearchFocused = true
            }
        }
        .onKeyPress(.escape) {
            if engine.isZStackOpen {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    engine.isZStackOpen = false
                }
                return .handled
            }
            if !engine.searchResults.isEmpty {
                engine.searchResults = []
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

                Button { engine.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .disabled(!engine.canGoForward)

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
                        }
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 28)
                }
                .help("Open Z-Stack Navigation Deck (⌘\\)")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(.ultraThinMaterial))

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search Kanji, Kana, Romaji, or English (press Enter)...", text: $engine.searchQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onChange(of: engine.searchQuery) { _, _ in
                        engine.performSearch()
                    }
                    .onSubmit {
                        engine.submitSearchQuery()
                    }

                if !engine.searchQuery.isEmpty {
                    Button {
                        engine.searchQuery = ""
                        engine.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            }
            .frame(maxWidth: 400)

            Button {
                engine.openKanjiLookup()
            } label: {
                Label("Kanji Index", systemImage: "character.book.closed.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(engine.activeScreen == .kanjiLookup ? Color.accentColor : Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)

            Button {
                engine.openRadicalBuilder()
            } label: {
                Label("Radicals", systemImage: "puzzlepiece.extension.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(engine.activeScreen == .radicalBuilder ? Color.accentColor : Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)

            Button {
                engine.openWordCosmos()
            } label: {
                Label("Word Cosmos", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(engine.activeScreen == .wordCosmos ? Color.accentColor : Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .help("Open the Word Cosmos — a randomized prevalence bubble cloud (⌘⇧W)")

            Toggle("Names", isOn: $engine.includeNames)
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
                .onChange(of: engine.includeNames) { _, _ in
                    engine.performSearch()
                    engine.invalidateFisheyeSnapshots()
                    if engine.activeScreen == .fisheye, let cp = engine.activeKanji?.codepoint {
                        engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: 1.85)
                    } else if engine.activeScreen == .kanjiDetail {
                        engine.refreshActiveKanjiDetail()
                    }
                }

            Picker("Recall", selection: $engine.recallMode) {
                ForEach(RecallMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Spacer(minLength: 4)

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
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var searchResultsDropdown: some View {
        VStack {
            HStack {
                LiquidGlassCard(cornerRadius: 18, highlightOpacity: 0.35) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(engine.searchResults) { hit in
                                Button {
                                    engine.openWordEntry(entryId: hit.id)
                                    engine.searchResults = []
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
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxWidth: 640, maxHeight: 420)
                }
                .padding(.leading, 118)
                Spacer()
            }
            Spacer()
        }
        .padding(.top, 4)
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
