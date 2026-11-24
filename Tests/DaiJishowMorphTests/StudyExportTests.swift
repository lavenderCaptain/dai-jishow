import Testing
@testable import DaiJishowMorph

@Suite("Study export formatting (StudyExporter)")
struct StudyExportTests {

    @Test("Pitch formatting handles Heiban, Atamadaka, Nakadaka, and unknown 255")
    func pitchFormatting() {
        let heiban = StudySavedItem(kind: .word, targetId: 1, headword: "学校", reading: "がっこう", gloss: "school", pitchAccent: 0)
        let atamadaka = StudySavedItem(kind: .word, targetId: 2, headword: "猫", reading: "ねこ", gloss: "cat", pitchAccent: 1)
        let nakadaka = StudySavedItem(kind: .word, targetId: 3, headword: "食べる", reading: "たべる", gloss: "to eat", pitchAccent: 2)
        let unknown = StudySavedItem(kind: .word, targetId: 4, headword: "謎", reading: "なぞ", gloss: "mystery", pitchAccent: 255)

        #expect(heiban.formattedPitch == "Heiban [0]")
        #expect(atamadaka.formattedPitch == "Atamadaka [1]")
        #expect(nakadaka.formattedPitch == "[2]")
        #expect(unknown.formattedPitch == "")
    }

    @Test("Anki TSV strips tabs/newlines and includes Anki directives")
    func ankiTsvFormat() {
        let item = StudySavedItem(
            kind: .word,
            targetId: 100,
            headword: "勉強",
            reading: "べんきょう",
            gloss: "study;\tdiligence\nlearning",
            pitchAccent: 0,
            metadata: "N5 • Grade 3",
            exampleJp: "毎日日本語を勉強します。",
            exampleEn: "I study Japanese every day."
        )

        let out = StudyExporter.format(items: [item], format: .ankiTSV, includeHeader: true)
        let lines = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines.count == 4)
        #expect(lines[0] == "#separator:tab")
        #expect(lines[1] == "#html:false")
        #expect(lines[2].hasPrefix("#columns:Headword\tReading\tPitch"))
        #expect(lines[3] == "勉強\tべんきょう\tHeiban [0]\tstudy; diligence learning\tN5 • Grade 3\t毎日日本語を勉強します。\tI study Japanese every day.")
    }

    @Test("CSV properly quotes commas, double quotes, and newlines per RFC-4180")
    func csvQuoting() {
        let item = StudySavedItem(
            kind: .kanji,
            targetId: 0x5927,
            headword: "大",
            reading: "ダイ, タイ / おお.きい",
            gloss: "large, \"great\", big",
            pitchAccent: nil,
            metadata: "3 strokes • N5 • G1"
        )

        let out = StudyExporter.format(items: [item], format: .csv, includeHeader: true)
        let lines = out.split(separator: "\n").map(String.init)
        #expect(lines.count == 2)
        #expect(lines[0] == "Headword,Reading,Pitch,Meaning,Notes,Example JP,Example EN")
        #expect(lines[1] == "大,\"ダイ, タイ / おお.きい\",,\"large, \"\"great\"\", big\",3 strokes • N5 • G1,,")
    }
}
