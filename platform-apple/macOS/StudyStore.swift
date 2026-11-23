import Foundation
import DaiJishowMorph
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

@MainActor
final class StudyStore: ObservableObject {
    @Published private(set) var decks: [StudyDeck] = []
    @Published private(set) var savedWordIds: Set<UInt32> = []
    @Published private(set) var savedKanjiCodepoints: Set<UInt32> = []
    @Published var selectedDeckId: UUID?

    private let storageURL: URL

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let dir = appSupport.appendingPathComponent("Dai-Jishow", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("study_library.json")
        }
        load()
    }

    var defaultDeck: StudyDeck {
        if let def = decks.first(where: { $0.isDefault }) ?? decks.first {
            return def
        }
        let created = StudyDeck(name: "Favorites", isDefault: true)
        decks = [created]
        selectedDeckId = created.id
        persist()
        return created
    }

    var totalSavedCount: Int {
        Set(decks.flatMap { $0.items.map(\.id) }).count
    }

    func isWordSaved(_ entryId: UInt32) -> Bool {
        savedWordIds.contains(entryId)
    }

    func isKanjiSaved(_ codepoint: UInt32) -> Bool {
        savedKanjiCodepoints.contains(codepoint)
    }

    func deckIds(containingItemId itemId: String) -> Set<UUID> {
        Set(decks.filter { $0.items.contains(where: { $0.id == itemId }) }.map(\.id))
    }

    @discardableResult
    func createDeck(named rawName: String) -> StudyDeck {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Untitled Deck" : trimmed
        let deck = StudyDeck(name: name, isDefault: false)
        decks.append(deck)
        selectedDeckId = deck.id
        persist()
        return deck
    }

    func renameDeck(id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = decks.firstIndex(where: { $0.id == id }) else { return }
        decks[idx].name = trimmed
        persist()
    }

    func deleteDeck(id: UUID) {
        guard let idx = decks.firstIndex(where: { $0.id == id }), !decks[idx].isDefault else { return }
        decks.remove(at: idx)
        if selectedDeckId == id {
            selectedDeckId = decks.first?.id
        }
        rebuildIndexes()
        persist()
    }

    func toggleItem(_ item: StudySavedItem, inDeck deckId: UUID? = nil) {
        let targetId = deckId ?? defaultDeck.id
        guard let idx = decks.firstIndex(where: { $0.id == targetId }) else { return }
        if let existing = decks[idx].items.firstIndex(where: { $0.id == item.id }) {
            decks[idx].items.remove(at: existing)
        } else {
            decks[idx].items.insert(item, at: 0)
        }
        rebuildIndexes()
        persist()
    }

    func addItem(_ item: StudySavedItem, toDeck deckId: UUID) {
        guard let idx = decks.firstIndex(where: { $0.id == deckId }) else { return }
        if let existing = decks[idx].items.firstIndex(where: { $0.id == item.id }) {
            decks[idx].items[existing] = item
        } else {
            decks[idx].items.insert(item, at: 0)
        }
        rebuildIndexes()
        persist()
    }

    func removeItem(id itemId: String, fromDeck deckId: UUID) {
        guard let idx = decks.firstIndex(where: { $0.id == deckId }) else { return }
        decks[idx].items.removeAll { $0.id == itemId }
        rebuildIndexes()
        persist()
    }

    /// Removes the item from whichever decks contain it, or adds it to Favorites if absent.
    func toggleStar(_ item: StudySavedItem) {
        let isSaved = (item.kind == .word) ? isWordSaved(item.targetId) : isKanjiSaved(item.targetId)
        if isSaved {
            for i in decks.indices {
                decks[i].items.removeAll { $0.id == item.id }
            }
            rebuildIndexes()
            persist()
        } else {
            addItem(item, toDeck: defaultDeck.id)
        }
    }

    func exportDeckText(deckId: UUID, format: AnkiExportFormat) -> String {
        guard let deck = decks.first(where: { $0.id == deckId }) else { return "" }
        return StudyExporter.format(items: deck.items, format: format, includeHeader: true)
    }

    func exportAllSavedText(format: AnkiExportFormat) -> String {
        var seen = Set<String>()
        var unique: [StudySavedItem] = []
        for deck in decks {
            for item in deck.items where seen.insert(item.id).inserted {
                unique.append(item)
            }
        }
        return StudyExporter.format(items: unique, format: format, includeHeader: true)
    }

    func exportSingleItemText(_ item: StudySavedItem, format: AnkiExportFormat) -> String {
        StudyExporter.format(items: [item], format: format, includeHeader: format == .ankiTSV ? false : true)
    }

    func saveExportFile(content: String, suggestedName: String, format: AnkiExportFormat) {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(suggestedName).\(format.fileExtension)"
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [format == .csv ? .commaSeparatedText : .tabSeparatedText]
        }
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
        #endif
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([StudyDeck].self, from: data),
           !decoded.isEmpty {
            self.decks = decoded
        } else {
            self.decks = [StudyDeck(name: "Favorites", isDefault: true)]
            persist()
        }
        if !decks.contains(where: { $0.isDefault }) {
            decks.insert(StudyDeck(name: "Favorites", isDefault: true), at: 0)
        }
        if selectedDeckId == nil || !decks.contains(where: { $0.id == selectedDeckId }) {
            selectedDeckId = decks.first?.id
        }
        rebuildIndexes()
    }

    private func rebuildIndexes() {
        var words = Set<UInt32>()
        var kanji = Set<UInt32>()
        for deck in decks {
            for item in deck.items {
                switch item.kind {
                case .word: words.insert(item.targetId)
                case .kanji: kanji.insert(item.targetId)
                }
            }
        }
        self.savedWordIds = words
        self.savedKanjiCodepoints = kanji
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(decks) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
