// SpeechEngine.swift — a single shared Japanese (ja-JP) text-to-speech voice.
//
// The app already renders the kana reading of every headword and the full
// Japanese text of every example sentence, so a "hear it" button is the natural
// next step. AVSpeechSynthesizer is kept as ONE app-wide instance so that
// tapping the speaker on different words/sentences *cancels* the in-flight
// utterance instead of letting audio overlap.
//
// Two deliberate design choices:
//   * Japanese is a *downloadable* system voice on macOS, so the engine reports
//     whether a ja-JP voice is installed (`japaneseVoiceAvailable`) and callers
//     disable the button — with an install hint — when it isn't, rather than
//     silently doing nothing.
//   * Audio is strictly user-initiated: nothing is spoken unless a button is
//     tapped. The mora-by-mora PitchAccentContour is a *display/learning* asset;
//     AVSpeechSynthesizer does not expose per-mora pitch-accent control, so the
//     voice speaks with its own accent — the speaker is "hear the standard
//     reading", not a re-rendering of the diagram's downstep.
//
// Why an ObservableObject: `AVSpeechSynthesisVoice.speechVoices()` can return an
// EMPTY list at the instant the UI first renders (AVFoundation hasn't finished
// enumerating voices in the app process yet). If the enabled/disabled state is a
// plain computed value, the buttons lock into a greyed-out state that never
// refreshes even after voices appear. We therefore warm up asynchronously and
// *publish* the flag, so the speaker buttons enable the moment a voice is found.

import AVFoundation
import Combine
import SwiftUI

// MARK: - Shared engine

/// One app-wide ja-JP voice. A tap cancels the current utterance and starts a
/// new one, so mashing the button never leaves audio overlapping.
final class SpeechEngine: ObservableObject {
    static let shared = SpeechEngine()

    /// Whether a Japanese (ja-JP) system voice is installed and usable. Starts
    /// `false` and flips `true` once the voice list is ready, so buttons that
    /// first rendered "no voice" still enable when the voice appears.
    @Published private(set) var japaneseVoiceAvailable = false

    /// The single synthesizer, created lazily on the first tap so we don't open
    /// the audio subsystem until the user actually asks to hear something.
    private var synthesizer: AVSpeechSynthesizer?

    /// The selected ja-JP voice, cached once resolved (a premium voice if the
    /// user has one, otherwise the first available).
    private var cachedVoice: AVSpeechSynthesisVoice?

    private var warmUpTimers: [Timer] = []

    private init() {
        scheduleWarmUp()
    }

    // MARK: Warm-up

    private func scheduleWarmUp() {
        checkVoices(retriesLeft: 12)
    }

    /// `AVSpeechSynthesisVoice.speechVoices()` may be empty the instant the UI
    /// first renders. Poll briefly so `japaneseVoiceAvailable` can flip to
    /// `true` and the buttons enable; stop polling the moment a voice is found.
    private func checkVoices(retriesLeft: Int) {
        let available = hasJapaneseVoice()
        DispatchQueue.main.async { [weak self] in
            self?.japaneseVoiceAvailable = available
        }
        if !available && retriesLeft > 0 {
            let timer = Timer(timeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.checkVoices(retriesLeft: retriesLeft - 1)
            }
            RunLoop.main.add(timer, forMode: .common)
            warmUpTimers.append(timer)
        }
    }

    /// True when at least one Japanese (ja-JP) system voice is installed.
    private func hasJapaneseVoice() -> Bool {
        AVSpeechSynthesisVoice.speechVoices()
            .contains { $0.language.hasPrefix("ja") }
    }

    // MARK: Voice

    /// The voice to speak with, or nil when no ja voice is installed. Prefers a
    /// premium-quality voice when the user has one, else the first Japanese voice.
    private func resolveVoice() -> AVSpeechSynthesisVoice? {
        if let cached = cachedVoice { return cached }
        let ja = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ja") }
        cachedVoice = ja.first(where: { $0.quality == .premium }) ?? ja.first
        return cachedVoice
    }

    // MARK: Speaking

    /// Speak `text` with the ja-JP voice, cancelling any in-flight utterance so
    /// rapid taps never overlap. A no-op for empty text or when no Japanese voice
    /// is installed — callers disable the button in that case, so this guard is a
    /// safety net, not the main path.
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let voice = resolveVoice() else { return }

        if synthesizer == nil {
            synthesizer = AVSpeechSynthesizer()
        }
        let synth = synthesizer!

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice
        // The utterance inherits its language from the voice (ja-JP, resolved
        // above); AVSpeechUtterance has no separate language field.
        // A touch slower than the default rate — easier for learners to follow.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9

        synth.stopSpeaking(at: .immediate)
        synth.speak(utterance)
    }

    /// Stop any in-flight speech (e.g. when the user navigates away).
    func stop() {
        synthesizer?.stopSpeaking(at: .immediate)
    }
}

// MARK: - Speaker button

/// A "hear it" control. Renders as a full capsule beside the headword
/// (`.headword`) or a compact icon in the dense sentence rows (`.compact`).
///
/// It observes the shared engine, so it enables the instant a Japanese voice is
/// found — even if voices weren't ready at first render. When none is installed
/// the button is disabled and its tooltip points the user to *System Settings ▸
/// Speech ▸ System Voice* to install one.
struct SpeakerButton: View {
    /// Observes the shared engine so this button's enabled/disabled state
    /// refreshes when a voice appears.
    @ObservedObject private var engine: SpeechEngine = .shared

    /// The text to speak — the kana headword for `.headword`, or the full
    /// Japanese sentence for a row. Whitespace-trimmed before synthesis.
    let text: String
    /// How the button renders.
    var variant: Variant = .compact
    /// Optional extra tooltip shown when a voice *is* available.
    var extraHelp: String? = nil

    enum Variant {
        case headword
        case compact
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var helpText: String {
        if engine.japaneseVoiceAvailable {
            return extraHelp ?? "Hear this read aloud in Japanese (ja-JP)."
        }
        return "No Japanese voice installed. Add a ja-JP voice in "
            + "System Settings ▸ Speech ▸ System Voice ▸ Manage Voices, then reopen DaiJiShow."
    }

    var body: some View {
        let available = engine.japaneseVoiceAvailable
        let hasText = !trimmed.isEmpty
        let enabled = available && hasText

        Button {
            SpeechEngine.shared.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(variant == .headword ? .title3 : .caption)
                .fontWeight(.semibold)
                .padding(.horizontal, variant == .headword ? 12 : 7)
                .padding(.vertical, variant == .headword ? 8 : 4)
                .background(Capsule().fill(Color.accentColor.opacity(enabled ? 1 : 0.18)))
                .foregroundStyle(enabled ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(helpText)
        .fixedSize()
    }
}
