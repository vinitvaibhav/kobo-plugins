# Kobo Plugins 📖⚡

A curated collection of production-ready plugins, automation tools, and games for **Kobo e-readers** and **KOReader**.

---

## 📦 Available Plugins

| Plugin | Path | Description | Status |
| :--- | :--- | :--- | :--- |
| **`twixtle`** | [`twixtle.koplugin/`](twixtle.koplugin/) | **100% Offline Word Chain Puzzle Game** for Kobo Clara BW (NickelMenu Standalone & KOReader). 550 verified progressive levels, 4 transformation rules, virtual touch keyboard, manual rule choice, ↵ ENTER submit, auto-reset. Zero Wi-Fi dependencies. | ✅ **Active** |
| **`kobostatsmerge.koplugin`** | [`kobostatsmerge.koplugin/`](kobostatsmerge.koplugin/) | **Seamless 2-Way Reading Stats Synchronization** between KOReader and Kobo Stock App (Nickel). Unifies reading hours, sessions, and activity stats across all supported formats with full database safety nets. | ✅ **Active** |

---

## 🎮 Featured: `twixtle` (Word Puzzle Game v4)

### Why Native Lua / Standalone vs Browser?
Earlier web-based versions run via Kobo's stock browser suffered from:
1. **Wi-Fi Gatekeeping**: Kobo's browser refuses to open or prompts for internet even for local `file:///` URLs.
2. **Outdated QtWebKit Engine**: Missing modern JavaScript (ES6+) causes scripts to throw syntax errors on load, rendering touch screens frozen and unresponsive.

**`Twixtle v4`** runs natively on Kobo hardware:
- 🚀 **100% Offline**: Never requires Wi-Fi or internet connection.
- 🔘 **Direct from NickelMenu**: Launch directly from the home screen (`NickelMenu` ➔ `Twixtle`) without needing to open KOReader, just like built-in Kobo games!
- 📖 **Inside KOReader**: Also fully accessible inside KOReader under `Tools` ➔ `More tools` ➔ `Twixtle`.
- ⚡ **Instant Touch Response**: Native KOReader touch event pipeline with responsive full-touch QWERTY keyboard flush to the bottom.
- 🎯 **Manual Action Choice**: Tap pills (`Homophone`, `Compound`, `Anagram`, `Verb`) to choose your path; 4th action auto-assigned.
- ↵ **Explicit Enter Submit & Auto-Reset**: Submit via `↵ ENTER`; invalid words immediately clear the field for rapid re-typing.
- 🔀 **Alternative Path Support**: Free exploration of valid English word paths beyond canonical puzzle solutions.
- ↺ **Instant Reset & Selection**: Header controls (`[ ↺ RESET ] [ ▦ SELECT ] [ ✕ EXIT ]`) at top right.
- 🔋 **Zero Battery Drain**: Event-driven rendering on e-ink Carta 1300 displays; zero background CPU usage.
- 🧩 **550 Progressive Levels**: 2,200 unique 4-step word transformations rigorously verified with automated solvers.
- 💾 **Progress Persistence**: Unlocked levels and star ratings saved across restarts.

👉 **[Read the full Twixtle documentation →](twixtle.koplugin/README.md)**

---

## 🚀 Featured: `kobostatsmerge.koplugin` (2-Way Reading Stats)

### The Problem
When using both KOReader and Kobo's stock reader:
1. KOReader reading time does not reflect in Kobo's native **Activity → Reading Stats** screen.
2. Stock app reading progress does not show up in KOReader or ZenOS dashboard widgets.
3. Reading statistics remain completely split and out of sync.

### The Solution
`kobostatsmerge.koplugin` bridges the gap with an automatic, bidirectional sync engine:
- **Unified Activity Stats**: Updates Kobo's **Total Hours Read**, **Avg Minutes per Session**, and **Avg Page Turns per Minute**.
- **Unified KOReader Stats**: Ingests stock reader sessions into KOReader's `page_stat_data` without duplication.
- **Universal Format Support**: Works across EPUB, KePub, PDF, CBZ, CBR, TXT, MOBI, and Kobo Store downloads.
- **Cryptographic Event Integrity**: Pure-Lua Qt `QVariantMap` binary encoder & Kobo `Event.Checksum` validator (100% accepted by Kobo Nickel).
- **Zero-Corruption Safety Nets**: Rolling versioned backups (`.bak.1`, `.bak.2`, `.golden.bak`), atomic SQLite transactions, and post-commit verification with auto-rollback.

👉 **[Read the full kobostatsmerge documentation →](kobostatsmerge.koplugin/README.md)**

---

## ⚡ Quick Start & Installation

### Option 1: Universal Installer Script (macOS / Linux)
1. Connect your Kobo e-reader to your computer via USB (tap **Connect** on the Kobo screen).
2. Clone this repository (if not already cloned):
   ```bash
   git clone https://github.com/vinitvaibhav/kobo-plugins.git
   cd kobo-plugins
   ```
3. Run the installer script:
   ```bash
   ./install.sh
   ```
   *(Or install only Twixtle: `./install.sh twixtle`)*
   *(The script automatically detects `/Volumes/KOBOeReader` on macOS or `/media/...` on Linux).*
4. Safely eject your Kobo e-reader.

### Option 2: Manual Installation
Copy the desired plugin folder into your Kobo's KOReader plugins directory:
```bash
cp -r twixtle.koplugin /Volumes/KOBOeReader/.adds/koreader/plugins/
cp -r kobostatsmerge.koplugin /Volumes/KOBOeReader/.adds/koreader/plugins/
```

---

## 📂 Repository Structure

```
kobo-plugins/
├── twixtle.koplugin/                # Native KOReader Word Chain Game (100% Offline)
│   ├── _meta.lua                    # KOReader plugin metadata
│   ├── main.lua                     # Plugin lifecycle & menu registration
│   ├── twixtle_screen.lua           # Full-screen Carta 1300 E-Ink UI & touch keyboard
│   ├── engine.lua                   # Game mechanics & hint reveal logic
│   ├── dictionary.lua               # Fast offline move verification engine
│   ├── dict_data.lua                # Compiled compounds, homophones & verb mappings
│   ├── words.txt                    # 74,500+ word dictionary
│   ├── puzzles.lua                  # 550 verified progressive puzzle chains
│   ├── storage.lua                  # Persistent progress & rating storage
│   ├── install.sh                   # Dedicated 1-click plugin installer
│   └── README.md                    # Detailed game instructions & mechanics
├── kobostatsmerge.koplugin/          # 2-Way Kobo ↔ KOReader stats sync plugin
│   ├── _meta.lua                    # Plugin metadata
│   ├── main.lua                     # KOReader lifecycle hooks & UI menus
│   ├── qvariant.lua                 # Qt binary QVariantMap codec & MD5 checksum engine
│   ├── sync_engine.lua              # Bidirectional synchronization engine
│   └── README.md                    # In-depth technical documentation
├── tests/                           # LuaJIT unit & end-to-end test suite
│   ├── test_twixtle.lua             # 3,900+ assertions verifying dictionary & 550 levels
│   └── test_sync_engine.lua         # Reading stats sync test suite
├── install.sh                       # Universal one-command installer
├── .gitignore
├── LICENSE                          # GNU General Public License v3.0
└── README.md
```

---

## 🛡️ Compatibility

- **Hardware**: All modern Kobo e-readers (Kobo Clara BW, Clara 2E, Clara Colour, Libra 2, Libra Colour, Sage, Elipsa, Forma, Aura, etc.).
- **Software**: KOReader (2023.x, 2024.x, 2025.x, 2026.x+) with NickelMenu on Kobo firmware 4.x+.

---

## 🤝 Contributing

Contributions, feature requests, and bug reports are welcome! Please feel free to open an issue or submit a pull request.

---

## 📄 License

This repository is licensed under the **GNU General Public License v3.0** (GPL-3.0). See [LICENSE](LICENSE) for details.
