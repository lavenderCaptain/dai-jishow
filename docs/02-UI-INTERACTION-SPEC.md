# 02 — UI & Interaction Specification (Liquid Glass & Focus + Context)

Dai-Jishow abandons conventional nested menus, sidebars, and modal dialogs in favor of a spatial **Focus + Context** paradigm rendered with translucent **Liquid Glass** materials.

> **Status snapshot.** The macOS desktop shell ships today. The **Z-Stack
> navigation deck**, single-window liquid-glass surface, **Reader/Cockpit**
> word entry, **Kanji detail** with a "Vocabulary & Compounds" display-mode
> switch, the **Fisheye** explorer, **Word Cosmos**, **Recall** modes,
> **hover tooltips** on every control, **text selection + copy**, and an
> **About / Preferences** window are all **built**. The 3D "Time Machine" zoom,
> the **Radial Bloom** selection menu (§3), and the multi-device matrix (§5) are
> **designed, not yet built**. See §6 for the current macOS layout.

---

## 1. Visual Language: Liquid Glass

* **Depth-Layered Translucency:** Every active surface is rendered as a frosted, refractive glass pane floating in Z-space (`Z = 0` for active focus; `Z = -1, -2, ...` for receding context).
* **Refractive Rim & Edge Highlights:** Subtle specular edge highlights separate overlapping cards without heavy opaque borders, allowing the underlying kanji graph or live camera feed to bleed softly through.
* **Adaptive Contrast:** Japanese typography (headwords, furigana, stroke diagrams) renders at crisp high contrast on top of dynamically blurred backdrop layers (`Gaussian blur + luminance clamping`) so readability never degrades over busy camera backgrounds.

---

## 2. The 3D Time Machine Z-Stack

Instead of flat page replacement or a cramped text breadcrumb bar, every lookup step pushes a new glass frame forward along the Z-axis—inspired by macOS Time Machine and classic console "zoom-out for commentary" framing.

### 2.1 Depth States
* **Focus Mode (`Zoomed In`, Default):**
  * The active card sits at `Z = 0` (`scale = 1.0`, `blur = 0`).
  * Previous cards recede backward (`Z = -1`, `Z = -2`, `Z = -3`), scaling down slightly (`0.94^|z|`), shifting upward slightly, and gaining progressive backdrop blur.
* **Context Mode (`Zoomed Out`):**
  * **Triggers:** Trackpad two-finger pinch-out (macOS), screen pinch-out (iOS/iPadOS), `Esc` key, top-bar `Zoom Out` toggle, or Digital Crown / rotary scroll (watchOS/Wear OS).
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

---

## 5. Multi-Device Adaptation Matrix

| Feature | macOS Desktop | iPhone / iPad | Apple Watch / Wear OS |
| :--- | :--- | :--- | :--- |
| **Z-Stack Scrubbing** | Trackpad pinch + scroll wheel + `←/→` keys | Edge swipe + two-finger pinch | **Digital Crown / Rotating Bezel** |
| **Fisheye Node Count** | 30–40 neighbors (15–20 per side) | 20–24 neighbors (10–12 per side) | **6 neighbors (3 Left + 3 Right)** |
| **Camera / Lens** | Continuity Camera, Screen-Region OCR, File/Clipboard | Live 60/120 Hz AR camera + Split-Screen Reader | Voice dictation, Scribble/Handwriting, Synced Cards |
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
  dropdown and a clear button.
* **Kanji Index**, **Radicals** (builder), **Word Cosmos** buttons.
* **Names** toggle (include proper names), a segmented **Recall** picker
  (*Full / Hide Kana / Hide Gloss*), and **recent-kanji** chips.
* **Every control carries a hover tooltip** explaining what it is / does.

### 6.2 Word Entry (Reader / Cockpit)
* **Hero card:** ruby headword, **pitch-accent contour**, **telemetry pills**
  (frequency tier, JLPT, grade, stroke count), a **corpus-frequency meter**, and
  "also written as" variant chips — each with a tooltip.
* **Reader / Cockpit** toggle and a **Gloss Language** toggle (EN / JA / Both),
  both persisted in `UserDefaults`.
* **Cockpit dashboard:** Kanji DNA strip, POS-tagged **Definitions**, a
  **自他 pair** banner, **Homonyms** (同音異義語), **Word Family** (prefix/suffix
  compounds), **Corpus Collocations**, **Example Sentences**, and a **conjugation
  matrix**.
* **Pills that would clip off-screen** (Homonyms, Compounds, Collocations) now
  **wrap to multiple rows** and show the **top 10** with a **"Show more / Show
  Less"** button — no horizontal scroll, nothing cut off.

### 6.3 Kanji Detail
* Glyph with **animated KanjiVG stroke vectors**, on/kun readings, full metadata,
  and a **"Vocabulary & Compounds Containing …"** list with a **display-mode
  switch**: **Prevalence** (most-common-first, the default) / **Starts with** /
  **Ends with** — persisted per user. A counter reads "X of Y words" and an
  empty-state message appears when a filtered view has no matches.

### 6.4 Navigation, Feedback & Packaging
* **Z-Stack deck** (⌘\\) scrubs the lookup trail; **Word Cosmos** (⌘⇧W) is a
  randomized prevalence bubble cloud; ⌘⇧C toggles Cockpit.
* **Text selection + copy** is enabled on entries, kanji detail, and the search
  dropdown, with context menus and a **⌘⌥C "Copy Entry"** command (native ⌘C for
  selections).
* **About** (version + source/license credits) and **Preferences** windows.
* The app is packaged as a signed **`.app`** and a **drag-to-Applications DMG**
  (`tools/build_app_bundle.sh`) containing the app + an `/Applications` symlink.
