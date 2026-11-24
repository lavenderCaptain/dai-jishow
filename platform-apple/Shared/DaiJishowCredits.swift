import Foundation

// MARK: - Upstream Data Sources & Licenses
//
// Single source of truth for the upstream corpus attributions shared across
// macOS, iOS/iPadOS, and watchOS. Mirrors tools/corpus-builder/fetch_sources.py
// and root NOTICE.
//
// Verified upstream licenses:
//   • EDRG JMdict_e / JMnedict ....... CC BY-SA 4.0 (James William Breen & EDRG)
//   • EDRG KANJIDIC2 .................. CC BY-SA 4.0 (James William Breen & EDRG)
//   • KanjiVG stroke vectors .......... CC BY-SA 3.0 (Ulrich Apel)
//   • mifunetoshiro/kanjium accents ... CC BY-SA 4.0 (Uros O.)
//   • Tatoeba sentences/links ......... CC BY 2.0 (Tatoeba Project)

struct DataCredit: Identifiable {
    let name: String
    let attribution: String
    let role: String
    let license: String
    let licenseURL: String
    let url: String

    var id: String { name }
}

enum DaiJishowCredits {
    static let sources: [DataCredit] = [
        DataCredit(
            name: "JMdict_e (EDRG)",
            attribution: "James William Breen & Electronic Dictionary Research and Development Group",
            role: "Japanese–English word & phrase definitions (compiled into SQLite)",
            license: "CC BY-SA 4.0",
            licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/",
            url: "https://www.edrdg.org/edrdg/licence.html"
        ),
        DataCredit(
            name: "JMnedict / ENAMDICT (EDRG)",
            attribution: "James William Breen & Electronic Dictionary Research and Development Group",
            role: "Japanese proper names, places & organizations (compiled into SQLite)",
            license: "CC BY-SA 4.0",
            licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/",
            url: "https://www.edrdg.org/edrdg/licence.html"
        ),
        DataCredit(
            name: "KANJIDIC2 (EDRG)",
            attribution: "James William Breen & Electronic Dictionary Research and Development Group",
            role: "Kanji readings, meanings, radicals & stroke counts (compiled into SQLite)",
            license: "CC BY-SA 4.0",
            licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/",
            url: "https://www.edrdg.org/edrdg/licence.html"
        ),
        DataCredit(
            name: "KanjiVG",
            attribution: "Copyright © 2009–2013 Ulrich Apel",
            role: "Stroke-order vector diagrams & component radicals (quantized into SQLite)",
            license: "CC BY-SA 3.0",
            licenseURL: "https://creativecommons.org/licenses/by-sa/3.0/",
            url: "https://kanjivg.tagaini.net"
        ),
        DataCredit(
            name: "Kanjium Accents",
            attribution: "Pitch-accent notation provided by Uros O. (Kanjium)",
            role: "Tokyo pitch-accent downstep positions (mapped onto entries)",
            license: "CC BY-SA 4.0",
            licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/",
            url: "https://github.com/mifunetoshiro/kanjium"
        ),
        DataCredit(
            name: "Tatoeba",
            attribution: "Tatoeba Project & Contributors",
            role: "Real-world example sentences (80,000 JP–EN pairs subset)",
            license: "CC BY 2.0",
            licenseURL: "https://creativecommons.org/licenses/by/2.0/",
            url: "https://tatoeba.org"
        ),
    ]
}

// MARK: - Offline Corpus Locator

enum DatabaseLocator {
    static func locateDatabasePath() -> String {
        if let bundlePath = Bundle.main.path(forResource: "daijishow", ofType: "db") {
            return bundlePath
        }
        let candidates = [
            "daijishow.db",
            "build/daijishow.db",
            "../data/daijishow.db",
            "../../data/daijishow.db"
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return "daijishow.db"
    }
}
