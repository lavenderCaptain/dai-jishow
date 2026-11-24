// SenseTagsTests — regression coverage for Morph.senseTags(...).
//
// WHY THESE EXIST
// ---------------
// rc7 replaced the old "does the English gloss start with 'to '?" part-of-speech
// heuristic with the corpus posMask (POS_BITS). That heuristic mis-labeled nouns
// whose gloss happened to begin with "to " as verbs, and never saw na-adjectives.
// These tests lock the new POS-driven verdict so the heuristic cannot creep back.
//
// posMask encoding (POS_BITS in build_corpus.py): bit0=n, bits1–5=v1/v5/vs/vt/vi,
// bit6=adj-i, bit7=adj-na, bit8=adv, bit10=prt. See the top of Morph.swift.

import Testing
@testable import DaiJishowMorph

@Suite("Part-of-speech / grammatical tags (Morph.senseTags)")
struct SenseTagsTests {

    // MARK: Adjectives

    @Test("Na-Adj: bit 7 → 'Na-Adj'")
    func naAdj() {
        let tags = Morph.senseTags(kana: "しずか", posMask: 1 << 7, glosses: "quiet; calm")
        #expect(tags == ["Na-Adj"])
    }

    @Test("i-Adj: bit 6 → 'i-Adj'")
    func iAdj() {
        let tags = Morph.senseTags(kana: "たかい", posMask: 1 << 6, glosses: "high; tall; expensive")
        #expect(tags == ["i-Adj"])
    }

    // MARK: Verbs — transitive vs intransitive, and the class (godan / ichidan / suru)

    @Test("Transitive godan 書く: bits 2+4 → Transitive • 他動詞 + Godan")
    func transitiveGodan() {
        let tags = Morph.senseTags(kana: "かく", posMask: (1 << 2) | (1 << 4), glosses: "to write; to draw")
        #expect(tags == ["Transitive • 他動詞", "Godan Verb"])
    }

    @Test("Intransitive godan 来る: bit 5 → Intransitive • 自動詞 + Godan")
    func intransitiveGodan() {
        let tags = Morph.senseTags(kana: "くる", posMask: 1 << 5, glosses: "to come; to arrive")
        #expect(tags == ["Intransitive • 自動詞", "Godan Verb"])
    }

    @Test("Transitive ichidan 食べる: bits 1+4 → Transitive • 他動詞 + Ichidan")
    func transitiveIchidan() {
        let tags = Morph.senseTags(kana: "たべる", posMask: (1 << 1) | (1 << 4), glosses: "to eat")
        #expect(tags == ["Transitive • 他動詞", "Ichidan Verb"])
    }

    @Test("Suru 勉強する: bit 3 + '…する' → 'Suru Verb' (no Godan/Ichidan suffix)")
    func suru() {
        // A suru-verb is tagged 'Suru Verb' and nothing else from the verb-class branch.
        let tags = Morph.senseTags(kana: "べんきょうする", posMask: 1 << 3, glosses: "to study")
        #expect(tags == ["Suru Verb"])
    }

    // MARK: Nouns

    @Test("Noun 猫: bit 0 only → 'Noun / Expr.'")
    func noun() {
        let tags = Morph.senseTags(kana: "ねこ", posMask: 1, glosses: "cat")
        #expect(tags == ["Noun / Expr."])
    }

    // The headline rc7 regression: a noun whose English gloss begins with "to " must
    // NOT be mis-read as a verb. The corpus mask wins over gloss sniffing.
    @Test("Noun with a 'to ' gloss is NOT mis-tagged as a verb (POS-driven, not gloss-sniff)")
    func nounWithToGloss() {
        let tags = Morph.senseTags(kana: "て", posMask: 1, glosses: "to hand over; to give")
        #expect(tags.contains("Noun / Expr."))
        #expect(tags.contains(where: { $0.contains("Verb") }) == false,
                "a noun with a 'to ' gloss must not gain a verb tag")
    }

    // MARK: Prefix / Suffix markers come from gloss punctuation, not the mask.

    @Test("Gloss punctuation: '-' prefix marks a suffix; trailing '-' a prefix")
    func prefixSuffixMarkers() {
        // A token beginning with "-" marks a suffix; a token ending with "-" a prefix.
        let suffix = Morph.senseTags(kana: "し", posMask: 1, glosses: "-ness; suffix")
        #expect(suffix.contains("Suffix"))

        let prefix = Morph.senseTags(kana: "しょ", posMask: 1, glosses: "un-; prefix")
        #expect(prefix.contains("Prefix"))
    }

    // MARK: Register & specialized POS bits

    @Test("Standalone adverb / particle / onomatopoeia senseTags")
    func specializedPrimaryTags() {
        #expect(Morph.senseTags(kana: "とても", posMask: 1 << 8, glosses: "very") == ["Adverb"])
        #expect(Morph.senseTags(kana: "から", posMask: 1 << 10, glosses: "from") == ["Particle"])
        #expect(Morph.senseTags(kana: "きらきら", posMask: 1 << 13, glosses: "glittering") == ["Onomatopoeia"])
        #expect(Morph.senseTags(kana: "いちじく", posMask: 1 << 11, glosses: "four chars") == ["Yojijukugo"])
        #expect(Morph.senseTags(kana: "ねこにこばん", posMask: 1 << 21, glosses: "pearls before swine") == ["Proverb"])
    }

    @Test("registerTags extracts keigo, colloquial, slang, dialect, and idiom badges")
    func registerTagsExtraction() {
        let keigoMask: UInt64 = (1 << 14) | (1 << 16) | (1 << 17)
        let keigo = Morph.registerTags(posMask: keigoMask)
        #expect(keigo.contains("Honorific • 尊敬語"))
        #expect(keigo.contains("Polite • 丁寧語"))
        #expect(keigo.contains("Colloquial"))

        let idiomMask: UInt64 = (1 << 12) | (1 << 13) | (1 << 20)
        let idioms = Morph.registerTags(posMask: idiomMask)
        #expect(idioms.contains("Idiom • 慣用句"))
        #expect(idioms.contains("Onomatopoeia"))
        #expect(idioms.contains("Kansai-ben"))
    }
}
