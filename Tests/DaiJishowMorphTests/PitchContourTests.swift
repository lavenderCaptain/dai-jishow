// PitchContourTests — regression coverage for PitchAccentContour.build(...) and
// the KanaNormalizer mora splitter that feeds it.
//
// WHY THESE EXIST
// ---------------
// rc7 gated the trailing が particle on nouns only (a verb/adjective "taberu-ga" /
// "takai-ga" reads ungrammatically). The struct carries `showParticle`; the
// noun-vs-verb decision lives in the view layer (GlassViews.pitchContour, on
// posMask bit0). These tests lock (a) the four contour shapes and their particle
// pitch, and (b) that build() faithfully preserves the showParticle flag the
// caller decides on.
//
// pitchAccent is the downstep position k: 0 = heiban, 1 = atamadaka,
// 1 < k < n = nakadaka, k >= n = odaka; 255 = "no data" → nil.

import Testing
@testable import DaiJishowMorph

@Suite("Pitch-accent contour (PitchAccentContour.build)")
struct PitchContourTests {

    // "たべる" is 3 morae: [た, べ, る].

    @Test("Heiban [0]: L-H-H with a HIGH particle")
    func heiban() {
        let c = PitchAccentContour.build(kana: "たべる", pitchAccent: 0, showParticle: true)
        #expect(c != nil)
        #expect(c?.patternName == "平板 [0]")
        #expect(c?.patternSublabel == "Heiban (Flat)")
        #expect(c?.morae == ["た", "べ", "る"])
        #expect(c?.highStates == [false, true, true])
        #expect(c?.particleHigh == true)
    }

    @Test("Atamadaka [1]: H-L-L with a LOW particle")
    func atamadaka() {
        let c = PitchAccentContour.build(kana: "たべる", pitchAccent: 1)
        #expect(c?.patternName == "頭高 [1]")
        #expect(c?.highStates == [true, false, false])
        #expect(c?.particleHigh == false)
    }

    @Test("Nakadaka [2] on a 3-mora word: L-H-L with a LOW particle")
    func nakadaka() {
        let c = PitchAccentContour.build(kana: "たべる", pitchAccent: 2)
        #expect(c?.patternName == "中高 [2]")
        #expect(c?.highStates == [false, true, false])
        #expect(c?.particleHigh == false)
    }

    @Test("Odaka [k >= n]: L-H-H with a LOW particle")
    func odaka() {
        // k (3) == n (3): every mora after the first is high.
        let c = PitchAccentContour.build(kana: "たべる", pitchAccent: 3)
        #expect(c?.patternName == "尾高 [3]")
        #expect(c?.highStates == [false, true, true])
        #expect(c?.particleHigh == false)
    }

    @Test("No pitch data (255) → nil")
    func noData() {
        #expect(PitchAccentContour.build(kana: "たべる", pitchAccent: 255) == nil)
    }

    @Test("Empty reading → nil")
    func empty() {
        #expect(PitchAccentContour.build(kana: "", pitchAccent: 0) == nil)
    }

    // The rc7 gate: build() does not decide noun-vs-verb (that is the view layer,
    // on posMask bit0); it faithfully preserves whatever showParticle the caller
    // passes. A noun keeps the が node; a conjugated verb/adjective drops it.
    @Test("showParticle is preserved through build (noun keeps が, verb drops it)")
    func showParticleGate() {
        #expect(PitchAccentContour.build(kana: "ねこ", pitchAccent: 0, showParticle: true)?.showParticle == true)
        #expect(PitchAccentContour.build(kana: "たべる", pitchAccent: 0, showParticle: false)?.showParticle == false)
    }
}

@Suite("Mora splitting (KanaNormalizer.splitMorae)")
struct KanaNormalizerTests {

    @Test("Plain kana splits into one mora per syllable")
    func plain() {
        #expect(KanaNormalizer.splitMorae("にほん") == ["に", "ほ", "ん"])
    }

    @Test("Combining (small) kana fold onto the preceding mora")
    func combining() {
        // しゃ = し + ぁ (combining), so the two codepoints are one mora.
        #expect(KanaNormalizer.splitMorae("しゃしん") == ["しゃ", "し", "ん"])
    }

    @Test("Whitespace is trimmed before splitting")
    func trimmed() {
        #expect(KanaNormalizer.splitMorae(" たべ ") == ["た", "べ"])
    }
}
