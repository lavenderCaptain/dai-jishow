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
                        if engine.isZStackOpen {
                            engine.isZStackOpen = false
                        } else {
                            engine.openHistoryStack()
                        }
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

// Captures two-finger trackpad horizontal/vertical scroll events so users can scrub the 3D history deck smoothly
private struct HistoryScrollWheelCatcher: NSViewRepresentable {
    let onStep: (Int) -> Void

    func makeNSView(context: Context) -> ScrollWheelView {
        let view = ScrollWheelView()
        view.onStep = onStep
        return view
    }

    func updateNSView(_ nsView: ScrollWheelView, context: Context) {
        nsView.onStep = onStep
    }

    final class ScrollWheelView: NSView {
        var onStep: ((Int) -> Void)?
        private var accumDelta: CGFloat = 0
        private var lastStepTime: TimeInterval = 0

        override func scrollWheel(with event: NSEvent) {
            let primaryDelta = abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY)
                ? event.scrollingDeltaX
                : event.scrollingDeltaY

            if event.phase == .began || event.phase == .ended || event.phase == .cancelled {
                accumDelta = 0
            }

            accumDelta += primaryDelta
            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 36.0 : 2.0
            let now = ProcessInfo.processInfo.systemUptime

            if abs(accumDelta) >= threshold && (now - lastStepTime) > 0.11 {
                let step = accumDelta < 0 ? 1 : -1
                accumDelta = 0
                lastStepTime = now
                DispatchQueue.main.async {
                    self.onStep?(step)
                }
            }
        }
    }
}

struct MainWorkspaceView: View {
    @ObservedObject var engine: DaiJishowEngine
    @FocusState private var searchFieldFocused: Bool
    @FocusState private var historyStackFocused: Bool

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
        .onChange(of: engine.isZStackOpen) { _, isOpen in
            if isOpen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    historyStackFocused = true
                }
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
                        engine.invalidateFisheyeSnapshots()
                        if engine.activeScreen == .fisheye, let cp = engine.activeKanji?.codepoint {
                            engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: 1.85, animated: true)
                        }
                        if engine.isZStackOpen {
                            engine.openHistoryStack()
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
                        if engine.isZStackOpen {
                            engine.isZStackOpen = false
                        } else {
                            engine.openHistoryStack()
                        }
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

    // MARK: - 3D Sideways-Angled History Card Deck

    private var historyZStackView: some View {
        let total = engine.history.count
        let focusedIdx = min(max(0, engine.zStackFocusedIndex), max(0, total - 1))

        return GeometryReader { geo in
            let cardW = min(max(620.0, geo.size.width * 0.64), 860.0)
            let cardH = min(max(380.0, geo.size.height - 84.0), 530.0)

            ZStack {
                // Dark radial stage backdrop (tap outside cards to close)
                RadialGradient(
                    colors: [
                        Color.cyan.opacity(0.08),
                        Color.black.opacity(0.45)
                    ],
                    center: .center,
                    startRadius: 40,
                    endRadius: max(geo.size.width, geo.size.height) * 0.7
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        engine.isZStackOpen = false
                    }
                }

                // Trackpad two-finger scroll wheel handler across the entire deck
                HistoryScrollWheelCatcher { step in
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        engine.stepZStack(by: step)
                    }
                }

                if total == 0 {
                    Text("No navigation history yet.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.65))
                } else {
                    // Render cards within ±4 slots of focusedIdx in a 3D sideways-angled fan
                    ForEach(Array(engine.history.enumerated()), id: \.element.id) { idx, item in
                        let rel = idx - focusedIdx
                        if abs(rel) <= 4 {
                            let isCenter = (rel == 0)
                            let absRel = abs(rel)
                            let xOffset: CGFloat = isCenter
                                ? 0
                                : (CGFloat(rel) * (cardW * 0.27) + (rel < 0 ? -68.0 : 68.0))
                            let yOffset: CGFloat = isCenter ? -16.0 : (CGFloat(absRel) * 5.0 - 10.0)
                            let angleY: Double = isCenter ? 0.0 : (rel < 0 ? 28.0 : -28.0)
                            let scale: CGFloat = isCenter
                                ? 1.0
                                : max(0.62, 0.86 - CGFloat(absRel - 1) * 0.075)
                            let opacity: Double = isCenter
                                ? 1.0
                                : max(0.32, 0.90 - Double(absRel - 1) * 0.17)
                            let zOrder: Double = Double(50 - absRel)

                            historyDeckCard(
                                item: item,
                                index: idx,
                                isCenter: isCenter,
                                isCurrentActive: idx == engine.historyIndex,
                                cardWidth: cardW,
                                cardHeight: cardH
                            )
                            .frame(width: cardW, height: cardH)
                            .scaleEffect(scale)
                            .rotation3DEffect(
                                .degrees(angleY),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: .center,
                                anchorZ: 0,
                                perspective: 0.42
                            )
                            .offset(x: xOffset, y: yOffset)
                            .opacity(opacity)
                            .zIndex(zOrder)
                            .onTapGesture {
                                if isCenter {
                                    engine.jumpToHistory(index: idx)
                                } else {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                        engine.zStackFocusedIndex = idx
                                        engine.ensureHistorySnapshot(at: idx)
                                    }
                                }
                            }
                        }
                    }

                    // Bottom Interactive Deck Controls (Prev / Card Strip / Next / Open)
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                    engine.stepZStack(by: -1)
                                }
                            } label: {
                                Label("Older", systemImage: "chevron.left")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                            .disabled(focusedIdx <= 0)

                            HStack(spacing: 5) {
                                ForEach(0..<total, id: \.self) { dotIdx in
                                    Button {
                                        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                            engine.zStackFocusedIndex = dotIdx
                                            engine.ensureHistorySnapshot(at: dotIdx)
                                        }
                                    } label: {
                                        Capsule()
                                            .fill(
                                                dotIdx == focusedIdx
                                                    ? Color.cyan
                                                    : (dotIdx == engine.historyIndex ? Color.white.opacity(0.65) : Color.white.opacity(0.22))
                                            )
                                            .frame(width: dotIdx == focusedIdx ? 22 : 8, height: 7)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 6)

                            Text("\(focusedIdx + 1) / \(total)")
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(.white.opacity(0.8))

                            Button {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                    engine.stepZStack(by: 1)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Newer")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                            .disabled(focusedIdx >= total - 1)

                            Divider().frame(height: 16).overlay(Color.white.opacity(0.22))

                            Button("Open Card") {
                                engine.jumpToHistory(index: focusedIdx)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("Close") {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                    engine.isZStackOpen = false
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.08, green: 0.11, blue: 0.17).opacity(0.94))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
                        .padding(.bottom, 8)
                    }
                    .zIndex(80)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusable()
            .focused($historyStackFocused)
            .focusEffectDisabled()
            .onKeyPress(.leftArrow) {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                    engine.stepZStack(by: -1)
                }
                return .handled
            }
            .onKeyPress(.rightArrow) {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                    engine.stepZStack(by: 1)
                }
                return .handled
            }
            .onKeyPress(.return) {
                engine.jumpToHistory(index: focusedIdx)
                return .handled
            }
            .onKeyPress(.escape) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    engine.isZStackOpen = false
                }
                return .handled
            }
        }
    }

    @ViewBuilder
    private func historyDeckCard(
        item: NavBreadcrumb,
        index: Int,
        isCenter: Bool,
        isCurrentActive: Bool,
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        let headerH: CGFloat = 34.0
        let contentH = max(200.0, cardHeight - headerH)
        // Render full desktop view at 1020pt logical width and scale cleanly into the card viewport
        let virtualW: CGFloat = 1020.0
        let previewScale = cardWidth / virtualW
        let virtualH = contentH / previewScale

        LiquidGlassCard(cornerRadius: 20) {
            VStack(spacing: 0) {
                // Compact top card bar
                HStack(spacing: 8) {
                    Text(isCurrentActive ? "ACTIVE VIEW" : "HISTORY #\(index + 1)")
                        .font(.caption2.bold())
                        .foregroundStyle(isCurrentActive ? Color(red: 0.45, green: 0.88, blue: 1.0) : .white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (isCurrentActive ? Color.cyan.opacity(0.24) : Color.white.opacity(0.08)),
                            in: Capsule()
                        )

                    Text(item.label)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("— \(item.subtitle)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)

                    Spacer()

                    Text(isCenter ? "Click or ⏎ to restore" : "Click to focus")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isCenter ? Color.cyan : .white.opacity(0.55))
                }
                .padding(.horizontal, 14)
                .frame(height: headerH)
                .background(Color.white.opacity(0.04))

                Divider().overlay(Color.white.opacity(0.14))

                // Complete screen view for this history item
                ZStack {
                    HistorySnapshotScreenView(
                        item: item,
                        snapshot: engine.snapshot(for: item),
                        engine: engine
                    )
                    .frame(width: virtualW, height: virtualH)
                    .scaleEffect(previewScale, anchor: .center)
                    .allowsHitTesting(false)
                }
                .frame(width: cardWidth, height: contentH)
                .clipped()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isCenter ? Color.cyan.opacity(0.85) : Color.white.opacity(0.18),
                    lineWidth: isCenter ? 2.0 : 1.0
                )
        )
        .shadow(color: isCenter ? Color.cyan.opacity(0.22) : Color.black.opacity(0.55), radius: isCenter ? 24 : 14, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
