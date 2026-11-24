import Foundation
import Testing
@testable import DaiJishowMorph

@Suite("Study library persistence and deck operations (StudyStore)")
@MainActor
struct StudyStoreTests {

    private func makeParentedTempURL() throws -> (dir: URL, file: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("daijishow-study-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (dir, dir.appendingPathComponent("study_library.json"))
    }

    @Test("Bootstraps default Favorites deck and persists JSON on missing file")
    func bootstrapsDefaultDeck() throws {
        let (dir, url) = try makeParentedTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = StudyStore(storageURL: url)
        #expect(store.decks.count == 1)
        #expect(store.decks[0].name == "Favorites")
        #expect(store.decks[0].isDefault)
        #expect(store.selectedDeckId == store.decks[0].id)
        #expect(store.totalSavedCount == 0)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Save and reload JSON round-trip preserves decks, items, and indexes")
    func saveReloadRoundTrip() throws {
        let (dir, url) = try makeParentedTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let word = StudySavedItem(
            kind: .word,
            targetId: 42,
            headword: "学校",
            reading: "がっこう",
            gloss: "school",
            pitchAccent: 0,
            metadata: "N5"
        )
        let kanji = StudySavedItem(
            kind: .kanji,
            targetId: 0x65E5,
            headword: "日",
            reading: "ニチ / ひ",
            gloss: "day; sun",
            metadata: "4 strokes"
        )

        let store1 = StudyStore(storageURL: url)
        let favId = store1.defaultDeck.id
        let jlptDeck = store1.createDeck(named: "  JLPT N5  ")
        #expect(jlptDeck.name == "JLPT N5")

        store1.addItem(word, toDeck: favId)
        store1.addItem(kanji, toDeck: jlptDeck.id)

        // Reload into a brand-new StudyStore instance pointing at the same URL
        let store2 = StudyStore(storageURL: url)
        #expect(store2.decks.count == 2)
        #expect(store2.decks[0].id == favId)
        #expect(store2.decks[0].items.map(\.id) == ["word:42"])
        #expect(store2.decks[1].id == jlptDeck.id)
        #expect(store2.decks[1].name == "JLPT N5")
        #expect(store2.decks[1].items.map(\.id) == ["kanji:\(0x65E5)"])
        #expect(store2.isWordSaved(42))
        #expect(!store2.isWordSaved(99))
        #expect(store2.isKanjiSaved(0x65E5))
        #expect(store2.totalSavedCount == 2)
    }

    @Test("Deduplicates items across decks and updates in-place within the same deck")
    func deduplicationAndCrossDeckMembership() throws {
        let (dir, url) = try makeParentedTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = StudyStore(storageURL: url)
        let favId = store.defaultDeck.id
        let verbsDeck = store.createDeck(named: "Verbs")

        let initial = StudySavedItem(kind: .word, targetId: 100, headword: "食べる", reading: "たべる", gloss: "to eat")
        let updated = StudySavedItem(kind: .word, targetId: 100, headword: "食べる", reading: "たべる", gloss: "to eat; consume")

        store.addItem(initial, toDeck: favId)
        store.addItem(initial, toDeck: verbsDeck.id)
        #expect(store.totalSavedCount == 1)
        #expect(store.deckIds(containingItemId: initial.id) == Set([favId, verbsDeck.id]))

        // Re-adding updated item to Favorites replaces in place instead of appending a duplicate
        store.addItem(updated, toDeck: favId)
        let favItems = store.decks.first(where: { $0.id == favId })?.items ?? []
        #expect(favItems.count == 1)
        #expect(favItems[0].gloss == "to eat; consume")

        // Removing from Favorites still preserves membership in Verbs deck
        store.removeItem(id: initial.id, fromDeck: favId)
        #expect(store.isWordSaved(100))
        #expect(store.deckIds(containingItemId: initial.id) == Set([verbsDeck.id]))
    }

    @Test("toggleItem and toggleStar manage membership and clean across all decks")
    func toggleItemAndToggleStar() throws {
        let (dir, url) = try makeParentedTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = StudyStore(storageURL: url)
        let extraDeck = store.createDeck(named: "Review")
        let kanji = StudySavedItem(kind: .kanji, targetId: 0x5C71, headword: "山", reading: "サン / やま", gloss: "mountain")

        // toggleItem with nil deckId targets Favorites
        store.toggleItem(kanji)
        #expect(store.isKanjiSaved(0x5C71))
        #expect(store.deckIds(containingItemId: kanji.id) == Set([store.defaultDeck.id]))

        // Also place in extra deck, then toggleStar removes from ALL decks at once
        store.addItem(kanji, toDeck: extraDeck.id)
        #expect(store.deckIds(containingItemId: kanji.id).count == 2)
        store.toggleStar(kanji)
        #expect(!store.isKanjiSaved(0x5C71))
        #expect(store.totalSavedCount == 0)

        // toggleStar again restores to Favorites
        store.toggleStar(kanji)
        #expect(store.isKanjiSaved(0x5C71))
        #expect(store.deckIds(containingItemId: kanji.id) == Set([store.defaultDeck.id]))

        // Second toggleItem removes it from Favorites
        store.toggleItem(kanji)
        #expect(!store.isKanjiSaved(0x5C71))
    }

    @Test("Deck creation, renaming, and non-deletable default deck protection")
    func deckLifecycle() throws {
        let (dir, url) = try makeParentedTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = StudyStore(storageURL: url)
        let favId = store.defaultDeck.id

        // Empty/whitespace name falls back to "Untitled Deck"
        let untitled = store.createDeck(named: "   \n ")
        #expect(untitled.name == "Untitled Deck")
        #expect(store.selectedDeckId == untitled.id)

        // Whitespace rename is ignored; valid rename updates and persists
        store.renameDeck(id: untitled.id, to: "   ")
        #expect(store.decks[1].name == "Untitled Deck")
        store.renameDeck(id: untitled.id, to: "  Core Kanji  ")
        #expect(store.decks[1].name == "Core Kanji")

        // Default deck cannot be deleted
        store.deleteDeck(id: favId)
        #expect(store.decks.count == 2)

        // Deleting non-default deck removes its unique items and updates selectedDeckId
        let item = StudySavedItem(kind: .word, targetId: 77, headword: "山", reading: "やま", gloss: "mountain")
        store.addItem(item, toDeck: untitled.id)
        #expect(store.isWordSaved(77))

        store.deleteDeck(id: untitled.id)
        #expect(store.decks.count == 1)
        #expect(store.selectedDeckId == favId)
        #expect(!store.isWordSaved(77))
    }

    @Test("Recovers from corrupt JSON and inserts missing default deck on reload")
    func corruptAndMissingDefaultRecovery() throws {
        let (dir, url) = try makeParentedTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        // 1. Corrupt file falls back cleanly to default Favorites deck
        try Data("not valid json {{{".utf8).write(to: url)
        let recovered = StudyStore(storageURL: url)
        #expect(recovered.decks.count == 1)
        #expect(recovered.decks[0].isDefault)
        #expect(recovered.decks[0].name == "Favorites")

        // 2. Valid JSON without an isDefault deck inserts Favorites at index 0
        let customItem = StudySavedItem(kind: .word, targetId: 9, headword: "海", reading: "うみ", gloss: "sea")
        let customOnly = [StudyDeck(name: "Travel", isDefault: false, items: [customItem])]
        let encoded = try JSONEncoder().encode(customOnly)
        try encoded.write(to: url)

        let withInsertedDefault = StudyStore(storageURL: url)
        #expect(withInsertedDefault.decks.count == 2)
        #expect(withInsertedDefault.decks[0].isDefault)
        #expect(withInsertedDefault.decks[0].name == "Favorites")
        #expect(withInsertedDefault.decks[1].name == "Travel")
        #expect(withInsertedDefault.isWordSaved(9))
    }

    @Test("Export helpers format deck, deduplicated library, and single items")
    func exportHelpers() throws {
        let (dir, url) = try makeParentedTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = StudyStore(storageURL: url)
        let favId = store.defaultDeck.id
        let otherDeck = store.createDeck(named: "Extra")
        let item = StudySavedItem(kind: .word, targetId: 5, headword: "猫", reading: "ねこ", gloss: "cat", pitchAccent: 1)

        store.addItem(item, toDeck: favId)
        store.addItem(item, toDeck: otherDeck.id)

        #expect(store.exportDeckText(deckId: UUID(), format: .csv) == "")

        let allTsv = store.exportAllSavedText(format: .ankiTSV)
        let allLines = allTsv.split(separator: "\n")
        #expect(allLines.count == 4) // 3 Anki header lines + 1 deduplicated item

        let singleTsv = store.exportSingleItemText(item, format: .ankiTSV)
        #expect(!singleTsv.hasPrefix("#separator:tab"))
        #expect(singleTsv == "猫\tねこ\tAtamadaka [1]\tcat\t\t\t")

        let singleCsv = store.exportSingleItemText(item, format: .csv)
        #expect(singleCsv.hasPrefix("Headword,Reading,Pitch"))
    }
}
