> [!IMPORTANT]
> **Recommended:** For the best offline experience without Kobo Nickel browser Wi-Fi prompts or QtWebKit latency, use the native KOReader plugin: [**`twixtle.koplugin`**](../twixtle.koplugin/).

# Twixtle for Kobo eReader (Legacy Web App)

A lightweight, offline, E-Ink optimized word transformation game designed for Kobo's built-in browser via NickelMenu.

Faithfully recreates the daily word game from [twixtle.games](https://twixtle.games/) with **550 offline verified levels** and a sequential level-progression system.

---

## 📸 Screenshots & Integration

Twixtle launches seamlessly from Kobo's **NickelMenu** popup right alongside **KOReader**, **Sudoku**, and **Solitaire**:

```text
NickelMenu
 ├── KOReader
 ├── Sudoku
 ├── Solitaire
 └── Twixtle ◄── Launches offline modal web app
```

---

## 🎯 Gameplay Rules

Transform a **START** word into an **END** word in exactly 4 steps using each of the 4 move types once:

| Move Type | Rule | Example |
| :--- | :--- | :--- |
| **ANAGRAM** | Rearrange the letters to form a new valid word. | `ARC` ➔ `CAR`<br>`HEART` ➔ `EARTH` |
| **COMPOUND** | Combine with the current word to form a single closed compound word. | `CAR` ➔ `SIDE` (*sidecar*)<br>`SWEAT` ➔ `BAND` (*sweatband*) |
| **HOMOPHONE** | Swap for a word that sounds identical but is spelled differently. | `SIDE` ➔ `SIGHED`<br>`FLOWER` ➔ `FLOUR` |
| **VERB** | Change to another grammatical tense or inflection of the same verb. | `SIGHED` ➔ `SIGH`<br>`RUN` ➔ `RAN` |

### ★ Perfect Mode
- Each connector between words displays as a mystery pill (`?`).
- Solve the level without revealing any move types to earn a **Gold Star ★**!
- If you get stuck, tap any `?` pill to reveal that move type as a hint.
- Tap **💡 Word Hint** to reveal the starting letters of the target word if needed.

---

## ⚡ E-Ink Carta 1300 Optimizations

1. **Monochrome High Contrast**: Pure `#000000` text and borders on `#ffffff` backgrounds. Crisp 2px/3px borders, no washed-out grays.
2. **Zero Screen Flickering / Strobing**: All CSS transitions and animations are strictly disabled (`animation: none !important; transition: none !important;`). The display only refreshes upon user touch.
3. **Built-in On-Screen QWERTY Keyboard**: Sized with comfortable 48px+ touch targets. Bypasses the clunky, unpredictable native Kobo OS virtual keyboard.
4. **Zero Battery Drain**: 100% offline, zero network requests, zero background daemon processes or timers. Completely dormant when not in use.
5. **Instant Local Storage**: Saves in-progress guesses and completed level badges (`✓` and `★`) in `localStorage`.

---

## 🚀 1-Click Installation

### Prerequisites:
- A Kobo eReader with **NickelMenu** installed.

### Automated Install:
1. Connect your Kobo to your computer via USB and tap **Connect** on the screen.
2. Run the installer script from this repository:
   ```bash
   cd twixtle
   ./install.sh
   ```
3. Safely eject your Kobo.
4. On the Kobo Home screen, tap **NickelMenu** and select **Twixtle**!

---

## 🛠 Manual Installation

If you prefer to install manually:

1. Connect Kobo via USB and open the mounted drive (`/Volumes/KOBOeReader` on macOS).
2. Create the folder `.adds/twixtle` on your Kobo.
3. Copy the following files into `.adds/twixtle/`:
   ```
   .adds/twixtle/
   ├── index.html
   ├── app.css
   ├── app.js
   ├── puzzles.js
   └── dict/
       └── data.js
   ```
4. Open (or create) `.adds/nm/config` or `.adds/nm/twixtle` on your Kobo, and add this line:
   ```text
   menu_item :main :Twixtle :nickel_browser :modal :file:///mnt/onboard/.adds/twixtle/index.html
   ```
5. Safely eject the device.

---

## 🧪 Verification & Testing

All 550 levels in `puzzles.js` have been verified using the offline dictionary and the complete move validation engine:

```bash
python3 tools/verify_puzzles.py
```

Output:
```
Loading dictionary rules...
Reading puzzles.js...
Verifying 550 levels...
SUCCESS: All 550 levels are 100% verified and legally solvable!
```

---

## 📁 Repository Structure

```
twixtle/
├── index.html              # E-Ink optimized single-page application shell
├── app.css                 # Pure monochrome high-contrast stylesheet
├── app.js                  # Move validation engine, on-screen keyboard, game manager
├── puzzles.js              # Curated 550-level dataset with verified solution paths
├── install.sh              # 1-click deployment script for Kobo & NickelMenu
├── dict/
│   ├── data.js             # Bundled synchronous dictionary (homophones, compounds, verbs)
│   ├── homophones.json     # Raw curated homophone pairings
│   ├── compounds.json      # Raw closed compound pairs
│   ├── irregular-verbs.json# Raw irregular verb forms
│   ├── regular-verbs.json  # Raw regular verb lemmas
│   └── words.txt           # Clean 74k English wordlist
└── tools/
    ├── build_dictionary.py # Bundles raw dictionaries into dict/data.js
    ├── fetch_and_solve.py  # Automation harvester & graph-solver for levels
    └── verify_puzzles.py   # Automated offline verification suite
```

---

## 📄 License

MIT License. Free to use, modify, and share with the Kobo reading community!
