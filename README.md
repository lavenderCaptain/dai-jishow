# Dai-Jishow (大辞書)

**Dai-Jishow** is an encyclopedic, zero-bloat, offline-first Japanese–English and
Japanese–Japanese dictionary, kanji explorer, and study deck companion. The
engine is built in **C++20** behind a flat **C11 ABI**, and today it ships a
**native macOS desktop app** rendered with translucent *glass* materials.
Apple (iOS/iPadOS/watchOS) and Android (Wear OS) shells are on the roadmap;
the macOS shell is the current product.

> **Naming.** *Dai‑Jishow* (hyphenated) is the display/product name, used in prose,
> the UI, and this page. In code the name is written fused — `DaiJishow`,
> `DaiJishowCore`, `DaiJishowMac`, and the `daijishow.db` bundle — because Swift /
> C++ / CMake identifiers and the compiled binary cannot contain a hyphen; the
> lowercase `dai-jishow` is the repository and URL. The hyphenated name now reaches
> the shipped app too: the `Dai-Jishow.app` bundle and `Dai-Jishow-<version>.dmg`
> installer set their display name to "Dai-Jishow" so Finder, the Dock, the menu
> bar, and the About panel all read "Dai-Jishow" (the binary inside builds as
> `Dai-Jishow` in Xcode and `DaiJishowMac` in SwiftPM). This split is intentional,
> not a typo.

## What's Built Today (macOS)

A single-window, focus-first desktop dictionary. No tab bar, no nested menus —
one glass surface that reframes as you drill in.

- **Omni-search** — type kanji, kana, romaji (`dzu/tzu`, `n'ya`, long vowels),
  English glosses, or wildcards; results appear live in a dropdown with quick
  filters (**Common**, POS, **Yojijukugo**, **Idioms**, **Proverbs**, **Keigo**,
  **Colloquial**, and approximate KANJIDIC2 **JLPT / Grade** bands). A toggle
  includes/excludes **proper names** (人名).
- **Word entry** — headword + ruby, a **Tokyo pitch-accent contour**, telemetry
  pills (corpus frequency tier, JLPT, grade, stroke count), a corpus-frequency
  meter, "also written as" variant chips, and on-demand Japanese TTS playback.
- **Reader / Detailed modes** — *Reader* shows definitions cleanly; *Detailed*
  reveals the full analysis dashboard: a wrapping **Kanji DNA** strip,
  **Definitions** (POS & register-tagged senses), a **自他 pair** banner,
  **Homonyms** (同音異義語), **Word Family** (prefix/suffix compounds),
  **Corpus Collocations** (extracted from Tatoeba examples), **Example
  Sentences**, and a **conjugation matrix** for verbs and adjectives.
- **Kanji detail & Radical Lookup** — glyph with animated **KanjiVG stroke
  vectors**, on/kun readings, metadata (strokes, grade, JLPT, radical, JIS,
  SKIP, 4-Corner, kyūjitai↔shinjitai), **Yojijukugo / idioms**, a
  **Prevalence / Starts / Ends** compound switcher, plus a multi-radical,
  SKIP, and 4-Corner kanji lookup view.
- **Dokusha Spatial Fisheye & Word Cosmos** — prefix neighbors on the left and
  suffix neighbors on the right weighted by compound frequency/PMI with a tier
  legend, alongside a randomized **Word Cosmos** prevalence bubble cloud.
- **Study Decks & Flashcard Export** — save words and kanji into persistent JSON
  decks (`StudyStore`), organize across custom decks, and export to **Flashcard
  TSV** (Anki-compatible) or RFC-4180 **CSV**.
- **Z-Stack navigation & Recall modes** — every lookup pushes a glass frame
  forward with a visual **3D History Deck (`⌘\`)** and **Full / Hide Kana /
  Hide Defn.** recall self-quizzing.
- **Adaptive & Sandboxed macOS App** — Native unified toolbar with Liquid Glass
  on macOS 26+ (material fallbacks on macOS 14–15), **System / Dark / Light**
  appearance, VoiceOver/keyboard navigation, Reduce Transparency / Motion /
  Increase Contrast adaptation, macOS **App Sandbox** (`DaiJishow.entitlements`),
  Apple **Privacy Manifest** (`PrivacyInfo.xcprivacy`), and bundled
  **MIT / Creative Commons** licensing (`LICENSE`, `NOTICE`).

All dictionary lookups run **100% offline** against a single read-only,
memory-mapped SQLite corpus (`daijishow.db`) bundled with the app.

## What's Still Roadmap (Vision)

- **Live AR camera / screen-OCR furigana lens** and **Radial Bloom** selection
  menu (designed in `docs/`).
- **Spaced repetition (SRS) scheduler** and "Snarf Unknown Kanji" workflow over
  the existing Study Decks foundation.
- **Pre-populated static `keigo_ladders` & corpus-wide `collocations` tables**
  (schema tables exist; `collocations` are currently synthesized on demand from
  Tatoeba sentences).
- **Developer ID notarization & Mac App Store distribution** (code-signing
  entitlements, Privacy Manifest, export compliance, and `LICENSE`/`NOTICE` are
  already in place; requires an Apple Developer Program membership).
- **iPhone / iPad**, **Apple Watch**, and **Android / Wear OS** UI shells over
  `DaiJishowCore`.

## Repository Layout

* `docs/` — Product, UI/interaction, architecture, and corpus specifications.
* `core/` — Platform-agnostic C++20 engine (`dj_storage`, `dj_nlp`, `dj_graph`,
  `dj_state`, `dj_capi`), built as `DaiJishowCore`.
* `core/test/` — Native C++20 unit & DB-backed storage regression tests
  (`test_romaji`, `test_pair_head`, `test_idioms`, `test_storage`,
  `test_db_storage`; **426 checks across 33 tests**).
* `Sources/DaiJishowMorph/` — Pure, dependency-free Swift morphology, pitch
  contour, flashcard export, and `StudyStore` library.
* `Tests/DaiJishowMorphTests/` — **Swift Testing** suite covering conjugation,
  POS tags, pitch-accent contours, TSV/CSV export, and `StudyStore` persistence
  (**42 tests in 6 suites**).
* `Tests/DaiJishowAppTests/` — Hosted macOS app test target verifying App Sandbox,
  bundle metadata, `LICENSE`/`NOTICE`/`PrivacyInfo.xcprivacy`, `DaiJishowEngine`
  navigation, and SwiftUI view layout inside `Dai-Jishow.app`.
* `tools/corpus-builder/` — Offline Python ETL that builds `daijishow.db`
  (`build_corpus.py`, `fetch_sources.py`, `pack_kanjivg.py`).
* `platform-apple/macOS/` — Native SwiftUI glass-material macOS shell, plus
  `DaiJishow.entitlements` and `PrivacyInfo.xcprivacy`.
* `DaiJishow.xcodeproj/` — Native Xcode project defining `Dai-Jishow`,
  `DaiJishowMorph`, `DaiJishowCore`, `DaiJishowMorphTests`, and
  `DaiJishowAppTests` targets (with shared `Dai-Jishow` scheme and
  `icons/DaiJishow.icon`).
* `platform-android/` — Placeholder (`.gitkeep`); Android/Wear OS shell not yet built.
* `tools/` — `build_app_bundle.sh` (test gates + sandboxed `.app` + `.dmg`),
  `build_cpp_tests.sh`, `dj_cli.cpp`, and `make_icon.swift`.
* `LICENSE` & `NOTICE` — MIT license for Dai-Jishow source code and required
  Creative Commons attributions for the compiled dictionary corpus.

## Build & Test

Open `DaiJishow.xcodeproj` directly in Xcode (scheme `Dai-Jishow`, **⌘R** to
run, **⌘U** to run both `DaiJishowMorphTests` and sandboxed `DaiJishowAppTests`),
or run from the command line:

```bash
# 1. Build & run the SwiftPM app and unit tests (42 tests)
swift build && swift test

# 2. Build & run the C++20 core & DB-backed storage tests (426 checks / 33 tests)
./tools/build_cpp_tests.sh

# 3. Run the full Xcode test suite (including hosted sandboxed DaiJishowAppTests)
xcodebuild -project DaiJishow.xcodeproj -scheme Dai-Jishow -destination 'platform=macOS' test

# 4. Assemble a sandboxed Dai-Jishow.app + drag-to-Applications DMG in build/
./tools/build_app_bundle.sh
```

Handy `build_app_bundle.sh` flags: `--release` (optimized build), `--no-db`
(skip the ~221 MB corpus), `--symlink-db` (link instead of copy for local dev),
`--no-dmg` (skip the DMG), `--skip-tests` / `--skip-cpp-tests` (bypass test
gates during quick local iteration). Recreate the offline corpus from upstream
sources with:

```bash
cd tools/corpus-builder && python3 fetch_sources.py && python3 build_corpus.py
```

## License & Corpus Attribution

- **Source code:** Licensed under the **MIT License** — see [`LICENSE`](LICENSE).
- **Compiled offline corpus (`daijishow.db`):** Separately licensed under Creative
  Commons licenses by its upstream contributors — see [`NOTICE`](NOTICE) and the
  in-app **About Dai-Jishow** panel for full attributions:
  - **JMdict_e**, **JMnedict / ENAMDICT**, and **KANJIDIC2** — James William Breen & EDRG (**CC BY-SA 4.0**)
  - **KanjiVG** — Copyright © 2009–2013 Ulrich Apel (**CC BY-SA 3.0**)
  - **Kanjium** — Pitch-accent notation by Uros O. (**CC BY-SA 4.0**)
  - **Tatoeba** — Tatoeba Project & Contributors (**CC BY 2.0**)
