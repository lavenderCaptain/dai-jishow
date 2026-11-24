# 03 — Cross-Platform Architecture & C11 ABI

## 1. Architectural Pattern: Hub-and-Spoke Native Core

Dai-Jishow uses a **shared C++20 core** exposed through a **flat C11 ABI (`dj_capi.h`)**, consumed by thin, 100% native UI shells on each OS family (SwiftUI + Metal on Apple; Jetpack Compose + AGSL on Android).

```text
  [ macOS ]   [ iOS / iPadOS ]   [ watchOS ]          [ Android ]   [ Wear OS ]
      \              |               /                     \            /
       +-------------+--------------+                       +----------+
                     |                                            |
          Swift 6 Direct C Interop                     Thin JNI Wrapper (dj-jni)
                     \                                            /
                      +--------------------+---------------------+
                                           |
                           C11 ABI Boundary (dj_capi.h)
                                           |
                     +---------------------+---------------------+
                     |            C++20 Core Engine              |
                     |  dj_storage | dj_nlp | dj_graph | dj_state|
                     +---------------------+---------------------+
                                           |
                         Read-Only mmap SQLite (daijishow.db)
```

---

## 2. Resource & Performance Budgets

* **Zero VM / Web Overhead:** No Electron, Chromium, React Native, or JavaScript engines.
* **Memory-Mapped Corpus:** `daijishow.db` is opened with `SQLITE_OPEN_READONLY` and `PRAGMA mmap_size = 268435456`. The OS kernel faults in only the exact 4 KB B-tree pages queried.
* **Target Budgets:**
  * **Binary Code Size:** `< 8 MB` (Desktop/Mobile), `< 4 MB` (Watch).
  * **Idle Resident Memory (RSS):** `< 20 MB` (Desktop/Mobile), `< 12 MB` (Watch).
  * **Query / Fisheye Solve Latency:** `< 0.5 ms` per frame.

---

## 3. Core C++20 Modules (`core/`)

### 3.1 `dj_storage`
* Wraps SQLite3 (`WITHOUT ROWID` tables, FTS5 contentless prefix/substring indexes, and `ATTACH DATABASE` support for user-imported Yomitan ZIP dictionaries).
* Decodes quantized binary KanjiVG polylines (`uint16` coordinate streams) and pre-tokenized example sentence span blobs.
* **Reverse lookup (English → Japanese):** the `entries_fts` index over `en_glosses` backs the "Also in English glosses" column — `db_search_words` runs the English-gloss FTS5 query (mode `DJ_SEARCH_ENGLISH`) and re-ranks hits by `english_gloss_relevance_tier` (sense-0 gloss relevance) before truncating. This makes English a *supplementary, relevance-ranked* match path; it is **not** a co-equal Japanese→English search axis. A full-string / multi-gloss ranking and a dedicated English-anchored search are a planned expansion.

### 3.2 `dj_nlp`
* **Morphological Analyzer:** Embeds `libmecab` with a compact binary dictionary for sub-millisecond tokenization of live OCR text and recursive Japanese definition jumps.
* **Wa-puro Romaji Parser:** Deterministic state machine converting Romaji (`dzu/tzu`, `n'ya`, double-consonant small *tsu*, `toukyou`) to Hiragana/Katakana.
* **Reverse De-Inflector & Grammar/Idiom Matcher:** Strips verb/adjective agglutinations back to canonical `entry_id` lemmas, matches conjugated multi-word idioms via `idiom_triggers`, and annotates Japanese historical era dates (`Gengō`) and counters.

### 3.3 `dj_graph`
* Queries precomputed bidirectional `kanji_edges` (2-kanji compounds, *Yojijukugo*, and look-alike confusables).
* Computes normalized 2D polar fisheye coordinates (`[-1.0, +1.0]`), node scales, and frequency-weighted opacities in C++ so Metal and AGSL render identical geometry without duplicating math.

### 3.4 `dj_state`
* Owns the 3D Z-Stack (`std::vector<ZCard>`), zoom-out camera state, persistent **6-Kanji Compound Ring**, **16-Search History Ring**, active-recall display masks (`Full / Hide Kana / Hide Gloss`), and SRS flashcard progress (`user_state.db`).

---

## 4. C11 ABI Contract (`core/include/dj_capi.h`)

* **Memory Ownership:** Strings and arrays returned via `out_*` pointers live inside a per-engine arena buffer owned by `dj_engine_t` and remain valid until the next call on that handle—eliminating manual `free()` boilerplate across Swift and JNI.
* **Coordinate Space:** All spatial coordinates (`norm_x`, `norm_y`, `z_depth`, `blur_radius`, `scale`) are normalized floats ready for GPU shader uniforms.

---

## 5. Current Build System & Packaging (macOS)

* **Build:** The whole project builds with the **Swift Package Manager** (no
  `.xcodeproj`). `Package.swift` compiles the `core/` C++20 sources into the
  `DaiJishowCore` library, the pure-Swift morphology core into the dependency-free
  `DaiJishowMorph` library, and the `DaiJishowMac` SwiftUI app (which depends on
  both), targeting `.macOS(.v14)`. Run `swift build` at the repo root.
* **Native C interop:** `platform-apple/macOS/EngineBridge.swift` calls the C11
  ABI (`dj_capi.h`) directly and owns all app state (history/Z-stack, recall
  mode, kanji display mode, search). `GlassViews.swift` holds the views;
  `DaiJishowMacApp.swift` the scene, menu commands, and top bar; `AppChrome.swift`
  the About/Preferences windows.
* **Packaging:** `tools/build_app_bundle.sh` assembles `build/Dai-Jishow.app`
  (compiled executable + `AppIcon.icns` generated by `tools/make_icon.swift` from
  the 1024² iOS export + the ~221 MB self-contained `daijishow.db` + a real
  `Info.plist`), applies an **ad-hoc code signature**, and produces a
  **drag-to-Applications DMG** (`Dai-Jishow-<version>.dmg`: the app plus an
  `/Applications` symlink). Flags: `--release`, `--no-db`, `--symlink-db`,
  `--no-dmg`, `--skip-tests` (bypass the Swift regression gate for fast local iteration), `--skip-cpp-tests` (bypass the C++ core regression gate).
* **Morphology library & regression gate:** The pure conjugation / part-of-speech
  / pitch-accent logic — `Morph.inflections`, `Morph.senseTags`,
  `PitchAccentContour` (its `build` factory), `KanaNormalizer`, and the
  `InflectionForm` value type — lives in the dependency-free `DaiJishowMorph`
  Swift library (`Sources/DaiJishowMorph/`), extracted out of the `DaiJishowMac`
  executable so it can be unit-tested: SwiftPM cannot `@testable import` an
  *executable* target, so logic worth locking down must first live in a library.
  The move is behavior-preserving (bodies verbatim; only the entry point flattens
  from `EntryDetail` / `SenseItem` to plain `String` / `UInt64` params and the
  access level widens to `public`); `DaiJishowMac` then `import`s the library and
  adapts its own aggregates into the morpher's flat parameters at the two call
  sites in `EngineBridge.swift`.
* **Regression tests:** `Tests/DaiJishowMorphTests/` locks the morphology with
  **Swift Testing** (`@Suite` / `@Test` / `#expect`) — the chosen framework for all
  unit / backend / integration logic; **XCTest is reserved for UI automation**.
  The suite is hermetic (hand-built `(surface, kana, posMask)` fixtures, no
  ~221 MB corpus, no engine). `tools/build_app_bundle.sh` runs `swift test` as a
  **gate before `.app` / DMG assembly**, so a broken conjugation, POS verdict, or
  pitch contour can never ship.
   * **C++ core regression tests:** `core/test/` mirrors that gate on the *native*
     side, locking the pure, DB-free logic of `core/dj_nlp` and `core/dj_graph`
     that `swift test` (which builds only the Swift `DaiJishowMorph` library)
     **never compiles** — so without it a broken romaji transliteration or fisheye
     pair-head choice could ship a DMG. It is a hand-rolled, dependency-free C++
     harness in the spirit of `tools/dj_cli.cpp` (`dj_test.hpp`: a `TEST`
     registry + `CHECK` / `CHECK_EQ_STR` macros; `dj_test_main.cpp`: a `main()`
     that runs every registered thunk and exits non-zero on any failed `CHECK`):
     `test_romaji.cpp` pins the wa-puro state machine (morae, alternate spellings,
     youon glides, geminate / `t-`, syllabic-n, the katakana sweep, pass-through,
     `is_ascii_romaji`, `encode_utf8`), and `test_pair_head.cpp` pins
     `dj::select_pair_head` (the substitution of a hovered `(center, neighbor)`
     compound edge's *displayed* headword — shortest matching alt form wins). Both
     are pure, so they run without the ~221 MB corpus. `tools/build_cpp_tests.sh`
     compiles them (`clang++ -std=c++20 -Wall -Wextra -Wpedantic`, linking the
     two production translation units `romaji.cpp` + `fisheye.cpp` against system
     `sqlite3`) and runs the binary; `build_app_bundle.sh` invokes it as a
     **second gate**, right after `swift test`, so a regression aborts the build
     (proven: a deliberately-failing `CHECK` aborts *before* assembly). To make
     `select_pair_head` unit-testable it was promoted from the anonymous namespace
     in `fisheye.cpp` to **external** linkage (declared in `dj_internal.hpp`);
     its definition now sits after the `} // namespace` close so it still sees
     `utf8_to_cps_local`. Bypass for fast iteration with `--skip-cpp-tests`.
* **Naming:** The *code stem* — `DaiJishow`, `DaiJishowCore`, `DaiJishowMac`, and
  the `daijishow.db` bundle — is written fused on purpose: Swift / C++ / CMake
  identifiers and the compiled binary cannot carry a hyphen. The hyphenated
  *Dai‑Jishow* is the display/product name used in prose and the UI (see the
  README's "Naming" note), and it now extends to the **shipped `.app` bundle and
  DMG** — `build/Dai-Jishow.app` and `Dai-Jishow-<version>.dmg` set
  `CFBundleName` / `CFBundleDisplayName` to "Dai-Jishow" so the app presents as
  "Dai-Jishow" end-to-end (Finder, Dock, menu bar, and the About panel), even
  though the binary inside it stays `DaiJishowMac`.
* **Status:** Today the only shipped UI shell is **macOS**. The iOS/iPadOS,
  watchOS, and Android/Wear OS shells in the diagram above are designed but not
  yet implemented; the C++ core is shared and platform-neutral.
