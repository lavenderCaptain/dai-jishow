import SwiftUI
import DaiJishowCore

struct LiquidGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.13, blue: 0.19).opacity(0.88))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.32)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.38), .white.opacity(0.10), .cyan.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)
    }
}

// MARK: - Per-Kanji Ruby Cell

struct RubyCellView: View {
    let cell: RubyCell
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        VStack(spacing: 3) {
            if engine.recallMode != .hideKana && !cell.furigana.isEmpty {
                Text(cell.furigana)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
            } else {
                Text(" ")
                    .font(.system(size: 14))
            }

            if cell.kanjiCodepoint > 0 {
                Button {
                    engine.openFisheye(codepoint: cell.kanjiCodepoint, recordHistory: true)
                } label: {
                    Text(cell.surface)
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(.white)
                        .underline(color: .cyan.opacity(0.65))
                }
                .buttonStyle(.plain)
                .help("Explore 「\(cell.surface)」 in Dokusha Fisheye")
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(cell.surface.unicodeScalars.enumerated()), id: \.offset) { _, scalar in
                        let ch = String(scalar)
                        if engine.isKanjiScalar(scalar.value) {
                            Button {
                                engine.openFisheye(codepoint: scalar.value, recordHistory: true)
                            } label: {
                                Text(ch)
                                    .font(.system(size: 46, weight: .bold))
                                    .foregroundStyle(.white)
                                    .underline(color: .cyan.opacity(0.65))
                            }
                            .buttonStyle(.plain)
                            .help("Explore 「\(ch)」 in Dokusha Fisheye")
                        } else {
                            Text(ch)
                                .font(.system(size: 46, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Wrapping Flow Layout for Interactive Sentence Tokens

struct WrappingTokenFlow: Layout {
    var horizontalSpacing: CGFloat = 2
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 800
        var curX: CGFloat = 0
        var curY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if curX + sz.width > maxWidth && curX > 0 {
                curX = 0
                curY += lineHeight + verticalSpacing
                lineHeight = 0
            }
            curX += sz.width + horizontalSpacing
            lineHeight = max(lineHeight, sz.height)
        }
        return CGSize(width: maxWidth, height: curY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var curX = bounds.minX
        var curY = bounds.minY
        var lineHeight: CGFloat = 0

        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if curX + sz.width > bounds.maxX && curX > bounds.minX {
                curX = bounds.minX
                curY += lineHeight + verticalSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: curX, y: curY), anchor: .topLeading, proposal: .unspecified)
            curX += sz.width + horizontalSpacing
            lineHeight = max(lineHeight, sz.height)
        }
    }
}

struct InteractiveSentenceView: View {
    let sentence: SentenceItem
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WrappingTokenFlow(horizontalSpacing: 2, verticalSpacing: 6) {
                ForEach(sentence.segments) { seg in
                    if let eid = seg.entryId {
                        Button {
                            engine.openWordEntry(entryId: eid)
                        } label: {
                            VStack(spacing: 1) {
                                if engine.recallMode != .hideKana, let furi = seg.furigana {
                                    Text(furi)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                } else {
                                    Text(" ")
                                        .font(.system(size: 11))
                                }
                                Text(seg.text)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white)
                                    .underline(color: Color.cyan.opacity(0.55))
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Open dictionary entry for 「\(seg.text)」")
                    } else {
                        VStack(spacing: 1) {
                            Text(" ")
                                .font(.system(size: 11))
                            Text(seg.text)
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if engine.recallMode != .hideGloss {
                Text(sentence.enText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.76))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Word Entry Detail Card

struct WordDetailView: View {
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        if let entry = engine.activeEntry {
            WordDetailContentView(entry: entry, engine: engine)
        }
    }
}

struct WordDetailContentView: View {
    let entry: EntryDetail
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        let variants = entry.header.variantList

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 20) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(entry.rubyCells) { cell in
                            RubyCellView(cell: cell, engine: engine)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if engine.recallMode != .hideKana {
                            HStack(spacing: 10) {
                                Text(entry.header.kanaHead)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                if entry.header.pitchAccent != 255 {
                                    Text(entry.header.pitchAccent == 0 ? "平板 [0]" : "Accent [\(entry.header.pitchAccent)]")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan.opacity(0.28), in: Capsule())
                                }
                            }
                        } else {
                            Text("••••••").font(.title2).foregroundStyle(.white.opacity(0.45))
                        }

                        if !variants.isEmpty {
                            HStack(spacing: 8) {
                                Text("Variants:")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.72))

                                ForEach(variants, id: \.self) { variant in
                                    Button {
                                        engine.openVariantForm(variant)
                                    } label: {
                                        Text(variant)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(Color.cyan.opacity(0.45), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .help("Switch headword / open variant 「\(variant)」")
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)

                    Spacer()

                    if entry.header.pairEntryId > 0 && !entry.pairedKanji.isEmpty {
                        Button {
                            engine.openWordEntry(entryId: entry.header.pairEntryId)
                        } label: {
                            Label("Paired Verb: \(entry.pairedKanji) (\(entry.pairedKana))", systemImage: "arrow.left.arrow.right")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Divider().overlay(Color.white.opacity(0.18))

                VStack(alignment: .leading, spacing: 10) {
                    Text("DEFINITIONS")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.62))

                    ForEach(entry.senses) { sense in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(sense.id + 1).")
                                .font(.body.bold())
                                .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                            if engine.recallMode == .hideGloss {
                                Text("[Gloss hidden — Active Recall mode]")
                                    .italic()
                                    .foregroundStyle(.white.opacity(0.55))
                            } else {
                                Text(sense.enGlosses)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                if !entry.sentences.isEmpty {
                    Divider().overlay(Color.white.opacity(0.18))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EXAMPLE SENTENCES (\(entry.sentences.count)) — CLICK ANY WORD TO JUMP")
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.62))

                        ForEach(entry.sentences) { sent in
                            InteractiveSentenceView(sentence: sent, engine: engine)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Dokusha Spatial Fisheye Kanji Explorer

private struct FisheyeLegendBar: View {
    @State private var hoveredLegendTier: String?

    private struct LegendTier: Identifiable {
        let id: String
        let color: Color
        let description: String
    }

    private let legendItems: [LegendTier] = [
        LegendTier(
            id: "Core",
            color: Color(red: 0.22, green: 0.74, blue: 0.97),
            description: "Everyday Core — High-frequency compounds in the top ~2,500 Japanese words."
        ),
        LegendTier(
            id: "Jōyō",
            color: Color(red: 0.20, green: 0.83, blue: 0.60),
            description: "Standard Jōyō — Official 2,136 Jōyō kanji & standard newspaper vocabulary."
        ),
        LegendTier(
            id: "Literary",
            color: Color(red: 0.98, green: 0.75, blue: 0.14),
            description: "Literary / Specialized — Formal, written, or domain-specific compounds."
        ),
        LegendTier(
            id: "Kyūjitai",
            color: Color(red: 0.65, green: 0.55, blue: 0.98),
            description: "Kyūjitai / Non-Jōyō — Traditional pre-1946 forms or Jinmeiyō / rare kanji."
        )
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(legendItems) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.color.opacity(0.35))
                        .overlay(Circle().strokeBorder(item.color, lineWidth: 1.5))
                        .frame(width: 9, height: 9)
                    Text(item.id)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    hoveredLegendTier == item.id ? item.color.opacity(0.22) : Color.clear,
                    in: Capsule()
                )
                .onHover { hovering in
                    hoveredLegendTier = hovering ? item.id : (hoveredLegendTier == item.id ? nil : hoveredLegendTier)
                }
                .popover(isPresented: Binding(
                    get: { hoveredLegendTier == item.id },
                    set: { if !$0 && hoveredLegendTier == item.id { hoveredLegendTier = nil } }
                ), arrowEdge: .bottom) {
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(width: 240)
                }
            }
        }
    }
}

private struct FisheyeBubbleView: View {
    let node: FisheyeNode
    let showPercentages: Bool
    let isSelected: Bool
    let isHovered: Bool
    let dimmed: Bool
    let onTap: () -> Void

    var body: some View {
        let active = !dimmed && (isSelected || isHovered)
        let baseDiam: CGFloat = showPercentages ? 52.0 : 45.0
        let diameter = baseDiam * node.scale

        Button(action: onTap) {
            VStack(spacing: 0) {
                Text(node.glyph)
                    .font(.system(size: (showPercentages ? 21.0 : 22.0) * node.scale, weight: active ? .bold : .semibold))
                    .foregroundStyle(.white)
                if showPercentages {
                    Text(node.shareText)
                        .font(.system(size: 8.5 * max(0.82, node.scale * 0.84), weight: .semibold, design: .monospaced))
                        .foregroundStyle(node.tierColor.opacity(0.95))
                }
            }
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(
                        active
                            ? node.tierColor.opacity(0.45)
                            : Color(red: 0.11, green: 0.15, blue: 0.22).opacity(0.94)
                    )
                    .overlay(
                        Circle().fill(node.tierColor.opacity(active ? 0.25 : 0.16))
                    )
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        active ? Color.white : node.tierColor.opacity(0.75),
                        lineWidth: active ? 2.2 : 1.4
                    )
            )
            .shadow(color: active ? node.tierColor.opacity(0.45) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .opacity(dimmed ? 0.15 : node.opacity)
        .allowsHitTesting(!dimmed)
    }
}

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

struct FisheyeExplorerView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var lastAspect: Float = 1.85
    @State private var lastFocusNorm: CGPoint?

    // Unified overflow fan state owned by the full-canvas explorer so outer rings never clip or lose hover
    @State private var expandedOverflowSide: UInt8?
    @State private var overflowStage: Int = 0 // 0 = closed, 1 = hover preview, 2 = 1st click, 3 = all items
    @State private var overflowPointerPos: CGPoint?
    @State private var hoveredOverflowPos: CGPoint?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if let k = engine.activeKanji {
                    HStack(spacing: 10) {
                        Text(k.glyph)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(k.meanings)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("On: \(k.onReadings.joined(separator: "・"))   Kun: \(k.kunReadings.joined(separator: "・"))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                    Button("Kanji Details & Strokes") {
                        engine.openKanjiDetail(codepoint: k.codepoint)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                FisheyeLegendBar()

                // Toggle Percentages under Kanji to save screen space
                Toggle("%", isOn: $engine.showFisheyePercentages)
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .help("Show or hide compound frequency percentages beneath kanji")

                // Max Popular Items Selector
                Picker("Max", selection: $engine.maxFisheyePerSide) {
                    Text("Top 8").tag(8)
                    Text("Top 12").tag(12)
                    Text("Top 16").tag(16)
                    Text("Top 24").tag(24)
                }
                .labelsHidden()
                .frame(width: 86)
                .onChange(of: engine.maxFisheyePerSide) { _, _ in
                    collapseOverflow()
                    refreshLayout(animated: true)
                }

                Picker("Orbit Mode", selection: $engine.fisheyeMode) {
                    Text("2-Kanji").tag(DJ_EDGE_COMPOUNDS)
                    Text("四字熟語").tag(DJ_EDGE_YOJIJUKUGO)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 165)
                .onChange(of: engine.fisheyeMode) { _, _ in
                    engine.selectedFisheyeNode = nil
                    engine.hoveredFisheyeNode = nil
                    collapseOverflow()
                    refreshLayout(animated: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let halfW = max(1.0, geo.size.width / 2)
                let halfH = max(1.0, geo.size.height / 2)
                let ar = Float(geo.size.width / max(1, geo.size.height))

                let leftAnchor = CGPoint(x: 54, y: geo.size.height - 50)
                let rightAnchor = CGPoint(x: geo.size.width - 54, y: geo.size.height - 50)
                let isFanOpen = (expandedOverflowSide != nil && overflowStage > 0)

                let activeFan: OverflowFanLayout? = {
                    guard let side = expandedOverflowSide, overflowStage > 0 else { return nil }
                    let anchor = (side == 0) ? leftAnchor : rightAnchor
                    return computeOverflowFan(side: side, stage: overflowStage, anchor: anchor)
                }()

                ZStack {
                    HStack {
                        Text("← PREFIX + CENTER")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text("CENTER + SUFFIX →")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .top)

                    Path { p in
                        p.move(to: CGPoint(x: center.x, y: 24))
                        p.addLine(to: CGPoint(x: center.x, y: geo.size.height - 24))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    .foregroundStyle(.white.opacity(0.10))

                    Canvas { ctx, _ in
                        for node in engine.fisheyeNodes {
                            let pt = CGPoint(x: center.x + node.normX * halfW, y: center.y + node.normY * halfH)
                            var path = Path()
                            path.move(to: center)
                            path.addLine(to: pt)
                            let isHighlighted = !isFanOpen && ((engine.selectedFisheyeNode?.id == node.id) || (engine.hoveredFisheyeNode?.id == node.id))
                            let baseAlpha = isFanOpen ? 0.06 : (0.24 * node.opacity)
                            ctx.stroke(
                                path,
                                with: .color(isHighlighted ? node.tierColor.opacity(0.95) : node.tierColor.opacity(baseAlpha)),
                                lineWidth: isHighlighted ? 2.4 : 1.1
                            )
                        }
                    }

                    // Main Fisheye Bubbles (dimmed & non-interactive while an overflow fan is open so they don't steal hover/clicks)
                    ForEach(engine.fisheyeNodes) { node in
                        let isSelected = engine.selectedFisheyeNode?.id == node.id
                        let isHovered = engine.hoveredFisheyeNode?.id == node.id
                        let pos = CGPoint(x: center.x + node.normX * halfW, y: center.y + node.normY * halfH)

                        FisheyeBubbleView(
                            node: node,
                            showPercentages: engine.showFisheyePercentages,
                            isSelected: isSelected,
                            isHovered: isHovered,
                            dimmed: isFanOpen,
                            onTap: {
                                if isSelected {
                                    engine.openFisheye(codepoint: node.codepoint, recordHistory: true)
                                } else {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        engine.selectedFisheyeNode = node
                                    }
                                }
                            }
                        )
                        .position(pos)
                        .zIndex((!isFanOpen && (isSelected || isHovered)) ? 30.0 : Double(node.scale * 10.0))
                    }

                    // Expanded Overflow Sub-Bubbles (rendered directly in canvas space with zero bounding-box clipping)
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

                            let baseSize: CGFloat = engine.showFisheyePercentages ? 36.0 : 31.0
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
                                        .font(.system(size: 14.5 * dockScale, weight: active ? .bold : .semibold))
                                        .foregroundStyle(.white)
                                    if engine.showFisheyePercentages {
                                        Text(sub.shareText)
                                            .font(.system(size: 7.0 * dockScale, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(sub.tierColor)
                                    }
                                }
                                .frame(width: diam, height: diam)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.12, green: 0.17, blue: 0.25).opacity(0.97))
                                        .overlay(Circle().fill(sub.tierColor.opacity(active ? 0.36 : 0.18)))
                                )
                                .overlay(
                                    Circle().strokeBorder(active ? Color.white : sub.tierColor, lineWidth: active ? 2.0 : 1.2)
                                )
                                .shadow(color: active ? sub.tierColor.opacity(0.55) : .black.opacity(0.45), radius: 7)
                            }
                            .buttonStyle(.plain)
                            .frame(width: diam, height: diam)
                            .contentShape(Circle())
                            .position(item.pos)
                            .zIndex(25.0 + Double(dockScale * 10.0))
                            .transition(.scale(scale: 0.35).combined(with: .opacity))
                        }
                    }

                    // Bottom-Left & Bottom-Right "+N more" Corner Triggers
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

                    if let centerKanji = engine.activeKanji {
                        Text(centerKanji.glyph)
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 92, height: 92)
                            .background(Color(red: 0.12, green: 0.17, blue: 0.25), in: Circle())
                            .overlay(Circle().strokeBorder(.cyan.opacity(0.85), lineWidth: 2.5))
                            .shadow(color: .cyan.opacity(0.3), radius: 18)
                            .position(center)
                            .zIndex(15)
                    }

                    // Floating mouse-over pop-up card for whichever kanji is currently hovered
                    if let hov = engine.hoveredFisheyeNode {
                        let nodeX: CGFloat = {
                            if hov.isOverflowPreview {
                                return hoveredOverflowPos?.x ?? (hov.side == 0 ? 170.0 : geo.size.width - 170.0)
                            }
                            return center.x + hov.normX * halfW
                        }()
                        let nodeY: CGFloat = {
                            if hov.isOverflowPreview {
                                return hoveredOverflowPos?.y ?? (geo.size.height - 180.0)
                            }
                            return center.y + hov.normY * halfH
                        }()
                        let popY = (nodeY < 115) ? (nodeY + 62) : (nodeY - 62)
                        let popX = min(max(nodeX, 150), geo.size.width - 150)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(hov.compoundWord)
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                Text("【\(hov.compoundKana)】")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(hov.tierColor)
                                Spacer(minLength: 4)
                                Text("\(hov.tierLabel) • \(hov.shareText)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(hov.tierColor.opacity(0.32), in: Capsule())
                            }
                            Text(hov.compoundGloss)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(width: 280, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(red: 0.08, green: 0.11, blue: 0.17).opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(hov.tierColor.opacity(0.85), lineWidth: 1.3)
                        )
                        .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 6)
                        .position(x: popX, y: popY)
                        .allowsHitTesting(false)
                        .zIndex(50)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    guard let cp = engine.activeKanji?.codepoint else { return }
                    switch phase {
                    case .active(let loc):
                        // 1. Check if pointer entered either corner "+N more" trigger
                        let nearLeftTrigger = engine.leftOverflowCount > 0 && hypot(loc.x - leftAnchor.x, loc.y - leftAnchor.y) <= 34.0
                        let nearRightTrigger = engine.rightOverflowCount > 0 && hypot(loc.x - rightAnchor.x, loc.y - rightAnchor.y) <= 34.0

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

                        // 2. If an overflow fan is currently open, keep it alive as long as the pointer stays inside its generous envelope
                        if let activeSide = expandedOverflowSide, overflowStage > 0 {
                            let anchor = (activeSide == 0) ? leftAnchor : rightAnchor
                            let fan = computeOverflowFan(side: activeSide, stage: overflowStage, anchor: anchor)
                            let distFromAnchor = hypot(loc.x - anchor.x, loc.y - anchor.y)
                            let withinHemisphere = (activeSide == 0) ? (loc.x <= center.x + 36.0) : (loc.x >= center.x - 36.0)

                            if withinHemisphere && distFromAnchor <= fan.maxRadius + 56.0 {
                                overflowPointerPos = loc
                                let baseSize: CGFloat = engine.showFisheyePercentages ? 36.0 : 31.0
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

                        // 3. Normal main-bubble 3D fisheye tracking
                        let fx = Float((loc.x - center.x) / halfW)
                        let fy = Float((loc.y - center.y) / halfH)
                        let nearCenter = hypot(Double(fx * ar), Double(fy)) < 0.11

                        if nearCenter {
                            engine.hoveredFisheyeNode = nil
                            if lastFocusNorm != nil {
                                lastFocusNorm = nil
                                engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: ar, animated: true)
                            }
                        } else {
                            let wasFocused = (lastFocusNorm != nil)
                            lastFocusNorm = CGPoint(x: CGFloat(fx), y: CGFloat(fy))
                            engine.solveFisheye(center: cp, hasFocus: true, focusX: fx, focusY: fy, aspectRatio: ar, animated: !wasFocused)

                            let baseDiam: CGFloat = engine.showFisheyePercentages ? 52.0 : 45.0
                            var bestNode: FisheyeNode?
                            var bestDist: CGFloat = .greatestFiniteMagnitude
                            for node in engine.fisheyeNodes {
                                let bx = center.x + node.normX * halfW
                                let by = center.y + node.normY * halfH
                                let d = hypot(loc.x - bx, loc.y - by)
                                let hitRadius = (baseDiam * node.scale) * 0.56
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
                        lastFocusNorm = nil
                        engine.hoveredFisheyeNode = nil
                        collapseOverflow()
                        engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: ar, animated: true)
                    }
                }
                .onAppear {
                    lastAspect = ar
                    refreshLayout(animated: false)
                }
                .onChange(of: geo.size) { _, newSize in
                    lastAspect = Float(newSize.width / max(1, newSize.height))
                    refreshLayout(animated: false)
                }
                .onChange(of: engine.activeKanji?.codepoint) { _, _ in
                    lastFocusNorm = nil
                    collapseOverflow()
                    refreshLayout(animated: false)
                }
            }

            HStack(spacing: 16) {
                if let sel = engine.selectedFisheyeNode {
                    Text(sel.compoundWord)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("【\(sel.compoundKana)】")
                        .font(.headline)
                        .foregroundStyle(sel.tierColor)
                    Text(sel.compoundGloss)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                    Spacer()
                    Button("Open Word Entry") {
                        engine.openWordEntry(entryId: sel.topEntryId)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Center on 「\(sel.glyph)」") {
                        engine.openFisheye(codepoint: sel.codepoint, recordHistory: true)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("Move pointer across bubbles for 3D magnification & compound preview; click to pin or double-click to pivot.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
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
                    overflowStage = 1
                }
            }
        } label: {
            VStack(spacing: 1) {
                Text(!isExpanded ? "+\(totalOverflow)" : (remaining > 0 ? "+\(remaining)" : "All \(totalOverflow)"))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text(!isExpanded ? "more" : (remaining > 0 ? "expand" : "shown"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .frame(width: 50, height: 50)
            .background(Color.white.opacity(isExpanded ? 0.18 : 0.09), in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: isExpanded ? [] : [3, 3]))
                    .foregroundStyle(.cyan.opacity(0.85))
            )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(!isExpanded ? "Hover to preview; click to expand more kanji" : (remaining > 0 ? "Click again to show even more kanji" : "Click to collapse back to inner rings"))
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

    private func refreshLayout(animated: Bool) {
        guard let cp = engine.activeKanji?.codepoint else { return }
        if let pt = lastFocusNorm {
            engine.solveFisheye(center: cp, hasFocus: true, focusX: Float(pt.x), focusY: Float(pt.y), aspectRatio: lastAspect, animated: animated)
        } else {
            engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: lastAspect, animated: animated)
        }
    }
}

// MARK: - Kanji Detail & Animated Quantized Stroke-Order Canvas

struct KanjiDetailView: View {
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        if let k = engine.activeKanji {
            KanjiDetailContentView(kanji: k, engine: engine)
        }
    }
}

struct KanjiDetailContentView: View {
    let kanji: KanjiDetail
    @ObservedObject var engine: DaiJishowEngine
    @State private var visibleStrokes: Int = 999

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.35))
                    Path { p in
                        p.move(to: CGPoint(x: 110, y: 0)); p.addLine(to: CGPoint(x: 110, y: 220))
                        p.move(to: CGPoint(x: 0, y: 110)); p.addLine(to: CGPoint(x: 220, y: 110))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(0.22))

                    Canvas { ctx, size in
                        let limit = min(visibleStrokes, kanji.strokePolylines.count)
                        for sIdx in 0..<limit {
                            let pts = kanji.strokePolylines[sIdx]
                            guard pts.count >= 2 else { continue }
                            var path = Path()
                            path.move(to: CGPoint(x: pts[0].x * size.width, y: pts[0].y * size.height))
                            for pt in pts.dropFirst() {
                                path.addLine(to: CGPoint(x: pt.x * size.width, y: pt.y * size.height))
                            }
                            let isLatest = (sIdx == limit - 1 && visibleStrokes <= kanji.strokePolylines.count)
                            ctx.stroke(
                                path,
                                with: .color(isLatest ? .cyan : .white),
                                style: StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .padding(16)
                }
                .frame(width: 220, height: 220)

                HStack {
                    Button("Animate Strokes") {
                        animateStrokes(total: kanji.strokePolylines.count)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Explorer") {
                        engine.openFisheye(codepoint: kanji.codepoint, recordHistory: true)
                    }
                    .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(kanji.glyph)
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(.white)
                    Text(kanji.meanings)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Divider().overlay(Color.white.opacity(0.18))

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                    GridRow {
                        Text("On'yomi:").foregroundStyle(.white.opacity(0.65))
                        Text(kanji.onReadings.isEmpty ? "—" : kanji.onReadings.joined(separator: "、"))
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    GridRow {
                        Text("Kun'yomi:").foregroundStyle(.white.opacity(0.65))
                        Text(kanji.kunReadings.isEmpty ? "—" : kanji.kunReadings.joined(separator: "、"))
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    GridRow {
                        Text("Component Radicals:").foregroundStyle(.white.opacity(0.65))
                        Text(kanji.componentRadicals.isEmpty ? "Radical #\(kanji.radicalId)" : kanji.componentRadicals)
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                    }
                    GridRow {
                        Text("Stats:").foregroundStyle(.white.opacity(0.65))
                        Text("\(kanji.strokes) strokes  •  JLPT N\(kanji.jlpt == 0 ? "-" : "\(kanji.jlpt)")  •  Grade \(kanji.grade)  •  Freq #\(kanji.freqRank)")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .onAppear { visibleStrokes = kanji.strokePolylines.count }
    }

    private func animateStrokes(total: Int) {
        visibleStrokes = 0
        for step in 1...max(1, total) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.16) {
                withAnimation(.easeOut(duration: 0.14)) {
                    visibleStrokes = step
                }
            }
        }
    }
}

// MARK: - Dokusha 7-Slot Multi-Radical Intersection Builder

private let kCommonRadicals: [(UInt8, String)] = [
    (9, "亻"), (30, "口"), (32, "土"), (38, "女"), (40, "宀"), (42, "小"),
    (46, "山"), (61, "忄"), (64, "扌"), (72, "日"), (74, "月"), (75, "木"),
    (85, "氵"), (86, "灬"), (94, "犭"), (96, "王"), (102, "田"), (109, "目"),
    (112, "石"), (113, "礻"), (115, "禾"), (118, "⺮"), (120, "糸"), (130, "⺼"),
    (140, "艹"), (142, "虫"), (149, "言"), (154, "貝"), (157, "⻊"), (159, "車"),
    (162, "⻌"), (167, "金"), (169, "門"), (170, "阝"), (173, "雨"), (184, "食")
]

struct RadicalBuilderView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var tolerance: Int8 = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("7-Slot Multi-Radical Intersection")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Stepper("Strokes: \(engine.radicalTargetStrokes == 0 ? "Any" : "\(engine.radicalTargetStrokes)")", value: $engine.radicalTargetStrokes, in: 0...30)
                    .foregroundStyle(.white)
                    .frame(width: 170)
                    .onChange(of: engine.radicalTargetStrokes) { _, _ in runQuery() }
                Button("Clear") {
                    engine.radicalSelectedIds.removeAll()
                    engine.radicalMatches = []
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { slot in
                    let radId = slot < engine.radicalSelectedIds.count ? engine.radicalSelectedIds[slot] : nil
                    let glyph = radId.flatMap { id in kCommonRadicals.first(where: { $0.0 == id })?.1 } ?? "—"
                    Text(glyph)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(radId != nil ? Color.cyan.opacity(0.32) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 12), spacing: 6) {
                ForEach(kCommonRadicals, id: \.0) { radId, glyph in
                    let active = engine.radicalSelectedIds.contains(radId)
                    Button {
                        if active {
                            engine.radicalSelectedIds.removeAll { $0 == radId }
                        } else if engine.radicalSelectedIds.count < 7 {
                            engine.radicalSelectedIds.append(radId)
                        }
                        runQuery()
                    } label: {
                        Text(glyph)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(active ? Color.cyan.opacity(0.38) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().overlay(Color.white.opacity(0.18))

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                    ForEach(engine.radicalMatches, id: \.self) { cp in
                        let glyph = String(UnicodeScalar(cp)!)
                        Button {
                            engine.openFisheye(codepoint: cp, recordHistory: true)
                        } label: {
                            Text(glyph)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
    }

    private func runQuery() {
        engine.searchRadicals(selectedIds: engine.radicalSelectedIds, targetStrokes: Int16(engine.radicalTargetStrokes), tolerance: tolerance)
    }
}

// MARK: - Complete Screen Preview Renderer for 3D History Deck Cards

struct HistorySnapshotScreenView: View {
    let item: NavBreadcrumb
    let snapshot: HistorySnapshot?
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        switch snapshot {
        case .wordEntry(let entry):
            WordDetailContentView(entry: entry, engine: engine)
        case .kanjiDetail(let kanji):
            KanjiDetailContentView(kanji: kanji, engine: engine)
        case .fisheye(let kanji, let nodes, let leftOverflow, let rightOverflow):
            FisheyePreviewCardView(
                kanji: kanji,
                nodes: nodes,
                leftOverflow: leftOverflow,
                rightOverflow: rightOverflow,
                showPercentages: engine.showFisheyePercentages
            )
        case .radicalBuilder(let selectedIds, let targetStrokes, let matches):
            RadicalBuilderPreviewView(selectedIds: selectedIds, targetStrokes: targetStrokes, matches: matches)
        case nil:
            VStack(spacing: 10) {
                Text(item.label)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct FisheyePreviewCardView: View {
    let kanji: KanjiDetail
    let nodes: [FisheyeNode]
    let leftOverflow: Int
    let rightOverflow: Int
    let showPercentages: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(kanji.glyph)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kanji.meanings)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("On: \(kanji.onReadings.joined(separator: "・"))   Kun: \(kanji.kunReadings.joined(separator: "・"))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer()
                FisheyeLegendBar()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let halfW = max(1.0, geo.size.width / 2)
                let halfH = max(1.0, geo.size.height / 2)

                ZStack {
                    HStack {
                        Text("← PREFIX + CENTER")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text("CENTER + SUFFIX →")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .top)

                    Path { p in
                        p.move(to: CGPoint(x: center.x, y: 24))
                        p.addLine(to: CGPoint(x: center.x, y: geo.size.height - 24))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    .foregroundStyle(.white.opacity(0.10))

                    Canvas { ctx, _ in
                        for node in nodes {
                            let pt = CGPoint(x: center.x + node.normX * halfW, y: center.y + node.normY * halfH)
                            var path = Path()
                            path.move(to: center)
                            path.addLine(to: pt)
                            ctx.stroke(
                                path,
                                with: .color(node.tierColor.opacity(0.26 * node.opacity)),
                                lineWidth: 1.2
                            )
                        }
                    }

                    ForEach(nodes) { node in
                        let pos = CGPoint(x: center.x + node.normX * halfW, y: center.y + node.normY * halfH)
                        FisheyeBubbleView(
                            node: node,
                            showPercentages: showPercentages,
                            isSelected: false,
                            isHovered: false,
                            dimmed: false,
                            onTap: {}
                        )
                        .position(pos)
                    }

                    if leftOverflow > 0 {
                        VStack(spacing: 1) {
                            Text("+\(leftOverflow)").font(.caption.bold()).foregroundStyle(.white)
                            Text("more").font(.system(size: 9)).foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.09), in: Circle())
                        .overlay(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])).foregroundStyle(.cyan.opacity(0.8)))
                        .position(x: 54, y: geo.size.height - 46)
                    }

                    if rightOverflow > 0 {
                        VStack(spacing: 1) {
                            Text("+\(rightOverflow)").font(.caption.bold()).foregroundStyle(.white)
                            Text("more").font(.system(size: 9)).foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.09), in: Circle())
                        .overlay(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])).foregroundStyle(.cyan.opacity(0.8)))
                        .position(x: geo.size.width - 54, y: geo.size.height - 46)
                    }

                    Text(kanji.glyph)
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 92)
                        .background(Color(red: 0.12, green: 0.17, blue: 0.25), in: Circle())
                        .overlay(Circle().strokeBorder(.cyan.opacity(0.85), lineWidth: 2.5))
                        .shadow(color: .cyan.opacity(0.3), radius: 18)
                        .position(center)
                }
            }
            .padding(.bottom, 12)
        }
    }
}

private struct RadicalBuilderPreviewView: View {
    let selectedIds: [UInt8]
    let targetStrokes: Int
    let matches: [UInt32]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("7-Slot Multi-Radical Intersection")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("Strokes: \(targetStrokes == 0 ? "Any" : "\(targetStrokes)")")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { slot in
                    let radId = slot < selectedIds.count ? selectedIds[slot] : nil
                    let glyph = radId.flatMap { id in kCommonRadicals.first(where: { $0.0 == id })?.1 } ?? "—"
                    Text(glyph)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(radId != nil ? Color.cyan.opacity(0.32) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 12), spacing: 6) {
                ForEach(kCommonRadicals, id: \.0) { radId, glyph in
                    let active = selectedIds.contains(radId)
                    Text(glyph)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(active ? Color.cyan.opacity(0.38) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Divider().overlay(Color.white.opacity(0.18))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                ForEach(matches.prefix(30), id: \.self) { cp in
                    let glyph = String(UnicodeScalar(cp)!)
                    Text(glyph)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            Spacer()
        }
        .padding(20)
    }
}
