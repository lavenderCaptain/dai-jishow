# 02 — UI & Interaction Specification (Glass Material & Focus + Context)

Dai-Jishow abandons conventional nested menus, sidebars, and modal dialogs in favor of a spatial **Focus + Context** paradigm rendered with translucent **glass** materials.

> **Status snapshot.** The macOS desktop shell ships today. The **Z-Stack
> navigation deck**, single-window glass surface, **Reader/Detailed**
> word entry, **Kanji detail** with a "Vocabulary & Compounds" display-mode
> switch, the **Fisheye** explorer, **Word Cloud**, the **Compound Kanji**
> decomposer, **Recall** modes,
> **hover tooltips** on every control, **text selection + copy**, and an
> **About / Preferences** window are all **built**. The 3D **Zoom-Out Z-Stack**,
> the **Radial Bloom** selection menu (§3), and the multi-device matrix (§5) are
> **designed, not yet built**. See §6 for the current macOS layout.

---

## 1. Visual Language: Glass Material

* **Depth-Layered Translucency:** Every active surface is rendered as a frosted, refractive glass pane floating in Z-space (`Z = 0` for active focus; `Z = -1, -2, ...` for receding context).
* **Refractive Rim & Edge Highlights:** Subtle specular edge highlights separate overlapping cards without heavy opaque borders, allowing the underlying kanji graph or live camera feed to bleed softly through.
* **Adaptive Contrast:** Japanese typography (headwords, furigana, stroke diagrams) renders at crisp high contrast on top of dynamically blurred backdrop layers (`Gaussian blur + luminance clamping`) so readability never degrades over busy camera backgrounds.

---

## 2. The 3D Zoom-Out Z-Stack

Instead of flat page replacement or a cramped text breadcrumb bar, every lookup step pushes a new glass frame forward along the Z-axis—inspired by zoom-out-for-context navigation and classic console "zoom-out for commentary" framing.

### 2.1 Depth States
* **Focus Mode (`Zoomed In`, Default):**
  * The active card sits at `Z = 0` (`scale = 1.0`, `blur = 0`).
  * Previous cards recede backward (`Z = -1`, `Z = -2`, `Z = -3`), scaling down slightly (`0.94^|z|`), shifting upward slightly, and gaining progressive backdrop blur.
* **Context Mode (`Zoomed Out`):**
  * **Triggers:** Trackpad two-finger pinch-out (macOS), screen pinch-out (iOS/iPadOS), `Esc` key, top-bar `Zoom Out` toggle, or crown / rotary scroll (watchOS/Wear OS).
  * **Spatial Layout:** The camera pulls back into a three-quarter isometric view displaying the entire card stack simultaneously, connected by subtle luminous tether lines showing which character spawned the next card.
  * **Peripheral Coaching Panels:** Zooming out reveals ambient side panels around the stack:
    1. **6-Kanji Compound Ring:** The last 6 inspected kanji with toggles for `ALL` / `ANY` compound searches.
    2. **Session Study Extractor:** One-click **"Snarf Trail Kanji"** button to queue unmastered kanji from the current trail into flashcards, plus session JLPT/frequency stats.
  * **Direct Jump:** Clicking or tapping any card at `Z = -N` brings that frame smoothly to `Z = 0` (either popping forward or reordering the stack).

---

## 3. Focus + Context Radial Bloom (Selection Menu)

Whenever the user clicks or taps a Japanese word or kanji (in a definition, an example sentence, the split-screen reader, or an AR camera frame):

1. **In-Place Magnification:** The selected token scales up (`1.35x`) and lifts forward slightly (`Z = +0.2`) while surrounding text dims and blurs slightly.
2. **Orbital Satellites:** 4 to 6 translucent glass pills bloom in a circular arc around the magnified token:
   * **Kanji Satellites:** `Explorer` (Dokusha Fisheye), `Kanji Details`, `Stroke Order`, `Compounds`, `+ Flashcard (◆)`, `+ 6-Kanji Ring`.
   * **Word Satellites:** `Definition`, `Examples`, `Homonyms`, `Break Down Kanji`, `Audio TTS`, `+ Flashcard (◆)`.
3. **Marking-Menu Gesture:** On pointer/touch devices, users can click/tap to open the satellites *or* press-drag directly toward a satellite pill and release in a single fluid motion.

---

## 4. Dokusha Spatial Fisheye Kanji Explorer

* **Hemispherical Layout:**
  * **Center (`0, 0`):** Focal kanji with reading summary and stroke trigger.
  * **Left Hemisphere (`x < 0`):** Prefix-forming neighbors (`[Neighbor] + [Center]`, e.g., `愛称`).
  * **Right Hemisphere (`x > 0`):** Suffix-forming neighbors (`[Center] + [Neighbor]`, e.g., `称賛`).
* **Fisheye Distortion & Prevalence Weighting:**
  * Node radius, font weight, and opacity scale with compound frequency / Pointwise Mutual Information (PMI).
  * Moving the cursor or dragging a finger warps nearby nodes smoothly using a polar fisheye lens function (`dj_graph_solve_fisheye`).
* **Two-Tap Navigation Rule:**
  * **1st Tap:** Highlights the edge and previews the resulting compound (`word`, `kana`, `English gloss`) in the bottom glass ribbon.
  * **2nd Tap (same node):** Re-centers the explorer on that kanji and pushes a new Explorer frame onto the 3D Z-Stack.
* **Orbit Mode Switcher:** Toggle orbiting nodes between **2-Kanji Compounds**, **Yojijukugo (四字熟語)**, and **Look-Alike Confusables (類似漢字)**.
* **Tier Legend:** A **Core / Jōyō / Literary / Kyūjitai** color key (matching the
  node `tierColor` tiers) sits in the explorer's top bar so the prevalence
  coloring is always decoded at a glance. Each dot carries a **hover tooltip**
  explaining its tier's frequency threshold (Core ≤ 2,500 · Jōyō ≤ 12,000 ·
  Literary > 12,000 · Kyūjitai = ungraded / non-Jōyō).
* **Toggle Tooltips:** The **% Share** toggle and the **Top-N /side** menu also
  carry hover tooltips — the former explains that it swaps a node's prevalence
  color for its share of the center kanji's compound frequency; the latter
  explains how many neighbors to show per side of the center kanji.

---

## 5. Multi-Device Adaptation Matrix

| Feature | macOS Desktop | iPhone / iPad | Apple Watch / Wear OS |
| :--- | :--- | :--- | :--- |
| **Z-Stack Scrubbing** | Trackpad pinch + scroll wheel + `←/→` keys | Edge swipe + two-finger pinch | **Crown / Rotating Bezel** |
| **Fisheye Node Count** | 30–40 neighbors (15–20 per side) | 20–24 neighbors (10–12 per side) | **6 neighbors (3 Left + 3 Right)** |
| **Camera / Lens** | Camera scan, Screen-Region OCR, File/Clipboard | Live 60/120 Hz AR camera + Split-Screen Reader | Voice dictation, Handwriting input, Synced Cards |
| **Active Recall** | Keyboard shortcuts (`1/2/3`) for `Full / Hide Kana / Hide Gloss` | Top glass toggle pills | Tap-to-reveal reading/gloss on card |

---

## 6. Current macOS Implementation (what ships today)

A single, tab-free glass window (`1320 × 880`, one `Window` scene — no double
vision, no tab bar). Layout:

### 6.1 Top Bar
* **Navigation cluster:** Back / Forward chevrons (disabled at the ends) and a
  **Z-Stack history** button whose badge shows the ring count — the badge reserves
  two-digit width so it never squashes past 9 entries.
* **Omni-search field:** kanji / kana / romaji / English, with a live results
  dropdown and a clear button. The dropdown's large result sets (e.g. `DJ_SEARCH_AUTO`
  up to 40 hits) can be narrowed **instantly, without re-querying**, via a sticky row
  of **quick-filter chips** — *Common* (overall frequency rank ≤ 12,000 / Jōyō band),
  *Nouns*, *Verbs* (ichidan/godan/other verb forms), *Adjectives* (i- and na-),
  *Adverbs*, *Particles*, plus JLPT / grade chips — *N5…N1* and *Grade 1–3*, each
  derived from a word's hardest / highest head-kanji level (kana-only words match none) — plus a **Clear** control. Each chip carries its own **tint** (a colour-coded legend:
  teal/blue/orange/purple/green/indigo for POS, a green→red ramp for JLPT, and a
  slate ramp for grade), shown as a leading dot with a tinted
  outline when inactive and a filled tint when active; chips stay active across
  searches, and an empty-state message appears when the filters match nothing.
   **English-gloss section (always-on, unified):** for a romaji-looking query that
   *also* names a real English word (e.g. *sake* → *さけ* alcohol/salmon, *and* the
   English "sake / benefit"), the engine runs the English-gloss FTS index *in addition*
   to the Japanese lookup and shows a labeled **"Also in English glosses"** section
   in a narrower right-hand column *beside* the main results (the card widens to
   fit; Jisho.org-style, no toggle, so it never slows a lookup).
   It is deduped against the main list, so no entry appears twice, and is skipped for
   kanji/kana queries. As a special case, when a clean-romaji query transliterates to
   kana that matches nothing (e.g. *bore* → *ぼれ*), those English-gloss results
   populate the main list directly, so the dropdown is never empty.
    **Reverse lookups (capability note):** this is a genuine *English → Japanese*
    reverse lookup — type an English word and the engine returns the Japanese
    entries whose sense-0 gloss matches (e.g. *sake* → 酒/鮭 *and* 為 *benefit*),
    plus the romaji → kana/kanji direction (*sake* → *さけ*). It is **not** a full
    bidirectional English↔Japanese dictionary: the engine's spine is
    Japanese-headword → definition, so English is a *supplementary, relevance-ranked*
    match path (FTS5 over `en_glosses`, re-ranked by `english_gloss_relevance_tier`,
    capped, deduped against the main list, and shown only for ASCII queries with
    ≥ 2 chars). The Japanese→English "find me an English word" direction is not a
    distinct search axis today, and richer English-anchored reverse lookup
    (full-string / multi-gloss ranking, English proper names) is a planned
    expansion, not the current design.
* **Names** toggle (include proper names — with a graceful **auto-nudge** when a
  proper name is the search's best match but is hidden by Names being off; see
  §6.5), a segmented **Recall** picker
  (*Full / Hide Kana / Hide Gloss*), and **recent-kanji** chips.
* **Every control carries a hover tooltip** explaining what it is / does.

### 6.2 Word Entry (Reader / Detailed)
* **Hero card:** ruby headword with the **primary meaning** (the most-common
  sense's gloss, in the chosen language) shown **beside the kanji, level with it**,
  then the **pitch-accent contour**, **telemetry pills**
  (frequency tier, JLPT, grade, stroke count), a **corpus-frequency meter**, and
  "also written as" variant chips — each with a tooltip.
* **Reader / Detailed** toggle and a **Gloss Language** toggle (EN / JA / Both),
  both persisted in `UserDefaults`.
* **Detailed dashboard:** a wrapping **Kanji DNA** strip, POS-tagged
  **Definitions**, a **自他 pair** banner, **Homonyms** (同音異義語), **Word
  Family** (prefix/suffix compounds), **Corpus Collocations**, **Example
  Sentences**, and a **conjugation matrix** for verbs / adjectives.
* **Pills that would clip off-screen** (the Kanji DNA strip, Homonyms,
  Compounds, Collocations) now **wrap to multiple rows** — no horizontal
  scroll, nothing cut off — and show the **top 10** with a **"Show more / Show
  Less"** button. The engine now surfaces a deeper pool behind that button
  (up to **24** homonyms; up to **16** prefix + **16** suffix compounds; up to
  **120** kanji vocabulary), so "Show more" stays meaningful past the first
  ten.
* **Corpus Collocations** shows, for the word, the particles that sit next to
  it in its example sentences; each chip reads `pattern ×N`, where the `×N`
  count is how many of those example sentences use the pairing (a
  relative-frequency signal: higher = a more typical neighbour). Both the
  section header and every chip carry a **hover tooltip** — the chip tooltip
  decodes the `〜`-marked slot, names the grammatical role (Modifier /
  Preceding / Following Particle / Adjectival), and explains the `×N` count.
* **Open the Compound Kanji screen:** the **Kanji DNA** strip's header carries an
  **"Open compound breakdown ↗"** button that seeds the dedicated Compound Kanji
  screen (§6.4) with *this* word, so you can pivot from a word's quick per-kanji
  strip to the full, interactive decomposition (each part inspectable on its own).

### 6.3 Kanji Detail
* Glyph with **animated KanjiVG stroke vectors**, on/kun readings, full metadata,
  and a **"Vocabulary & Compounds Containing …"** list with a **display-mode
  switch**: **Prevalence** (most-common-first, the default) / **Starts with** /
  **Ends with** — persisted per user. A counter reads "X of Y words" and an
  empty-state message appears when a filtered view has no matches.

### 6.4 Compound Kanji
* **The screen:** a dedicated **Compound Kanji** view that decomposes any
  multi-kanji word into its individual kanji, each inspectable on its own — the
  "Kanji DNA" strip of a single word, elevated to a first-class, interactive
  screen. Reached two ways: a **4th top-bar button** ("Compounds", the same
  icon-collapsing treatment as the other three screens) and the **"Open compound
  breakdown ↗"** button on a word entry's **Kanji DNA** strip (§6.2), which seeds
  the screen with *that* word.
* **Header card:** the headword with **furigana over each glyph** (per-kanji
  ruby, from the engine's `rubyCells`), the **kana reading**, and the **primary
  gloss**. A **"Show in context"** button (top-right, next to the headword
  speaker) is the **inverse of "Open compound breakdown ↗"**: it jumps from this
  decomposition back to the word's **full dictionary entry** (definitions,
  example sentences, inflections) so a decomposition never strands you away from
  the word itself — `openWordEntry` for the same headword you are decomposing.
* **Reading insight — "compound ≠ sum of parts":** a card that lays each **ruby
  cell's** reading beside the compound's overall reading, joined with `+` then
  `→` (e.g. 日本 (にほん) + 語 (ご) → 日本語 (にほんご)). The cell is the right
  granularity: the corpus bundles multi-kanji subwords (e.g. 日本 → にほん) into
  one ruby cell, so iterating *per-kanji* on-readings would misleadingly imply
  日本語 is read ニチ + ホン + ご. Each cell shows its furigana over its surface
  (in cyan), matching the header card; a cell with no recorded reading shows a
  muted "—". When a part is flagged **`isJukujikun`** it is highlighted with a
  **熟字訓**
  note ("a meaning-based reading not in its own standard on/kun set") — the
  pedagogically interesting case the screen exists to surface. Jukujikun is a
  *single-kanji* phenomenon, so a multi-kanji cell (e.g. 日本, an on-reading
  compound with 連音) is never flagged; only a single-kanji cell whose furigana
  matches none of its on/kun readings is.
* **Per-kanji cards:** a wrapping grid, one card per kanji — glyph, **on + kun**
  readings (the *matched* reading highlighted in its row), **meaning**,
  **JLPT / grade / stroke** pills, and a **熟字訓** chip when applicable — each
  with a **speaker button** (hears the kanji's reading — its in-compound reading
  when the corpus records one, else its on-reading — for
  audible review, reusing `SpeakerButton`) and two drills: **Detail** (→ the
  kanji's detail page) and **Graph** (→ that kanji's *own* single-kanji compound
  graph; labeled "Graph" with the `circle.hexagongrid.fill` glyph, matching the
  "Explore Compound Graph" wording used elsewhere). A literal multi-centered
  "fisheye of fisheyes" for the *whole* compound is a **deliberate later step** —
  each kanji drills into its single-center graph today.
* **Seeding / empty state:** the on-screen search (or one of the **example-word
  chips**) resolves a typed word to an entry (preferring a multi-kanji exact
  hit); opening from a word's strip seeds that word; a bare top-bar open falls
  back to the current word when it is multi-kanji, else a curated default compound.
  A **kana-only** word shows a "no kanji to decompose" nudge, and a screen opened
  with no word shows the example chips to start from.
* **Name-search resilience:** a typed word may be a proper name, which the exact
  search skips unless "Names" is on. The compound search **retries with names
  forced on** when the first pass returns nothing (mirroring the omni-search's
  auto-enable), and if *that* still finds nothing it surfaces a **"No compound
  found for …"** notice under the field rather than failing silently.
* **Recent-kanji examples:** the "Try:" chips lead with the **most frequent
  compound for each of the 6 recent kanji** (one chip per recent kanji,
  de-duplicated by word, capped at 4) so the examples track what the user has
  been studying; canonical example words fill out the row when the ring is sparse.
* **Unmistakable field, good layout:** on this screen the **top omni-search is
  hidden** and the screen's own field is **prominent and autofocuses on arrival**
  — it is the field the user kept mistaking for the top search bar. The whole
  screen is wrapped in a `ScrollView` (like its siblings), so a tall
  decomposition never overflows into the window-shade band or centers awkwardly.
* **Audible review & copy:** a **speaker button** on the header card hears the
  headword's kana aloud; each kanji card carries its own. The screen opts into
  **`.textSelection(.enabled)`** and a right-click **context menu** (Speak
  Headword / Copy Entry / Copy Headword), so nothing is un-copyable.
* **No new core data:** the screen is a pure-SwiftUI composition over the
  engine's existing per-kanji `kanjiDNA` (built by `build_per_kanji_ruby`), so
  each part's readings/meaning/level and the 熟字訓 flag come straight from the
  engine — the drills reuse `openKanjiDetail` / `openFisheye`, and the screen is
  part of the Z-Stack history (a breadcrumb that restores to the same word).

### 6.5 Navigation, Feedback & Packaging
* **Z-Stack deck** (⌘\\) scrubs the lookup trail; **Word Cloud** (⌘⇧W) is a
  randomized prevalence bubble cloud whose bubbles can be **tinted by difficulty** — a **Color** control (the control bar) switches between **Prevalence** (the frequency tiers), **JLPT** (a green→red N5…N1 ramp from the word's hardest head-kanji level), and **Grade** (a light→deep slate ramp from its highest head-kanji grade; kana-only words get a neutral dot); ⌘⇧C toggles the **Detailed** view. In the **ranked** layout each row carries the frequency-tier chip *plus* a **JLPT** chip and a **grade** chip (when the word has a head kanji to derive them from), each self-documenting via tooltip.
* **JLPT / grade guidance:** the JLPT legend, the ranked-row JLPT chip, and the
  JLPT search-filter chips all draw from one canonical source
  (`jlptLevelDescription(_:)` — N5 basic kana/short conversations → N1 abstract
  editorials/critiques), so every surface agrees on *what a level means*, not
  just which words match. The grade ramp runs **G1 (earliest, most basic) → G10
  (latest, most advanced)** — grades 7–10 mark high-school / Jōyō / Jinmeiyō /
  variant kanji rather than a single school year.
* **Hear it — native Japanese TTS:** a speaker button beside the headword (a
  full capsule in the hero card, plus a "Speak Headword" context-menu item) and
  a compact icon at the top-right of every example-sentence row, each using a
  single shared `AVSpeechSynthesizer` (ja-JP). Taps are strictly user-initiated
  (never auto-play), and a new tap cancels the in-flight utterance so rapid
  clicks never overlap. The voice speaks the **kana headword** and each
  sentence's **full Japanese text** at ~0.9× the default rate, preferring a
  premium-quality voice when one is installed. Because Japanese is a *downloadable*
  system voice, the engine checks for an installed `ja` voice: when none is
  present every button is **disabled with a tooltip** pointing to *System Settings
  ▸ Speech ▸ System Voice ▸ Manage Voices* rather than silently doing nothing.
  Note the pitch-accent diagram (`PitchAccentContourView`) is a *learning* asset —
  `AVSpeechSynthesizer` has no per-mora pitch control, so the voice speaks its own
  standard accent; the speaker is "hear the standard reading", not a re-render of
  the diagram's downstep.
* **Proper-name auto-nudge** (the top-bar **Names** toggle, `includeNames`): with
  Names **off**, the omni-search excludes proper names (`is_name = 1`), so a place
  like **Akihabara** can hide its real answer — 秋葉原 — behind the only visible
  result, an event compound such as 秋葉原通り魔事件. The detection is precise:
  proper names carry a *frequency sentinel*, and the AUTO search orders by
  *exact-head-then-frequency*, so a name lands at **#1 only when no common word has
  an exact reading match for it** (verified: it does **not** fire on ordinary words
  like *aoi* / *yuki* / *michi*, whose common reading always outranks the name
  homonym). On the debounced settle of a Names-off search the engine runs one small
  speculative Names-on search; if its top hit is a proper name, it acts **on the
  user's behalf** — flips **Names** on (re-running the search via the toggle's
  `.onChange`), **flashes the toggle** so the result shift reads as "this control
  just changed", and shows a one-line **fading banner** at the top of the results
  (*"Found the name 秋葉原 · Names turned on · Undo"*). The intent is honoured: a
  **manual off** switches the nudge to a *non-flipping* "you might want to turn it
  back on" **suggestion** (same banner, *"Turn on Names"* instead of *"Undo"*), and
  a query the user has **undone or dismissed** is not re-nudged until they run a new
  one. The banner auto-dismisses after ~6 s.
* **Window behaviour** (the title bar is hidden, so the usual affordances are
  re-installed by a transparent top-bar handle — `WindowZoomHandle` /
  `WindowFrameCoordinator`): **drag** the window from its empty top bar;
  **double-click** the top bar to **zoom/restore** (toggle between the maximised
  "standard" size and the previous size, via AppKit's native `zoom(_:)`); the
  window **remembers its last size & position** (persisted to `UserDefaults`) and
  on launch **validates** the saved frame — a corrupt or off-screen save falls
  back to a centred **1320×880** default rather than launching crunched.
* **Anti-crunch layout:** the Fisheye control bar (Graph Mode picker, Top-N menu,
  % Share, colour legend) **wraps** instead of squashing when the window
  narrows — the interactive controls stay fixed-width and legible while the
  decorative legend drops to its own row, so the "Graph Mode" label never
  collapses into a multi-line mess.
* **Icon-collapse ("crunch to icon"):** the top-bar **Kanji Index / Radicals /
  Word Cloud / Compounds** buttons and the Word Cloud control bar's **Roll / Sample / Color**
  controls **drop their text label and show the icon only** when the row is too
  narrow to fit it, so a label never spills onto a second line. Each row measures
  its own width (`measureWidth(into:)` in `AdaptiveControls.swift`) and gates the
  collapse on a named threshold (the top-bar cluster is sized for **four** screen
  buttons); a **tooltip is always attached**, so a collapsed
  icon stays self-documenting.
* **Legend tooltips:** the Word Cloud colour legend carries a per-dot tooltip
  (its meaning) *and* an overall tooltip, so when the window is narrow and only
  the dots show (no words) the legend still explains itself — the same
  "dots-only" case the Fisheye legend already covers.
* **Text selection + copy** is enabled on entries, kanji detail, and the search
  dropdown, with context menus and a **⌘⌥C "Copy Entry"** command (native ⌘C for
  selections).
* **About** (version + source/license credits) and **Preferences** windows.
* The app is packaged as a signed **`.app`** and a **drag-to-Applications DMG**
  (`tools/build_app_bundle.sh`) containing the app + an `/Applications` symlink.
