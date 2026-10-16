local _ = require("gettext")

return {
    name = "kobostatsmerge",
    fullname = _("Kobo ↔ KOReader 2-Way Stats Sync"),
    description = _([[Automatically synchronizes and merges reading statistics (reading time, sessions, page turns, and book completion status) bidirectionally between Kobo Stock App (Nickel) and KOReader across all supported formats, with automatic rolling database backups and integrity verification.]]),
}
