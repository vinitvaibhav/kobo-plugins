# Kobo Plugins 📖⚡

A curated collection of production-ready plugins, automation tools, and utilities for **Kobo e-readers** and **KOReader**.

---

## 📦 Available Plugins

| Plugin | Path | Description | Status |
| :--- | :--- | :--- | :--- |
| **`kobostatsmerge.koplugin`** | [`kobostatsmerge.koplugin/`](kobostatsmerge.koplugin/) | **Seamless 2-Way Reading Stats Synchronization** between KOReader and Kobo Stock App (Nickel). Unifies reading hours, sessions, and activity stats across all supported formats with full database safety nets. | ✅ **Active** |
| **`twixtle`** | [`twixtle/`](twixtle/) | **Offline Word Chain Game for Kobo** (Carta 1300 E-Ink optimized). 550 verified progressive levels with NickelMenu integration, on-screen touch keyboard, zero battery drain. | ✅ **Active** |

---

## 🚀 Featured Plugin: `kobostatsmerge.koplugin`

### The Problem
When using both KOReader and Kobo's stock reader (via NickelMenu):
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
1. Connect your Kobo e-reader to your computer via USB.
2. Clone this repository:
   ```bash
   git clone https://github.com/vinitvaibhav/kobo-plugins.git
   cd kobo-plugins
   ```
3. Run the installer script:
   ```bash
   ./install.sh
   ```
   *(The script automatically detects `/Volumes/KOBOeReader` on macOS or `/media/...` on Linux).*
4. Safely eject your Kobo e-reader.

### Option 2: Manual Installation
Copy the desired plugin folder into your Kobo's KOReader plugins directory:
```bash
cp -r kobostatsmerge.koplugin /Volumes/KOBOeReader/.adds/koreader/plugins/
```

---

## 📂 Repository Structure

```
kobo-plugins/
├── kobostatsmerge.koplugin/          # 2-Way Kobo ↔ KOReader stats sync plugin
│   ├── _meta.lua                    # Plugin metadata
│   ├── main.lua                     # KOReader lifecycle hooks & UI menus
│   ├── qvariant.lua                 # Qt binary QVariantMap codec & MD5 checksum engine
│   ├── sync_engine.lua              # Bidirectional synchronization engine
│   └── README.md                    # In-depth technical documentation
├── twixtle/                         # Offline Word Chain Game for Kobo (Carta 1300 E-Ink)
│   ├── index.html                   # High-contrast E-Ink application shell
│   ├── app.css                      # Monochrome stylesheet (zero transitions/flicker)
│   ├── app.js                       # Game engine, move validator & on-screen keyboard
│   ├── puzzles.js                   # 550 verified progressive offline puzzles
│   ├── install.sh                   # 1-click deployment & NickelMenu setup
│   ├── dict/                        # Offline English dictionaries (verbs, compounds, homophones)
│   ├── tools/                       # Puzzle harvesting, solving & test verification tools
│   └── README.md                    # Detailed game instructions & manual setup
├── tests/                           # LuaJIT unit & end-to-end test suite
│   └── test_sync_engine.lua
├── install.sh                       # One-command installer for connected Kobo devices
├── .gitignore
├── LICENSE                          # GNU General Public License v3.0
└── README.md
```

---

## 🛡️ Compatibility

- **Hardware**: All modern Kobo e-readers (Kobo Clara BW, Clara 2E, Clara Colour, Libra 2, Libra Colour, Sage, Elipsa, Forma, Aura, etc.).
- **Software**: KOReader (2023.x, 2024.x, 2025.x, 2026.x) with NickelMenu on Kobo firmware 4.x+.

---

## 🤝 Contributing

Contributions, feature requests, and bug reports are welcome! Please feel free to open an issue or submit a pull request.

---

## 📄 License

This repository is licensed under the [GNU General Public License v3.0 (GPLv3)](LICENSE), consistent with the KOReader plugin ecosystem.
