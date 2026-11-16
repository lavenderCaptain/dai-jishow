/**
 * DaiJishowMacApp.swift
 * =====================
 * Native macOS entry point for Dai-Jishow (大辞書) with clean breadcrumb navigation,
 * instant Wa-puro / English search dropdown, and the 6-Kanji Compound Ring dock.
 */

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
                .frame(minWidth: 1040, minHeight: 740)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
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
                    LiquidGlassCard(cornerRadius: 22) {
                        activeCardView
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !engine.searchResults.isEmpty {
                        searchResultsOverlay
                    }
                }

                bottomKanjiRingDock
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
            HStack(spacing: 12) {
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
                            engine.performSearch()
                        }
                        .onSubmit {
                            if let first = engine.searchResults.first {
                                engine.openWordEntry(entryId: first.id)
                                engine.searchResults = []
                            }
                        }

                    if !engine.searchQuery.isEmpty {
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
                    .onChange(of: engine.includeNames) { _, _ in engine.performSearch() }

                Divider().frame(height: 20).overlay(Color.white.opacity(0.2))

                Picker("Recall", selection: $engine.recallMode) {
                    ForEach(RecallMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 225)

                Button {
                    engine.openRadicalBuilder()
                } label: {
                    Label("Radicals", systemImage: "square.grid.3x3")
                }
                .buttonStyle(.bordered)
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

    private var bottomKanjiRingDock: some View {
        LiquidGlassCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                Text("6-KANJI RING")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))

                ForEach(engine.recentKanji, id: \.self) { cp in
                    let glyph = String(UnicodeScalar(cp)!)
                    Button {
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
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
