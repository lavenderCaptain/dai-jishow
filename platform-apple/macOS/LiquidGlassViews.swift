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

// MARK: - Per-Kanji Ruby Cell (supports both single-kanji & multi-kanji jukujikun cells with individually clickable kanji)

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
                // Multi-kanji jukujikun cell (e.g. `山車` with centered `だし`): make each individual kanji clickable!
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
}

// MARK: - Dokusha Spatial Fisheye Kanji Explorer

struct FisheyeExplorerView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var lastAspect: Float = 1.5
    @State private var hoveredLegendTier: String?
    @State private var explodedOverflowSide: UInt8?

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
        VStack(spacing: 12) {
            HStack(spacing: 12) {
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

                // Interactive Color Legend with Hover Pop-over Explanations
                HStack(spacing: 8) {
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
                    if let cp = engine.activeKanji?.codepoint {
                        engine.solveFisheye(center: cp, focusX: 0, focusY: 0, aspectRatio: lastAspect, animated: true)
                    }
                }

                Picker("Orbit Mode", selection: $engine.fisheyeMode) {
                    Text("2-Kanji").tag(DJ_EDGE_COMPOUNDS)
                    Text("四字熟語").tag(DJ_EDGE_YOJIJUKUGO)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 170)
                .onChange(of: engine.fisheyeMode) { _, _ in
                    if let cp = engine.activeKanji?.codepoint {
                        engine.selectedFisheyeNode = nil
                        engine.hoveredFisheyeNode = nil
                        engine.solveFisheye(center: cp, focusX: 0, focusY: 0, aspectRatio: lastAspect, animated: true)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let halfW = geo.size.width / 2
                let halfH = geo.size.height / 2
                let ar = Float(geo.size.width / max(1, geo.size.height))

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
                            let isHighlighted = (engine.selectedFisheyeNode?.id == node.id) || (engine.hoveredFisheyeNode?.id == node.id)
                            ctx.stroke(
                                path,
                                with: .color(isHighlighted ? node.tierColor.opacity(0.95) : node.tierColor.opacity(0.24 * node.opacity)),
                                lineWidth: isHighlighted ? 2.4 : 1.1
                            )
                        }
                    }

                    // Main Fisheye Bubbles with Compound Share % below the Kanji
                    ForEach(engine.fisheyeNodes) { node in
                        let isSelected = engine.selectedFisheyeNode?.id == node.id
                        let isHovered = engine.hoveredFisheyeNode?.id == node.id
                        let active = isSelected || isHovered
                        let diameter = 52.0 * node.scale
                        let pos = CGPoint(x: center.x + node.normX * halfW, y: center.y + node.normY * halfH)

                        Button {
                            if isSelected {
                                engine.openFisheye(codepoint: node.codepoint, recordHistory: true)
                            } else {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    engine.selectedFisheyeNode = node
                                }
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Text(node.glyph)
                                    .font(.system(size: 21 * node.scale, weight: active ? .bold : .semibold))
                                    .foregroundStyle(.white)
                                Text(node.shareText)
                                    .font(.system(size: 8.5 * max(0.85, node.scale * 0.85), weight: .semibold, design: .monospaced))
                                    .foregroundStyle(node.tierColor.opacity(0.95))
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
                        .opacity(max(0.70, node.opacity))
                        .onHover { hovering in
                            if hovering {
                                engine.hoveredFisheyeNode = node
                                if let cp = engine.activeKanji?.codepoint {
                                    engine.solveFisheye(
                                        center: cp,
                                        focusX: Float(node.normX),
                                        focusY: Float(node.normY),
                                        aspectRatio: ar,
                                        animated: true
                                    )
                                }
                            } else if engine.hoveredFisheyeNode?.id == node.id {
                                engine.hoveredFisheyeNode = nil
                                if let cp = engine.activeKanji?.codepoint {
                                    engine.solveFisheye(center: cp, focusX: 0, focusY: 0, aspectRatio: ar, animated: true)
                                }
                            }
                        }
                        .position(pos)
                        .zIndex(active ? 10 : 1)
                    }

                    // Overflow "+N more" Bubbles on Left (side 0) & Right (side 1) that explode out mini sub-bubbles on hover!
                    if engine.leftOverflowCount > 0 {
                        overflowClusterView(
                            side: 0,
                            count: engine.leftOverflowCount,
                            anchorPos: CGPoint(x: 64, y: geo.size.height - 52)
                        )
                    }
                    if engine.rightOverflowCount > 0 {
                        overflowClusterView(
                            side: 1,
                            count: engine.rightOverflowCount,
                            anchorPos: CGPoint(x: geo.size.width - 64, y: geo.size.height - 52)
                        )
                    }

                    if let centerKanji = engine.activeKanji {
                        Text(centerKanji.glyph)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(Color(red: 0.12, green: 0.17, blue: 0.25), in: Circle())
                            .overlay(Circle().strokeBorder(.cyan.opacity(0.85), lineWidth: 2.5))
                            .shadow(color: .cyan.opacity(0.3), radius: 18)
                            .position(center)
                            .zIndex(5)
                    }

                    // Floating mouse-over pop-up bubble for whichever kanji is currently hovered
                    if let hov = engine.hoveredFisheyeNode {
                        let nodeX = hov.isOverflowPreview
                            ? (hov.side == 0 ? 150.0 : geo.size.width - 150.0)
                            : (center.x + hov.normX * halfW)
                        let nodeY = hov.isOverflowPreview
                            ? (geo.size.height - 135.0)
                            : (center.y + hov.normY * halfH)
                        let popY = (!hov.isOverflowPreview && hov.normY < -0.35) ? (nodeY + 60) : (nodeY - 62)
                        let popX = min(max(nodeX, 145), geo.size.width - 145)

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
                        .frame(width: 275, alignment: .leading)
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
                        .zIndex(25)
                    }
                }
                .onAppear { lastAspect = ar }
                .onChange(of: geo.size) { _, newSize in
                    lastAspect = Float(newSize.width / max(1, newSize.height))
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
                    Text("Hover any kanji bubble for a preview; click once to pin it below, or click again to pivot onto it.")
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
    private func overflowClusterView(side: UInt8, count: Int, anchorPos: CGPoint) -> some View {
        let previews = engine.overflowPreviewNodes.filter { $0.side == side }
        let isExploded = (explodedOverflowSide == side)

        ZStack {
            if isExploded {
                ForEach(Array(previews.enumerated()), id: \.element.id) { idx, sub in
                    let angleDeg = (side == 0)
                        ? (-85.0 + Double(idx) * 22.0)
                        : (-95.0 - Double(idx) * 22.0)
                    let rad = angleDeg * .pi / 180.0
                    let radius: CGFloat = 56.0
                    let dx = CGFloat(cos(rad)) * radius
                    let dy = CGFloat(sin(rad)) * radius

                    Button {
                        engine.openFisheye(codepoint: sub.codepoint, recordHistory: true)
                    } label: {
                        Text(sub.glyph)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(red: 0.13, green: 0.18, blue: 0.26), in: Circle())
                            .overlay(Circle().strokeBorder(sub.tierColor, lineWidth: 1.4))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
                    .onHover { hov in
                        if hov { engine.hoveredFisheyeNode = sub }
                        else if engine.hoveredFisheyeNode?.id == sub.id { engine.hoveredFisheyeNode = nil }
                    }
                    .offset(x: dx, y: dy)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(spacing: 1) {
                Text("+\(count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text("more")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(width: 48, height: 48)
            .background(Color.white.opacity(isExploded ? 0.16 : 0.08), in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.3, dash: [3, 3]))
                    .foregroundStyle(.cyan.opacity(0.75))
            )
            .contentShape(Circle())
        }
        .frame(width: 140, height: 140)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                if hovering {
                    explodedOverflowSide = side
                } else if explodedOverflowSide == side {
                    explodedOverflowSide = nil
                }
            }
        }
        .position(anchorPos)
        .zIndex(15)
    }
}

// MARK: - Kanji Detail & Animated Quantized Stroke-Order Canvas

struct KanjiDetailView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var visibleStrokes: Int = 999

    var body: some View {
        if let k = engine.activeKanji {
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
                            let limit = min(visibleStrokes, k.strokePolylines.count)
                            for sIdx in 0..<limit {
                                let pts = k.strokePolylines[sIdx]
                                guard pts.count >= 2 else { continue }
                                var path = Path()
                                path.move(to: CGPoint(x: pts[0].x * size.width, y: pts[0].y * size.height))
                                for pt in pts.dropFirst() {
                                    path.addLine(to: CGPoint(x: pt.x * size.width, y: pt.y * size.height))
                                }
                                let isLatest = (sIdx == limit - 1 && visibleStrokes <= k.strokePolylines.count)
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
                            animateStrokes(total: k.strokePolylines.count)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Explorer") {
                            engine.openFisheye(codepoint: k.codepoint, recordHistory: true)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(k.glyph)
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(.white)
                        Text(k.meanings)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    Divider().overlay(Color.white.opacity(0.18))

                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                        GridRow {
                            Text("On'yomi:").foregroundStyle(.white.opacity(0.65))
                            Text(k.onReadings.isEmpty ? "—" : k.onReadings.joined(separator: "、"))
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        GridRow {
                            Text("Kun'yomi:").foregroundStyle(.white.opacity(0.65))
                            Text(k.kunReadings.isEmpty ? "—" : k.kunReadings.joined(separator: "、"))
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        GridRow {
                            Text("Component Radicals:").foregroundStyle(.white.opacity(0.65))
                            Text(k.componentRadicals.isEmpty ? "Radical #\(k.radicalId)" : k.componentRadicals)
                                .font(.headline)
                                .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                        }
                        GridRow {
                            Text("Stats:").foregroundStyle(.white.opacity(0.65))
                            Text("\(k.strokes) strokes  •  JLPT N\(k.jlpt == 0 ? "-" : "\(k.jlpt)")  •  Grade \(k.grade)  •  Freq #\(k.freqRank)")
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .onAppear { visibleStrokes = k.strokePolylines.count }
        }
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

struct RadicalBuilderView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var selectedRadicals: [UInt8] = []
    @State private var targetStrokes: Int = 0
    @State private var tolerance: Int8 = 1

    private let commonRadicals: [(UInt8, String)] = [
        (9, "亻"), (30, "口"), (32, "土"), (38, "女"), (40, "宀"), (42, "小"),
        (46, "山"), (61, "忄"), (64, "扌"), (72, "日"), (74, "月"), (75, "木"),
        (85, "氵"), (86, "灬"), (94, "犭"), (96, "王"), (102, "田"), (109, "目"),
        (112, "石"), (113, "礻"), (115, "禾"), (118, "⺮"), (120, "糸"), (130, "⺼"),
        (140, "艹"), (142, "虫"), (149, "言"), (154, "貝"), (157, "⻊"), (159, "車"),
        (162, "⻌"), (167, "金"), (169, "門"), (170, "阝"), (173, "雨"), (184, "食")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("7-Slot Multi-Radical Intersection")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Stepper("Strokes: \(targetStrokes == 0 ? "Any" : "\(targetStrokes)")", value: $targetStrokes, in: 0...30)
                    .foregroundStyle(.white)
                    .frame(width: 170)
                    .onChange(of: targetStrokes) { _, _ in runQuery() }
                Button("Clear") {
                    selectedRadicals.removeAll()
                    engine.radicalMatches = []
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { slot in
                    let radId = slot < selectedRadicals.count ? selectedRadicals[slot] : nil
                    let glyph = radId.flatMap { id in commonRadicals.first(where: { $0.0 == id })?.1 } ?? "—"
                    Text(glyph)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(radId != nil ? Color.cyan.opacity(0.32) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 12), spacing: 6) {
                ForEach(commonRadicals, id: \.0) { radId, glyph in
                    let active = selectedRadicals.contains(radId)
                    Button {
                        if active {
                            selectedRadicals.removeAll { $0 == radId }
                        } else if selectedRadicals.count < 7 {
                            selectedRadicals.append(radId)
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
        engine.searchRadicals(selectedIds: selectedRadicals, targetStrokes: Int16(targetStrokes), tolerance: tolerance)
    }
}
