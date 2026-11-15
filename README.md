# Dai-Jishow (大辞書)

**Dai-Jishow** is an encyclopedic, zero-bloat, offline-first Japanese–English and Japanese–Japanese dictionary, kanji explorer, and live AR reading lens built in **C++20** with native **Liquid Glass** frontends for **macOS, iOS/iPadOS, watchOS, Android, and Wear OS**.

## Design Philosophy

1. **Zero Framework Bloat:** Inspired by classic dedicated electronic dictionaries (Canon WordTank) and Palm OS utilities (Dokusha v1.5), the entire core engine, morphological analyzer, graph solver, and state machine live in pure **C++20** exposed via a flat **C11 ABI (`dj_capi.h`)**. No Electron, no web views, and `< 20 MB` active RAM via read-only memory-mapped SQLite (`mmap`).
2. **Focus + Context Everywhere:** Navigation abandons flat page reloads in favor of a **3D Time Machine Z-Stack** ("Zoom Out" for spatial trail context) and a **Radial Bloom** selection menu around any tapped character or word.
3. **Encyclopedic Offline Depth:** Merges JMdict, JMnedict, KANJIDIC2, KanjiVG, Kanjium pitch accents, BCCWJ/Jiten frequency profiles, Tatoeba lemmatized sentences, *Yojijukugo* / idioms / proverbs, monolingual *Kokugo* glosses, collocations, and *Keigo* register ladders into a single unified database.

## Repository Layout

* `docs/` — Complete product, UI/interaction, architecture, and corpus specifications.
* `core/` — Platform-agnostic C++20 engine (`dj_storage`, `dj_nlp`, `dj_graph`, `dj_state`, `dj_capi`).
* `tools/corpus-builder/` — Offline Python/C++ ETL compiler that builds `daijishow.db`.
* `platform-apple/` — Native SwiftUI + Metal + Apple Vision shells (macOS, iOS/iPadOS, watchOS).
* `platform-android/` — Native Jetpack Compose + AGSL + ML Kit shells (Android, Wear OS).

## Roadmap

- [x] **Phase 0:** Reverse-engineer Dokusha v1.5 interaction model & design interactive macOS Liquid Glass prototype.
- [ ] **Phase 1:** Build `tools/corpus-builder` ETL pipeline and compile unified `daijishow.db`.
- [ ] **Phase 2:** Implement `core/` C++20 engine + `dj_capi.h` + sub-millisecond CLI test suite.
- [ ] **Phase 3:** Build **macOS Desktop** native SwiftUI + Metal application.
- [ ] **Phase 4:** Extend Apple shells to **iPhone/iPad** (Live AR Camera) and **Apple Watch** (Digital Crown Z-stack).
- [ ] **Phase 5:** Port native UI shell to **Android** and **Wear OS** over `libdaijishow.so`.
