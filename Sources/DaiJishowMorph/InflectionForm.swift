// InflectionForm — one row in the conjugation matrix shown in the word cockpit.
//
// WHY THIS MODULE EXISTS
// ---------------------
// Moved out of `DaiJishowMac`'s `EngineBridge.swift` into the `DaiJishowMorph`
// library so `Morph.inflections` (the conjugation generator) can *return* it and
// the generator can be unit-tested. A `@testable` import cannot reach into an
// executable target, so the value the tested function produces must itself live in
// a library module.
//
// The type is unchanged from the app — same fields, same `Identifiable` conformance
// (the cockpit's `ForEach` keys on `id`). It is now `public` so the executable's
// views can bind to it across the module boundary.

public struct InflectionForm: Identifiable, Equatable {
    /// Stable row key for SwiftUI `ForEach` (e.g. "pol", "neg", "past", "te",
    /// "pot", "pas" for verbs; "na", "adv" for adjectives).
    public let id: String
    /// Human label, e.g. "Polite", "Negative", "Te-form", "Adjectival".
    public let label: String
    /// The conjugated surface as shown to the user (kanji + okurigana where the
    /// headword carries kanji).
    public let surface: String
    /// The all-kana rendering of the same form, used for pitch / reading display.
    public let kana: String

    public init(id: String, label: String, surface: String, kana: String) {
        self.id = id
        self.label = label
        self.surface = surface
        self.kana = kana
    }
}
