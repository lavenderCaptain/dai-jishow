// ConjugationTests — regression coverage for Morph.inflections(...).
//
// WHY THESE EXIST
// ---------------
// The conjugation matrix is the highest-visibility logic in the app: a wrong
// form is garbage Japanese on screen. These tests lock the behavior that shipped
// in rc7 (na-adjectives, the irregular 来る/くる / ある / いる verbs, plus the
// godan / ichidan / suru / i-ku / i-adjective tables) so a future edit that
// regresses a form fails `swift test` before a DMG can be built.
//
// FRAMEWORK: Swift Testing (`@Suite` / `@Test` / `#expect`) — the chosen framework
// for all unit / backend / integration logic. XCTest is reserved for UI automation
// (see the build pipeline). `@testable import DaiJishowMorph` reaches the public
// Morph API; the library is dependency-free, so the tests are fast and deterministic.
//
// FIXTURES: each case builds a (surface, kana, posMask) by hand rather than
// querying the corpus, so the tests are hermetic — no ~221 MB DB, no engine.
// posMask uses the POS_BITS encoding (bit0=n, bits1–5=v1/v5/vs/vt/vi, bit6=adj-i,
// bit7=adj-na); see the top of Morph.swift and build_corpus.py.

import Testing
@testable import DaiJishowMorph

@Suite("Conjugation matrix (Morph.inflections)")
struct ConjugationTests {

    // MARK: Na-adjectives (keiyogo), corpus bit 7
    // The surface itself is the stem: 静か → 静かな / 静かに / 静かだった / 静かではない.

    @Test("Na-Adj 静か → 静かな / 静かに / 静かだった / 静かではない")
    func naAdjective() {
        let (forms, header) = Morph.inflections(surface: "静か", kana: "しずか", posMask: 1 << 7)
        #expect(header == "Na-Adjective Inflections")
        #expect(forms.map { $0.surface } == [
            "静かな", "静かに", "静かだった", "静かではない"
        ])
        #expect(forms.map { $0.kana } == [
            "しずかな", "しずかに", "しずかだった", "しずかではない"
        ])
    }

    // MARK: Irregular verbs — the rc7 headline fix. These look ichidan but are not.

    @Test("Irregular 来る → 来ます / 来ない / 来た / 来て (NOT 来れる / 来ます-from-く)")
    func kuru() {
        let (forms, header) = Morph.inflections(surface: "来る", kana: "くる", posMask: 1 << 5)
        #expect(header == "Irregular Verb (来る / くる)")
        #expect(forms.map { $0.surface } == [
            "来ます", "来ない", "来た", "来て", "来られる", "来られる"
        ])
        // The negative must be 来ない (the irregular stem), not the ichidan 来ない-lookalike
        // 来ない from 来る→来 + ない, and the te-form is 来て not 来たり 来て.
        #expect(forms.first { $0.id == "neg" }?.surface == "来ない")
        #expect(forms.first { $0.id == "te" }?.surface == "来て")
        #expect(forms.first { $0.id == "pot" }?.surface == "来られる")
    }

    @Test("Irregular ある → あります / ない / あった / あって (NOT あらない)")
    func aru() {
        let (forms, header) = Morph.inflections(surface: "ある", kana: "ある", posMask: 36)
        #expect(header == "Irregular Verb (ある)")
        #expect(forms.map { $0.surface } == [
            "あります", "ない", "あった", "あって", "あれる", "あられる"
        ])
        // The regression we care about: the negative is ない, NOT the godan-looking あらない.
        #expect(forms.first { $0.id == "neg" }?.surface == "ない")
    }

    @Test("Irregular いる → います / いない / いた / いて (NOT いらない)")
    func iru() {
        let (forms, header) = Morph.inflections(surface: "いる", kana: "いる", posMask: 36)
        #expect(header == "Irregular Verb (いる)")
        #expect(forms.map { $0.surface } == [
            "います", "いない", "いた", "いて", "いられる", "いられる"
        ])
        #expect(forms.first { $0.id == "neg" }?.surface == "いない")
    }

    // MARK: Regular verb tables

    @Test("Godan 書く → 書きます / 書かない / 書いた / 書いて / 書ける / 書かれる")
    func godan() {
        // 書く is a transitive godan verb: bit2 (v5) + bit4 (vt) = 20.
        let (forms, header) = Morph.inflections(surface: "書く", kana: "かく", posMask: (1 << 2) | (1 << 4))
        #expect(header == "Godan Verb Inflections")
        #expect(forms.map { $0.surface } == [
            "書きます", "書かない", "書いた", "書いて", "書ける", "書かれる"
        ])
    }

    @Test("Ichidan 食べる → 食べます / 食べない / 食べた / 食べて / 食べられる")
    func ichidan() {
        // 食べる is a transitive ichidan verb: bit1 (v1) + bit4 (vt) = 18.
        let (forms, header) = Morph.inflections(surface: "食べる", kana: "たべる", posMask: 18)
        #expect(header == "Ichidan Verb Inflections")
        #expect(forms.map { $0.surface } == [
            "食べます", "食べない", "食べた", "食べて", "食べられる", "食べられる"
        ])
    }

    @Test("Suru 勉強する → 勉強します / 勉強しない / 勉強した / 勉強して / 勉強できる")
    func suru() {
        // 勉強する is a suru-verb: bit3 (vs) = 8.
        let (forms, header) = Morph.inflections(surface: "勉強する", kana: "べんきょうする", posMask: 1 << 3)
        #expect(header == "Suru Verb Inflections")
        #expect(forms.map { $0.surface } == [
            "勉強します", "勉強しない", "勉強した", "勉強して", "勉強できる", "勉強される"
        ])
    }

    @Test("Godan 行く te-form = 行って / 行った (the 行く/ゆく irregular, NOT いく)")
    func iku() {
        let forms = Morph.inflections(surface: "行く", kana: "いく", posMask: 1 << 2).0
        // 行く/ゆく are the one godan verb with an irregular te/ta: って / った.
        #expect(forms.first { $0.id == "te" }?.surface == "行って")
        #expect(forms.first { $0.id == "past" }?.surface == "行った")
    }

    // MARK: i-Adjectives (い), corpus bit 6

    @Test("i-Adj 高い → 高く / 高くない / 高かった / 高くて")
    func iAdjective() {
        let (forms, header) = Morph.inflections(surface: "高い", kana: "たかい", posMask: 1 << 6)
        #expect(header == "i-Adjective Inflections")
        #expect(forms.map { $0.surface } == ["高く", "高くない", "高かった", "高くて"])
    }

    // MARK: Guards — non-inflecting / too-short inputs conjugate to nothing.

    @Test("Noun (猫) conjugates to nothing")
    func nounConjugatesToNothing() {
        // posMask bit0 (noun) only: no verb/adj bits, and mask != 0 so the legacy
        // i-adj kana fallback does not fire. Result: empty matrix, nil header.
        let (forms, header) = Morph.inflections(surface: "猫", kana: "ねこ", posMask: 1)
        #expect(forms.isEmpty)
        #expect(header == nil)
    }

    @Test("Headword shorter than 2 kana conjugates to nothing")
    func tooShort() {
        // The guard `surface.count >= 2, kana.count >= 2` short-circuits even
        // when a verb bit is set.
        let (forms, header) = Morph.inflections(surface: "い", kana: "い", posMask: 1 << 5)
        #expect(forms.isEmpty)
        #expect(header == nil)
    }
}
