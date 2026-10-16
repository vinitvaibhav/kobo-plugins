# kobostatsmerge.koplugin

**Automatic Bidirectional (2-Way) Reading Statistics Synchronization Plugin for KOReader & Kobo Stock Reading App (Nickel).**

---

## 📖 Overview

If you use both **KOReader** and the **Kobo Stock Reading App** on your Kobo e-reader (via NickelMenu), your reading statistics are normally completely isolated:
- Hours read in KOReader do not appear in Kobo's **More → Activity → Reading Stats**.
- Hours read in the Kobo stock app do not count towards KOReader's **Reading Statistics** or ZenOS dashboard widgets.
- Books read in one app show `0%` progress in the other.

**`kobostatsmerge.koplugin`** solves this by providing seamless, automatic, 2-way synchronization between KOReader's SQLite database (`statistics.sqlite3`) and Kobo's internal SQLite database (`.kobo/KoboReader.sqlite`).

---

## ✨ Features

- **🔄 True 2-Way Synchronization**:
  - **KOReader → Kobo**: Exports KOReader reading sessions, page turns, per-book reading seconds, and completion status into Kobo's `content` and `Event` tables.
  - **Kobo → KOReader**: Ingests Kobo stock app reading sessions into KOReader's `page_stat_data` table without duplicating existing intervals.
- **📊 Unified Kobo Activity Stats**:
  - Updates Kobo's **Total Hours Read**, **Average Minutes per Session**, **Average Page Turns per Minute**, and **Books Finished** in the native Kobo **Activity** section.
- **📚 Universal Format & Content Support**:
  - Sideloaded KePub (`*.kepub.epub`), Standard EPUB (`*.epub`), PDF (`*.pdf`), Manga/Comics (`*.cbz`, `*.cbr`), Text (`*.txt`), HTML, and Kobo Store / OverDrive downloads.
  - Works across moved folders (e.g. books moved from root into `bookshelf/` or `myfeed/`).
- **🔐 Cryptographic Event Verification**:
  - Kobo Nickel signs every telemetry event using an internal MD5 algorithm (`Event.Checksum`). This plugin includes a pure-Lua implementation of the exact Kobo checksum algorithm, guaranteeing Kobo Nickel accepts all synced rows as native and untampered.
- **⚡ Pure-Lua Qt `QVariantMap` Binary Codec**:
  - Custom binary encoder and decoder for Qt `QDataStream` binary blobs (`Event.ExtraData`), preserving byte-for-byte AST integrity across firmware versions.
- **🛡️ 7-Layer Database Safety Nets**:
  - Pre-flight `PRAGMA quick_check` verification before opening writes.
  - Rolling versioned backups (`.bak.1`, `.bak.2`, `.bak.3`) and untouched `.golden.bak` baseline in `settings/kobostatsmerge_backups/`.
  - Atomic `BEGIN IMMEDIATE ... COMMIT` / `ROLLBACK` transactions.
  - Post-commit full `PRAGMA integrity_check` with automatic pre-sync backup restore if any verification check fails.
  - Strict monotonic guarantee: reading time only accumulates; no historical records are ever deleted.

---

## 🛠️ Installation

### Option 1: Automatic Script (Recommended)
Connect your Kobo to your computer via USB, make sure it is mounted, and run from the repository root:
```bash
./install.sh
```

### Option 2: Manual Installation
1. Connect your Kobo e-reader to your computer via USB.
2. Copy the entire `kobostatsmerge.koplugin` folder to:
   ```
   [KOBO_MOUNT]/.adds/koreader/plugins/kobostatsmerge.koplugin/
   ```
3. Safely eject your Kobo e-reader and open KOReader.

---

## 📱 KOReader Menu & Settings

Access the plugin settings in KOReader via:
**Top Menu → More Tools (`...`) → Kobo ↔ KOReader Stats Sync**

| Menu Option | Description | Default |
| :--- | :--- | :--- |
| **Sync now (2-Way Kobo ↔ KOReader)** | Triggers immediate bidirectional sync with visual progress | Manual |
| **Auto-sync when closing book** | Flushes page turns and syncs when exiting any book | **Enabled** |
| **Auto-sync on KOReader startup** | Syncs new Kobo stock sessions when KOReader boots | **Enabled** |
| **Auto-sync on device suspend** | Syncs stats right before putting device to sleep | Disabled |
| **Show sync notifications** | Displays brief on-screen toast when sync completes | **Enabled** |
| **Verify database integrity** | Runs deep integrity checks on both databases | Manual |
| **Restore databases from backup...** | Safely restores pre-sync `.bak.1` or baseline `.golden.bak` | Manual |

### Dispatcher Action
The plugin registers a Dispatcher action `kobostatsmerge_sync_now`, allowing you to bind "Sync Stats Now" to gestures, bottom status bar taps, or custom physical button shortcuts.

---

## 🔬 Technical Details

### Kobo `Event.Checksum` Formula
Kobo stock firmware validates event rows in `Event` by hashing all columns alphabetically with a salt:
$$\text{Checksum} = \text{MD5}(\text{ContentID} \mathbin{\Vert} \text{EventCount} \mathbin{\Vert} \text{EventType} \mathbin{\Vert} \text{ExtraData} \mathbin{\Vert} \text{FirstOccurrence} \mathbin{\Vert} \text{LastOccurrence} \mathbin{\Vert} \text{"kobo.rules"})$$

`qvariant.lua` implements this formula using KOReader's fast `ffi/sha2` with an embedded pure-Lua MD5 fallback.

### Qt `QDataStream` Binary Layout
`Event.ExtraData` is serialized by Kobo's Qt framework using `QDataStream` format version 16 (Qt 4.8 / 5.x):
- Big-endian byte order
- `QMap` keys sorted in **reverse UTF-16BE order**
- Supported AST types: `Invalid` (0x00), `bool` (0x01), `int` (0x02), `uint` (0x03), `qlonglong` (0x04), `double` (0x06), `QChar` (0x07), `QMap` (0x08), `QList` (0x09), `QString` (0x0a), `QByteArray` (0x0c), `QDateTime` (0x10).

---

## 📄 License
GNU General Public License v3.0 (GPLv3).
