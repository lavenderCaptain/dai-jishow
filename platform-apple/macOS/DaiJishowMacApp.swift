import SwiftUI
import AppKit
import DaiJishowCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct DaiJishowMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var engine: DaiJishowEngine

    init() {
        let cliPath = CommandLine.arguments.dropFirst().first
        let envPath = ProcessInfo.processInfo.environment["DAIJISHOW_DB_PATH"]
        let defaultPath = FileManager.default.currentDirectoryPath + "/build/daijishow.db"
        let resolvedPath = cliPath ?? envPath ?? defaultPath
        _engine = StateObject(wrappedValue: DaiJishowEngine(dbPath: resolvedPath))
    }

    var body: some Scene {
        WindowGroup("Dai-Jishow 大辞書") {
            MainWorkspaceView(engine: engine)
                .frame(minWidth: 1060, minHeight: 750)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Toggle History Z-Stack") {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        engine.isZStackOpen.toggle()
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

struct MainWorkspaceView: View {
    @ObservedObject var engine: DaiJishowEngine
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.11),
                    Color(red: 0.08, green: 0.11, blue: 0.17),
                    Color(red: 0.05, green: 0.08, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                topBar

                ZStack(alignment: .top) {
                    if engine.isZStackOpen {
                        historyZStackView
                    } else {
                        LiquidGlassCard(cornerRadius: 22) {
                            activeCardView
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if !engine.searchResults.isEmpty {
                        searchResultsOverlay
                    }
                }

                bottomNavigationDock
            }
            .padding(16)
        }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                searchFieldFocused = true
            }
        }
    }

    private var topBar: some View {
        LiquidGlassCard(cornerRadius: 16) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Button {
                        engine.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.bold())
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!engine.canGoBack)

                    Button {
                        engine.goForward()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!engine.canGoForward)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                    TextField("Search Kanji, Kana, Wa-puro Romaji, or English...", text: $engine.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .focused($searchFieldFocused)
                        .onChange(of: engine.searchQuery) { _, _ in
                            engine.isZStackOpen = false
                            engine.performSearch()
                        }
                        .onSubmit {
                            engine.isZStackOpen = false
                            engine.submitSearchQuery()
                        }

                    if !engine.searchQuery.isEmpty {
                        if engine.searchResults.isEmpty {
                            Button("Results") {
                                engine.performSearch()
                            }
                            .font(.caption.bold())
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Button {
                            engine.searchQuery = ""
                            engine.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )

                Toggle("Names", isOn: $engine.includeNames)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .foregroundStyle(.white)
                    .fixedSize()
                    .onChange(of: engine.includeNames) { _, _ in
                        engine.performSearch()
                        if engine.activeScreen == .fisheye, let cp = engine.activeKanji?.codepoint {
                            engine.solveFisheye(center: cp, focusX: 0, focusY: 0, aspectRatio: 1.5, animated: true)
                        }
                    }

                Divider().frame(height: 20).overlay(Color.white.opacity(0.2))

                Picker("Recall", selection: $engine.recallMode) {
                    ForEach(RecallMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 215)

                Button {
                    engine.isZStackOpen = false
                    engine.openRadicalBuilder()
                } label: {
                    Label("Radicals", systemImage: "square.grid.3x3")
                }
                .buttonStyle(.bordered)
                .fixedSize()

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        engine.isZStackOpen.toggle()
                    }
                } label: {
                    Label("History Stack (\(engine.history.count))", systemImage: "square.stack.3d.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.isZStackOpen ? .cyan : Color.white.opacity(0.18))
                .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var activeCardView: some View {
        switch engine.activeScreen {
        case .wordEntry:
            WordDetailView(engine: engine)
        case .kanjiDetail:
            KanjiDetailView(engine: engine)
        case .radicalBuilder:
            RadicalBuilderView(engine: engine)
        case .fisheye:
            FisheyeExplorerView(engine: engine)
        }
    }

    // 3D Z-Axis History Navigator Stack
    private var historyZStackView: some View {
        let recentStack = Array(engine.history.prefix(engine.historyIndex + 1).reversed().prefix(7))
        return ZStack {
            ForEach(Array(recentStack.enumerated()), id: \.element.id) { depth, item in
                let actualIndex = engine.historyIndex - depth
                LiquidGlassCard(cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(depth == 0 ? "ACTIVE CARD" : "HISTORY DEPTH -\(depth)")
                                .font(.caption.bold())
                                .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                            Spacer()
                            Text("Click card to restore")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }

                        Text(item.label)
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(.white)

                        Text(item.subtitle)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)

                        Spacer()
                    }
                    .padding(28)
                }
                .frame(maxWidth: 820, maxHeight: 450)
                .scaleEffect(1.0 - CGFloat(depth) * 0.065)
                .offset(y: CGFloat(depth) * -32)
                .rotation3DEffect(.degrees(Double(depth) * 3.5), axis: (x: 1, y: 0, z: 0))
                .opacity(max(0.28, 1.0 - Double(depth) * 0.14))
                .zIndex(Double(20 - depth))
                .onTapGesture {
                    engine.jumpToHistory(index: actualIndex)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchResultsOverlay: some View {
        LiquidGlassCard(cornerRadius: 16) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(engine.searchResults) { hit in
                        Button {
                            engine.openWordEntry(entryId: hit.id)
                            engine.searchResults = []
                        } label: {
                            HStack(spacing: 12) {
                                Text(hit.displayHeadword)
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 110, alignment: .leading)

                                if engine.recallMode != .hideKana {
                                    Text(hit.kanaHead)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                        .frame(minWidth: 100, alignment: .leading)
                                }

                                if hit.isName {
                                    Text("NAME")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.55), in: Capsule())
                                }

                                if engine.recallMode != .hideGloss {
                                    Text(hit.primaryGloss)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.85))
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 330)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .shadow(color: .black.opacity(0.65), radius: 30, x: 0, y: 16)
    }

    private var bottomNavigationDock: some View {
        LiquidGlassCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                Text("RECENT KANJI")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize()

                ForEach(engine.recentKanji, id: \.self) { cp in
                    let glyph = String(UnicodeScalar(cp)!)
                    Button {
                        engine.isZStackOpen = false
                        engine.openFisheye(codepoint: cp, recordHistory: true)
                    } label: {
                        Text(glyph)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Explore 「\(glyph)」 in Dokusha Fisheye")
                }

                Divider().frame(height: 18).overlay(Color.white.opacity(0.2))

                // Overflow-safe Breadcrumb Trail that auto-scrolls to the active item
                if engine.history.count > 6 {
                    Menu {
                        ForEach(Array(engine.history.enumerated()), id: \.element.id) { idx, crumb in
                            Button("\(idx + 1). \(crumb.label)") {
                                engine.jumpToHistory(index: idx)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white.opacity(0.75))
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
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                Button {
                                    engine.jumpToHistory(index: idx)
                                } label: {
                                    Text(crumb.label)
                                        .font(.caption.weight(idx == engine.historyIndex ? .bold : .medium))
                                        .foregroundStyle(idx == engine.historyIndex ? Color(red: 0.45, green: 0.88, blue: 1.0) : .white.opacity(0.75))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            idx == engine.historyIndex ? Color.cyan.opacity(0.22) : Color.white.opacity(0.06),
                                            in: Capsule()
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
