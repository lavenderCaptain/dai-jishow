// PitchAccentContour — the mora-by-mora Tokyo pitch-accent diagram.
//
// WHY THIS MODULE EXISTS
// ---------------------
// Moved out of `DaiJishowMac`'s `EngineBridge.swift` into the `DaiJishowMorph`
// library because its `build` factory is the pitch-accent logic we most want to
// lock down with regression tests (the trailing が gating landed in rc7). It is
// `public` so `DaiJishowMac`'s `PitchAccentContourView` can render it across the
// module boundary.
//
// `build` is a pure function of (kana, pitchAccent, showParticle): no engine, no
// state. That is why it is testable and why it belongs here rather than on the
// `@MainActor` engine.

public struct PitchAccentContour: Equatable {
    /// The downstep position `k` as stored in the corpus (0 = heiban, 1 =
    /// atamadaka, k≥n = odaka, 1<k<n = nakadaka). 255 is the "no data" sentinel
    /// and is handled by `build` returning nil.
    public let downstep: UInt8
    /// The mora units the contour is laid over (from `KanaNormalizer.splitMorae`).
    public let morae: [String]
    /// Per-mora high/low flags; length == morae.count.
    public let highStates: [Bool]
    /// Pitch of the trailing particle (e.g. が) — high or low relative to the word.
    public let particleHigh: Bool
    /// Render the trailing が node at all. TRUE for nouns only: a trailing が reads
    /// ungrammatically after a conjugated verb/adjective (e.g. 食べが, 高が), so the
    /// caller passes this on the strength of the noun POS bit and the view honors it.
    public let showParticle: Bool
    /// Display name, e.g. "頭高 [1]", "平板 [0]", "中高 [2]", "尾高 [3]".
    public let patternName: String
    /// Latin sublabel, e.g. "Atamadaka", "Heiban", "Nakadaka", "Odaka".
    public let patternSublabel: String

    /// Memberwise initializer, `public` so the executable can construct contours
    /// (e.g. a snapshot) and the `build` factory above can too. A public struct's
    /// synthesized initializer is internal by default, so it must be redeclared
    /// `public` to be reachable across the module boundary.
    public init(
        downstep: UInt8,
        morae: [String],
        highStates: [Bool],
        particleHigh: Bool,
        showParticle: Bool,
        patternName: String,
        patternSublabel: String
    ) {
        self.downstep = downstep
        self.morae = morae
        self.highStates = highStates
        self.particleHigh = particleHigh
        self.showParticle = showParticle
        self.patternName = patternName
        self.patternSublabel = patternSublabel
    }

    /// Build a contour from a reading + its pitch-accent number.
    ///
    /// - Parameters:
    ///   - kana: the kana reading (e.g. "たべる").
    ///   - pitchAccent: the downstep position; 255 means "no data" → returns nil.
    ///   - showParticle: render the trailing が node. Pass true only for nouns.
    /// - Returns: the computed contour, or nil when there is no data to draw.
    public static func build(kana: String, pitchAccent: UInt8, showParticle: Bool = false) -> PitchAccentContour? {
        guard pitchAccent != 255 else { return nil }
        let morae = KanaNormalizer.splitMorae(kana)
        guard !morae.isEmpty else { return nil }

        let n = morae.count
        let k = Int(pitchAccent)
        var highs = [Bool](repeating: false, count: n)
        let particleHigh: Bool
        let name: String
        let sublabel: String

        if k == 0 {
            // Heiban (平板): L-H-H...H, and the particle stays high (H-H).
            for i in 1..<n { highs[i] = true }
            particleHigh = true
            name = "平板 [0]"
            sublabel = "Heiban (Flat)"
        } else if k == 1 {
            // Atamadaka (頭高): H-L-L...L, particle low.
            highs[0] = true
            particleHigh = false
            name = "頭高 [1]"
            sublabel = "Atamadaka (Initial Drop)"
        } else if k >= n {
            // Odaka (尾高): L-H-H...H through the last mora, particle low.
            for i in 1..<n { highs[i] = true }
            particleHigh = false
            name = "尾高 [\(k)]"
            sublabel = "Odaka (Tail Drop)"
        } else {
            // Nakadaka (中高): L-H...H (up to k) then L...L, particle low.
            for i in 1..<min(k, n) { highs[i] = true }
            particleHigh = false
            name = "中高 [\(k)]"
            sublabel = "Nakadaka (Mid Drop)"
        }

        return PitchAccentContour(
            downstep: pitchAccent,
            morae: morae,
            highStates: highs,
            particleHigh: particleHigh,
            showParticle: showParticle,
            patternName: name,
            patternSublabel: sublabel
        )
    }
}
