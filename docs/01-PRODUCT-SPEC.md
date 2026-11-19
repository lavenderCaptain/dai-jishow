# 01 — Product & Feature Specification

Dai-Jishow fuses three paradigms into a single cohesive study and reference environment:
1. **Dokusha v1.5 (Palm OS):** Compound neighborhood exploration, 7-slot multi-radical intersection, two-tap boundary refinement, and active-recall display toggles.
2. **Dedicated-Dictionary "Jump" Lookups:** Instant recursive "jump" lookups on any word or kanji on screen, compound search over recent kanji, and deep specialized reference appendices.
3. **Live Spatial AR Lens:** Real-time camera & screen OCR with 3D-pinned furigana, adaptive *i+1* reading hiding, and split-screen reflowed reading.

> **Status snapshot (current macOS build).** The macOS desktop shell, the C++20
> core + C11 ABI, the corpus ETL + `daijishow.db`, and the Omni-search / word /
> kanji / fisheye / Z-Stack surfaces are **built and shipping**. The AR lens
> (1.3), SRS flashcards, *Keigo* ladders, monolingual *Kokugo* glosses, and the
> iOS/Watch/Android shells remain **designed, not yet built**. Within the macOS
> app, `Collocations` and `Keigo` corpus tables exist but are not yet populated.
> See `README.md` for the full "what's built / what's roadmap" list.

---

## 1. Core Functional Modules

### 1.1 Omni-Search & Dictionary Lookup (和英 / 英和 / 国語) — *Built (macOS)*
* **Unified Auto-Detecting Input:** Accepts Kanji, Kana, Wa-puro Romaji (`dzu/tzu`, `n'ya`, double-consonant small *tsu*, `toukyou` long vowels), English glosses, SKIP codes (`1-?-3`), or Four-Corner codes without manual mode switching.
* **Match Modes:** Exact, Initial (prefix), Any (substring), Longest Match, and Homonyms (same reading).
* **Reverse De-Inflection:** Automatically strips complex verb/adjective agglutinations (e.g., `食べさせられなかった` → `食べる`) and displays the morphological derivation chain.
* **Rich Entry Cards:**
  * Headword, kana reading, **Tokyo Pitch Accent step graph**, and corpus frequency badges (Novel / Anime / News / Spoken).
  * **Monolingual Toggle (`国語 / EN`):** Switch seamlessly between English glosses and native Japanese definitions (with every Japanese word tappable for recursive jumps).
  * **Transitive / Intransitive Verb Pair Link:** One-tap jump between *jidōshi* and *tadōshi* pairs (e.g., `開く` ↔ `開ける`).
  * **Keigo & Register Ladder:** Shows Casual, Polite (*Teineigo*), Honorific (*Sonkeigo*), and Humble (*Kenjōgo*) equivalents.
  * **Natural Collocations:** Statistical `Noun + を + Verb` and modifier pairings.
  * **Lemmatized Example Sentences:** Pre-indexed by lemma ID so conjugated forms appear automatically, with toggleable furigana and audio TTS.
* **Active-Recall Display Toggles:** Instant pills for `Full`, `Hide Kana`, `Hide Gloss`, `Kana Only`, and `Kanji Only`.

### 1.2 Kanji Reference & Dokusha Spatial Fisheye Explorer — *Built (macOS)*
* **Kanji Detail View:**
  * *On'yomi* (katakana) and *Kun'yomi* (hiragana with typographic `・` okurigana dots and `ー` suffix bars).
  * Stroke count, Jouyou/Jinmeiyou grade, JLPT level, Kanken level, Kangxi radical, JIS X 0208 code, SKIP, Four-Corner, *Kyūjitai* ↔ *Shinjitai* mapping, and phonetic component series.
  * **Interactive Stroke Order Diagram:** Vector playback powered by quantized KanjiVG paths.
* **Dokusha Spatial Fisheye Explorer:**
  * **Left / Right Compound Hemispheres:** Displays prefix-forming neighbors (`[Neighbor] + [Center]`, e.g., `愛称`) on the left and suffix-forming neighbors (`[Center] + [Neighbor]`, e.g., `称賛`) on the right, weighted by compound frequency and PMI.
  * **Two-Tap Interaction:** Single-tap a neighbor node to preview the 2-kanji compound and definition in the bottom ribbon; tap the same node a second time to smoothly re-center the fisheye on that kanji and push a new frame onto the 3D Z-Stack.
  * **Mode Switchers:** Toggle orbiting satellites between **2-Kanji Compounds**, **Yojijukugo (四字熟語)**, and **Look-Alike Confusables (類似漢字)**.
* **7-Slot Multi-Radical Builder:** Select up to 7 component radicals in a visual grid with stroke-count tolerance (`Exact`, `±1`, `±2`, `Auto`) to intersect matching kanji.

### 1.3 Live Camera & Screen Furigana Lens — *Planned (not built)*
* **Mode A — Spatially Pinned AR Overlay:** Runs on-device OCR + C++ MeCab tokenization and pins furigana in 3D/2D space above horizontal text or to the right of vertical (*tategaki*) text using 60/120 Hz optical-flow/rectangle tracking.
* **Mode B — Split-Screen Reflowed Reader:** Freezes or streams detected text into a clean, glare-free bottom reading pane with two-tap word boundary adjustment, contextual translation, and **Historical Era (`Gengō`) / Counter** auto-annotations.
* **Adaptive *i+1* Training Wheels:** Tracks kanji/words the user has mastered and automatically hides furigana on known vocabulary, showing readings only on unknown or recently missed words.
* **Multi-Word Idiom & Grammar Detection:** Highlights conjugated idioms (`猫の手も借りたい`) and compound grammar patterns (`〜に違いない`) inline.

### 1.4 Study Tools & History Rings — *Partial (macOS): history rings built; flashcards / Snarf planned*
* **Persistent 6-Kanji Ring & Compound Search:** Tracks the last 6 inspected kanji and allows one-tap `ALL` or `ANY` compound word searches across any subset.
* **16-Search History Ring:** Instant replay of recent queries.
* **Flashcards & "Snarf Unknown Kanji":** One-tap `◆` bookmarking on any word/kanji plus a **"Snarf Unknown Kanji"** batch extractor that pulls unmastered kanji from any camera scan or reading passage into a spaced-repetition queue.
