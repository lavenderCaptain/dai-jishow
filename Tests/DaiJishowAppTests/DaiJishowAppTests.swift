import AppKit
import Foundation
import SQLite3
import SwiftUI
import Testing
@testable import Dai_Jishow
@testable import DaiJishowMorph

@Suite("Dai-Jishow sandboxed app integration & UI smoke tests")
@MainActor
struct DaiJishowAppTests {

    // MARK: - Helpers

    private static func snapshotDefaults(_ keys: [String]) -> [String: Any?] {
        var snapshot: [String: Any?] = [:]
        for key in keys {
            snapshot[key] = UserDefaults.standard.object(forKey: key)
        }
        return snapshot
    }

    private static func restoreDefaults(_ snapshot: [String: Any?]) {
        for (key, value) in snapshot {
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    /// Returns the bundled `daijishow.db` path if available, or creates a minimal
    /// in-sandbox SQLite fixture so integration tests pass even on clean CI clones.
    private static func resolveOrCreateTestDatabase() throws -> (path: String, isTemporary: Bool) {
        if let bundled = Bundle.main.path(forResource: "daijishow", ofType: "db"),
           FileManager.default.fileExists(atPath: bundled) {
            return (bundled, false)
        }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("daijishow-apptest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("fixture.db")

        var db: OpaquePointer?
        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK, let db else {
            throw NSError(domain: "DaiJishowAppTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open fixture sqlite DB"])
        }
        defer { sqlite3_close(db) }

        let sql = """
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY,
            kanji_head TEXT NOT NULL,
            kana_head TEXT NOT NULL,
            alt_forms TEXT NOT NULL DEFAULT '',
            primary_gloss TEXT NOT NULL,
            pos_mask INTEGER NOT NULL DEFAULT 0,
            pitch_accent INTEGER NOT NULL DEFAULT 255,
            freq_rank INTEGER NOT NULL DEFAULT 0,
            pair_entry_id INTEGER NOT NULL DEFAULT 0,
            is_name INTEGER NOT NULL DEFAULT 0,
            reading_romaji TEXT NOT NULL DEFAULT '',
            english_tokens TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE senses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_id INTEGER NOT NULL,
            sense_idx INTEGER NOT NULL,
            pos_mask INTEGER NOT NULL DEFAULT 0,
            en_glosses TEXT NOT NULL DEFAULT '',
            ja_glosses TEXT NOT NULL DEFAULT '',
            tags TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE sentences (
            id INTEGER PRIMARY KEY,
            jp_text TEXT NOT NULL,
            en_text TEXT NOT NULL,
            ruby_json TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE sentence_entry_links (
            entry_id INTEGER NOT NULL,
            sentence_id INTEGER NOT NULL
        );
        CREATE TABLE kanji (
            codepoint INTEGER PRIMARY KEY,
            glyph TEXT NOT NULL,
            strokes INTEGER NOT NULL DEFAULT 0,
            grade INTEGER NOT NULL DEFAULT 0,
            jlpt INTEGER NOT NULL DEFAULT 0,
            freq_rank INTEGER NOT NULL DEFAULT 0,
            radical_id INTEGER NOT NULL DEFAULT 0,
            skip_code INTEGER NOT NULL DEFAULT 0,
            four_corner INTEGER NOT NULL DEFAULT 0,
            kyujitai_cp INTEGER NOT NULL DEFAULT 0,
            on_readings TEXT NOT NULL DEFAULT '',
            kun_readings TEXT NOT NULL DEFAULT '',
            meanings TEXT NOT NULL DEFAULT '',
            component_radicals TEXT NOT NULL DEFAULT '',
            strokes_blob BLOB
        );
        CREATE TABLE kanji_edges (
            src_cp INTEGER NOT NULL,
            dst_entry INTEGER NOT NULL,
            edge_kind INTEGER NOT NULL,
            weight INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (src_cp, dst_entry, edge_kind)
        );
        CREATE TABLE entry_kanji_refs (
            entry_id INTEGER NOT NULL,
            codepoint INTEGER NOT NULL,
            pos_idx INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE collocations (
            anchor_id INTEGER NOT NULL,
            partner_id INTEGER NOT NULL,
            relation TEXT NOT NULL DEFAULT '',
            pmi_score REAL NOT NULL DEFAULT 0,
            example_jp TEXT NOT NULL DEFAULT '',
            example_en TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE keigo_ladders (
            base_id INTEGER PRIMARY KEY,
            sonkeigo_id INTEGER,
            kenjougo_id INTEGER,
            teineigo_id INTEGER
        );
        INSERT INTO entries (id, kanji_head, kana_head, alt_forms, primary_gloss, pos_mask, pitch_accent, freq_rank, reading_romaji, english_tokens)
        VALUES
          (100, '食べる', 'たべる', '', 'to eat', 18, 2, 120, 'taberu', 'eat'),
          (101, '大学', 'だいがく', '', 'university; college', 1, 0, 200, 'daigaku', 'university college'),
          (102, '大きい', 'おおきい', '', 'big; large', 64, 3, 90, 'ookii', 'big large');
        INSERT INTO senses (entry_id, sense_idx, pos_mask, en_glosses, ja_glosses, tags)
        VALUES
          (100, 0, 18, 'to eat', '', 'Ichidan verb, transitive'),
          (101, 0, 1, 'university; college', '', 'Noun'),
          (102, 0, 64, 'big; large', '', 'i-adjective');
        INSERT INTO kanji (codepoint, glyph, strokes, grade, jlpt, freq_rank, radical_id, on_readings, kun_readings, meanings)
        VALUES
          (22823, '大', 3, 1, 5, 7, 37, 'ダイ,タイ', 'おお-,おお.きい', 'large, big'),
          (39135, '食', 9, 2, 5, 328, 184, 'ショク,ジキ', 'く.う,た.べる', 'eat, food');
        INSERT INTO kanji_edges (src_cp, dst_entry, edge_kind, weight)
        VALUES
          (22823, 101, 1, 500),
          (22823, 102, 1, 800),
          (39135, 100, 1, 900);
        INSERT INTO entry_kanji_refs (entry_id, codepoint, pos_idx)
        VALUES
          (100, 39135, 0),
          (101, 22823, 0),
          (102, 22823, 0);
        """

        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown sqlite error"
            sqlite3_free(errMsg)
            throw NSError(domain: "DaiJishowAppTests", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return (dbURL.path, true)
    }

    // MARK: - Bundle, Sandbox & Legal Metadata

    @Test("App bundle carries App Store metadata, sandbox entitlement, Privacy Manifest, and legal docs")
    func bundleComplianceAndSandbox() throws {
        let bundle = Bundle.main
        #expect(bundle.bundleIdentifier == "org.daijishow.mac")

        let shortVersion = try #require(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        #expect(shortVersion.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil)

        let buildVersion = try #require(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        #expect(buildVersion.range(of: #"^\d+$"#, options: .regularExpression) != nil)

        let usesNonExempt = bundle.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool
        #expect(usesNonExempt == false)

        let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        #expect(category == "public.app-category.education")

        // Verify the hosted app runs inside macOS App Sandbox.
        #expect(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil)

        let licenseURL = try #require(bundle.url(forResource: "LICENSE", withExtension: nil))
        let licenseText = try String(contentsOf: licenseURL, encoding: .utf8)
        #expect(licenseText.contains("MIT License"))

        let noticeURL = try #require(bundle.url(forResource: "NOTICE", withExtension: nil))
        let noticeText = try String(contentsOf: noticeURL, encoding: .utf8)
        #expect(noticeText.contains("JMdict"))
        #expect(noticeText.contains("KanjiVG"))
        #expect(noticeText.contains("Ulrich Apel"))
        #expect(noticeText.contains("Kanjium"))
        #expect(noticeText.contains("Tatoeba"))

        let privacyURL = try #require(bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let privacyData = try Data(contentsOf: privacyURL)
        #expect(!privacyData.isEmpty)
    }

    @Test("About credits match verified upstream licenses and attribution requirements")
    func creditsIntegrity() {
        let sources = DaiJishowCredits.sources
        #expect(sources.count == 6)
        for source in sources {
            #expect(!source.attribution.isEmpty)
            #expect(URL(string: source.url)?.scheme == "https")
            #expect(URL(string: source.licenseURL)?.scheme == "https")
        }

        let kanjivg = sources.first { $0.name.contains("KanjiVG") }
        #expect(kanjivg?.license == "CC BY-SA 3.0")
        #expect(kanjivg?.attribution.contains("Ulrich Apel") == true)

        let kanjium = sources.first { $0.name.contains("Kanjium") }
        #expect(kanjium?.license == "CC BY-SA 4.0")
        #expect(kanjium?.attribution.contains("Uros O.") == true)

        let jmnedict = sources.first { $0.name.contains("JMnedict") }
        #expect(jmnedict?.role.localizedCaseInsensitiveContains("proper names") == true)
    }

    // MARK: - EngineBridge + C++ Core + SwiftUI Smoke Tests

    @Test("Engine initializes, searches, navigates screens, and lays out SwiftUI views inside sandbox")
    func engineNavigationAndViewLayout() async throws {
        let keys = [
            "daijishow.recentKanji",
            "daijishow.lastScreen",
            "daijishow.lastTargetId",
            "daijishow.includeNames",
            "daijishow.appearanceMode",
        ]
        let saved = Self.snapshotDefaults(keys)
        defer { Self.restoreDefaults(saved) }

        let (dbPath, isTemp) = try Self.resolveOrCreateTestDatabase()
        defer {
            if isTemp {
                let dir = URL(fileURLWithPath: dbPath).deletingLastPathComponent()
                try? FileManager.default.removeItem(at: dir)
            }
        }

        let engine = DaiJishowEngine(dbPath: dbPath)
        #expect(engine.isReady == true)

        // Search debounce -> real C++ search execution
        engine.searchQuery = "食べる"
        engine.performSearch()
        try await Task.sleep(for: .milliseconds(250))

        #expect(!engine.searchResults.isEmpty)
        let firstHit = try #require(engine.searchResults.first)
        #expect(firstHit.displayHeadword.contains("食") || firstHit.kanaHead == "たべる")

        // Open Word Entry
        engine.openWordEntry(entryId: firstHit.id)
        #expect(engine.activeScreen == .wordEntry)
        #expect(engine.activeEntry?.header.id == firstHit.id)

        // Open Kanji Detail (食 U+98DF)
        engine.openKanjiDetail(codepoint: 0x98DF)
        #expect(engine.activeScreen == .kanjiDetail)
        #expect(engine.activeKanji?.codepoint == 0x98DF)

        // Open Fisheye (大 U+5927)
        engine.openFisheye(codepoint: 0x5927)
        #expect(engine.activeScreen == .fisheye)
        #expect(!engine.fisheyeNodes.isEmpty)

        // History back/forward
        #expect(engine.canGoBack == true)
        engine.goBack()
        #expect(engine.activeScreen == .kanjiDetail)
        engine.goForward()
        #expect(engine.activeScreen == .fisheye)

        // Verify JLPT level copy clarity, StudyStore inside sandbox, & TTS query safety
        #expect(DaiJishowEngine.jlptLevelDescription(1).contains("approximate KANJIDIC2 study band"))
        #expect(DaiJishowEngine.jlptLevelDescription(0).contains("Kana-only"))
        _ = SpeechEngine.shared.japaneseVoiceAvailable

        let sandboxStoreDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("daijishow-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: sandboxStoreDir) }
        let store = StudyStore(storageURL: sandboxStoreDir.appendingPathComponent("study.json"))
        #expect(store.decks.count == 1)

        // Instantiate and lay out SwiftUI views across screens and min/default window sizes
        let mainHost = NSHostingView(rootView: MainWorkspaceView(engine: engine))
        let screenTransitions: [() -> Void] = [
            { engine.openWordEntry(entryId: firstHit.id) },
            { engine.openKanjiDetail(codepoint: 0x98DF) },
            { engine.openFisheye(codepoint: 0x5927) },
            { engine.openWordCosmos() },
            { engine.openCompoundKanji(seedEntryId: firstHit.id) },
            { engine.openKanjiLookup() },
            { engine.openStudyLibrary() },
        ]
        for transition in screenTransitions {
            transition()
            mainHost.frame = NSRect(x: 0, y: 0, width: 820, height: 560)
            mainHost.layoutSubtreeIfNeeded()
            mainHost.frame = NSRect(x: 0, y: 0, width: 1320, height: 880)
            mainHost.layoutSubtreeIfNeeded()
        }

        for auxView in [
            AnyView(AboutView(engine: engine)),
            AnyView(SettingsView(engine: engine)),
            AnyView(HelpSheetView()),
        ] {
            let host = NSHostingView(rootView: auxView)
            host.frame = NSRect(x: 0, y: 0, width: 640, height: 520)
            host.layoutSubtreeIfNeeded()
        }
    }
}
