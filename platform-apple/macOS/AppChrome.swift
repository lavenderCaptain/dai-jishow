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

// Upstream credits live in platform-apple/Shared/DaiJishowCredits.swift.

// MARK: - About

/// The standard "About" panel, presented as a sheet from the app menu.
struct AboutView: View {
    @ObservedObject var engine: DaiJishowEngine
    @Environment(\.dismiss) private var dismiss

    private var appName: String {
        // Prefer the display name (what the menu bar / Finder show), then the
        // bundle name, then a sane literal — so the headline always reads
        // "Dai-Jishow", even as a bare dev binary with no Info.plist.
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
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

            Text("Dai-Jishow fuses an offline Japanese lexicon — headwords, kanji, pitch accent, and real-world example sentences — into a single fisheye-driven study dashboard. Application source code is MIT-licensed; the bundled corpus database (daijishow.db) transforms the open datasets below and is distributed under CC BY-SA 4.0 (see NOTICE in app resources).")
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
                if let url = URL(string: "https://github.com/lavenderCaptain/dai-jishow") {
                    Link(destination: url) {
                        Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
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
        .frame(minWidth: 500, idealWidth: 560, maxWidth: 640, minHeight: 480, idealHeight: 580)
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
                Text(credit.attribution)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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

            if let licURL = URL(string: credit.licenseURL) {
                Link(destination: licURL) {
                    Text(credit.license)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .help("View \(credit.license) license deed")
            } else {
                Text(credit.license)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
        }
    }
}

// MARK: - Settings / Preferences

/// The Preferences scene (⌘,). Binds directly to the shared engine so changes
/// take effect live across the whole app.
struct SettingsView: View {
    @ObservedObject var engine: DaiJishowEngine

    private var hasJapaneseGlossesInActiveEntry: Bool {
        engine.activeEntry?.hasJapaneseGlosses ?? false
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $engine.appearanceMode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("Follow macOS System appearance, or lock Dark or Light mode.")
            }

            Section("Display") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Gloss Language", selection: $engine.glossLanguageMode) {
                        ForEach(GlossLanguageMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!hasJapaneseGlossesInActiveEntry && engine.glossLanguageMode == .english)
                    .help("Which definition languages to show when Japanese-language glosses are available in the corpus.")

                    if !hasJapaneseGlossesInActiveEntry {
                        Text("Japanese definitions (国語) are shown automatically for entries whose corpus includes Japanese glosses.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Recall Mode", selection: $engine.recallMode) {
                    ForEach(RecallMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
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
        .frame(minWidth: 460, idealWidth: 500, minHeight: 410)
    }
}

// MARK: - Help & Keyboard Shortcuts Sheet

struct HelpSheetView: View {
    @Environment(\.dismiss) private var dismiss

    private struct ShortcutRow: Identifiable {
        let id = UUID()
        let keys: String
        let title: String
        let detail: String
    }

    private let navigationShortcuts: [ShortcutRow] = [
        ShortcutRow(keys: "⌘F", title: "Focus Search", detail: "Type kanji, kana, romaji (e.g. dzu, n'ya), or English"),
        ShortcutRow(keys: "⌘[  /  ⌘]", title: "Navigate Back / Forward", detail: "Step through your lookup trail"),
        ShortcutRow(keys: "⌘\\", title: "Navigation Deck (Z-Stack)", detail: "Scrub visual snapshots with ←/→, trackpad scroll, or Enter"),
        ShortcutRow(keys: "⌘⇧F", title: "Kanji Fisheye", detail: "Prefix & suffix compound explorer around a kanji"),
        ShortcutRow(keys: "⌘⇧K", title: "Kanji Index", detail: "Browse by stroke count, reading, SKIP, 4-Corner, or grade"),
        ShortcutRow(keys: "⌘⇧R", title: "7-Slot Radical Builder", detail: "Compose kanji from component radicals"),
        ShortcutRow(keys: "⌘⇧W", title: "Word Cloud", detail: "Randomized prevalence / JLPT / grade bubble explorer"),
        ShortcutRow(keys: "⌘⇧D", title: "Compounds", detail: "Decompose a compound word into its constituent kanji"),
        ShortcutRow(keys: "⌘⇧L", title: "Saved Decks", detail: "Manage study decks and export Anki TSV / CSV"),
    ]

    private let studyShortcuts: [ShortcutRow] = [
        ShortcutRow(keys: "⌘1 / ⌘2 / ⌘3", title: "Recall Mode", detail: "Full, Hide Kana, or Hide Defn. for self-quizzing"),
        ShortcutRow(keys: "⌘⇧C", title: "Detailed / Reader Mode", detail: "Toggle full lexical dashboard on a word entry"),
        ShortcutRow(keys: "⌘B", title: "Toggle Bookmark", detail: "Save or remove the current word/kanji in Favorites"),
        ShortcutRow(keys: "⌘⌥C", title: "Copy Entry", detail: "Copy formatted headword, readings, and glosses"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dai-Jishow Shortcuts & Search Guide")
                        .font(.title2.weight(.bold))
                    Text("Offline Japanese dictionary, kanji fisheye, and study decks")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    shortcutSection("Navigation & Views", rows: navigationShortcuts)
                    shortcutSection("Study & Editing", rows: studyShortcuts)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("SEARCH TIPS")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Text("• Switch between Prefix (exact/prefix priority) and Contains (substring match anywhere) from the search bar badge.\n• Toggle Names to include or hide proper names (人名); Dai-Jishow also auto-nudges when a name is the top match.\n• Use ↑ / ↓ and Return inside the search dropdown, or Esc to dismiss overlays.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(minWidth: 540, idealWidth: 600, minHeight: 460, idealHeight: 560)
    }

    private func shortcutSection(_ title: String, rows: [ShortcutRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.keys)
                            .font(.caption.monospaced().weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .frame(minWidth: 118, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.title)
                                .font(.callout.weight(.semibold))
                            Text(row.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}
