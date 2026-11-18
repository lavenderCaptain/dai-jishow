# Dai-Jishow (大辞書)

**Dai-Jishow** is an encyclopedic, zero-bloat, offline-first Japanese–English and
Japanese–Japanese dictionary, kanji explorer, and (eventually) live AR reading
lens. The engine is built in **C++20** behind a flat **C11 ABI**, and today it
ships a **native macOS desktop app** rendered with translucent *Liquid Glass*
materials. Apple (iOS/watchOS) and Android (Wear OS) shells are on the roadmap;
the macOS shell is the current product.

## What's Built Today (macOS)

A single-window, focus-first desktop dictionary. No tab bar, no nested menus —
one glass surface that reframes as you drill in.

- **Omni-search** — type kanji, kana, romaji (`dzu/tzu`, `n'ya`, long vowels),
  or English; results appear live in a dropdown, press **Enter** to open the
  top hit. A toggle includes/excludes **proper names** (人名).
- **Word entry** — headword + ruby, a **Tokyo pitch-accent contour**, telemetry
  pills (corpus frequency tier, JLPT, grade, stroke count), a corpus-frequency
  meter, and "also written as" variant chips.
- **Reader / Cockpit modes** — *Reader* shows just the definitions; *Cockpit*
  reveals the full analysis dashboard: **Kanji DNA** strip, **Definitions**
  (POS-tagged senses), a **自他 pair** banner, **Homonyms** (同音異義語),
  **Word Family** (prefix/suffix compounds), **Corpus Collocations**,
  **Example Sentences**, and a **conjugation matrix** for verbs/adjectives.
- **Kanji detail** — glyph with animated **KanjiVG stroke vectors**, on/kun
  readings, full metadata (strokes, grade, JLPT, radical, JIS, SKIP, 4-Corner,
  kyūjitai↔shinjitai), and a **"Vocabulary & Compounds Containing …"** list with
  a display-mode switch: **Prevalence** (most-common-first) / **Starts** /
  **Ends**.
- **Dokusha Spatial Fisheye** — prefix neighbors on the left, suffix neighbors on
  the right, weighted by compound frequency/PMI; **Word Cosmos** is a randomized
  prevalence bubble cloud over the same graph.
- **Z-Stack navigation** — every lookup pushes a glass frame forward; the history
  deck (⌘\\) scrubs the trail.
- **Recall modes** — *Full / Hide Kana / Hide Gloss* for self-quizzing.
- **Tooltips** on every control; **text selection + copy** (⌘C, plus a
  ⌘⌥C "Copy Entry" command); **About** (with source/license credits) and
  **Preferences**.

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
   (Canon WordTank) and Palm OS utilities (Dokusha v1.5), the core engine,
   morphological path, graph solver, and state machine live in pure **C++20**
   exposed via a flat **C11 ABI (`dj_capi.h`)**. No Electron, no web views, and
   a tiny active footprint via read-only memory-mapped SQLite (`mmap`).
2. **Focus + Context Everywhere:** Navigation abandons flat page reloads in favor
   of a **3D Time Machine Z-Stack** ("Zoom Out" for spatial trail context).
3. **Encyclopedic Offline Depth:** Merges JMdict, JMnedict, KANJIDIC2, KanjiVG,
   Kanjium pitch accents, and Tatoeba example sentences into a single unified
   database, with BCCWJ/Jiten frequency profiles and *Yojijukugo* / idioms on the
   way.

## Repository Layout

* `docs/` — Product, UI/interaction, architecture, and corpus specifications.
* `core/` — Platform-agnostic C++20 engine (`dj_storage`, `dj_nlp`, `dj_graph`,
  `dj_state`, `dj_capi`), built as the `DaiJishowCore` library.
* `tools/corpus-builder/` — Offline Python ETL that builds `daijishow.db`
  (`build_corpus.py`, with `fetch_sources.py` and `pack_kanjivg.py`).
* `platform-apple/macOS/` — The native SwiftUI + Liquid Glass macOS shell
  (`DaiJishowMac`): `EngineBridge` (C11 bridge + app state), `LiquidGlassViews`,
  `DaiJishowMacApp`, `AppChrome`, `RadicalCatalog`.
* `platform-android/` — Placeholder (`.gitkeep`); the Android/Wear OS shell is
  not yet built.
* `tools/` — `build_app_bundle.sh` (assembles `DaiJishow.app` + a
  drag-to-Applications DMG) and `make_icon.swift`.

## Build & Run

The project builds with the Swift Package Manager (there is no `.xcodeproj`):

```bash
# 1. Build the C++ core + macOS app
swift build

# 2. Assemble a distributable .app (icon + self-contained corpus + Info.plist)
#    and a drag-to-Applications DMG in build/
./tools/build_app_bundle.sh

# Open the app directly:
open build/DaiJishow.app

# …or the installer: open build/DaiJishow-<version>.dmg and drag DaiJishow onto
# the Applications folder.
```

Handy flags: `--release` (optimized build), `--no-db` (skip the ~221 MB corpus),
`--symlink-db` (link instead of copy), `--no-dmg` (skip the DMG). The corpus is
recreated from raw sources with:

```bash
cd tools/corpus-builder && python3 build_corpus.py
```

## Roadmap

- [x] **Phase 0:** Reverse-engineer the Dokusha v1.5 interaction model & design
      the interactive macOS Liquid Glass prototype.
- [x] **Phase 1:** Build `tools/corpus-builder` ETL pipeline and compile a
      unified `daijishow.db`.
- [x] **Phase 2:** Implement the `core/` C++20 engine + `dj_capi.h` and a CLI
      (`tools/dj_cli`) test harness.
- [x] **Phase 3:** Build the **macOS Desktop** native SwiftUI + Liquid Glass
      application, packaged as a signed `.app` + DMG.
- [ ] **Phase 4:** Extend the Apple shell to **iPhone/iPad** (live AR camera) and
      **Apple Watch** (Digital-Crown Z-stack).
- [ ] **Phase 5:** Port the native UI shell to **Android** and **Wear OS** over
      `libdaijishow.so`.
