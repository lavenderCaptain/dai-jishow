// AppChrome.swift — standard macOS application chrome:
//   • AboutView  — the "About Dai-Jishow" sheet (version, credits, and the
//                  upstream source / license shout-outs that keep us compliant).
//   • SettingsView — the Preferences scene (⌘,): display, recall, fisheye.
//
// The app is a SwiftPM executable, so the About panel reads its version from the
// bundle's Info.plist when packaged as a .app and falls back gracefully when run
// as a bare dev binary.

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Upstream Data Sources & Licenses
//
// Single source of truth for the shout-outs. These mirror the canonical fetch
// list in tools/corpus-builder/fetch_sources.py, so the credits never drift
// from what actually compiled the corpus.
//
// License notes (verified against upstream at time of writing):
//   • EDRG JMdict_e / JMnedict ....... CC BY 4.0
//   • EDRG KANJIDIC2 .................. CC BY-SA 4.0
//   • KanjiVG stroke vectors .......... Open-source (see repository)
//   • mifunetoshiro/kanjium accents ... Open-source (see repository)
//   • Tatoeba sentences/links ......... CC BY 2.0

struct DataCredit {
    let name: String
    let role: String
    let license: String
    let url: String
}

enum DaiJishowCredits {
    static let sources: [DataCredit] = [
        DataCredit(
            name: "JMdict_e (EDRG)",
            role: "Japanese–English word & phrase definitions",
            license: "CC BY 4.0",
            url: "http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz"
        ),
        DataCredit(
            name: "JMnedict (EDRG)",
            role: "Japanese–Japanese definitions",
            license: "CC BY 4.0",
            url: "http://ftp.edrdg.org/pub/Nihongo/JMnedict.xml.gz"
        ),
        DataCredit(
            name: "KANJIDIC2 (EDRG)",
            role: "Kanji readings, meanings, radicals & stroke counts",
            license: "CC BY-SA 4.0",
            url: "http://ftp.edrdg.org/pub/Nihongo/kanjidic2.xml.gz"
        ),
        DataCredit(
            name: "KanjiVG",
            role: "Stroke-order polylines & radical diagrams",
            license: "Open Source",
            url: "https://github.com/KanjiVG/kanjivg"
        ),
        DataCredit(
            name: "kanjium accents",
            role: "Pitch-accent downstep positions",
            license: "Open Source",
            url: "https://github.com/mifunetoshiro/kanjium"
        ),
        DataCredit(
            name: "Tatoeba",
            role: "Real-world example sentences (JP / EN)",
            license: "CC BY 2.0",
            url: "https://tatoeba.org"
        ),
    ]
}

// MARK: - About

/// The standard "About" panel, presented as a sheet from the app menu.
struct AboutView: View {
    @ObservedObject var engine: DaiJishowEngine
    @Environment(\.dismiss) private var dismiss

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Dai-Jishow"
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, let build, short != build {
            return "\(short) (build \(build))"
        }
        return short ?? build ?? "Development Build"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header: icon + identity
            HStack(alignment: .center, spacing: 16) {
                aboutIcon
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(appName)
                        .font(.largeTitle.weight(.bold))
                    Text("日本語辞書 · a Japanese dictionary & study dashboard")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(appVersion)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }

            Divider()

            Text("Dai-Jishow fuses an offline Japanese lexicon — headwords, kanji, pitch accent, and real-world example sentences — into a single fisheye-driven study dashboard. The corpus below is built entirely from open linguistic datasets; their licenses are honoured in full.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Credits
            VStack(alignment: .leading, spacing: 10) {
                Text("SOURCES & LICENSES")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(DaiJishowCredits.sources, id: \.name) { credit in
                            creditRow(credit)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 260)
            }

            Divider()

            // Actions
            HStack {
                if let url = URL(string: "https://github.com") {
                    Link(destination: url) {
                        Label("Project", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
                Spacer()
                Button("OK") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560, height: 560)
    }

    @ViewBuilder
    private var aboutIcon: some View {
        #if os(macOS)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback when running the bare dev binary (no bundle icon).
            Image(systemName: "character.book.closed.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color.accentColor)
                .padding(18)
        }
        #else
        Image(systemName: "character.book.closed.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(Color.accentColor)
            .padding(18)
        #endif
    }

    private func creditRow(_ credit: DataCredit) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(credit.name)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 150, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(credit.role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = URL(string: credit.url) {
                    Link(destination: url) {
                        Text(credit.url)
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                    }
                } else {
                    Text(credit.url)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(credit.license)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
    }
}

// MARK: - Settings / Preferences

/// The Preferences scene (⌘,). Binds directly to the shared engine so changes
/// take effect live across the whole app.
struct SettingsView: View {
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        Form {
            Section("Display") {
                Picker("Gloss Language", selection: $engine.glossLanguageMode) {
                    ForEach(GlossLanguageMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Which definition languages to show in entries.")

                Picker("Recall Mode", selection: $engine.recallMode) {
                    ForEach(RecallMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Toggle kana and/or glosses for self-quiz recall.")

                Toggle("Include proper names in search", isOn: Binding(
                    get: { engine.includeNames },
                    set: { engine.setNamesIncluded($0, userInitiated: true) }
                ))
                Toggle("Expand Detailed View (full dashboard)", isOn: $engine.isWordCockpitExpanded)
            }

            Section("Kanji Fisheye") {
                Toggle("Show commonality percentages", isOn: $engine.showFisheyePercentages)
                Stepper("Ideographs per side: \(engine.maxFisheyePerSide)",
                        value: $engine.maxFisheyePerSide, in: 4...24)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 360)
    }
}
