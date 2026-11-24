import SwiftUI
import DaiJishowMorph

// MARK: - Word Entry Detail (iPhone & iPad)

struct IOSWordEntryView: View {
    @ObservedObject var engine: DaiJishowEngine
    let entryId: UInt32
    let onOpenWord: (UInt32) -> Void
    let onOpenKanji: (UInt32) -> Void

    @State private var glossMode: GlossLanguageMode = .english
    @State private var copiedFeedback = false

    private var entry: EntryDetail? {
        if let active = engine.activeEntry, active.header.id == entryId {
            return active
        }
        return engine.fetchEntryDetail(entryId)
    }

    var body: some View {
        ScrollView {
            if let entry {
                let insights = engine.activeWordInsights?.entryId == entry.header.id
                    ? engine.activeWordInsights
                    : nil
                let isSaved = engine.studyStore.isWordSaved(entry.header.id)

                VStack(alignment: .leading, spacing: 18) {
                    headerCard(entry: entry, insights: insights, isSaved: isSaved)
                    controlsRow(entry: entry)
                    definitionsSection(entry: entry, insights: insights)

                    if entry.header.pairEntryId > 0 && !entry.pairedKanji.isEmpty {
                        pairJumpCard(entry: entry)
                    }

                    if let insights, !insights.kanjiDNA.isEmpty {
                        kanjiDNASection(dna: insights.kanjiDNA)
                    }

                    if let insights, !insights.inflections.isEmpty {
                        conjugationSection(
                            header: insights.inflectionHeader ?? "Conjugations",
                            forms: insights.inflections
                        )
                    }

                    if let insights, !insights.idioms.isEmpty {
                        idiomsSection(idioms: insights.idioms)
                    }

                    if let insights, !insights.homonyms.isEmpty {
                        wordStripSection(title: "Homonyms (同音異義語)", words: insights.homonyms)
                    }

                    if let insights, !insights.prefixCompounds.isEmpty || !insights.suffixCompounds.isEmpty {
                        wordStripSection(
                            title: "Word Family",
                            words: insights.prefixCompounds + insights.suffixCompounds
                        )
                    }

                    let sentences = entry.sentences.isEmpty
                        ? (insights?.fallbackSentences ?? [])
                        : entry.sentences
                    if !sentences.isEmpty {
                        sentencesSection(sentences: sentences)
                    }
                }
                .padding()
            } else {
                ProgressView("Loading entry…")
                    .padding(.top, 48)
            }
        }
        .navigationTitle(entry?.header.displayHeadword ?? "Entry")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if engine.activeEntry?.header.id != entryId {
                engine.openWordEntry(entryId: entryId, recordHistory: false)
            }
        }
    }

    private func headerCard(entry: EntryDetail, insights: WordLexicalInsights?, isSaved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if engine.recallMode != .hideKana && !entry.header.kanaHead.isEmpty && entry.header.kanaHead != entry.header.displayHeadword {
                        Text(entry.header.kanaHead)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.header.displayHeadword)
                        .font(.system(size: 36, weight: .bold))
                }
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        let speakText = entry.header.kanaHead.isEmpty ? entry.header.displayHeadword : entry.header.kanaHead
                        SpeechEngine.shared.speak(speakText)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.accentColor.opacity(0.14)))
                    }
                    .disabled(!SpeechEngine.shared.japaneseVoiceAvailable)

                    Button {
                        engine.toggleSaveWord(entry, insights: insights)
                    } label: {
                        Image(systemName: isSaved ? "star.fill" : "star")
                            .foregroundStyle(isSaved ? .yellow : .primary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.secondary.opacity(0.14)))
                    }
                }
            }

            if !entry.header.variantList.isEmpty {
                Text("Also: \(entry.header.variantList.joined(separator: " • "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let isNoun = (entry.header.posMask & (1 << 0)) != 0
            if engine.recallMode != .hideKana,
               let contour = PitchAccentContour.build(
                kana: entry.header.kanaHead,
                pitchAccent: entry.header.pitchAccent,
                showParticle: isNoun
               ) {
                IOSPitchContourView(contour: contour)
            }

            if let t = insights?.telemetry {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        badge(t.frequencyTier, tint: t.tierColor)
                        if let jlpt = t.jlptLabel { badge(jlpt, tint: .blue) }
                        if let grade = t.gradeLabel { badge(grade, tint: .teal) }
                        if t.totalStrokes > 0 { badge("\(t.totalStrokes) strokes", tint: .secondary) }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
    }

    private func controlsRow(entry: EntryDetail) -> some View {
        HStack {
            Picker("Recall", selection: $engine.recallMode) {
                ForEach(RecallMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Button {
                engine.copyText(entry.copyText)
                copiedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    copiedFeedback = false
                }
            } label: {
                Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                    .padding(9)
                    .background(Circle().fill(Color.secondary.opacity(0.14)))
            }
            .accessibilityLabel("Copy entry")
        }
    }

    private func definitionsSection(entry: EntryDetail, insights: WordLexicalInsights?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Definitions")
                    .font(.headline)
                Spacer()
                if entry.hasJapaneseGlosses {
                    Picker("Gloss", selection: $glossMode) {
                        ForEach(GlossLanguageMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 190)
                }
            }

            if engine.recallMode == .hideGloss {
                Text("Definitions hidden (Recall Mode). Switch to Full to reveal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
            } else {
                ForEach(Array(entry.senses.enumerated()), id: \.element.id) { idx, sense in
                    let tags = insights?.senseTags[sense.id] ?? Morph.senseTags(kana: entry.header.kanaHead, posMask: sense.posMask, glosses: sense.enGlosses)
                    VStack(alignment: .leading, spacing: 6) {
                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    Text("\(idx + 1).")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    ForEach(tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                                    }
                                }
                            }
                        }
                        if glossMode != .japanese && !sense.enGlosses.isEmpty {
                            Text(sense.enGlosses)
                                .font(.body)
                        }
                        if glossMode != .english && !sense.jaGlosses.isEmpty {
                            Text(sense.jaGlosses)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
                }
            }
        }
    }

    private func pairJumpCard(entry: EntryDetail) -> some View {
        Button {
            onOpenWord(entry.header.pairEntryId)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("自他 Transitive / Intransitive Pair")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(entry.pairedKanji) (\(entry.pairedKana))")
                        .font(.headline)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
    }

    private func kanjiDNASection(dna: [WordKanjiDNA]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kanji DNA")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(dna) { item in
                        Button {
                            onOpenKanji(item.codepoint)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(item.glyph)
                                        .font(.title2.bold())
                                    if let reading = item.intermediateReading {
                                        Text(reading)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(item.meanings)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .frame(width: 110, alignment: .leading)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func conjugationSection(header: String, forms: [InflectionForm]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(forms) { form in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(form.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(form.surface)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                }
            }
        }
    }

    private func idiomsSection(idioms: [IdiomItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Idioms & Yojijukugo")
                .font(.headline)
            ForEach(idioms) { idiom in
                Button {
                    onOpenWord(idiom.entryId)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(idiom.displayHeadword)
                                .font(.headline)
                            Text(idiom.kanaHead)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(idiom.shortKindLabel)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple.opacity(0.16)))
                        }
                        Text(idiom.figurativeGloss)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func wordStripSection(title: String, words: [WordHit]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(words.prefix(12)) { hit in
                        Button {
                            onOpenWord(hit.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(hit.displayHeadword)
                                    .font(.subheadline.weight(.semibold))
                                Text(hit.kanaHead)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(hit.primaryGloss)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 140, alignment: .leading)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sentencesSection(sentences: [SentenceItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example Sentences")
                .font(.headline)
            ForEach(sentences.prefix(8)) { sentence in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text(sentence.jpText)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button {
                            SpeechEngine.shared.speak(sentence.jpText)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.caption)
                        }
                        .disabled(!SpeechEngine.shared.japaneseVoiceAvailable)
                    }
                    if engine.recallMode != .hideGloss {
                        Text(sentence.enText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
            }
        }
    }

    private func badge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.16)))
            .foregroundStyle(tint == .secondary ? .secondary : tint)
    }
}

// MARK: - Pitch Accent Contour View

struct IOSPitchContourView: View {
    let contour: PitchAccentContour

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(contour.patternName)
                    .font(.caption.weight(.semibold))
                Text(contour.patternSublabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            let totalNodes = contour.morae.count + (contour.showParticle ? 1 : 0)
            Canvas { ctx, size in
                guard totalNodes > 0 else { return }
                let stepX = size.width / CGFloat(max(totalNodes, 1))
                let highY = size.height * 0.24
                let lowY = size.height * 0.68

                var points: [CGPoint] = []
                var filled: [Bool] = []
                for idx in contour.morae.indices {
                    let x = stepX * (CGFloat(idx) + 0.5)
                    let y = contour.highStates[idx] ? highY : lowY
                    points.append(CGPoint(x: x, y: y))
                    filled.append(true)
                }
                if contour.showParticle {
                    let x = stepX * (CGFloat(contour.morae.count) + 0.5)
                    let y = contour.particleHigh ? highY : lowY
                    points.append(CGPoint(x: x, y: y))
                    filled.append(false)
                }

                if points.count >= 2 {
                    var line = Path()
                    line.move(to: points[0])
                    for p in points.dropFirst() {
                        line.addLine(to: p)
                    }
                    ctx.stroke(line, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                for (idx, pt) in points.enumerated() {
                    let rect = CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)
                    if filled[idx] {
                        ctx.fill(Path(ellipseIn: rect), with: .color(.accentColor))
                    } else {
                        ctx.fill(Path(ellipseIn: rect), with: .color(.clear))
                        ctx.stroke(Path(ellipseIn: rect), with: .color(.accentColor), lineWidth: 2)
                    }
                }
            }
            .frame(height: 36)

            HStack(spacing: 0) {
                ForEach(Array(contour.morae.enumerated()), id: \.offset) { _, mora in
                    Text(mora)
                        .font(.caption2.monospaced())
                        .frame(maxWidth: .infinity)
                }
                if contour.showParticle {
                    Text("が")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

// MARK: - Kanji Detail View (iPhone & iPad)

struct IOSKanjiDetailView: View {
    @ObservedObject var engine: DaiJishowEngine
    let codepoint: UInt32
    let onOpenWord: (UInt32) -> Void
    let onOpenFisheye: (UInt32) -> Void

    @State private var shownStrokes: Int = Int.max
    @State private var playbackTask: Task<Void, Never>?

    private var kanji: KanjiDetail? {
        if let active = engine.activeKanji, active.codepoint == codepoint {
            return active
        }
        return nil
    }

    var body: some View {
        ScrollView {
            if let kanji {
                let total = kanji.strokePolylines.count
                let visible = min(shownStrokes, total)
                let isSaved = engine.studyStore.isKanjiSaved(kanji.codepoint)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.ultraThinMaterial)
                            IOSKanjiStrokeDiagram(
                                polylines: kanji.strokePolylines,
                                visibleCount: visible,
                                highlightLatest: visible < total
                            )
                            .padding(16)
                        }
                        .frame(width: 150, height: 150)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(kanji.glyph)
                                    .font(.system(size: 46, weight: .bold))
                                Spacer()
                                Button {
                                    engine.toggleSaveKanji(kanji)
                                } label: {
                                    Image(systemName: isSaved ? "star.fill" : "star")
                                        .foregroundStyle(isSaved ? .yellow : .primary)
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(Color.secondary.opacity(0.14)))
                                }
                            }
                            if !kanji.meanings.isEmpty {
                                Text(kanji.meanings)
                                    .font(.subheadline)
                            }
                            HStack(spacing: 8) {
                                if kanji.strokes > 0 { chip("\(kanji.strokes) strokes") }
                                if kanji.jlpt > 0 { chip("N\(kanji.jlpt)") }
                                if !kanji.skipCodeLabel.isEmpty { chip("SKIP \(kanji.skipCodeLabel)") }
                            }
                        }
                    }

                    if total > 0 {
                        HStack(spacing: 12) {
                            Button {
                                startStrokeAnimation(total: total)
                            } label: {
                                Label("Play Strokes", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                playbackTask?.cancel()
                                shownStrokes = total
                            } label: {
                                Text("Show All (\(total))")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Button {
                        onOpenFisheye(kanji.codepoint)
                    } label: {
                        Label("Explore in Spatial Fisheye", systemImage: "circle.hexagongrid")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 8) {
                        if !kanji.onReadings.isEmpty {
                            Text("On'yomi: \(kanji.onReadings.joined(separator: " • "))")
                                .font(.subheadline)
                        }
                        if !kanji.kunReadings.isEmpty {
                            Text("Kun'yomi: \(kanji.kunReadings.joined(separator: " • "))")
                                .font(.subheadline)
                        }
                        if !kanji.fourCornerLabel.isEmpty {
                            Text("Four-Corner: \(kanji.fourCornerLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let kyujitai = kanji.kyujitaiGlyph {
                            Text("Kyūjitai: \(kyujitai)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))

                    if !kanji.idioms.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Idioms & Yojijukugo")
                                .font(.headline)
                            ForEach(kanji.idioms.prefix(10)) { idiom in
                                Button {
                                    onOpenWord(idiom.entryId)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(idiom.displayHeadword)  (\(idiom.kanaHead))")
                                            .font(.subheadline.weight(.semibold))
                                        Text(idiom.figurativeGloss)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !kanji.relatedWords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Compounds")
                                    .font(.headline)
                                Spacer()
                                Picker("Filter", selection: $engine.kanjiRelatedMode) {
                                    ForEach(KanjiRelatedDisplayMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 220)
                            }

                            let filtered = filterRelated(kanji.relatedWords, glyph: kanji.glyph)
                            ForEach(filtered.prefix(25)) { word in
                                Button {
                                    onOpenWord(word.id)
                                } label: {
                                    IOSWordHitRow(hit: word, engine: engine)
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            } else {
                ProgressView("Loading kanji…")
                    .padding(.top, 48)
            }
        }
        .navigationTitle(kanji?.glyph ?? "Kanji")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if engine.activeKanji?.codepoint != codepoint {
                engine.openKanjiDetail(codepoint: codepoint, recordHistory: false)
            }
        }
        .onDisappear {
            playbackTask?.cancel()
        }
    }

    private func filterRelated(_ words: [WordHit], glyph: String) -> [WordHit] {
        switch engine.kanjiRelatedMode {
        case .prevalence: return words
        case .startsWith: return words.filter { $0.displayHeadword.hasPrefix(glyph) }
        case .endsWith:   return words.filter { $0.displayHeadword.hasSuffix(glyph) }
        }
    }

    private func startStrokeAnimation(total: Int) {
        playbackTask?.cancel()
        shownStrokes = 1
        playbackTask = Task {
            for step in 2...total {
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                shownStrokes = step
            }
        }
    }

    private func chip(_ label: String) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
    }
}

struct IOSKanjiStrokeDiagram: View {
    let polylines: [[CGPoint]]
    let visibleCount: Int
    var highlightLatest: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            var grid = Path()
            grid.move(to: CGPoint(x: w * 0.5, y: 0))
            grid.addLine(to: CGPoint(x: w * 0.5, y: h))
            grid.move(to: CGPoint(x: 0, y: h * 0.5))
            grid.addLine(to: CGPoint(x: w, y: h * 0.5))
            ctx.stroke(grid, with: .color(.primary.opacity(0.14)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            let count = min(visibleCount, polylines.count)
            for idx in 0..<count {
                let pts = polylines[idx]
                guard pts.count >= 2 else { continue }
                var path = Path()
                path.move(to: CGPoint(x: pts[0].x * w, y: pts[0].y * h))
                for p in pts.dropFirst() {
                    path.addLine(to: CGPoint(x: p.x * w, y: p.y * h))
                }
                let isLatest = highlightLatest && (idx == count - 1)
                ctx.stroke(
                    path,
                    with: .color(isLatest ? Color.accentColor : Color.primary),
                    style: StrokeStyle(lineWidth: isLatest ? 6.5 : 5.0, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}
