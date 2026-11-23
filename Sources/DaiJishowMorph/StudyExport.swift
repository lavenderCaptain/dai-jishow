import Foundation

/// Kind of study item stored in a saved deck or exported flashcard row.
public enum StudyItemKind: String, Codable, Hashable, Sendable {
    case word
    case kanji
}

/// A portable, Codable flashcard / bookmark record for a Japanese word or kanji.
public struct StudySavedItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let kind: StudyItemKind
    public let targetId: UInt32
    public let headword: String
    public let reading: String
    public let gloss: String
    public let pitchAccent: UInt8?
    public let metadata: String
    public let exampleJp: String
    public let exampleEn: String
    public let addedAt: Date

    public init(
        kind: StudyItemKind,
        targetId: UInt32,
        headword: String,
        reading: String,
        gloss: String,
        pitchAccent: UInt8? = nil,
        metadata: String = "",
        exampleJp: String = "",
        exampleEn: String = "",
        addedAt: Date = Date()
    ) {
        self.id = "\(kind.rawValue):\(targetId)"
        self.kind = kind
        self.targetId = targetId
        self.headword = headword
        self.reading = reading
        self.gloss = gloss
        self.pitchAccent = pitchAccent
        self.metadata = metadata
        self.exampleJp = exampleJp
        self.exampleEn = exampleEn
        self.addedAt = addedAt
    }

    /// Human-readable pitch label (e.g. "Heiban [0]", "Atamadaka [1]", "[2]"), or "".
    public var formattedPitch: String {
        guard let pitch = pitchAccent, pitch < 255 else { return "" }
        if pitch == 0 { return "Heiban [0]" }
        if pitch == 1 { return "Atamadaka [1]" }
        return "[\(pitch)]"
    }
}

/// User-curated study deck (e.g. "Favorites" or a custom topic/JLPT list).
public struct StudyDeck: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public let isDefault: Bool
    public let createdAt: Date
    public var items: [StudySavedItem]

    public init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        items: [StudySavedItem] = []
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.items = items
    }
}

/// Supported flashcard export formats.
public enum AnkiExportFormat: String, CaseIterable, Identifiable, Sendable {
    case ankiTSV = "Anki TSV (.tsv)"
    case csv = "CSV (.csv)"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .ankiTSV: return "tsv"
        case .csv: return "csv"
        }
    }
}

/// Pure, unit-tested serializer for Anki TSV and RFC-4180 CSV flashcard exports.
public enum StudyExporter {
    public static let columns = [
        "Headword",
        "Reading",
        "Pitch",
        "Meaning",
        "Notes",
        "Example JP",
        "Example EN"
    ]

    public static func format(
        items: [StudySavedItem],
        format: AnkiExportFormat,
        includeHeader: Bool = true
    ) -> String {
        switch format {
        case .ankiTSV:
            var lines: [String] = []
            if includeHeader {
                lines.append("#separator:tab")
                lines.append("#html:false")
                lines.append("#columns:\(columns.joined(separator: "\t"))")
            }
            for item in items {
                let fields = rowFields(for: item).map(sanitizeTSVField)
                lines.append(fields.joined(separator: "\t"))
            }
            return lines.joined(separator: "\n")

        case .csv:
            var lines: [String] = []
            if includeHeader {
                lines.append(columns.map(escapeCSVField).joined(separator: ","))
            }
            for item in items {
                let fields = rowFields(for: item).map(escapeCSVField)
                lines.append(fields.joined(separator: ","))
            }
            return lines.joined(separator: "\n")
        }
    }

    public static func rowFields(for item: StudySavedItem) -> [String] {
        [
            item.headword,
            item.reading,
            item.formattedPitch,
            item.gloss,
            item.metadata,
            item.exampleJp,
            item.exampleEn
        ]
    }

    public static func sanitizeTSVField(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func escapeCSVField(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsQuotes = trimmed.contains(",") || trimmed.contains("\"") || trimmed.contains("\n") || trimmed.contains("\r")
        if !needsQuotes {
            return trimmed
        }
        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
