import SwiftUI
import DaiJishowMorph

// MARK: - Reusable Bookmark + Deck Assignment Control

struct BookmarkDeckControl: View {
    @ObservedObject var engine: DaiJishowEngine
    @ObservedObject var studyStore: StudyStore
    let item: StudySavedItem
    var compact: Bool = false

    @State private var showingNewDeckPrompt: Bool = false
    @State private var newDeckName: String = ""

    private var containingDecks: Set<UUID> {
        studyStore.deckIds(containingItemId: item.id)
    }

    private var isSaved: Bool {
        !containingDecks.isEmpty
    }

    private var controlHeight: CGFloat { compact ? 26 : 30 }
    private var iconFont: Font { compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold) }

    var body: some View {
        HStack(spacing: 2) {
            starButton

            Divider()
                .frame(height: compact ? 13 : 16)
                .opacity(0.22)

            deckMenuButton
        }
        .frame(height: controlHeight)
        .fixedSize()
        .background(pillBackground)
        .popover(isPresented: $showingNewDeckPrompt, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Create Study Deck")
                    .font(.headline)
                TextField("Deck name (e.g. JLPT N3 Verbs)", text: $newDeckName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                    .onSubmit { createAndAdd() }
                HStack {
                    Spacer()
                    Button("Cancel") { showingNewDeckPrompt = false }
                    Button("Create & Add") { createAndAdd() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var starButton: some View {
        Button {
            studyStore.toggleStar(item)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isSaved ? "star.fill" : "star")
                    .font(iconFont)
                if !compact {
                    Text(isSaved ? "Saved" : "Save")
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(isSaved ? Color.yellow : .primary)
            .padding(.horizontal, compact ? 8 : 11)
            .frame(minWidth: compact ? 28 : 34)
            .frame(height: controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isSaved ? "Remove from saved decks (⌘B)" : "Save to Favorites deck (⌘B)")
        .djAccessibleControl(
            label: isSaved ? "Saved in study decks" : "Save to Favorites deck",
            hint: "Toggle Favorites bookmark (⌘B)",
            selected: isSaved
        )
    }

    @ViewBuilder
    private var deckMenuButton: some View {
        Menu {
            Section("Add or Remove from Deck") {
                ForEach(studyStore.decks) { deck in
                    let inDeck = containingDecks.contains(deck.id)
                    Button {
                        studyStore.toggleItem(item, inDeck: deck.id)
                    } label: {
                        Label(deck.name, systemImage: inDeck ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
            Divider()
            Button {
                newDeckName = ""
                showingNewDeckPrompt = true
            } label: {
                Label("New Deck…", systemImage: "folder.badge.plus")
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: compact ? 22 : 26, height: controlHeight)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Choose which study decks contain this item")
        .djAccessibleControl(label: "Choose study decks", hint: "Add or remove this item from study decks")
    }

    private var pillBackground: some View {
        Capsule()
            .fill(isSaved ? Color.yellow.opacity(0.16) : Color.primary.opacity(0.08))
            .overlay(
                Capsule()
                    .strokeBorder(isSaved ? Color.yellow.opacity(0.45) : Color.primary.opacity(0.14), lineWidth: 1)
            )
    }

    private func createAndAdd() {
        let deck = studyStore.createDeck(named: newDeckName)
        studyStore.addItem(item, toDeck: deck.id)
        showingNewDeckPrompt = false
    }
}

// MARK: - Saved Study Decks & Anki Export View

struct StudyLibraryView: View {
    @ObservedObject var engine: DaiJishowEngine
    @ObservedObject var studyStore: StudyStore

    @State private var itemFilterText: String = ""
    @State private var showingNewDeckSheet: Bool = false
    @State private var newDeckName: String = ""
    @State private var renamingDeckId: UUID? = nil
    @State private var renameDeckDraft: String = ""
    @State private var exportNotice: String? = nil

    private var selectedDeck: StudyDeck? {
        if let sid = studyStore.selectedDeckId,
           let found = studyStore.decks.first(where: { $0.id == sid }) {
            return found
        }
        return studyStore.decks.first
    }

    private var filteredItems: [StudySavedItem] {
        guard let deck = selectedDeck else { return [] }
        let q = itemFilterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return deck.items }
        return deck.items.filter { item in
            item.headword.lowercased().contains(q)
                || item.reading.lowercased().contains(q)
                || item.gloss.lowercased().contains(q)
                || item.metadata.lowercased().contains(q)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let isNarrow = geo.size.width < 880
            Group {
                if isNarrow {
                    VStack(spacing: 14) {
                        decksSidebar
                            .frame(maxHeight: 220)
                        deckContentPane
                    }
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        decksSidebar
                            .frame(width: 270)
                        deckContentPane
                    }
                }
            }
            .padding(22)
        }
    }

    // MARK: - Decks List Sidebar

    private var decksSidebar: some View {
        GlassCard(cornerRadius: 20, surface: .content) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Study Decks", systemImage: "books.vertical.fill")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Button {
                        newDeckName = ""
                        showingNewDeckSheet = true
                    } label: {
                        Label("New", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.accentColor.opacity(0.22)))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Create a custom study deck")
                    .djAccessibleControl(label: "Create study deck")
                }

                if showingNewDeckSheet {
                    HStack(spacing: 6) {
                        TextField("Deck name…", text: $newDeckName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { commitNewDeck() }
                        Button("Add") { commitNewDeck() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(newDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button {
                            showingNewDeckSheet = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .djAccessibleControl(label: "Cancel creating deck")
                    }
                }

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(studyStore.decks) { deck in
                            deckRow(deck)
                        }
                    }
                }

                Divider().opacity(0.25)

                HStack {
                    Text("\(studyStore.totalSavedCount) unique items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("Copy All Decks (Anki TSV)") {
                            let tsv = studyStore.exportAllSavedText(format: .ankiTSV)
                            engine.copyText(tsv)
                            flashNotice("Copied Anki TSV for all decks")
                        }
                        Button("Save All Decks as Anki .tsv…") {
                            let tsv = studyStore.exportAllSavedText(format: .ankiTSV)
                            studyStore.saveExportFile(content: tsv, suggestedName: "Dai-Jishow-All-Decks", format: .ankiTSV)
                        }
                        Button("Save All Decks as CSV…") {
                            let csv = studyStore.exportAllSavedText(format: .csv)
                            studyStore.saveExportFile(content: csv, suggestedName: "Dai-Jishow-All-Decks", format: .csv)
                        }
                    } label: {
                        Label("Export All", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(studyStore.totalSavedCount == 0)
                }
            }
            .padding(16)
        }
    }

    private func deckRow(_ deck: StudyDeck) -> some View {
        let isSelected = (selectedDeck?.id == deck.id)
        let isRenaming = (renamingDeckId == deck.id)
        return HStack(spacing: 8) {
            Image(systemName: deck.isDefault ? "star.fill" : "folder.fill")
                .foregroundStyle(deck.isDefault ? Color.yellow : (isSelected ? Color.accentColor : .secondary))
                .font(.subheadline)

            if isRenaming {
                TextField("Deck name", text: $renameDeckDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        studyStore.renameDeck(id: deck.id, to: renameDeckDraft)
                        renamingDeckId = nil
                    }
                Button("Done") {
                    studyStore.renameDeck(id: deck.id, to: renameDeckDraft)
                    renamingDeckId = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            } else {
                Text(deck.name)
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
                    .lineLimit(1)
                Spacer()
                Text("\(deck.items.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .focusable(interactions: .activate)
        .djAccessibleControl(
            label: "\(deck.name) deck",
            hint: "Select study deck",
            value: "\(deck.items.count) items",
            selected: isSelected,
            isButton: true
        )
        .onTapGesture {
            studyStore.selectedDeckId = deck.id
        }
        .contextMenu {
            if !deck.isDefault {
                Button("Rename Deck") {
                    renameDeckDraft = deck.name
                    renamingDeckId = deck.id
                }
                Divider()
                Button("Delete Deck", role: .destructive) {
                    studyStore.deleteDeck(id: deck.id)
                }
            }
        }
    }

    // MARK: - Active Deck Contents

    private var deckContentPane: some View {
        GlassCard(cornerRadius: 20, surface: .content) {
            VStack(alignment: .leading, spacing: 14) {
                if let deck = selectedDeck {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(deck.name)
                                    .font(.title2.weight(.bold))
                                if !deck.isDefault {
                                    Button {
                                        renameDeckDraft = deck.name
                                        renamingDeckId = deck.id
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Rename deck")
                                    .djAccessibleControl(label: "Rename \(deck.name) deck")
                                }
                            }
                            Text("\(deck.items.count) saved \(deck.items.count == 1 ? "item" : "items")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let exportNotice {
                            Text(exportNotice)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.green.opacity(0.16)))
                                .transition(.opacity)
                        }

                        Menu {
                            Button {
                                let tsv = studyStore.exportDeckText(deckId: deck.id, format: .ankiTSV)
                                engine.copyText(tsv)
                                flashNotice("Copied \(deck.items.count) cards as Anki TSV")
                            } label: {
                                Label("Copy Anki TSV", systemImage: "doc.on.clipboard")
                            }

                            Button {
                                let tsv = studyStore.exportDeckText(deckId: deck.id, format: .ankiTSV)
                                studyStore.saveExportFile(
                                    content: tsv,
                                    suggestedName: deck.name.replacingOccurrences(of: " ", with: "-"),
                                    format: .ankiTSV
                                )
                            } label: {
                                Label("Save Anki .tsv File…", systemImage: "square.and.arrow.down")
                            }

                            Divider()

                            Button {
                                let csv = studyStore.exportDeckText(deckId: deck.id, format: .csv)
                                engine.copyText(csv)
                                flashNotice("Copied \(deck.items.count) cards as CSV")
                            } label: {
                                Label("Copy CSV", systemImage: "tablecells")
                            }

                            Button {
                                let csv = studyStore.exportDeckText(deckId: deck.id, format: .csv)
                                studyStore.saveExportFile(
                                    content: csv,
                                    suggestedName: deck.name.replacingOccurrences(of: " ", with: "-"),
                                    format: .csv
                                )
                            } label: {
                                Label("Save CSV File…", systemImage: "doc.badge.arrow.up")
                            }
                        } label: {
                            Label("Export Deck", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.accentColor))
                                .foregroundStyle(.white)
                        }
                        .menuStyle(.borderlessButton)
                        .disabled(deck.items.isEmpty)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Filter saved words or kanji…", text: $itemFilterText)
                            .textFieldStyle(.plain)
                        if !itemFilterText.isEmpty {
                            Button { itemFilterText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .djAccessibleControl(label: "Clear deck filter")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))

                    if filteredItems.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "star.leadinghalf.filled")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(.secondary)
                            Text(deck.items.isEmpty ? "This deck is empty" : "No saved items match “\(itemFilterText)”")
                                .font(.headline)
                            Text("Star any word or kanji (⌘B) to save it here for recall practice and Anki deck export.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredItems) { item in
                                    savedItemRow(item, inDeck: deck)
                                }
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    private func savedItemRow(_ item: StudySavedItem, inDeck deck: StudyDeck) -> some View {
        HStack(spacing: 12) {
            Text(item.kind == .word ? "WORD" : "KANJI")
                .font(.caption2.weight(.bold))
                .foregroundStyle(item.kind == .word ? Color.accentColor : Color.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill((item.kind == .word ? Color.accentColor : Color.orange).opacity(0.16)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.headword)
                        .font(.title3.weight(.bold))
                    if engine.recallMode != .hideKana && !item.reading.isEmpty {
                        Text(item.reading)
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                    if !item.formattedPitch.isEmpty, engine.recallMode != .hideKana {
                        Text(item.formattedPitch)
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    if !item.metadata.isEmpty {
                        Text(item.metadata)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if engine.recallMode != .hideGloss && !item.gloss.isEmpty {
                    Text(item.gloss)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            let speakSource = item.kind == .word
                ? (item.reading.isEmpty ? item.headword : item.reading)
                : (item.reading.split(separator: ",").first.map(String.init) ?? item.headword)
            SpeakerButton(text: speakSource, variant: .compact, extraHelp: "Hear pronunciation in Japanese")

            Button {
                let tsv = studyStore.exportSingleItemText(item, format: .ankiTSV)
                engine.copyText(tsv)
                flashNotice("Copied Anki card for \(item.headword)")
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Copy single-line Anki TSV card")
            .djAccessibleControl(label: "Copy Anki card for \(item.headword)")

            Button {
                if item.kind == .word {
                    engine.openWordEntry(entryId: item.targetId)
                } else {
                    engine.openKanjiDetail(codepoint: item.targetId)
                }
            } label: {
                Label("Open", systemImage: "arrow.up.forward.circle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.20)))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .djAccessibleControl(label: "Open \(item.headword)")

            if item.kind == .kanji {
                Button {
                    engine.openFisheye(codepoint: item.targetId)
                } label: {
                    Image(systemName: "scope")
                        .font(.caption.weight(.semibold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Open in Kanji Fisheye")
                .djAccessibleControl(label: "Open \(item.headword) in Kanji Fisheye")
            }

            Button {
                studyStore.removeItem(id: item.id, fromDeck: deck.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.red.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .help("Remove from \(deck.name)")
            .djAccessibleControl(label: "Remove \(item.headword) from \(deck.name)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if item.kind == .word {
                engine.openWordEntry(entryId: item.targetId)
            } else {
                engine.openKanjiDetail(codepoint: item.targetId)
            }
        }
    }

    private func commitNewDeck() {
        let trimmed = newDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = studyStore.createDeck(named: trimmed)
        showingNewDeckSheet = false
    }

    private func flashNotice(_ message: String) {
        withAnimation { exportNotice = message }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            await MainActor.run {
                if exportNotice == message {
                    withAnimation { exportNotice = nil }
                }
            }
        }
    }
}
