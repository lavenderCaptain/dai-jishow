import SwiftUI
import DaiJishowCore

// MARK: - Glass Surface Primitive

struct LiquidGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var highlightOpacity: Double = 0.28
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.14),
                                        Color.white.opacity(0.03),
                                        Color.black.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(highlightOpacity),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Ruby Text Layout (Furigana Above Kanji)

struct RubyWordView: View {
    let cells: [RubyCell]
    let hideKana: Bool
    let fontSize: CGFloat
    var onTapKanji: ((UInt32) -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(cells) { cell in
                VStack(spacing: 1) {
                    Text(hideKana || cell.furigana.isEmpty ? " " : cell.furigana)
                        .font(.system(size: max(11, fontSize * 0.30), weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .opacity(hideKana || cell.furigana.isEmpty ? 0 : 0.95)
                        .lineLimit(1)
                        .fixedSize()

                    Text(cell.surface)
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, cell.kanjiCodepoint > 0 ? 3 : 0)
                        .background {
                            if cell.kanjiCodepoint > 0 {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            }
                        }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if cell.kanjiCodepoint > 0 {
                        onTapKanji?(cell.kanjiCodepoint)
                    }
                }
            }
        }
    }
}

// MARK: - Z-Stack Coverflow History Overlay (Scaled Live Previews + Smooth Focus)

struct ZStackHistoryOverlay: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var dragDelta: CGFloat = 0

    private let baseCardWidth: CGFloat = 860
    private let baseCardHeight: CGFloat = 540

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(Color.black.opacity(0.68))
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                        engine.isZStackOpen = false
                    }
                }

            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Label("Navigation Deck", systemImage: "square.stack.3d.down.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    if !engine.history.isEmpty {
                        Text("\(engine.zStackFocusedIndex + 1) of \(engine.history.count)")
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }

                    Spacer()

                    Text("← / → or Scroll • Enter to Open • Esc to Close")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            engine.isZStackOpen = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 36)
                .padding(.top, 20)

                if engine.history.isEmpty {
                    Spacer()
                    Text("No history entries yet. Explore a Kanji or Word first.")
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                } else {
                    GeometryReader { geo in
                        let availW = max(320, geo.size.width - 80)
                        let availH = max(240, geo.size.height - 28)
                        let cardScale = min(availW / baseCardWidth, availH / baseCardHeight, 0.92)
                        let cardW = baseCardWidth * cardScale
                        let cardH = baseCardHeight * cardScale
                        let stepSpacing = min(145, cardW * 0.24)
                        let focused = CGFloat(engine.zStackFocusedIndex) - (dragDelta / max(80, stepSpacing))

                        ZStack {
                            ForEach(Array(engine.history.enumerated()), id: \.element.id) { idx, item in
                                let rel = CGFloat(idx) - focused
                                let absRel = abs(rel)

                                if absRel <= 5.5 {
                                    let depthScale = max(0.56, 1.0 - absRel * 0.115)
                                    let xOffset = rel * stepSpacing + (rel > 0 ? 18 : (rel < 0 ? -18 : 0))
                                    let yOffset = absRel * 10
                                    let yawDegrees = Double(max(-36, min(36, -rel * 16)))
                                    let cardOpacity = max(0.0, 1.0 - Double(absRel) * 0.21)
                                    let isFocused = (idx == engine.zStackFocusedIndex)

                                    ZStackScreenSnapshotCard(
                                        engine: engine,
                                        item: item,
                                        index: idx,
                                        isActiveCurrent: idx == engine.historyIndex,
                                        isFocused: isFocused,
                                        renderScale: cardScale,
                                        baseWidth: baseCardWidth,
                                        baseHeight: baseCardHeight
                                    )
                                    .frame(width: cardW, height: cardH)
                                    .scaleEffect(depthScale)
                                    .rotation3DEffect(
                                        .degrees(yawDegrees),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.55
                                    )
                                    .offset(x: xOffset, y: yOffset)
                                    .opacity(cardOpacity)
                                    .zIndex(100 - Double(absRel) * 10)
                                    .onTapGesture {
                                        if isFocused {
                                            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                                                engine.jumpToHistory(index: idx)
                                            }
                                        } else {
                                            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
                                                engine.zStackFocusedIndex = idx
                                                engine.ensureHistorySnapshot(at: idx)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    dragDelta = value.translation.width
                                }
                                .onEnded { value in
                                    let predicted = value.predictedEndTranslation.width
                                    let steps = Int((-predicted / max(80, stepSpacing)).rounded())
                                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
                                        dragDelta = 0
                                        if steps != 0 {
                                            engine.stepZStack(by: steps)
                                        }
                                    }
                                }
                        )
                    }

                    HStack(spacing: 20) {
                        Button {
                            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.82)) {
                                engine.stepZStack(by: -1)
                            }
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.zStackFocusedIndex <= 0)
                        .opacity(engine.zStackFocusedIndex <= 0 ? 0.4 : 1)

                        Button {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                                engine.jumpToHistory(index: engine.zStackFocusedIndex)
                            }
                        } label: {
                            Label("Open Selected Card", systemImage: "arrow.up.forward.app.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Color.accentColor))
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.82)) {
                                engine.stepZStack(by: 1)
                            }
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.zStackFocusedIndex + 1 >= engine.history.count)
                        .opacity(engine.zStackFocusedIndex + 1 >= engine.history.count ? 0.4 : 1)
                    }
                    .foregroundStyle(.white)
                    .padding(.bottom, 22)
                }
            }
        }
    }
}

private struct ZStackScreenSnapshotCard: View {
    @ObservedObject var engine: DaiJishowEngine
    let item: NavBreadcrumb
    let index: Int
    let isActiveCurrent: Bool
    let isFocused: Bool
    let renderScale: CGFloat
    let baseWidth: CGFloat
    let baseHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: iconForKind(item.kind))
                    .foregroundStyle(isFocused ? Color.accentColor : .white.opacity(0.75))
                Text(item.label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("•")
                    .foregroundStyle(.white.opacity(0.35))
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Spacer()
                if isActiveCurrent {
                    Text("Current")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor.opacity(0.85)))
                        .foregroundStyle(.white)
                }
                Text("#\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.45))

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.10, blue: 0.15),
                        Color(red: 0.11, green: 0.13, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                snapshotContent
                    .frame(width: baseWidth, height: baseHeight - 40)
                    .scaleEffect(renderScale, anchor: .center)
                    .allowsHitTesting(false)
            }
            .clipped()
        }
        .background(Color(red: 0.09, green: 0.11, blue: 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.accentColor.opacity(0.95) : Color.white.opacity(0.22),
                    lineWidth: isFocused ? 2.5 : 1
                )
        }
        .shadow(color: Color.black.opacity(isFocused ? 0.65 : 0.40), radius: isFocused ? 28 : 16, x: 0, y: 14)
        .onAppear {
            engine.ensureHistorySnapshot(at: index)
        }
    }

    @ViewBuilder
    private var snapshotContent: some View {
        switch engine.snapshot(for: item) {
        case .wordEntry(let detail):
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 18) {
                    RubyWordView(cells: detail.rubyCells, hideKana: false, fontSize: 64)
                    if detail.header.pitchAccent != 255 {
                        Text("[\(detail.header.pitchAccent)]")
                            .font(.title2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 10)
                    }
                    Spacer()
                }
                Divider().opacity(0.25)
                ForEach(detail.senses.prefix(4)) { sense in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(sense.id + 1).")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(sense.enGlosses)
                            .font(.title3)
                            .lineLimit(2)
                    }
                }
                if let firstSent = detail.sentences.first {
                    Spacer(minLength: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(firstSent.jpText)
                            .font(.headline)
                            .lineLimit(2)
                        Text(firstSent.enText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                }
                Spacer()
            }
            .padding(28)

        case .kanjiDetail(let kanji):
            HStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    KanjiVectorDiagram(polylines: kanji.strokePolylines, visibleCount: kanji.strokePolylines.count)
                        .padding(24)
                }
                .frame(width: 240, height: 240)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text(kanji.glyph)
                            .font(.system(size: 56, weight: .bold))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kanji.meanings.isEmpty ? (kanji.specialCaseTitle ?? kanji.unicodeHex) : kanji.meanings)
                                .font(.title2.weight(.bold))
                                .lineLimit(2)
                            Text(kanji.strokes > 0 ? "\(kanji.strokes) strokes • Radical #\(kanji.radicalId)" : "\(kanji.unicodeHex) • \(kanji.unicodeBlockLabel)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !kanji.onReadings.isEmpty {
                        Text("On: \(kanji.onReadings.joined(separator: "、"))")
                            .font(.headline)
                    }
                    if !kanji.kunReadings.isEmpty {
                        Text("Kun: \(kanji.kunReadings.joined(separator: "、"))")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    if let firstWord = kanji.relatedWords.first {
                        Text("Top Word: \(firstWord.displayHeadword) (\(firstWord.kanaHead)) — \(firstWord.primaryGloss)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(28)

        case .fisheye(let kanji, let nodes, let leftOv, let rightOv):
            GeometryReader { g in
                let w = g.size.width
                let h = g.size.height
                let cx = w * 0.5
                let cy = h * 0.5
                let nodeFontSize: CGFloat = min(28, max(16, min(w, h) * 0.048))

                ZStack {
                    ForEach(nodes) { node in
                        let nx = cx + node.normX * (w * 0.46)
                        let ny = cy + node.normY * (h * 0.44)
                        Path { path in
                            path.move(to: CGPoint(x: cx, y: cy))
                            path.addQuadCurve(
                                to: CGPoint(x: nx, y: ny),
                                control: CGPoint(x: (cx + nx) * 0.5, y: cy)
                            )
                        }
                        .stroke(node.tierColor.opacity(0.32), lineWidth: 1.5)
                    }

                    ForEach(nodes) { node in
                        let nx = cx + node.normX * (w * 0.46)
                        let ny = cy + node.normY * (h * 0.44)
                        VStack(spacing: 1) {
                            Text(node.glyph)
                                .font(.system(size: nodeFontSize, weight: .bold))
                                .foregroundStyle(.white)
                            Text(node.shareText)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(node.tierColor)
                        }
                        .frame(width: nodeFontSize * 1.9, height: nodeFontSize * 1.9)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().strokeBorder(node.tierColor.opacity(0.75), lineWidth: 1.5))
                        .scaleEffect(node.scale)
                        .position(x: nx, y: ny)
                    }

                    VStack(spacing: 2) {
                        Text(kanji.glyph)
                            .font(.system(size: min(56, min(w, h) * 0.11), weight: .heavy))
                            .foregroundStyle(.white)
                        Text(kanji.meanings.split(separator: ";").first.map(String.init) ?? "")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .frame(width: 112, height: 112)
                    .background(Circle().fill(Color.accentColor.opacity(0.28)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 2))
                    .position(x: cx, y: cy)

                    if leftOv > 0 {
                        Text("+\(leftOv) left")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                            .position(x: 68, y: h - 26)
                    }
                    if rightOv > 0 {
                        Text("+\(rightOv) right")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                            .position(x: w - 68, y: h - 26)
                    }
                }
            }

        case .radicalBuilder(let sel, let strokes, let matches):
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Text("7-Slot Radical Builder")
                        .font(.title2.weight(.bold))
                    if strokes > 0 {
                        Text("• \(strokes) strokes")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { idx in
                        let isFilled = idx < sel.count
                        Text(isFilled ? RadicalCatalog.glyph(for: sel[idx]) : "＋")
                            .font(.system(size: 28, weight: .bold))
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 12).fill(isFilled ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06)))
                    }
                }
                Text("\(matches.count) Matching Kanji")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54))], spacing: 10) {
                    ForEach(matches.prefix(24), id: \.self) { cp in
                        Text(String(UnicodeScalar(cp)!))
                            .font(.system(size: 26, weight: .semibold))
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    }
                }
                Spacer()
            }
            .padding(28)

        case .kanjiLookup(let mode, let strokeCount, let sortOrder, let results):
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Text("Wordtank Kanji Index")
                        .font(.title2.weight(.bold))
                    Text("• \(mode.rawValue) • \(sortOrder.rawValue)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if mode == .strokes {
                        Text("(\(strokeCount) strokes)")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text("\(results.count) Indexed Kanji")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 10) {
                    ForEach(results.prefix(24)) { item in
                        VStack(spacing: 2) {
                            Text(item.glyph)
                                .font(.system(size: 28, weight: .bold))
                            Text("\(item.strokes)画")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 62, height: 62)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    }
                }
                Spacer()
            }
            .padding(28)

        case .none:
            VStack(spacing: 10) {
                Text(item.label)
                    .font(.system(size: 54, weight: .bold))
                Text(item.subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func iconForKind(_ kind: ActiveScreenKind) -> String {
        switch kind {
        case .fisheye: return "circle.hexagongrid.fill"
        case .wordEntry: return "text.book.closed.fill"
        case .kanjiDetail: return "character.book.closed.fill"
        case .radicalBuilder: return "puzzlepiece.extension.fill"
        case .kanjiLookup: return "list.bullet.rectangle.portrait.fill"
        case .wordCosmos: return "sparkles"
        }
    }
}

// MARK: - Fisheye Kanji Graph View (Adaptive Sizing + Interactive Hover & Selection)

// MARK: - Fisheye Kanji Graph View (Adaptive Sizing + Interactive Hover & Escalating Overflow Fan)

private struct OverflowPlacedBubble: Identifiable {
    let node: FisheyeNode
    let pos: CGPoint
    var id: String { node.id }
}

private struct OverflowFanLayout {
    let placed: [OverflowPlacedBubble]
    let maxRadius: CGFloat
    let totalAvailable: Int
}

struct FisheyeGraphView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var focusPoint: CGPoint?
    @State private var expandedOverflowSide: UInt8?
    @State private var overflowStage: Int = 0
    @State private var overflowPointerPos: CGPoint?
    @State private var hoveredOverflowPos: CGPoint?

    private var activeInspectorNode: FisheyeNode? {
        engine.hoveredFisheyeNode ?? engine.selectedFisheyeNode
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minDim = min(w, h)
            let cx = w * 0.5
            let cy = h * 0.5
            let aspectRatio = Float(max(0.5, w / max(1.0, h)))

            let centerDiameter: CGFloat = min(132, max(88, minDim * 0.165))
            let centerGlyphSize: CGFloat = centerDiameter * 0.48
            let nodeDiameter: CGFloat = min(56, max(36, minDim * 0.068))
            let nodeGlyphSize: CGFloat = nodeDiameter * 0.48
            let nodePctSize: CGFloat = max(8.5, nodeDiameter * 0.185)

            let leftAnchor = CGPoint(x: 54, y: h - 50)
            let rightAnchor = CGPoint(x: w - 54, y: h - 50)
            let isFanOpen = (expandedOverflowSide != nil && overflowStage > 0)

            let activeFan: OverflowFanLayout? = {
                guard let side = expandedOverflowSide, overflowStage > 0 else { return nil }
                let anchor = (side == 0) ? leftAnchor : rightAnchor
                return computeOverflowFan(side: side, stage: overflowStage, anchor: anchor)
            }()

            ZStack {
                // Background radial connections
                ForEach(engine.fisheyeNodes) { node in
                    let nx = cx + node.normX * (w * 0.455)
                    let ny = cy + node.normY * (h * 0.435)
                    let isHighlighted = !isFanOpen && activeInspectorNode?.id == node.id

                    Path { path in
                        path.move(to: CGPoint(x: cx, y: cy))
                        path.addQuadCurve(
                            to: CGPoint(x: nx, y: ny),
                            control: CGPoint(x: (cx + nx) * 0.5, y: cy)
                        )
                    }
                    .stroke(
                        node.tierColor.opacity(isFanOpen ? 0.05 : (isHighlighted ? 0.85 : 0.30 * node.opacity)),
                        lineWidth: isHighlighted ? 2.6 : 1.5
                    )
                }

                // Normal fisheye nodes
                ForEach(engine.fisheyeNodes) { node in
                    let nx = cx + node.normX * (w * 0.455)
                    let ny = cy + node.normY * (h * 0.435)
                    let isHighlighted = !isFanOpen && activeInspectorNode?.id == node.id

                    Button {
                        if engine.selectedFisheyeNode?.id == node.id {
                            engine.openFisheye(codepoint: node.codepoint, recordHistory: true)
                        } else {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                engine.selectedFisheyeNode = node
                            }
                        }
                    } label: {
                        VStack(spacing: 1) {
                            Text(node.glyph)
                                .font(.system(size: nodeGlyphSize, weight: .bold))
                                .foregroundStyle(.primary)

                            if engine.showFisheyePercentages {
                                Text(node.shareText)
                                    .font(.system(size: nodePctSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(node.tierColor)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: nodeDiameter, height: nodeDiameter)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .fill(isHighlighted ? node.tierColor.opacity(0.24) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            node.tierColor.opacity(isHighlighted ? 1.0 : 0.72),
                                            lineWidth: isHighlighted ? 2.6 : 1.6
                                        )
                                )
                        }
                        .shadow(color: node.tierColor.opacity(isHighlighted ? 0.45 : 0.16), radius: isHighlighted ? 14 : 8)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(node.scale * (isHighlighted ? 1.12 : 1.0))
                    .opacity(isFanOpen ? 0.12 : node.opacity)
                    .allowsHitTesting(!isFanOpen)
                    .position(x: nx, y: ny)
                }

                // Center Kanji glyph
                if let kanji = engine.activeKanji {
                    Button {
                        engine.openKanjiDetail(codepoint: kanji.codepoint)
                    } label: {
                        VStack(spacing: 2) {
                            Text(kanji.glyph)
                                .font(.system(size: centerGlyphSize, weight: .heavy))
                                .foregroundStyle(.primary)
                            Text(kanji.meanings.split(separator: ";").first.map(String.init) ?? "")
                                .font(.system(size: max(10, centerDiameter * 0.095), weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                        }
                        .frame(width: centerDiameter, height: centerDiameter)
                        .background {
                            Circle()
                                .fill(.regularMaterial)
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [.white.opacity(0.55), .white.opacity(0.12)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                }
                        }
                        .shadow(color: Color.black.opacity(0.32), radius: 22, x: 0, y: 10)
                    }
                    .buttonStyle(.plain)
                    .position(x: cx, y: cy)
                    .zIndex(15)
                }

                // Subtle center dividing guide line
                Path { p in
                    p.move(to: CGPoint(x: cx, y: 56))
                    p.addLine(to: CGPoint(x: cx, y: h - 56))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .foregroundStyle(Color.white.opacity(0.12))

                // Faint directional hints (← PREFIX + CENTER and CENTER + SUFFIX →)
                HStack {
                    Text("← PREFIX + CENTER")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.38))
                    Spacer()
                    Text("CENTER + SUFFIX →")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.38))
                }
                .padding(.horizontal, 28)
                .padding(.top, 56)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Overflow Fan-out bubbles
                if let fan = activeFan {
                    ForEach(fan.placed) { item in
                        let sub = item.node
                        let dockScale: CGFloat = {
                            guard let pt = overflowPointerPos else { return 0.94 }
                            let dist = hypot(item.pos.x - pt.x, item.pos.y - pt.y)
                            let radius: CGFloat = 76.0
                            if dist < radius {
                                let t = cos((dist / radius) * (.pi / 2.0))
                                return 1.0 + 0.46 * t * t
                            } else {
                                return 0.90
                            }
                        }()

                        let baseSize: CGFloat = engine.showFisheyePercentages ? 38.0 : 32.0
                        let diam = baseSize * dockScale
                        let isSelected = engine.selectedFisheyeNode?.id == sub.id
                        let isHov = engine.hoveredFisheyeNode?.id == sub.id
                        let active = isSelected || isHov

                        Button {
                            if isSelected {
                                engine.openFisheye(codepoint: sub.codepoint, recordHistory: true)
                            } else {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    engine.selectedFisheyeNode = sub
                                }
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Text(sub.glyph)
                                    .font(.system(size: 15.0 * dockScale, weight: active ? .bold : .semibold))
                                    .foregroundStyle(.primary)
                                if engine.showFisheyePercentages {
                                    Text(sub.shareText)
                                        .font(.system(size: 7.5 * dockScale, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(sub.tierColor)
                                }
                            }
                            .frame(width: diam, height: diam)
                            .background {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Circle().fill(sub.tierColor.opacity(active ? 0.36 : 0.18)))
                                    .overlay(
                                        Circle().strokeBorder(active ? Color.white : sub.tierColor.opacity(0.85), lineWidth: active ? 2.0 : 1.2)
                                    )
                            }
                            .shadow(color: active ? sub.tierColor.opacity(0.55) : Color.black.opacity(0.35), radius: 8)
                        }
                        .buttonStyle(.plain)
                        .frame(width: diam, height: diam)
                        .contentShape(Circle())
                        .position(item.pos)
                        .zIndex(25.0 + Double(dockScale * 10.0))
                        .transition(.scale(scale: 0.35).combined(with: .opacity))
                    }
                }

                // Escalating overflow trigger buttons
                if engine.leftOverflowCount > 0 {
                    overflowTriggerButton(
                        side: 0,
                        totalOverflow: engine.leftOverflowCount,
                        shownCount: expandedOverflowSide == 0 ? (activeFan?.placed.count ?? 0) : 0,
                        anchor: leftAnchor
                    )
                }

                if engine.rightOverflowCount > 0 {
                    overflowTriggerButton(
                        side: 1,
                        totalOverflow: engine.rightOverflowCount,
                        shownCount: expandedOverflowSide == 1 ? (activeFan?.placed.count ?? 0) : 0,
                        anchor: rightAnchor
                    )
                }

                // Overlaid controls and bottom inspector card
                VStack {
                    HStack(spacing: 10) {
                        Picker("Graph Mode", selection: $engine.fisheyeMode) {
                            Text("Compounds").tag(DJ_EDGE_COMPOUNDS)
                            Text("Yojijukugo").tag(DJ_EDGE_YOJIJUKUGO)
                            Text("Components").tag(DJ_EDGE_COMPONENTS)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 320)
                        .onChange(of: engine.fisheyeMode) { _, _ in
                            collapseOverflow()
                            if let cp = engine.activeKanji?.codepoint {
                                engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: aspectRatio)
                            }
                        }

                        Menu {
                            ForEach([6, 10, 12, 16, 24], id: \.self) { count in
                                Button("Show Top \(count) per side") {
                                    collapseOverflow()
                                    engine.maxFisheyePerSide = count
                                    if let cp = engine.activeKanji?.codepoint {
                                        engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: aspectRatio)
                                    }
                                }
                            }
                        } label: {
                            Label("Top \(engine.maxFisheyePerSide)/side", systemImage: "slider.horizontal.3")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.ultraThinMaterial))
                        }
                        .menuStyle(.borderlessButton)

                        Button {
                            engine.showFisheyePercentages.toggle()
                        } label: {
                            Label("% Share", systemImage: engine.showFisheyePercentages ? "percent" : "circle")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(engine.showFisheyePercentages ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        HStack(spacing: 12) {
                            legendDot(color: Color(red: 0.22, green: 0.74, blue: 0.97), label: "Core")
                            legendDot(color: Color(red: 0.20, green: 0.83, blue: 0.60), label: "Jōyō")
                            legendDot(color: Color(red: 0.98, green: 0.75, blue: 0.14), label: "Literary")
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.ultraThinMaterial))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                    Spacer()

                    HStack(alignment: .bottom, spacing: 14) {
                        Spacer()

                        if let active = activeInspectorNode {
                            LiquidGlassCard(cornerRadius: 18) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(active.compoundWord.isEmpty ? active.glyph : active.compoundWord)
                                                .font(.title3.weight(.bold))
                                            if !active.compoundKana.isEmpty && engine.recallMode != .hideKana {
                                                Text("(\(active.compoundKana))")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text("\(active.tierLabel) • \(active.shareText)")
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(active.tierColor.opacity(0.22)))
                                                .foregroundStyle(active.tierColor)
                                        }
                                        if engine.recallMode != .hideGloss {
                                            Text(active.compoundGloss.isEmpty ? "Tap to inspect kanji or word entry" : active.compoundGloss)
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    if active.topEntryId > 0 {
                                        Button {
                                            engine.openWordEntry(entryId: active.topEntryId)
                                        } label: {
                                            Label("Word", systemImage: "book.fill")
                                                .font(.subheadline.weight(.semibold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(Capsule().fill(Color.accentColor))
                                                .foregroundStyle(.white)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Button {
                                        engine.openFisheye(codepoint: active.codepoint)
                                    } label: {
                                        Label("Re-Center", systemImage: "scope")
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(Color.white.opacity(0.14)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            Text("Move pointer across bubbles for 3D magnification & compound preview; click to pin or double-click to pivot.")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.65))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(.ultraThinMaterial))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 84)
                    .padding(.bottom, 16)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard let cp = engine.activeKanji?.codepoint else { return }
                switch phase {
                case .active(let loc):
                    let nearLeftTrigger = engine.leftOverflowCount > 0 && hypot(loc.x - leftAnchor.x, loc.y - leftAnchor.y) <= 36.0
                    let nearRightTrigger = engine.rightOverflowCount > 0 && hypot(loc.x - rightAnchor.x, loc.y - rightAnchor.y) <= 36.0

                    if nearLeftTrigger || nearRightTrigger {
                        let targetSide: UInt8 = nearLeftTrigger ? 0 : 1
                        if expandedOverflowSide != targetSide || overflowStage == 0 {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                expandedOverflowSide = targetSide
                                overflowStage = 1
                            }
                        }
                        overflowPointerPos = loc
                        hoveredOverflowPos = nil
                        if engine.hoveredFisheyeNode?.isOverflowPreview == true {
                            engine.hoveredFisheyeNode = nil
                        }
                        return
                    }

                    if let activeSide = expandedOverflowSide, overflowStage > 0 {
                        let anchor = (activeSide == 0) ? leftAnchor : rightAnchor
                        let fan = computeOverflowFan(side: activeSide, stage: overflowStage, anchor: anchor)
                        let distFromAnchor = hypot(loc.x - anchor.x, loc.y - anchor.y)
                        let withinHemisphere = (activeSide == 0) ? (loc.x <= cx + 48.0) : (loc.x >= cx - 48.0)

                        if withinHemisphere && distFromAnchor <= fan.maxRadius + 60.0 {
                            overflowPointerPos = loc
                            let baseSize: CGFloat = engine.showFisheyePercentages ? 38.0 : 32.0
                            var bestSub: FisheyeNode?
                            var bestPos: CGPoint?
                            var bestDist: CGFloat = .greatestFiniteMagnitude

                            for item in fan.placed {
                                let d = hypot(item.pos.x - loc.x, item.pos.y - loc.y)
                                let dockScale: CGFloat = d < 76.0 ? (1.0 + 0.46 * pow(cos((d / 76.0) * (.pi / 2.0)), 2)) : 0.90
                                let hitR = (baseSize * dockScale) * 0.58
                                if d <= hitR && d < bestDist {
                                    bestDist = d
                                    bestSub = item.node
                                    bestPos = item.pos
                                }
                            }

                            hoveredOverflowPos = bestPos
                            if engine.hoveredFisheyeNode?.id != bestSub?.id {
                                engine.hoveredFisheyeNode = bestSub
                            }
                            return
                        } else {
                            collapseOverflow()
                        }
                    }

                    let fx = Float((loc.x - cx) / max(1.0, w * 0.5))
                    let fy = Float((loc.y - cy) / max(1.0, h * 0.5))
                    let nearCenter = hypot(Double(fx * aspectRatio), Double(fy)) < 0.12

                    if nearCenter {
                        engine.hoveredFisheyeNode = nil
                        if focusPoint != nil {
                            focusPoint = nil
                            engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: aspectRatio, animated: true)
                        }
                    } else {
                        let wasFocused = (focusPoint != nil)
                        focusPoint = loc
                        engine.solveFisheye(center: cp, hasFocus: true, focusX: fx, focusY: fy, aspectRatio: aspectRatio, animated: !wasFocused)

                        var bestNode: FisheyeNode?
                        var bestDist: CGFloat = .greatestFiniteMagnitude
                        for node in engine.fisheyeNodes {
                            let bx = cx + node.normX * (w * 0.455)
                            let by = cy + node.normY * (h * 0.435)
                            let d = hypot(loc.x - bx, loc.y - by)
                            let hitRadius = (nodeDiameter * node.scale) * 0.60
                            if d <= hitRadius && d < bestDist {
                                bestDist = d
                                bestNode = node
                            }
                        }
                        if engine.hoveredFisheyeNode?.id != bestNode?.id {
                            engine.hoveredFisheyeNode = bestNode
                        }
                    }

                case .ended:
                    focusPoint = nil
                    engine.hoveredFisheyeNode = nil
                    collapseOverflow()
                    engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: aspectRatio, animated: true)
                }
            }
            .onChange(of: engine.activeKanji?.codepoint) { _, _ in
                focusPoint = nil
                collapseOverflow()
            }
        }
    }

    @ViewBuilder
    private func overflowTriggerButton(side: UInt8, totalOverflow: Int, shownCount: Int, anchor: CGPoint) -> some View {
        let isExpanded = (expandedOverflowSide == side && overflowStage > 0)
        let remaining = max(0, totalOverflow - shownCount)

        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                if expandedOverflowSide != side || overflowStage == 0 {
                    expandedOverflowSide = side
                    overflowStage = 1
                } else if overflowStage == 1 && remaining > 0 {
                    overflowStage = 2
                } else if overflowStage == 2 && remaining > 0 {
                    overflowStage = 3
                } else {
                    expandedOverflowSide = nil
                    overflowStage = 0
                }
            }
        } label: {
            VStack(spacing: 1) {
                Text(!isExpanded ? "+\(totalOverflow)" : (remaining > 0 ? "+\(remaining)" : "All \(totalOverflow)"))
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Text(!isExpanded ? "more" : (remaining > 0 ? "expand" : "shown"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, height: 52)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(
                Circle()
                    .strokeBorder(
                        Color.cyan.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1.5, dash: isExpanded ? [] : [3, 3])
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(!isExpanded ? "Hover to preview; click to expand more kanji" : (remaining > 0 ? "Click again to show even more kanji" : "Click to collapse"))
        .position(anchor)
        .zIndex(45)
    }

    private func computeOverflowFan(side: UInt8, stage: Int, anchor: CGPoint) -> OverflowFanLayout {
        let allItems = engine.overflowPreviewNodes.filter { $0.side == side }
        let maxRings: Int = {
            switch stage {
            case 1: return 2
            case 2: return 4
            default: return 99
            }
        }()

        let dir: CGFloat = (side == 0) ? 1.0 : -1.0
        let arcSpanDeg: CGFloat = 84.0
        let arcSpanRad: CGFloat = arcSpanDeg * .pi / 180.0
        let minArcSpacing: CGFloat = 40.0

        var rings: [[FisheyeNode]] = []
        var cursor = 0
        var ringIdx = 0
        while cursor < allItems.count && ringIdx < maxRings {
            let r = 68.0 + CGFloat(ringIdx) * 43.0
            let cap = max(3, Int(floor((r * arcSpanRad) / minArcSpacing)))
            let end = min(allItems.count, cursor + cap)
            rings.append(Array(allItems[cursor..<end]))
            cursor = end
            ringIdx += 1
        }

        var placed: [OverflowPlacedBubble] = []
        var outerRadius: CGFloat = 68.0

        for (rIdx, ringNodes) in rings.enumerated() {
            let r = 68.0 + CGFloat(rIdx) * 43.0
            outerRadius = r
            let count = ringNodes.count
            for (i, node) in ringNodes.enumerated() {
                let t = count <= 1 ? 0.5 : CGFloat(i) / CGFloat(count - 1)
                let angleDeg = -86.0 + t * arcSpanDeg
                let rad = angleDeg * .pi / 180.0
                let pos = CGPoint(
                    x: anchor.x + dir * cos(rad) * r,
                    y: anchor.y + sin(rad) * r
                )
                placed.append(OverflowPlacedBubble(node: node, pos: pos))
            }
        }

        return OverflowFanLayout(placed: placed, maxRadius: outerRadius, totalAvailable: allItems.count)
    }

    private func collapseOverflow() {
        if expandedOverflowSide != nil || overflowStage != 0 {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                expandedOverflowSide = nil
                overflowStage = 0
                overflowPointerPos = nil
                hoveredOverflowPos = nil
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Word Cosmos View (Randomized Prevalence Bubble Cloud)

/// A deterministic, seed-driven RNG (splitmix64) so the cloud re-flows to a
/// *new* but *stable* arrangement on every dice-roll instead of jumping to a
/// fresh random layout on each re-render.
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func fraction() -> Double {
        Double(next() & 0xFFFFFFFF) / Double(0xFFFFFFFF)
    }
}

/// Halton low-discrepancy sequence — even 2D coverage with no rejection cost,
/// used as the base of the "Cloud" Poisson-ish scatter.
private func halton(_ index: Int, base: Int) -> Double {
    var f = 1.0
    var r = 0.0
    var i = index
    while i > 0 {
        f /= Double(base)
        r += f * Double(i % base)
        i /= base
    }
    return r
}

/// Mirrors the cockpit's WordTelemetry tier → ratio → color mapping, but derived
/// straight from a raw `WordHit` (freqRank / isName) so the cosmos can size and
/// tint bubbles without loading a full entry detail.
private enum CosmosTierInfo {
    static func of(_ word: WordHit) -> (ratio: Double, color: Color, label: String, rankStr: String) {
        let rank = word.freqRank
        if word.isName {
            return (0.35, Color.purple, "Proper Name", rank < 999_999 ? "#\(rank)" : "Name")
        } else if rank <= 500 {
            return (1.0, Color(red: 0.22, green: 0.74, blue: 0.97), "Core Top 500", "#\(rank)")
        } else if rank <= 2500 {
            return (0.84, Color(red: 0.22, green: 0.74, blue: 0.97), "Core Top 2,500", "#\(rank)")
        } else if rank <= 10_000 {
            return (0.66, Color(red: 0.20, green: 0.83, blue: 0.60), "Jōyō Common", "#\(rank)")
        } else if rank <= 35_000 {
            return (0.45, Color(red: 0.98, green: 0.75, blue: 0.14), "Standard", "#\(rank)")
        } else if rank < 999_999 {
            return (0.26, Color(red: 0.65, green: 0.55, blue: 0.98), "Literary", "#\(rank)")
        } else {
            return (0.16, Color.white.opacity(0.55), "Unranked", "—")
        }
    }
}

/// One placed bubble: a sampled word with its deterministic position + tier.
private struct CosmosBubble: Identifiable {
    let word: WordHit
    var id: UInt32 { word.id }
    let pos: CGPoint
    let ratio: Double
    let color: Color
    let tierLabel: String
    let rankStr: String
    let hasKanji: Bool
    let diameter: CGFloat
}

/// Lay the current sample out for a given layout + seed + canvas.
/// `cloud` = Halton-jittered scatter; `constellation` = concentric rings by tier.
private func cosmosLayout(
    words: [WordHit],
    seed: UInt64,
    layout: WordCosmosLayout,
    w: CGFloat,
    h: CGFloat
) -> [CosmosBubble] {
    guard w > 0, h > 0, !words.isEmpty else { return [] }

    let topMargin: CGFloat = 78      // clears the top control bar
    let bottomMargin: CGFloat = 96   // clears the bottom inspector ribbon
    let sideMargin: CGFloat = 56
    let minDim = min(w, h)

    // Shrink bubble footprint as the sample grows so a 300-word roll stays legible.
    let countFactor = pow(50.0 / Double(max(1, words.count)), 0.35)
    let base = minDim * 0.135 * CGFloat(countFactor)

    var rng = SeededRNG(seed: seed)
    var bubbles: [CosmosBubble] = []
    bubbles.reserveCapacity(words.count)

    if layout == .constellation {
        let cx = w * 0.5
        let cy = topMargin + (h - topMargin - bottomMargin) * 0.5
        let maxR = minDim * 0.40

        // Group words into the six tier rings (ring 0 = innermost = most common).
        var rings: [[WordHit]] = Array(repeating: [], count: 6)
        for word in words {
            let info = CosmosTierInfo.of(word)
            let t = max(0.0, min(1.0, (info.ratio - 0.16) / (1.0 - 0.16))) // 1 = inner
            let ring = Int((1.0 - t) * 5.999)
            rings[max(0, min(5, ring))].append(word)
        }

        for (ring, group) in rings.enumerated() where !group.isEmpty {
            var ordered = group
            ordered.shuffle(using: &rng)
            let r = maxR * (CGFloat(ring) / 5.0 + 0.14)
            let n = ordered.count
            for (i, word) in ordered.enumerated() {
                let info = CosmosTierInfo.of(word)
                let angle = (2 * .pi * CGFloat(i) / CGFloat(n)) + rng.fraction() * 0.35
                let jitter = 1.0 + (rng.fraction() - 0.5) * 0.12
                let pos = CGPoint(x: cx + cos(angle) * r * CGFloat(jitter),
                                  y: cy + sin(angle) * r * CGFloat(jitter))
                bubbles.append(CosmosBubble(
                    word: word,
                    pos: pos,
                    ratio: info.ratio,
                    color: info.color,
                    tierLabel: info.label,
                    rankStr: info.rankStr,
                    hasKanji: word.firstKanjiCodepoint != nil,
                    diameter: max(22, base * CGFloat(info.ratio))
                ))
            }
        }
    } else {
        let innerW = max(1, w - sideMargin * 2)
        let innerH = max(1, h - topMargin - bottomMargin)
        for (i, word) in words.enumerated() {
            let info = CosmosTierInfo.of(word)
            let hx = halton(i + 1, base: 2)
            let hy = halton(i + 1, base: 3)
            let jx = (rng.fraction() - 0.5) * 0.16
            let jy = (rng.fraction() - 0.5) * 0.16
            let x = sideMargin + innerW * min(1.0, max(0.0, hx + jx))
            let y = topMargin + innerH * min(1.0, max(0.0, hy + jy))
            bubbles.append(CosmosBubble(
                word: word,
                pos: CGPoint(x: x, y: y),
                ratio: info.ratio,
                color: info.color,
                tierLabel: info.label,
                rankStr: info.rankStr,
                hasKanji: word.firstKanjiCodepoint != nil,
                diameter: max(22, base * CGFloat(info.ratio))
            ))
        }
    }

    return bubbles
}

struct WordCosmosView: View {
    @ObservedObject var engine: DaiJishowEngine

    @State private var pointerPos: CGPoint?
    @State private var hoveredWord: WordHit?

    private var activeWord: WordHit? { hoveredWord }

    var body: some View {
        ZStack {
            if engine.wordCosmosMode == .ranked {
                rankedListView
            } else {
                cosmosCloudView
            }
        }
        .overlay(alignment: .top) {
            controlBar
        }
        .overlay(alignment: .bottom) {
            if engine.wordCosmosMode == .cosmos {
                inspectorRibbon
            }
        }
    }

    // MARK: - Cosmos / Constellation cloud

    @ViewBuilder
    private var cosmosCloudView: some View {
        GeometryReader { geo in
            let bubbles = cosmosLayout(
                words: engine.wordCosmosWords,
                seed: engine.wordCosmosSeed,
                layout: engine.wordCosmosLayout,
                w: geo.size.width,
                h: geo.size.height
            )

            ZStack {
                if engine.wordCosmosLayout == .constellation {
                    constellationGuides(w: geo.size.width, h: geo.size.height)
                }

                if bubbles.isEmpty {
                    emptyState
                } else {
                    ForEach(bubbles) { b in
                        bubble(for: b)
                    }
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc):
                    pointerPos = loc
                    var best: CosmosBubble?
                    var bestDist: CGFloat = .greatestFiniteMagnitude
                    for b in bubbles {
                        let d = hypot(b.pos.x - loc.x, b.pos.y - loc.y)
                        let hitR = b.diameter * 0.62
                        if d <= hitR && d < bestDist {
                            bestDist = d
                            best = b
                        }
                    }
                    if hoveredWord?.id != best?.word.id {
                        hoveredWord = best?.word
                    }
                case .ended:
                    pointerPos = nil
                    withAnimation(.easeOut(duration: 0.15)) {
                        hoveredWord = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(for b: CosmosBubble) -> some View {
        let isActive = (hoveredWord?.id == b.id)
        let diameter = b.diameter

        // Fisheye lens: magnify bubbles near the pointer with a cosine bell
        // (same family as the overflow-dock magnification).
        let lensScale: CGFloat = {
            guard let p = pointerPos else { return 1.0 }
            let d = hypot(b.pos.x - p.x, b.pos.y - p.y)
            let reach = diameter + 96
            if d < reach {
                let t = cos((d / reach) * (.pi / 2.0))
                return 1.0 + 0.55 * t * t
            }
            return 1.0
        }()
        let scaled = diameter * lensScale
        let fontSize = max(9, scaled * 0.34)
        let showKana = b.hasKanji && !b.word.kanaHead.isEmpty
            && engine.recallMode != .hideKana && scaled >= 30

        VStack(spacing: 1) {
            Text(b.word.displayHeadword)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if showKana {
                Text(b.word.kanaHead)
                    .font(.system(size: max(6, fontSize * 0.34), weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: scaled, height: scaled)
        .background {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(b.color.opacity(isActive ? 0.34 : 0.18)))
                .overlay(
                    Circle().strokeBorder(
                        isActive ? Color.white : b.color.opacity(0.82),
                        lineWidth: isActive ? 2.4 : 1.4
                    )
                )
        }
        .shadow(color: b.color.opacity(isActive ? 0.5 : 0.14), radius: isActive ? 12 : 6)
        .contentShape(Circle())
        .scaleEffect(lensScale, anchor: .center)
        // Single tap → Word Cockpit; double tap → pivot into Kanji Fisheye.
        .onTapGesture {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                engine.openWordFromCosmos(b.word)
            }
        }
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                engine.pivotCosmosToKanjiFisheye(b.word)
            }
        }
        .position(b.pos)
        .zIndex(isActive ? 30 : 10 + Double(b.ratio))
        .transition(.scale(scale: 0.3).combined(with: .opacity))
    }

    @ViewBuilder
    private func constellationGuides(w: CGFloat, h: CGFloat) -> some View {
        let cx = w * 0.5
        let cy = 78 + (h - 78 - 96) * 0.5
        let maxR = min(w, h) * 0.40
        ZStack {
            ForEach(0...5, id: \.self) { ring in
                Circle()
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(
                        width: maxR * 2 * (CGFloat(ring) / 5.0 + 0.14),
                        height: maxR * 2 * (CGFloat(ring) / 5.0 + 0.14)
                    )
                    .position(x: cx, y: cy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.secondary)
            Text("The cosmos is empty")
                .font(.title2.weight(.semibold))
            Text("Roll the dice to summon a randomized cloud of words")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    engine.diceRollWordCosmos()
                }
            } label: {
                Label("Roll the Dice", systemImage: "dice")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Ranked "words by prevalence" list

    @ViewBuilder
    private var rankedListView: some View {
        let sorted = engine.wordCosmosWords.sorted { $0.freqRank < $1.freqRank }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, word in
                    rankedRow(word: word, rank: index + 1)
                }
            }
            .padding(16)
            .textSelection(.enabled)
        }
        .padding(.top, 64)   // clear the control bar
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func rankedRow(word: WordHit, rank: Int) -> some View {
        let info = CosmosTierInfo.of(word)
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            Text(word.displayHeadword)
                .font(.title3.weight(.bold))
                .frame(minWidth: 90, alignment: .leading)

            if engine.recallMode != .hideKana {
                Text(word.kanaHead)
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 96, alignment: .leading)
            }

            if engine.recallMode != .hideGloss {
                Text(word.primaryGloss)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(info.label) · \(info.rankStr)")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(info.color.opacity(0.2)))
                .foregroundStyle(info.color)

            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                    engine.openWordFromCosmos(word)
                }
            } label: {
                Label("Open", systemImage: "book.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            if word.firstKanjiCodepoint != nil {
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        engine.pivotCosmosToKanjiFisheye(word)
                    }
                } label: {
                    Image(systemName: "scope")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill((hoveredWord?.id == word.id) ? Color.white.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                engine.openWordFromCosmos(word)
            }
        }
        .onHover { inside in
            if inside { hoveredWord = word }
        }
    }

    // MARK: - Top control bar

    private var controlBar: some View {
        HStack(spacing: 10) {
            Picker("Layout", selection: $engine.wordCosmosLayout) {
                ForEach(WordCosmosLayout.allCases) { l in
                    Text(l.label).tag(l)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .opacity(engine.wordCosmosMode == .cosmos ? 1 : 0.35)

            Picker("View", selection: $engine.wordCosmosMode) {
                ForEach(WordCosmosMode.allCases) { m in
                    Text(m == .cosmos ? "Cosmos" : "Ranked").tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 168)

            Picker("Tier", selection: $engine.wordCosmosTier) {
                ForEach(WordCosmosTier.allCases) { t in
                    Text(t.label).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 196)
            .onChange(of: engine.wordCosmosTier) { _, new in
                engine.setWordCosmosTier(new)
            }

            Menu {
                ForEach([50, 150, 300], id: \.self) { count in
                    Button("Sample \(count) words") {
                        engine.sampleWordCosmos(count: count)
                    }
                }
            } label: {
                Label("\(engine.wordCosmosCount) words", systemImage: "number")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.ultraThinMaterial))
            }
            .menuStyle(.borderlessButton)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    engine.diceRollWordCosmos()
                }
            } label: {
                Label("Roll", systemImage: "dice")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .help("Re-roll a fresh randomized sample")

            Toggle(isOn: $engine.wordCosmosIncludeNames) {
                Text("Names").font(.caption.weight(.semibold))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .fixedSize()
            .onChange(of: engine.wordCosmosIncludeNames) { _, _ in
                engine.sampleWordCosmos(includeNames: engine.wordCosmosIncludeNames)
            }

            Spacer()

            HStack(spacing: 10) {
                legendDot(color: Color(red: 0.22, green: 0.74, blue: 0.97), label: "Core")
                legendDot(color: Color(red: 0.20, green: 0.83, blue: 0.60), label: "Jōyō")
                legendDot(color: Color(red: 0.98, green: 0.75, blue: 0.14), label: "Std")
                legendDot(color: Color(red: 0.65, green: 0.55, blue: 0.98), label: "Lit")
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.ultraThinMaterial))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Capsule().fill(.ultraThinMaterial).opacity(0.45))
    }

    // MARK: - Bottom inspector ribbon

    @ViewBuilder
    private var inspectorRibbon: some View {
        HStack(alignment: .bottom, spacing: 14) {
            Spacer()

            if let word = activeWord {
                let info = CosmosTierInfo.of(word)
                LiquidGlassCard(cornerRadius: 18) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(word.displayHeadword)
                                    .font(.title3.weight(.bold))
                                if engine.recallMode != .hideKana && !word.kanaHead.isEmpty {
                                    Text("(\(word.kanaHead))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(info.label) • \(info.rankStr)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(info.color.opacity(0.22)))
                                    .foregroundStyle(info.color)
                            }
                            if engine.recallMode != .hideGloss {
                                Text(word.primaryGloss.isEmpty ? "Tap to open the Word Cockpit" : word.primaryGloss)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Button {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                engine.openWordFromCosmos(word)
                            }
                        } label: {
                            Label("Word Cockpit", systemImage: "book.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.accentColor))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        if word.firstKanjiCodepoint != nil {
                            Button {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                    engine.pivotCosmosToKanjiFisheye(word)
                                }
                            } label: {
                                Label("Kanji Fisheye", systemImage: "scope")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Color.white.opacity(0.14)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("Hover a bubble to preview · click to open the Word Cockpit · double-click a kanji word to pivot into its Kanji Fisheye")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.ultraThinMaterial))
            }

            Spacer()
        }
        .padding(.horizontal, 84)
        .padding(.bottom, 16)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Word Entry Cockpit View (Reader + Cockpit Modes)

struct WordEntryView: View {
    @ObservedObject var engine: DaiJishowEngine
    let entry: EntryDetail

    @State private var showAllSentences: Bool = false

    // Top-10 expansion toggles for the cockpit pill lists (compounds + homonyms).
    // Reset when the active entry changes so each word starts collapsed.
    @State private var showAllPrefixCompounds: Bool = false
    @State private var showAllSuffixCompounds: Bool = false
    @State private var showAllHomonyms: Bool = false

    private var insights: WordLexicalInsights {
        if let active = engine.activeWordInsights, active.entryId == entry.header.id {
            return active
        }
        return engine.ensureWordInsights(for: entry)
    }

    private var pitchContour: PitchAccentContour? {
        guard engine.recallMode != .hideKana else { return nil }
        return PitchAccentContour.build(kana: entry.header.kanaHead, pitchAccent: entry.header.pitchAccent)
    }

    private var activeSentences: [SentenceItem] {
        entry.sentences.isEmpty ? insights.fallbackSentences : entry.sentences
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerHeroCard
                if engine.isWordCockpitExpanded {
                    cockpitDashboardContent
                } else {
                    readerCompactContent
                }
            }
            .padding(24)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
            .textSelection(.enabled)
            .contextMenu {
                Button {
                    engine.copyText(entry.copyText)
                } label: {
                    Label("Copy Entry", systemImage: "doc.on.doc")
                }
                Divider()
                Button {
                    engine.copyText(entry.header.displayHeadword)
                } label: {
                    Label("Copy Headword", systemImage: "text.cursor")
                }
            }
        }
        .onAppear {
            showAllSentences = false
            showAllPrefixCompounds = false
            showAllSuffixCompounds = false
            showAllHomonyms = false
            _ = engine.ensureWordInsights(for: entry)
        }
        .onChange(of: entry.header.id) { _, _ in
            showAllSentences = false
            showAllPrefixCompounds = false
            showAllSuffixCompounds = false
            showAllHomonyms = false
            _ = engine.ensureWordInsights(for: entry)
        }
    }

    // MARK: - 1. Hero Lexical Card (Headword + Pitch Contour + Telemetry + Mode Switch)

    private var headerHeroCard: some View {
        LiquidGlassCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    RubyWordView(
                        cells: entry.rubyCells,
                        hideKana: engine.recallMode == .hideKana,
                        fontSize: 48
                    ) { cp in
                        engine.openKanjiDetail(codepoint: cp)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 8) {
                            // Reader vs. Cockpit Toggle (Persisted in UserDefaults)
                            Picker("View Mode", selection: $engine.isWordCockpitExpanded) {
                                Label("Reader", systemImage: "doc.plaintext")
                                    .tag(false)
                                Label("Cockpit", systemImage: "rectangle.3.group.fill")
                                    .tag(true)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 196)
                            .help("Reader shows just the definitions; Cockpit reveals the full analysis dashboard (homonyms, compounds, collocations, conjugations, …).")

                            if entry.hasJapaneseGlosses {
                                Picker("Gloss Language", selection: $engine.glossLanguageMode) {
                                    ForEach(GlossLanguageMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 144)
                                .help("Show the definition in English, Japanese, or both.")
                            }
                        }

                        // Telemetry Pills
                        HStack(spacing: 6) {
                            telemetryPill(
                                text: "\(insights.telemetry.frequencyTier) (\(insights.telemetry.frequencyRankText))",
                                tint: insights.telemetry.tierColor
                            )
                            .help("Corpus frequency tier — how often this word appears, from the most common words down to rare ones.")
                            if let jlpt = insights.telemetry.jlptLabel {
                                telemetryPill(text: jlpt, tint: .cyan)
                                    .help("JLPT level — the Japanese-Language Proficiency Test tier this word is associated with.")
                            }
                            if let grade = insights.telemetry.gradeLabel {
                                telemetryPill(text: grade, tint: .green)
                                    .help("Grade — the Japanese school year in which this kanji is typically taught.")
                            }
                            if insights.telemetry.totalStrokes > 0 {
                                telemetryPill(text: "\(insights.telemetry.totalStrokes)画", tint: .orange)
                                    .help("Total strokes — the number of strokes in the word's kanji (画 means 'stroke').")
                            }
                        }
                    }
                }

                // Pitch Accent Visual Contour & Popularity Meter
                if pitchContour != nil || !entry.header.variantList.isEmpty {
                    HStack(alignment: .center, spacing: 16) {
                        if let contour = pitchContour {
                            PitchAccentContourView(contour: contour)
                                .help("Pitch-accent contour — the rise/fall of the spoken syllables; the bracketed number is the accent nucleus position.")
                        }

                        Spacer(minLength: 8)

                        // Popularity Meter Bar
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Corpus Frequency")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.10))
                                    Capsule()
                                        .fill(insights.telemetry.tierColor)
                                        .frame(width: max(12, barGeo.size.width * insights.telemetry.popularityRatio))
                                }
                            }
                            .frame(width: 112, height: 6)
                        }
                        .help("Corpus frequency meter — how common this word is in the corpus, from rare (short bar) to very common (full bar).")
                    }
                }

                // Alternative Orthographic Forms (表記ゆれ)
                if !entry.header.variantList.isEmpty {
                    HStack(spacing: 8) {
                        Text("Also written:")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .help("Alternative spellings of this word (表記ゆれ). Click one to open that variant.")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(entry.header.variantList, id: \.self) { variant in
                                    Button {
                                        engine.openVariantForm(variant)
                                    } label: {
                                        Text(variant)
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color.white.opacity(0.08)))
                                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open the variant form \(variant)")
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - 2A. Reader Mode (Clean Distraction-Free Definitions + Sentences)

    private var readerCompactContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            definitionsSection
            transitivityPairBanner
            if !activeSentences.isEmpty {
                sentencesSection
            }
        }
    }

    // MARK: - 2B. Cockpit Mode (Full Multi-Dimensional Lexical Dashboard)

    private var cockpitDashboardContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Kanji DNA Strip (Per-Kanji Breakdown + Active Reading Highlight)
            if !insights.kanjiDNA.isEmpty {
                kanjiDNASection
            }

            // Contextual Senses + Transitivity Pair
            definitionsSection
            transitivityPairBanner

            // Homonyms (同音異義語)
            if !insights.homonyms.isEmpty {
                homonymsSection
            }

            // Word Family (Prefix & Suffix Compounds)
            if !insights.prefixCompounds.isEmpty || !insights.suffixCompounds.isEmpty {
                wordFamilySection
            }

            // Corpus Collocations + Example Sentences
            if !insights.collocations.isEmpty || !activeSentences.isEmpty {
                sentencesAndCollocationsSection
            }

            // Verb / Adjective Inflection Matrix
            if !insights.inflections.isEmpty, let header = insights.inflectionHeader {
                inflectionMatrixSection(title: header, forms: insights.inflections)
            }
        }
    }

    // MARK: - Kanji DNA Breakdown Strip

    private var kanjiDNASection: some View {
        LiquidGlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Kanji DNA", systemImage: "square.grid.2x2.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .help("The individual kanji that make up this word, with their meanings, stroke counts, and JLPT level. Click one to open its detail page.")
                    Spacer()
                    Text("Tap any kanji to inspect stroke vectors & graph")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(insights.kanjiDNA) { k in
                            Button {
                                engine.openKanjiDetail(codepoint: k.codepoint)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(k.glyph)
                                        .font(.system(size: 36, weight: .bold))
                                        .frame(width: 54, height: 54)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(0.08))
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(k.meanings.split(separator: ";").first.map(String.init) ?? "Kanji")
                                                .font(.subheadline.weight(.bold))
                                                .lineLimit(1)
                                            if k.strokes > 0 {
                                                Text("\(k.strokes)画")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                            }
                                            if !k.jlptLabel.isEmpty {
                                                Text(k.jlptLabel)
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.cyan)
                                            }
                                            if k.isJukujikun {
                                                Text("熟字訓")
                                                    .font(.caption2.weight(.bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 1)
                                                    .background(Capsule().fill(Color.orange.opacity(0.22)))
                                                    .foregroundStyle(.orange)
                                            }
                                        }

                                        if !k.onReadings.isEmpty {
                                            readingTokenRow(
                                                label: "音",
                                                tokens: k.onReadings.prefix(4).map { $0 },
                                                matchedNormalized: k.matchedReadingNormalized
                                            )
                                        }
                                        if !k.kunReadings.isEmpty {
                                            readingTokenRow(
                                                label: "訓",
                                                tokens: k.kunReadings.prefix(4).map { $0 },
                                                matchedNormalized: k.matchedReadingNormalized
                                            )
                                        }
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Open \(k.glyph) — \(k.meanings.split(separator: ";").first.map(String.init) ?? "kanji")")
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    private func readingTokenRow(label: String, tokens: [String], matchedNormalized: String?) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            ForEach(tokens, id: \.self) { tok in
                let stem = KanaNormalizer.stemBeforeDot(tok)
                let isActive = (matchedNormalized != nil && !stem.isEmpty && stem == matchedNormalized)
                Text(tok)
                    .font(.caption.weight(isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                    .padding(.horizontal, isActive ? 6 : 2)
                    .padding(.vertical, 1)
                    .background {
                        if isActive {
                            Capsule().fill(Color.accentColor.opacity(0.20))
                        }
                    }
            }
        }
    }

    // MARK: - Contextual Senses Section

    private var definitionsSection: some View {
        LiquidGlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Definitions", systemImage: "book.pages.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .help("The dictionary senses of this word, in order of frequency. Each numbered item is a distinct meaning.")
                    Spacer()
                    Text("\(entry.senses.count) \(entry.senses.count == 1 ? "sense" : "senses")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if engine.recallMode == .hideGloss {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash.fill")
                        Text("Definitions hidden in Recall Mode — switch to Full in top bar to reveal.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                } else {
                    ForEach(entry.senses) { sense in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(sense.id + 1)")
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Color.accentColor.opacity(0.75)))

                                VStack(alignment: .leading, spacing: 6) {
                                    if let tags = insights.senseTags[sense.id], !tags.isEmpty {
                                        HStack(spacing: 6) {
                                            ForEach(tags, id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                            }
                                        }
                                    }

                                    let showEn = (engine.glossLanguageMode == .english || engine.glossLanguageMode == .both || !entry.hasJapaneseGlosses)
                                    let showJa = (engine.glossLanguageMode == .japanese || engine.glossLanguageMode == .both) && !sense.jaGlosses.isEmpty

                                    if showEn && !sense.enGlosses.isEmpty {
                                        Text(sense.enGlosses)
                                            .font(.body)
                                            .textSelection(.enabled)
                                    }

                                    if showJa {
                                        Text(sense.jaGlosses)
                                            .font(showEn ? .callout : .body)
                                            .foregroundStyle(showEn ? .secondary : .primary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                        if sense.id != entry.senses.last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    // MARK: - Transitivity Pair Banner (自他ペア)

    @ViewBuilder
    private var transitivityPairBanner: some View {
        if entry.header.pairEntryId > 0 {
            LiquidGlassCard(cornerRadius: 16) {
                HStack(spacing: 12) {
                    Label("自他ペア", systemImage: "arrow.left.arrow.right.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                        .help("A self/other verb pair (自他動詞): this verb and its counterpart that flips between the subject acting on itself vs. on something else. Click to open the pair.")

                    Text("Paired Verb:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        engine.openWordEntry(entryId: entry.header.pairEntryId)
                    } label: {
                        HStack(spacing: 6) {
                            Text(entry.pairedKanji.isEmpty ? entry.pairedKana : entry.pairedKanji)
                                .font(.headline.weight(.bold))
                            if !entry.pairedKanji.isEmpty && !entry.pairedKana.isEmpty && engine.recallMode != .hideKana {
                                Text("(\(entry.pairedKana))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "arrow.right")
                                .font(.caption.bold())
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Homonyms Section (同音異義語)

    private var homonymsSection: some View {
        let limit = 10
        let items = insights.homonyms
        let visible = showAllHomonyms ? items : Array(items.prefix(limit))
        let hasMore = items.count > limit
        return LiquidGlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Homonyms • 同音異義語 (\(entry.header.kanaHead))", systemImage: "waveform.and.magnifyingglass")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .help("Other words that share the same reading (\(entry.header.kanaHead)) but differ in meaning. Click a pill to open that word.")
                    Spacer()
                    Text("\(items.count) entries")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                WrappingHStack(alignment: .top, horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(visible) { hit in
                        Button {
                            engine.openWordEntry(entryId: hit.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(hit.displayHeadword)
                                        .font(.headline.weight(.bold))
                                    if hit.pitchAccent != 255 {
                                        Text("[\(hit.pitchAccent)]")
                                            .font(.caption2.monospacedDigit().weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if engine.recallMode != .hideGloss {
                                    Text(hit.primaryGloss)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(width: 176, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .help("\(hit.displayHeadword)\n\(hit.primaryGloss)\n\(hit.pitchAccent != 255 ? "Pitch accent [\(hit.pitchAccent)]" : "Same reading as \(entry.header.kanaHead)")")
                    }
                }

                if hasMore {
                    Button {
                        showAllHomonyms.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Text(showAllHomonyms ? "Show Less" : "Show more (\(items.count - limit) more)")
                            Image(systemName: showAllHomonyms ? "chevron.up" : "chevron.down")
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .help(showAllHomonyms ? "Collapse back to the top \(limit) homonyms" : "Show all \(items.count) homonyms")
                    .padding(.top, 2)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Word Family Section (Prefix & Suffix Compounds)

    private var wordFamilySection: some View {
        LiquidGlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Word Family • Compounds", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .help("Other words built from this headword: compounds that start with it (prefixes) and compounds that end with it (suffixes). Click a pill to open that word.")

                if !insights.prefixCompounds.isEmpty {
                    compoundGroupRow(title: "Starts with \(entry.header.displayHeadword)〜", items: insights.prefixCompounds, isExpanded: $showAllPrefixCompounds)
                }

                if !insights.suffixCompounds.isEmpty {
                    compoundGroupRow(title: "Ends with 〜\(entry.header.displayHeadword)", items: insights.suffixCompounds, isExpanded: $showAllSuffixCompounds)
                }
            }
            .padding(18)
        }
    }

    private func compoundGroupRow(title: String, items: [WordHit], isExpanded: Binding<Bool>) -> some View {
        let limit = 10
        let visible = isExpanded.wrappedValue ? items : Array(items.prefix(limit))
        let hasMore = items.count > limit
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .help(title)
                Spacer()
                if hasMore {
                    Text(isExpanded.wrappedValue ? "\(items.count) total" : "showing \(visible.count) of \(items.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            WrappingHStack(alignment: .top, horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(visible) { hit in
                    Button {
                        engine.openWordEntry(entryId: hit.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hit.displayHeadword)
                                .font(.headline.weight(.bold))
                            if engine.recallMode != .hideKana {
                                Text(hit.kanaHead)
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                            if engine.recallMode != .hideGloss {
                                Text(hit.primaryGloss)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 164, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.055))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("\(hit.displayHeadword) — \(hit.kanaHead)\n\(hit.primaryGloss)\nOpen full entry")
                }
            }

            if hasMore {
                Button {
                    isExpanded.wrappedValue.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded.wrappedValue ? "Show Less" : "Show more (\(items.count - limit) more)")
                        Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help(isExpanded.wrappedValue
                      ? "Collapse back to the top \(limit) compounds"
                      : "Show all \(items.count) compounds in this group")
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Corpus Collocations & Sentences Section

    private var sentencesAndCollocationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !insights.collocations.isEmpty {
                LiquidGlassCard(cornerRadius: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Corpus Collocations", systemImage: "link")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .help("Real-world word neighbours from the corpus: patterns that co-occur with this word, most frequent first.")

                        WrappingHStack(alignment: .center, horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(insights.collocations) { col in
                                HStack(spacing: 6) {
                                    Text(col.pattern)
                                        .font(.subheadline.weight(.bold))
                                    Text("×\(col.count)")
                                        .font(.caption2.monospacedDigit().weight(.bold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                .help("\(col.pattern) — appears \(col.count)×")
                            }
                        }
                    }
                    .padding(16)
                }
            }

            if !activeSentences.isEmpty {
                sentencesSection
            }
        }
    }

    private var sentencesSection: some View {
        let visibleList = showAllSentences ? activeSentences : Array(activeSentences.prefix(4))

        return LiquidGlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Example Sentences", systemImage: "text.quote")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .help("Real example sentences that use this word. Click any underlined word to open it.")

                    if let src = insights.fallbackSourceWord {
                        Text("via \(src)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange.opacity(0.18)))
                            .help("This word has no example of its own, so a close relative is used as a stand-in to show usage.")
                    }

                    Spacer()

                    if activeSentences.count > 4 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllSentences.toggle()
                            }
                        } label: {
                            Text(showAllSentences ? "Show Less" : "Show All (\(activeSentences.count))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help(showAllSentences ? "Collapse back to the first 4 example sentences" : "Reveal every example sentence")
                    }
                }

                ForEach(visibleList) { sent in
                    VStack(alignment: .leading, spacing: 6) {
                        SentenceFlowView(
                            segments: sent.segments,
                            hideKana: engine.recallMode == .hideKana
                        ) { targetEntryId in
                            engine.openWordEntry(entryId: targetEntryId)
                        }

                        if engine.recallMode != .hideGloss {
                            Text(sent.enText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if sent.id != visibleList.last?.id {
                        Divider().opacity(0.25)
                    }
                }
            }
            .padding(18)
        }
    }

    // MARK: - Verb / Adjective Conjugation Matrix

    private func inflectionMatrixSection(title: String, forms: [InflectionForm]) -> some View {
        LiquidGlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: "tablecells")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .help("Conjugation matrix — every grammatical form this word takes, by tense, mood, and polarity.")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], spacing: 10) {
                    ForEach(forms) { form in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(form.label.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(form.surface)
                                .font(.headline.weight(.bold))
                            if engine.recallMode != .hideKana && form.kana != form.surface {
                                Text(form.kana)
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.055))
                        )
                        .help("\(form.label): \(form.surface)\(form.kana != form.surface ? " (\(form.kana))" : "")")
                    }
                }
            }
            .padding(18)
        }
    }

    private func telemetryPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.16)))
    }
}

// MARK: - Pitch-Accent Mora Contour Diagram

struct PitchAccentContourView: View {
    let contour: PitchAccentContour

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(contour.patternName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                Text(contour.patternSublabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(contour.morae.enumerated()), id: \.offset) { idx, mora in
                    let isHigh = contour.highStates[idx]
                    let isDropPoint = (contour.downstep > 0 && idx + 1 == Int(contour.downstep))
                    let nextHigh: Bool? = {
                        if idx + 1 < contour.highStates.count {
                            return contour.highStates[idx + 1]
                        } else {
                            return contour.particleHigh
                        }
                    }()

                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            ZStack {
                                Color.clear.frame(width: 24, height: 22)
                                Circle()
                                    .fill(isHigh ? Color.accentColor : Color.white.opacity(0.55))
                                    .frame(width: 8, height: 8)
                                    .offset(y: isHigh ? -6 : 6)
                            }
                            Text(mora)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }

                        if let nh = nextHigh {
                            PitchConnectorSegment(fromHigh: isHigh, toHigh: nh, isDrop: isDropPoint)
                                .frame(width: 12, height: 38)
                        }
                    }
                }

                // Trailing grammatical particle node (が)
                VStack(spacing: 4) {
                    ZStack {
                        Color.clear.frame(width: 22, height: 22)
                        Circle()
                            .strokeBorder(contour.particleHigh ? Color.accentColor : Color.white.opacity(0.45), lineWidth: 1.5)
                            .frame(width: 8, height: 8)
                            .offset(y: contour.particleHigh ? -6 : 6)
                    }
                    Text("が")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.055))
            )
        }
    }
}

private struct PitchConnectorSegment: View {
    let fromHigh: Bool
    let toHigh: Bool
    let isDrop: Bool

    var body: some View {
        Canvas { ctx, size in
            let y1: CGFloat = fromHigh ? 6 : 18
            let y2: CGFloat = toHigh ? 6 : 18
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y1))
            path.addLine(to: CGPoint(x: size.width, y: y2))
            ctx.stroke(
                path,
                with: .color(isDrop ? Color.orange : Color.accentColor.opacity(0.75)),
                lineWidth: isDrop ? 2.0 : 1.5
            )
        }
    }
}

// MARK: - Interactive Sentence Token Flow

struct SentenceFlowView: View {
    let segments: [SentenceSegment]
    let hideKana: Bool
    let onTapEntry: (UInt32) -> Void

    var body: some View {
        WrappingHStack(alignment: .bottom, horizontalSpacing: 2, verticalSpacing: 6) {
            ForEach(segments) { seg in
                let isInteractive = (seg.entryId != nil && seg.entryId! > 0)
                Button {
                    if let eid = seg.entryId, eid > 0 {
                        onTapEntry(eid)
                    }
                } label: {
                    VStack(spacing: 0) {
                        if let furi = seg.furigana, !furi.isEmpty, !hideKana {
                            Text(furi)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(" ")
                                .font(.system(size: 10))
                                .opacity(0)
                        }
                        Text(seg.text)
                            .font(.title3)
                            .foregroundStyle(isInteractive ? Color.primary : Color.secondary)
                            .underline(isInteractive, color: Color.accentColor.opacity(0.45))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isInteractive)
            }
        }
    }
}

struct WrappingHStack: Layout {
    var alignment: VerticalAlignment = .center
    var horizontalSpacing: CGFloat = 4
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 600
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Kanji Detail & Stroke Vector View

struct KanjiDetailView: View {
    @ObservedObject var engine: DaiJishowEngine
    let kanji: KanjiDetail
    @State private var animatedStrokeCount: Int = 999

    /// The "Vocabulary & Compounds Containing" list, filtered/ordered by the
    /// user's chosen display mode. `relatedWords` already holds every word
    /// containing the glyph (prevalence-sorted), so this is pure client-side
    /// filtering.
    private var displayRelatedWords: [WordHit] {
        let glyph = kanji.glyph
        switch engine.kanjiRelatedMode {
        case .prevalence:
            return kanji.relatedWords
        case .startsWith:
            return kanji.relatedWords.filter { $0.displayHeadword.hasPrefix(glyph) }
        case .endsWith:
            return kanji.relatedWords.filter { $0.displayHeadword.hasSuffix(glyph) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let title = kanji.specialCaseTitle, let explanation = kanji.specialCaseExplanation {
                    LiquidGlassCard(cornerRadius: 18, highlightOpacity: 0.36) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(title)
                                    .font(.headline.weight(.bold))
                                Text(explanation)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(18)
                    }
                }

                HStack(alignment: .top, spacing: 24) {
                    LiquidGlassCard(cornerRadius: 24) {
                        VStack(spacing: 12) {
                            if kanji.strokePolylines.isEmpty {
                                VStack(spacing: 8) {
                                    Text(kanji.glyph)
                                        .font(.system(size: 120, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Text("No KanjiVG Stroke Data")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 240, height: 240)
                            } else {
                                KanjiVectorDiagram(
                                    polylines: kanji.strokePolylines,
                                    visibleCount: animatedStrokeCount
                                )
                                .frame(width: 240, height: 240)

                                Button {
                                    replayStrokes()
                                } label: {
                                    Label("Replay \(kanji.strokes) Strokes", systemImage: "play.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.22)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }

                    LiquidGlassCard(cornerRadius: 24) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Text(kanji.glyph)
                                    .font(.system(size: 52, weight: .bold))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(kanji.meanings.isEmpty ? (kanji.standaloneEntries.first?.header.primaryGloss ?? kanji.unicodeBlockLabel) : kanji.meanings)
                                        .font(.title2.weight(.bold))
                                    Text(kanji.strokes > 0
                                         ? "\(kanji.unicodeHex) • \(kanji.strokes) strokes • Radical #\(kanji.radicalId)\(kanji.jlpt > 0 ? " • JLPT N\(kanji.jlpt)" : "")"
                                         : "\(kanji.unicodeHex) • \(kanji.unicodeBlockLabel)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            if !kanji.onReadings.isEmpty {
                                Text("On'yomi: \(kanji.onReadings.joined(separator: "、"))")
                                    .font(.headline)
                            }
                            if !kanji.kunReadings.isEmpty {
                                Text("Kun'yomi: \(kanji.kunReadings.joined(separator: "、"))")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }

                            let radicalIds = RadicalCatalog.parseComponentRadicalIds(kanji.componentRadicals)
                            if !radicalIds.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Component Radicals (Tap to Search):")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        ForEach(radicalIds, id: \.self) { radId in
                                            let meta = RadicalCatalog.meta(for: radId)
                                            Button {
                                                engine.openRadicalBuilder(withRadicals: [radId], targetStrokes: 0)
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Text(meta.glyph)
                                                        .font(.headline.weight(.bold))
                                                    Text(meta.name)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            } else if !kanji.componentRadicals.isEmpty {
                                Text("Components: \(kanji.componentRadicals)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 12) {
                                Button {
                                    engine.openFisheye(codepoint: kanji.codepoint)
                                } label: {
                                    Label("Explore Compound Graph", systemImage: "circle.hexagongrid.fill")
                                        .font(.headline)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(Color.accentColor))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)

                                if !radicalIds.isEmpty {
                                    Button {
                                        engine.openRadicalBuilder(withRadicals: radicalIds, targetStrokes: kanji.strokes)
                                    } label: {
                                        Label("Search by All \(radicalIds.count) Radicals", systemImage: "puzzlepiece.extension.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Capsule().fill(Color.white.opacity(0.12)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(22)
                    }
                }

                if !kanji.standaloneEntries.isEmpty {
                    LiquidGlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Standalone Dictionary Entries (\(kanji.glyph))")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(kanji.standaloneEntries, id: \.header.id) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(entry.header.displayHeadword)
                                            .font(.title2.weight(.bold))
                                        if !entry.header.kanaHead.isEmpty && engine.recallMode != .hideKana {
                                            Text(entry.header.kanaHead)
                                                .font(.headline)
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        if entry.header.pitchAccent != 255 {
                                            Text("[\(entry.header.pitchAccent)]")
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button {
                                            engine.openWordEntry(entryId: entry.header.id)
                                        } label: {
                                            Label("Full Entry", systemImage: "arrow.up.forward.circle.fill")
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Capsule().fill(Color.white.opacity(0.10)))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if engine.recallMode != .hideGloss {
                                        ForEach(entry.senses) { sense in
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("\(sense.id + 1).")
                                                    .font(.subheadline.monospacedDigit().weight(.bold))
                                                    .foregroundStyle(.secondary)
                                                Text(sense.enGlosses)
                                                    .font(.body)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                    }
                                }
                                if entry.header.id != kanji.standaloneEntries.last?.header.id {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                        .padding(20)
                    }
                }

                if !kanji.relatedWords.isEmpty {
                    LiquidGlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Vocabulary & Compounds Containing \(kanji.glyph)")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .help("Every dictionary word that contains this kanji, sorted by how often it appears in the corpus. Switch the view to only show words that start with, or end with, the kanji.")
                                    Spacer()
                                    Text("\(displayRelatedWords.count) of \(kanji.relatedWords.count) words")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }

                                Picker("Display mode", selection: $engine.kanjiRelatedMode) {
                                    ForEach(KanjiRelatedDisplayMode.allCases) { mode in
                                        Text(mode.id).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .fixedSize()
                                .help(engine.kanjiRelatedMode.help)
                            }

                            if displayRelatedWords.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.secondary)
                                    Text("No words \(engine.kanjiRelatedMode == .startsWith ? "start with" : "end with") \(kanji.glyph) in this view.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                ForEach(displayRelatedWords) { word in
                                    Button {
                                        engine.openWordEntry(entryId: word.id)
                                    } label: {
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Text(word.displayHeadword)
                                                .font(.headline.weight(.bold))
                                                .frame(minWidth: 96, alignment: .leading)

                                            if engine.recallMode != .hideKana {
                                                Text(word.kanaHead)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.accentColor)
                                                    .frame(minWidth: 110, alignment: .leading)
                                            }

                                            if engine.recallMode != .hideGloss {
                                                Text(word.primaryGloss)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }

                                            Spacer()

                                            if word.isName {
                                                Text("Name")
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color.purple.opacity(0.22)))
                                                    .foregroundStyle(.purple)
                                            }

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                                    }
                                    .buttonStyle(.plain)
                                    .help("\(word.displayHeadword) — \(word.kanaHead)\n\(word.primaryGloss)")
                                }
                            }
                        }
                        .padding(20)
                    }
                } else if kanji.standaloneEntries.isEmpty {
                    LiquidGlassCard(cornerRadius: 18) {
                        HStack(spacing: 12) {
                            Image(systemName: "tray")
                                .foregroundStyle(.secondary)
                            Text(engine.includeNames
                                 ? "No dictionary entries or proper names containing \(kanji.glyph) were found in the active database."
                                 : "No standard dictionary words found for \(kanji.glyph). Enable \"Names\" in the top bar to search proper names.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(18)
                    }
                }
            }
            .padding(28)
            .textSelection(.enabled)
            .contextMenu {
                Button {
                    engine.copyText(kanji.copyText)
                } label: {
                    Label("Copy Kanji", systemImage: "doc.on.doc")
                }
                Divider()
                Button {
                    engine.copyText(kanji.glyph)
                } label: {
                    Label("Copy Glyph", systemImage: "text.cursor")
                }
            }
        }
        .onAppear {
            animatedStrokeCount = kanji.strokePolylines.count
        }
        .onChange(of: kanji.codepoint) { _, _ in
            animatedStrokeCount = kanji.strokePolylines.count
        }
    }

    private func replayStrokes() {
        animatedStrokeCount = 0
        Task {
            for i in 1...max(1, kanji.strokePolylines.count) {
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeOut(duration: 0.18)) {
                    animatedStrokeCount = i
                }
            }
        }
    }
}

struct KanjiVectorDiagram: View {
    let polylines: [[CGPoint]]
    let visibleCount: Int

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            var grid = Path()
            grid.move(to: CGPoint(x: w * 0.5, y: 0))
            grid.addLine(to: CGPoint(x: w * 0.5, y: h))
            grid.move(to: CGPoint(x: 0, y: h * 0.5))
            grid.addLine(to: CGPoint(x: w, y: h * 0.5))
            ctx.stroke(grid, with: .color(.white.opacity(0.14)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            let count = min(visibleCount, polylines.count)
            for idx in 0..<count {
                let pts = polylines[idx]
                guard pts.count >= 2 else { continue }
                var path = Path()
                path.move(to: CGPoint(x: pts[0].x * w, y: pts[0].y * h))
                for p in pts.dropFirst() {
                    path.addLine(to: CGPoint(x: p.x * w, y: p.y * h))
                }
                let isLatest = (idx == count - 1)
                ctx.stroke(
                    path,
                    with: .color(isLatest ? Color.accentColor : Color.primary),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                )

                let startPt = CGPoint(x: pts[0].x * w, y: pts[0].y * h)
                ctx.draw(
                    Text("\(idx + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.orange),
                    at: CGPoint(x: startPt.x - 8, y: startPt.y - 8)
                )
            }
        }
    }
}

// MARK: - 7-Slot Multi-Radical Builder View

struct RadicalBuilderView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var activeSlot: Int = 0
    @State private var radicalStrokeFilter: Int = 0
    @State private var radicalSearchText: String = ""

    private var filteredCatalog: [RadicalMeta] {
        let q = radicalSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return RadicalCatalog.all.filter { rad in
            if radicalStrokeFilter > 0 && rad.strokes != radicalStrokeFilter {
                return false
            }
            if !q.isEmpty {
                let idStr = String(rad.id)
                let matchText = rad.glyph.contains(q)
                    || rad.name.lowercased().contains(q)
                    || rad.variants.contains(q)
                    || idStr == q
                if !matchText { return false }
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { slotIdx in
                    let isFilled = slotIdx < engine.radicalSelectedIds.count
                    let isSelectedSlot = (slotIdx == activeSlot)
                    let radId = isFilled ? engine.radicalSelectedIds[slotIdx] : 0
                    let meta = isFilled ? RadicalCatalog.meta(for: radId) : nil

                    Button {
                        if isFilled {
                            var updated = engine.radicalSelectedIds
                            updated.remove(at: slotIdx)
                            activeSlot = min(slotIdx, updated.count)
                            engine.searchRadicals(
                                selectedIds: updated,
                                targetStrokes: Int16(engine.radicalTargetStrokes),
                                tolerance: engine.radicalStrokeTolerance
                            )
                        } else {
                            activeSlot = slotIdx
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(isFilled ? (meta?.glyph ?? "?") : "＋")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(isFilled ? .primary : .secondary)

                            Text(isFilled ? (meta?.name ?? "#\(radId)") : "Slot \(slotIdx + 1)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 68, height: 68)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(
                                            isSelectedSlot ? Color.accentColor : Color.white.opacity(0.22),
                                            lineWidth: isSelectedSlot ? 2.5 : 1
                                        )
                                }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Divider().frame(height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Kanji Strokes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Stepper(
                            engine.radicalTargetStrokes == 0 ? "Any Strokes" : "\(engine.radicalTargetStrokes) strokes",
                            value: $engine.radicalTargetStrokes,
                            in: 0...30
                        )
                        .onChange(of: engine.radicalTargetStrokes) { _, newVal in
                            engine.searchRadicals(
                                selectedIds: engine.radicalSelectedIds,
                                targetStrokes: Int16(newVal),
                                tolerance: engine.radicalStrokeTolerance
                            )
                        }

                        if engine.radicalTargetStrokes > 0 {
                            Picker("Tolerance", selection: $engine.radicalStrokeTolerance) {
                                Text("Exact").tag(Int8(0))
                                Text("±1").tag(Int8(1))
                                Text("±2").tag(Int8(2))
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 130)
                            .onChange(of: engine.radicalStrokeTolerance) { _, newTol in
                                engine.searchRadicals(
                                    selectedIds: engine.radicalSelectedIds,
                                    targetStrokes: Int16(engine.radicalTargetStrokes),
                                    tolerance: newTol
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)

                if !engine.radicalSelectedIds.isEmpty || engine.radicalTargetStrokes > 0 {
                    Button {
                        activeSlot = 0
                        engine.searchRadicals(selectedIds: [], targetStrokes: 0, tolerance: 0)
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)

            HStack(alignment: .top, spacing: 20) {
                LiquidGlassCard(cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("214 Kangxi Radicals")
                                .font(.headline)
                            Spacer()
                            Text("\(filteredCatalog.count) shown")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Filter radical by name, kanji, or #...", text: $radicalSearchText)
                                .textFieldStyle(.plain)
                            if !radicalSearchText.isEmpty {
                                Button {
                                    radicalSearchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                strokeFilterChip(label: "All", strokes: 0)
                                ForEach(1...17, id: \.self) { st in
                                    if RadicalCatalog.all.contains(where: { $0.strokes == st }) {
                                        strokeFilterChip(label: "\(st)画", strokes: st)
                                    }
                                }
                            }
                        }

                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 8) {
                                ForEach(filteredCatalog) { rad in
                                    let isSelected = engine.radicalSelectedIds.contains(rad.id)
                                    Button {
                                        var updated = engine.radicalSelectedIds
                                        if let existingIdx = updated.firstIndex(of: rad.id) {
                                            updated.remove(at: existingIdx)
                                            activeSlot = min(existingIdx, updated.count)
                                        } else {
                                            if activeSlot < updated.count {
                                                updated[activeSlot] = rad.id
                                            } else if updated.count < 7 {
                                                updated.append(rad.id)
                                            }
                                            activeSlot = min(6, updated.count)
                                        }
                                        engine.searchRadicals(
                                            selectedIds: updated,
                                            targetStrokes: Int16(engine.radicalTargetStrokes),
                                            tolerance: engine.radicalStrokeTolerance
                                        )
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(rad.glyph)
                                                .font(.system(size: 24, weight: .bold))
                                            Text(rad.name)
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                            Text("\(rad.strokes)画")
                                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                                .foregroundStyle(isSelected ? Color.accentColor : .secondary.opacity(0.8))
                                        }
                                        .frame(width: 62, height: 62)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(isSelected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.06))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .frame(maxWidth: 440)

                LiquidGlassCard(cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Matching Kanji (\(engine.radicalMatches.count))")
                                .font(.headline)
                            Spacer()
                            if engine.radicalTargetStrokes > 0 {
                                Text("Filtered to \(engine.radicalTargetStrokes)\(engine.radicalStrokeTolerance > 0 ? " ±\(engine.radicalStrokeTolerance)" : "") strokes")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }

                        if engine.radicalMatches.isEmpty {
                            Spacer()
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "character.magnify")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text(engine.radicalSelectedIds.isEmpty && engine.radicalTargetStrokes == 0
                                         ? "Pick one or more radicals on the left, or set a stroke count above."
                                         : "No Kanji match this exact radical + stroke combination.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                Spacer()
                            }
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 68))], spacing: 10) {
                                    ForEach(engine.radicalMatches, id: \.self) { cp in
                                        let meta = engine.kanjiIndexItem(for: cp)
                                        Button {
                                            engine.openKanjiDetail(codepoint: cp)
                                        } label: {
                                            VStack(spacing: 2) {
                                                Text(String(UnicodeScalar(cp)!))
                                                    .font(.system(size: 30, weight: .bold))
                                                if let st = meta?.strokes, st > 0 {
                                                    Text("\(st)画")
                                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .frame(width: 66, height: 66)
                                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            activeSlot = min(6, engine.radicalSelectedIds.count)
        }
    }

    private func strokeFilterChip(label: String, strokes: Int) -> some View {
        let active = (radicalStrokeFilter == strokes)
        return Button {
            radicalStrokeFilter = strokes
        } label: {
            Text(label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(active ? Color.accentColor : Color.white.opacity(0.08)))
                .foregroundStyle(active ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Wordtank Multi-Mode Kanji Lookup View

struct KanjiLookupView: View {
    @ObservedObject var engine: DaiJishowEngine

    private let skipPatterns: [(id: Int, title: String, subtitle: String, icon: String)] = [
        (1, "Left-Right (⿰)", "e.g. 明, 休, 時", "rectangle.split.2x1"),
        (2, "Top-Bottom (⿱)", "e.g. 花, 男, 字", "rectangle.split.1x2"),
        (3, "Enclosure (⿵/⿷/⿴)", "e.g. 国, 道, 医", "rectangle.inset.filled"),
        (4, "Solid / Single", "e.g. 大, 木, 水", "square.fill")
    ]

    private let gradeOptions: [(id: Int, label: String)] = [
        (1, "Grade 1 (80)"),
        (2, "Grade 2 (160)"),
        (3, "Grade 3 (200)"),
        (4, "Grade 4 (202)"),
        (5, "Grade 5 (193)"),
        (6, "Grade 6 (191)"),
        (8, "Secondary Jōyō"),
        (9, "Jinmeiyō"),
        (-5, "JLPT N5"),
        (-4, "JLPT N4"),
        (-3, "JLPT N3"),
        (-2, "JLPT N2"),
        (-1, "JLPT N1")
    ]

    var body: some View {
        VStack(spacing: 16) {
            LiquidGlassCard(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Picker("Lookup Mode", selection: $engine.kanjiLookupMode) {
                            ForEach(KanjiLookupMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: engine.kanjiLookupMode) { _, _ in
                            engine.runKanjiLookup()
                        }

                        Picker("Sort By", selection: $engine.kanjiLookupSort) {
                            ForEach(KanjiSortOrder.allCases) { order in
                                Label(order.rawValue, systemImage: "arrow.up.arrow.down").tag(order)
                            }
                        }
                        .frame(width: 175)
                        .onChange(of: engine.kanjiLookupSort) { _, _ in
                            engine.runKanjiLookup()
                        }
                    }

                    modeControlsView
                }
                .padding(18)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            LiquidGlassCard(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Indexed Kanji Results (\(engine.kanjiLookupResults.count))")
                            .font(.headline)
                        Spacer()
                        Text("Tap any kanji for strokes, readings & compounds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if engine.kanjiLookupResults.isEmpty {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("No kanji matched the current \(engine.kanjiLookupMode.rawValue) filter.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94))], spacing: 10) {
                                ForEach(engine.kanjiLookupResults) { item in
                                    Button {
                                        engine.openKanjiDetail(codepoint: item.codepoint)
                                    } label: {
                                        VStack(spacing: 3) {
                                            HStack {
                                                Text("\(item.strokes)画")
                                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                if !item.gradeLabel.isEmpty {
                                                    Text(item.gradeLabel)
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(Color.accentColor)
                                                } else if !item.jlptLabel.isEmpty {
                                                    Text(item.jlptLabel)
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(.green)
                                                }
                                            }
                                            .padding(.horizontal, 6)

                                            Text(item.glyph)
                                                .font(.system(size: 34, weight: .bold))
                                                .foregroundStyle(.primary)

                                            Text(item.primaryReading.isEmpty ? (item.meanings.split(separator: ";").first.map(String.init) ?? "") : item.primaryReading)
                                                .font(.system(size: 10.5, weight: .medium))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .padding(.horizontal, 4)
                                        }
                                        .frame(width: 90, height: 86)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.white.opacity(0.07))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            if engine.kanjiLookupResults.isEmpty {
                engine.runKanjiLookup()
            }
        }
    }

    @ViewBuilder
    private var modeControlsView: some View {
        switch engine.kanjiLookupMode {
        case .strokes:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Text("Total Strokes:")
                        .font(.subheadline.weight(.semibold))
                    Stepper("\(engine.kanjiLookupStrokeCount) strokes", value: $engine.kanjiLookupStrokeCount, in: 1...34)
                        .frame(width: 170)
                        .onChange(of: engine.kanjiLookupStrokeCount) { _, _ in
                            engine.runKanjiLookup()
                        }

                    Picker("Tolerance", selection: $engine.kanjiLookupStrokeTolerance) {
                        Text("Exact").tag(0)
                        Text("±1").tag(1)
                        Text("±2").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .onChange(of: engine.kanjiLookupStrokeTolerance) { _, _ in
                        engine.runKanjiLookup()
                    }

                    Picker("Set", selection: $engine.kanjiLookupLevelFilter) {
                        Text("All Kanji").tag(0)
                        Text("Jōyō Only").tag(1)
                        Text("Kyōiku (G1–G6)").tag(2)
                        Text("JLPT Only").tag(3)
                    }
                    .frame(width: 170)
                    .onChange(of: engine.kanjiLookupLevelFilter) { _, _ in
                        engine.runKanjiLookup()
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(1...24, id: \.self) { st in
                            let isSelected = (engine.kanjiLookupStrokeCount == st)
                            Button {
                                engine.kanjiLookupStrokeCount = st
                                engine.runKanjiLookup()
                            } label: {
                                Text("\(st)")
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .frame(width: 30, height: 26)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor : Color.white.opacity(0.08)))
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        case .reading:
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "character.ja")
                        .foregroundStyle(.secondary)
                    TextField("Enter On or Kun reading in Romaji, Hiragana, or Katakana (e.g. sei, せい, おお)...", text: $engine.kanjiLookupReadingQuery)
                        .textFieldStyle(.plain)
                        .onChange(of: engine.kanjiLookupReadingQuery) { _, _ in
                            engine.runKanjiLookup()
                        }
                    if !engine.kanjiLookupReadingQuery.isEmpty {
                        Button {
                            engine.kanjiLookupReadingQuery = ""
                            engine.runKanjiLookup()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                Picker("Scope", selection: $engine.kanjiLookupReadingScope) {
                    Text("All Readings").tag(0)
                    Text("On'yomi").tag(1)
                    Text("Kun'yomi").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .onChange(of: engine.kanjiLookupReadingScope) { _, _ in
                    engine.runKanjiLookup()
                }

                Toggle("Exact", isOn: $engine.kanjiLookupReadingExact)
                    .toggleStyle(.switch)
                    .onChange(of: engine.kanjiLookupReadingExact) { _, _ in
                        engine.runKanjiLookup()
                    }
            }

        case .skip:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(skipPatterns, id: \.id) { pat in
                        let selected = (engine.kanjiLookupSkipPattern == pat.id)
                        Button {
                            engine.kanjiLookupSkipPattern = pat.id
                            engine.runKanjiLookup()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: pat.icon)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pat.title)
                                        .font(.caption.weight(.bold))
                                    Text(pat.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 18) {
                    Stepper(
                        engine.kanjiLookupSkipPart1 == 0 ? "Part 1 Strokes: Any" : "Part 1: \(engine.kanjiLookupSkipPart1) strokes",
                        value: $engine.kanjiLookupSkipPart1,
                        in: 0...25
                    )
                    .frame(width: 210)
                    .onChange(of: engine.kanjiLookupSkipPart1) { _, _ in
                        engine.runKanjiLookup()
                    }

                    Stepper(
                        engine.kanjiLookupSkipPart2 == 0 ? "Part 2 Strokes: Any" : "Part 2: \(engine.kanjiLookupSkipPart2) strokes",
                        value: $engine.kanjiLookupSkipPart2,
                        in: 0...25
                    )
                    .frame(width: 210)
                    .onChange(of: engine.kanjiLookupSkipPart2) { _, _ in
                        engine.runKanjiLookup()
                    }

                    if engine.kanjiLookupSkipPart1 > 0 || engine.kanjiLookupSkipPart2 > 0 {
                        Button("Reset Part Counts") {
                            engine.kanjiLookupSkipPart1 = 0
                            engine.kanjiLookupSkipPart2 = 0
                            engine.runKanjiLookup()
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }

        case .fourCorner:
            HStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "number.square")
                        .foregroundStyle(.secondary)
                    TextField("Enter 1 to 4 Four-Corner digits (0–9, e.g. 4003 for 大)...", text: $engine.kanjiLookupFourCorner)
                        .textFieldStyle(.plain)
                        .onChange(of: engine.kanjiLookupFourCorner) { _, _ in
                            engine.runKanjiLookup()
                        }
                    if !engine.kanjiLookupFourCorner.isEmpty {
                        Button {
                            engine.kanjiLookupFourCorner = ""
                            engine.runKanjiLookup()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                .frame(maxWidth: 420)

                Text("0=Lid • 1=Horizontal • 2=Vertical • 3=Dot • 4=Cross • 5=Skewer • 6=Box • 7=Angle • 8=Eight • 9=Small")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        case .gradeJlpt:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(gradeOptions, id: \.id) { opt in
                        let selected = (engine.kanjiLookupGradeFilter == opt.id)
                        Button {
                            engine.kanjiLookupGradeFilter = opt.id
                            engine.runKanjiLookup()
                        } label: {
                            Text(opt.label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(selected ? Color.accentColor : Color.white.opacity(0.08)))
                                .foregroundStyle(selected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case .meaning:
            HStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search English Kanji meaning keywords (e.g. dragon, bridge, harmony, thunder)...", text: $engine.kanjiLookupMeaningQuery)
                    .textFieldStyle(.plain)
                    .onChange(of: engine.kanjiLookupMeaningQuery) { _, _ in
                        engine.runKanjiLookup()
                    }
                if !engine.kanjiLookupMeaningQuery.isEmpty {
                    Button {
                        engine.kanjiLookupMeaningQuery = ""
                        engine.runKanjiLookup()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
        }
    }
}
