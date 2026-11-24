import SwiftUI

private enum IOSExploreMode: String, CaseIterable, Identifiable {
    case fisheye = "Fisheye"
    case cosmos = "Cosmos"
    case compounds = "Compounds"
    case radicals = "Radicals"

    var id: String { rawValue }
}

struct IOSExploreHubView: View {
    @ObservedObject var engine: DaiJishowEngine
    let onOpenWord: (UInt32) -> Void
    let onOpenKanji: (UInt32) -> Void

    @State private var mode: IOSExploreMode = .fisheye

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Explore Mode", selection: $mode) {
                    ForEach(IOSExploreMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch mode {
                case .fisheye:
                    IOSSpatialFisheyeView(
                        engine: engine,
                        onOpenWord: onOpenWord,
                        onOpenKanji: onOpenKanji
                    )
                case .cosmos:
                    IOSWordCosmosView(engine: engine, onOpenWord: onOpenWord)
                case .compounds:
                    IOSCompoundKanjiView(engine: engine, onOpenWord: onOpenWord, onOpenKanji: onOpenKanji)
                case .radicals:
                    IOSRadicalLookupView(engine: engine, onOpenKanji: onOpenKanji)
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Touch Spatial Fisheye (Two-Tap Rule)

private struct IOSSpatialFisheyeView: View {
    @ObservedObject var engine: DaiJishowEngine
    let onOpenWord: (UInt32) -> Void
    let onOpenKanji: (UInt32) -> Void

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let scaleX = geo.size.width * 0.44
                let scaleY = geo.size.height * 0.42

                ZStack {
                    ForEach(engine.fisheyeNodes) { node in
                        let pos = CGPoint(
                            x: center.x + node.normX * scaleX,
                            y: center.y + node.normY * scaleY
                        )
                        let isSelected = engine.selectedFisheyeNode?.id == node.id

                        Button {
                            if isSelected {
                                // Second tap re-centers fisheye on this kanji
                                engine.openFisheye(codepoint: node.codepoint)
                            } else {
                                engine.selectedFisheyeNode = node
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(node.glyph)
                                    .font(.system(size: max(16, 24 * node.scale), weight: .semibold))
                                if engine.showFisheyePercentages {
                                    Text(node.shareText)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(isSelected ? node.tierColor.opacity(0.32) : node.tierColor.opacity(0.14))
                                    .overlay(
                                        Circle().strokeBorder(
                                            isSelected ? node.tierColor : node.tierColor.opacity(0.4),
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(node.opacity)
                        .position(pos)
                    }

                    if let centerKanji = engine.activeKanji {
                        Button {
                            onOpenKanji(centerKanji.codepoint)
                        } label: {
                            VStack(spacing: 2) {
                                Text(centerKanji.glyph)
                                    .font(.system(size: 40, weight: .bold))
                                Text("Tap for Detail")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 84, height: 84)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Circle().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5))
                            )
                        }
                        .buttonStyle(.plain)
                        .position(center)
                    }
                }
                .onAppear {
                    let ratio = Float(max(geo.size.width, 1) / max(geo.size.height, 1))
                    let cp = engine.activeKanji?.codepoint ?? (engine.recentKanji.first ?? 0x5927)
                    if engine.fisheyeNodes.isEmpty {
                        engine.openFisheye(codepoint: cp, recordHistory: false)
                    } else {
                        engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: ratio)
                    }
                }
            }

            if let selected = engine.selectedFisheyeNode {
                Button {
                    if selected.topEntryId > 0 {
                        onOpenWord(selected.topEntryId)
                    } else {
                        engine.openFisheye(codepoint: selected.codepoint)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(selected.compoundWord)
                                    .font(.headline)
                                Text(selected.compoundKana)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(selected.tierLabel)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(selected.tierColor.opacity(0.2)))
                            }
                            Text(selected.compoundGloss)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text("Tap \(selected.glyph) again to center")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Word Cosmos

private struct IOSWordCosmosView: View {
    @ObservedObject var engine: DaiJishowEngine
    let onOpenWord: (UInt32) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("Tier", selection: Binding(
                    get: { engine.wordCosmosTier },
                    set: { engine.setWordCosmosTier($0) }
                )) {
                    ForEach(WordCosmosTier.allCases) { tier in
                        Text(tier.label).tag(tier)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    engine.diceRollWordCosmos()
                } label: {
                    Label("Roll", systemImage: "dice")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                    ForEach(engine.wordCosmosWords) { word in
                        Button {
                            onOpenWord(word.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(word.displayHeadword)
                                    .font(.headline)
                                Text(word.kanaHead)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(word.primaryGloss)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if engine.wordCosmosWords.isEmpty {
                engine.sampleWordCosmos()
            }
        }
    }
}

// MARK: - Compound Kanji Decomposer

private struct IOSCompoundKanjiView: View {
    @ObservedObject var engine: DaiJishowEngine
    let onOpenWord: (UInt32) -> Void
    let onOpenKanji: (UInt32) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let entry = engine.compoundEntry {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.header.displayHeadword)
                                    .font(.largeTitle.bold())
                                Text("\(entry.header.kanaHead) — \(entry.header.primaryGloss)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Open Word") {
                                onOpenWord(entry.header.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))

                    if !entry.rubyCells.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                            ForEach(entry.rubyCells) { cell in
                                Button {
                                    if cell.kanjiCodepoint > 0 {
                                        onOpenKanji(cell.kanjiCodepoint)
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        if !cell.furigana.isEmpty {
                                            Text(cell.furigana)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(cell.surface)
                                            .font(.title.bold())
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Text("Select a word to decompose its kanji cells.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .onAppear {
            if engine.compoundEntry == nil {
                engine.openCompoundKanji(seedEntryId: engine.activeEntry?.header.id, recordHistory: false)
            }
        }
    }
}

// MARK: - Radical Lookup

private struct IOSRadicalLookupView: View {
    @ObservedObject var engine: DaiJishowEngine
    let onOpenKanji: (UInt32) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(engine.radicalSelectedIds.isEmpty ? "Tap radicals to intersect kanji" : "\(engine.radicalMatches.count) matches")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if !engine.radicalSelectedIds.isEmpty {
                    Button("Clear") {
                        engine.radicalSelectedIds.removeAll()
                        engine.radicalMatches.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)

            if !engine.radicalMatches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(engine.radicalMatches.prefix(50), id: \.self) { cp in
                            if let scalar = UnicodeScalar(cp) {
                                Button {
                                    onOpenKanji(cp)
                                } label: {
                                    Text(String(Character(scalar)))
                                        .font(.title2.bold())
                                        .frame(width: 44, height: 44)
                                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.ultraThinMaterial))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                    ForEach(RadicalCatalog.all) { radical in
                        let selected = engine.radicalSelectedIds.contains(radical.id)
                        Button {
                            if let idx = engine.radicalSelectedIds.firstIndex(of: radical.id) {
                                engine.radicalSelectedIds.remove(at: idx)
                            } else if engine.radicalSelectedIds.count < 7 {
                                engine.radicalSelectedIds.append(radical.id)
                            }
                            if engine.radicalSelectedIds.isEmpty {
                                engine.radicalMatches.removeAll()
                            } else {
                                engine.searchRadicals(
                                    selectedIds: engine.radicalSelectedIds,
                                    targetStrokes: Int16(engine.radicalTargetStrokes),
                                    tolerance: engine.radicalStrokeTolerance
                                )
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(radical.glyph)
                                    .font(.title3)
                                Text("\(radical.strokes)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selected ? Color.accentColor : Color.secondary.opacity(0.14))
                            )
                            .foregroundStyle(selected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
}
