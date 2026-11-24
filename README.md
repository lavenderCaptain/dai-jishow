# Dai-Jishow (大辞書)

**Dai-Jishow** is an encyclopedic, zero-bloat, offline-first Japanese–English and
Japanese–Japanese dictionary, kanji explorer, and (eventually) live AR reading
lens. The engine is built in **C++20** behind a flat **C11 ABI**, and today it
ships a **native macOS desktop app** rendered with translucent *glass*
materials. Apple (iOS/watchOS) and Android (Wear OS) shells are on the roadmap;
the macOS shell is the current product.

> **Naming.** *Dai‑Jishow* (hyphenated) is the display/product name, used in prose,
> the UI, and this page. In code the name is written fused — `DaiJishow`,
> `DaiJishowCore`, `DaiJishowMac`, and the `daijishow.db` bundle — because Swift /
> C++ / CMake identifiers and the compiled binary cannot contain a hyphen; the
> lowercase `dai-jishow` is the repository and URL. The hyphenated name now reaches
> the shipped app too: the `Dai-Jishow.app` bundle and `Dai-Jishow-<version>.dmg`
> installer set their display name to "Dai-Jishow" so Finder, the Dock, the menu
> bar, and the About panel all read "Dai-Jishow" (the binary inside still builds as
> `DaiJishowMac`). This split is intentional, not a typo.

## What's Built Today (macOS)

A single-window, focus-first desktop dictionary. No tab bar, no nested menus —
one glass surface that reframes as you drill in.

- **Omni-search** — type kanji, kana, romaji (`dzu/tzu`, `n'ya`, long vowels),
  or English; results appear live in a dropdown, press **Enter** to open the
  top hit. A toggle includes/excludes **proper names** (人名).
- **Word entry** — headword + ruby, a **Tokyo pitch-accent contour**, telemetry
  pills (corpus frequency tier, JLPT, grade, stroke count), a corpus-frequency
  meter, and "also written as" variant chips.
- **Reader / Detailed modes** — *Reader* shows just the definitions; *Detailed*
  reveals the full analysis dashboard: a wrapping **Kanji DNA** strip, **Definitions**
  (POS-tagged senses), a **自他 pair** banner, **Homonyms** (同音異義語),
  **Word Family** (prefix/suffix compounds), **Corpus Collocations**,
  **Example Sentences**, and a **conjugation matrix** for verbs/adjectives.
- **Kanji detail** — glyph with animated **KanjiVG stroke vectors**, on/kun
  readings, full metadata (strokes, grade, JLPT, radical, JIS, SKIP, 4-Corner,
  kyūjitai↔shinjitai), and a **"Vocabulary & Compounds Containing …"** list with
  a display-mode switch: **Prevalence** (most-common-first) / **Starts** /
  **Ends**.
- **Dokusha Spatial Fisheye** — prefix neighbors on the left, suffix neighbors on
  the right, weighted by compound frequency/PMI, with a **tier legend** (Core /
  Jōyō / Literary / Kyūjitai); the **Word Cloud** is a randomized prevalence
  bubble cloud over the same graph, with its own **tier legend** (Names / Core /
  Jōyō / Std / Lit).
- **Z-Stack navigation** — every lookup pushes a glass frame forward; the history
  deck (⌘\\) scrubs the trail.
- **Recall modes** — *Full / Hide Kana / Hide Gloss* for self-quizzing.
- **Adaptive macOS UI** — Native unified toolbar with Liquid Glass on macOS 26+
  (material fallbacks on macOS 14–15), **System / Dark / Light** appearance mode,
  VoiceOver/keyboard navigation, Reduce Transparency / Motion / Increase Contrast
  adaptation, **Edit / View / Navigate / Help (⌘/)** menus, **About**, and **Preferences**.

All of the above runs **100% offline** against a single read-only, memory-mapped
SQLite corpus bundled with the app.

## What's Still Roadmap (Vision)

The live **AR camera / screen-OCR furigana lens**, the **Radial Bloom**
selection menu, **SRS flashcards / "Snarf Unknown Kanji"**, **Keigo** register
ladders, iOS/iPad, Apple Watch, and Android/Wear OS shells are designed in
`docs/` but not yet built. Some corpus tables (collocations, keigo ladders,
idiom triggers) exist in the schema but are not yet populated by the ETL.

## Design Philosophy

1. **Zero Framework Bloat:** Inspired by classic dedicated electronic dictionaries
   and Palm OS utilities (Dokusha v1.5), the core engine,
   morphological path, graph solver, and state machine live in pure **C++20**
   exposed via a flat **C11 ABI (`dj_capi.h`)**. No Electron, no web views, and
   a tiny active footprint via read-only memory-mapped SQLite (`mmap`).
2. **Focus + Context Everywhere:** Navigation abandons flat page reloads in favor
   of a **3D Zoom-Out Z-Stack** ("Zoom Out" for spatial trail context).
3. **Encyclopedic Offline Depth:** Merges JMdict, JMnedict, KANJIDIC2, KanjiVG,
   Kanjium pitch accents, and Tatoeba example sentences into a single unified
   database, with BCCWJ/Jiten frequency profiles and *Yojijukugo* / idioms on the
   way.

## Repository Layout

* `docs/` — Product, UI/interaction, architecture, and corpus specifications.
* `core/` — Platform-agnostic C++20 engine (`dj_storage`, `dj_nlp`, `dj_graph`,
  `dj_state`, `dj_capi`), built as the `DaiJishowCore` library.
* `Sources/DaiJishowMorph/` — Pure, dependency-free Swift morphology core
  (`Morph.inflections` / `Morph.senseTags`, `PitchAccentContour`,
  `KanaNormalizer`, `InflectionForm`), extracted from the executable so it can be
  unit-tested (SwiftPM cannot `@testable import` an executable target).
  `DaiJishowMac` imports it and adapts its `EntryDetail` / `SenseItem` into the
  morpher's flat parameters.
* `Tests/DaiJishowMorphTests/` — Regression suite (**Swift Testing**) locking the
  conjugation / part-of-speech / pitch-accent behavior; run by `swift test` and
  gated into `tools/build_app_bundle.sh` so a broken form can't ship a DMG.
* `tools/corpus-builder/` — Offline Python ETL that builds `daijishow.db`
  (`build_corpus.py`, with `fetch_sources.py` and `pack_kanjivg.py`).
* `platform-apple/macOS/` — The native SwiftUI glass-material macOS shell
  (`DaiJishowMac`): `EngineBridge` (C11 bridge + app state), `GlassViews`,
  `DaiJishowMacApp`, `AppChrome`, `ThemeTokens`, `RadicalCatalog`,
  `SpeechEngine`, `StudyStore`, `StudyLibraryView`, `WindowChrome`.
* `DaiJishow.xcodeproj/` — Native Xcode project defining `Dai-Jishow`,
  `DaiJishowMorph`, `DaiJishowCore`, and `DaiJishowMorphTests` targets
  (with shared `Dai-Jishow` scheme and `icons/DaiJishow.icon`).
* `platform-android/` — Placeholder (`.gitkeep`); the Android/Wear OS shell is
  not yet built.
* `tools/` — `build_app_bundle.sh` (assembles `Dai-Jishow.app` + a
  drag-to-Applications DMG) and `make_icon.swift`.

## Build & Run

Open `DaiJishow.xcodeproj` directly in Xcode (scheme `Dai-Jishow`, **⌘R** to run, **⌘U** to run unit tests), or build from the command line with Xcode or Swift Package Manager:

```bash
# 1. Build the C++ core + macOS app
swift build

# 1b. (optional) Run the morphology regression suite — also run automatically
#     as a gate inside ./tools/build_app_bundle.sh below
swift test

# 2. Assemble a distributable .app (icon + self-contained corpus + Info.plist)
#    and a drag-to-Applications DMG in build/
./tools/build_app_bundle.sh

# Open the app directly:
open build/Dai-Jishow.app

# …or the installer: open build/Dai-Jishow-<version>.dmg and drag Dai-Jishow onto
# the Applications folder.
```

Handy flags: `--release` (optimized build), `--no-db` (skip the ~221 MB corpus),
`--symlink-db` (link instead of copy), `--no-dmg` (skip the DMG), `--skip-tests`
(bypass the `swift test` regression gate for fast local iteration). The corpus is
recreated from raw sources with:

```bash
cd tools/corpus-builder && python3 build_corpus.py
```

## Roadmap

- [x] **Phase 0:** Reverse-engineer the Dokusha v1.5 interaction model & design
      the interactive macOS glass-material prototype.
- [x] **Phase 1:** Build `tools/corpus-builder` ETL pipeline and compile a
      unified `daijishow.db`.
- [x] **Phase 2:** Implement the `core/` C++20 engine + `dj_capi.h` and a CLI
      (`tools/dj_cli`) test harness.
- [x] **Phase 3:** Build the **macOS Desktop** native SwiftUI glass-material
      application, packaged as a signed `.app` + DMG.
- [ ] **Phase 4:** Extend the Apple shell to **iPhone/iPad** (live AR camera) and
      **Apple Watch** (crown Z-stack).
- [ ] **Phase 5:** Port the native UI shell to **Android** and **Wear OS** over
      `libdaijishow.so`.
