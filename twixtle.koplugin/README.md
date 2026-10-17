# Twixtle for KOReader 🎮✨

A **100% offline**, native KOReader word puzzle game featuring **550 hand-crafted and verified progressive levels**, high-contrast Carta 1300 E-Ink optimization, on-screen touch keyboard, and zero Wi-Fi dependencies.

---

## 🎯 Game Concept & Rules

Transform the **START** word into the **END** word in exactly **4 steps** using each of the 4 transformation rules **exactly once**:

```
[ START WORD ]
      │
      ▼  Step 1: (Rule A)
[ WORD 1 ]
      │
      ▼  Step 2: (Rule B)
[ WORD 2 ]
      │
      ▼  Step 3: (Rule C)
[ WORD 3 ]
      │
      ▼  Step 4: (Rule D)
[  END WORD  ]
```

### The 4 Transformation Rules:

1. **ANAGRAM**: Rearrange all the letters to form a new valid English word.
   - *Example:* `ARC` ➔ `CAR`, `HEART` ➔ `EARTH`, `LEMON` ➔ `MELON`
2. **COMPOUND**: Form a valid closed single-word compound by prefixing or suffixing a new word.
   - *Example:* `CAR` ➔ `SIDE` (*sidecar*), `SWEAT` ➔ `BAND` (*sweatband*), `FIRE` ➔ `FLY` (*firefly*)
3. **HOMOPHONE**: Swap for a word that sounds identical in English but is spelled differently.
   - *Example:* `SIDE` ➔ `SIGHED`, `FLOWER` ➔ `FLOUR`, `KNIGHT` ➔ `NIGHT`, `PEACE` ➔ `PIECE`
   - *Supports suffix propagation:* `SIDES` ➔ `SIGHS`, `FLOWERING` ➔ `FLOURING`
4. **VERB FORM**: Change to another grammatical inflection of the same English verb (e.g., base, past, past participle, present participle, 3rd person singular).
   - *Example:* `SIGHED` ➔ `SIGH`, `RUN` ➔ `RAN`, `WRITE` ➔ `WRITTEN`, `BREAK` ➔ `BROKEN`

### ★ Perfect Solve Mode
- Each level begins with the move pills displayed as **`?` (Hidden)**.
- If you deduce the entire chain without tapping any move pill to reveal hints, you earn a **★ PERFECT** gold star rating!
- Stuck? Tap any move pill to reveal its transformation type (`ANAGRAM`, `COMPOUND`, `HOMOPHONE`, `VERB`), or use the **💡 Hint** / **Give Up** options in the toolbar.

---

## 🌟 Why Native KOReader Plugin?

Earlier attempts to run web-based games via Kobo's built-in browser (`nickel_browser`) suffered from two fatal hardware/firmware bottlenecks:
1. **Wi-Fi Gatekeeping**: Kobo's stock browser forces an active Wi-Fi connection even when opening local `file:///` URLs.
2. **Outdated QtWebKit Engine**: The browser engine lacks modern ECMAScript support (ES6+), leading to silent syntax crashes and frozen, unresponsive touch screens.

**Twixtle KOReader Plugin** runs as a native Lua widget inside KOReader:
- 🚀 **100% Offline**: Never prompts for Wi-Fi or internet access.
- ⚡ **Zero-Latency Touch UI**: Built directly on KOReader's `InputContainer`, `ButtonTable`, and Carta 1300 e-ink refresh pipeline.
- 🔋 **Zero Battery Drain**: Event-driven rendering — only redraws on touch inputs; zero CPU usage while idling.
- 💾 **Safe Persistent Storage**: Automatically saves unlocked levels, completion times, and perfect solve stars in KOReader's native `LuaSettings` (`twixtle_settings.lua`).
- 📚 **Comprehensive Offline Dictionaries**: 74,500+ English vocabulary words, 1,900+ homophone mappings, 1,200+ closed compounds, and 3,100+ verb inflections bundled locally.

---

## 📱 Hardware & Firmware Compatibility

- **Devices**:
  - Kobo Clara BW (Carta 1300 E-Ink)
  - Kobo Clara 2E / Clara HD
  - Kobo Clara Colour / Libra Colour
  - Kobo Libra 2 / H2O
  - Kobo Sage, Forma, Elipsa, Nia, Aura
- **Software**: KOReader (v2023.x, v2024.x, v2025.x, v2026.x+)

---

## ⚡ Installation

### Option 1: Automatic Installer (Recommended)
1. Plug your Kobo e-reader into your computer via USB.
2. Open terminal and run:
   ```bash
   cd twixtle.koplugin
   ./install.sh
   ```
   *(Or from the repository root: `./install.sh twixtle`)*
3. Safely eject your Kobo e-reader.

### Option 2: Manual Installation
1. Mount your Kobo via USB.
2. Copy the entire `twixtle.koplugin` folder to:
   ```
   [KOBO_DRIVE]/.adds/koreader/plugins/twixtle.koplugin
   ```
3. Safely eject your device.

---

## 🕹️ How to Launch in KOReader

1. Open **KOReader** on your Kobo.
2. Tap the top menu bar.
3. Navigate to:
   - **Tools (Magnifying Glass / Gear icon)** ➔ **More tools** ➔ **Twixtle**
   *(or under Games menu depending on your KOReader menu configuration)*
4. The full-screen Twixtle interface will open instantly!

---

## 🧪 Quality Assurance & Stress Testing

Twixtle includes a comprehensive LuaJIT test and stress testing suite in `tests/test_twixtle.lua`:
- **Vocabulary Coverage**: 74,508 words loaded and queried.
- **Rule Verification**: Comprehensive edge-case tests across anagrams, compounds, homophones (with suffix propagation), and regular/irregular verb forms.
- **Full Level Verification**: All 550 levels (2,200 individual transitions) programmatically solved and verified legal against the dictionary engine in `< 0.005s`.
- **Game Engine Playthrough Simulation**: Full automated playthrough of all 550 levels end-to-end.
- **Memory & Garbage Collection Stability**: Memory delta across 550 consecutive level loads and solves remains under **0.16 MB**, guaranteeing rock-solid stability on 512 MB Kobo RAM.

Run the test suite on your workstation with:
```bash
luajit tests/test_twixtle.lua
```

---

## 📄 License

GPLv3. See [LICENSE](../LICENSE) for details.
