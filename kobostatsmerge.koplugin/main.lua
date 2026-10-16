-- main.lua
-- KOReader plugin: kobostatsmerge
-- Seamless Bidirectional (2-Way) Reading Statistics Synchronization between
-- Kobo Stock Reading App (.kobo/KoboReader.sqlite) and KOReader (statistics.sqlite3).

local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local Notification = require("ui/widget/notification")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")

local SyncEngine = require("sync_engine")

local KoboStatsMerge = WidgetContainer:extend{
    name = "kobostatsmerge",
    is_doc_only = false,
}

local function format_time(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds <= 0 then return "0s" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    elseif m > 0 then
        return string.format("%dm %02ds", m, s)
    else
        return string.format("%ds", s)
    end
end

function KoboStatsMerge:init()
    local settings_file = DataStorage:getSettingsDir() .. "/kobostatsmerge.lua"
    self.settings = LuaSettings:open(settings_file)
    if not self.settings:has("auto_sync_on_book_close") then
        self.settings:saveSetting("auto_sync_on_book_close", true)
        self.settings:saveSetting("auto_sync_on_startup", true)
        self.settings:saveSetting("auto_sync_on_suspend", false)
        self.settings:saveSetting("show_notifications", true)
        self.settings:flush()
    end

    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()

    if self.settings:isTrue("auto_sync_on_startup", true) then
        UIManager:scheduleIn(2, function()
            self:sync(true)
        end)
    end
end

function KoboStatsMerge:onDispatcherRegisterActions()
    Dispatcher:registerAction("kobostatsmerge_sync_now", {
        category = "none",
        event = "KoboStatsMergeSyncNow",
        title = _("KoboStatsMerge: Sync Reading Stats Now"),
        general = true,
    })
end

function KoboStatsMerge:onKoboStatsMergeSyncNow()
    self:sync(false)
end

function KoboStatsMerge:onCloseDocument()
    if self.settings:isTrue("auto_sync_on_book_close", true) then
        self:flushReaderStats()
        self:sync(true)
    end
end

function KoboStatsMerge:onSuspend()
    if self.settings:isTrue("auto_sync_on_suspend", false) then
        self:flushReaderStats()
        self:sync(true)
    end
end

function KoboStatsMerge:flushReaderStats()
    -- Safely flush in-memory page turns from statistics.koplugin if loaded
    pcall(function()
        local stats = self.ui and self.ui.document and self.ui.document.statistics
        if stats and type(stats.insertDB) == "function" then
            stats:insertDB()
        end
    end)
end

function KoboStatsMerge:sync(silent)
    local settings_dir = DataStorage:getSettingsDir()
    local kobo_db = SyncEngine.DEFAULT_KOBO_DB
    local stats_db = settings_dir .. "/statistics.sqlite3"
    local bookinfo_db = settings_dir .. "/bookinfo_cache.sqlite3"
    local history_path = settings_dir .. "/history.lua"
    local backup_dir = settings_dir .. "/kobostatsmerge_backups"
    local onboard_dir = SyncEngine.DEFAULT_ONBOARD_DIR

    local f_k = io.open(kobo_db, "rb")
    if not f_k then
        if not silent then
            UIManager:show(ConfirmBox:new{
                text = _("Kobo Stock Database not found at:\n") .. kobo_db .. _("\n\nAre you running on a Kobo e-reader?"),
            })
        end
        return false
    end
    f_k:close()

    local progress_info = nil
    if not silent then
        progress_info = InfoMessage:new{
            text = _("Synchronizing reading statistics with Kobo stock app..."),
            timeout = 0,
        }
        UIManager:show(progress_info)
    end

    local ok, res = SyncEngine.run_two_way_sync({
        kobo_db_path = kobo_db,
        stats_db_path = stats_db,
        bookinfo_db_path = bookinfo_db,
        history_path = history_path,
        backup_dir = backup_dir,
        onboard_dir = onboard_dir,
    })

    if progress_info then
        UIManager:close(progress_info)
    end

    -- Invalidate ZenOS library cache if active
    pcall(function()
        if package.loaded["common/db_library"] then
            package.loaded["common/db_library"] = nil
        end
    end)

    if ok then
        local k2ko_b = res.kobo_to_ko_books or 0
        local k2ko_s = res.kobo_to_ko_seconds or 0
        local ko2k_b = res.ko_to_kobo_books or 0
        local ko2k_s = res.ko_to_kobo_seconds or 0

        local msg
        if k2ko_b == 0 and ko2k_b == 0 then
            msg = _("Reading stats are already synchronized!")
        else
            msg = string.format(
                _("Sync Complete!\n• Kobo → KOReader: %d book(s) (+%s)\n• KOReader → Kobo: %d book(s) (+%s)"),
                k2ko_b, format_time(k2ko_s),
                ko2k_b, format_time(ko2k_s)
            )
        end

        if not silent or self.settings:isTrue("show_notifications", true) then
            UIManager:show(Notification:new{ text = msg })
        end
        return true
    else
        logger.err("KoboStatsMerge sync failed:", tostring(res))
        UIManager:show(ConfirmBox:new{
            text = _("Reading Stats Sync Failed:\n\n") .. tostring(res) .. _("\n\nBoth databases are protected with automatic rollback."),
        })
        return false
    end
end

function KoboStatsMerge:verifyIntegrity()
    local settings_dir = DataStorage:getSettingsDir()
    local stats_db = settings_dir .. "/statistics.sqlite3"
    local kobo_db = SyncEngine.DEFAULT_KOBO_DB

    local ok_s, err_s = SyncEngine.check_db_integrity(stats_db, true)
    local ok_k, err_k = SyncEngine.check_db_integrity(kobo_db, true)

    local txt = _("Database Integrity Verification:\n\n")
    txt = txt .. "• KOReader (statistics.sqlite3):\n  " .. (ok_s and _("PASSED (All tables & indexes OK)") or (_("FAILED: ") .. tostring(err_s))) .. "\n\n"
    txt = txt .. "• Kobo Stock (.kobo/KoboReader.sqlite):\n  " .. (ok_k and _("PASSED (All tables & checksums OK)") or (_("FAILED: ") .. tostring(err_k)))

    UIManager:show(ConfirmBox:new{
        text = txt,
    })
end

function KoboStatsMerge:restoreBackupDialog()
    local backup_dir = DataStorage:getSettingsDir() .. "/kobostatsmerge_backups"
    local buttons = {
        {
            text = _("Restore Recent Backup (.bak.1)"),
            callback = function()
                self:performRestore(backup_dir, false)
            end,
        },
        {
            text = _("Restore Golden Backup (.golden.bak)"),
            callback = function()
                self:performRestore(backup_dir, true)
            end,
        },
        {
            text = _("Cancel"),
            callback = function() end,
        },
    }

    UIManager:show(ButtonDialog:new{
        title = _("Restore Reading Stats Database"),
        text = _("Choose a backup to restore both KOReader and Kobo databases to their previous clean state:"),
        buttons = buttons,
    })
end

function KoboStatsMerge:performRestore(backup_dir, use_golden)
    local settings_dir = DataStorage:getSettingsDir()
    local stats_db = settings_dir .. "/statistics.sqlite3"
    local kobo_db = SyncEngine.DEFAULT_KOBO_DB

    local ok_s, err_s = SyncEngine.restore_from_backup(backup_dir, "statistics.sqlite3", stats_db, use_golden)
    local ok_k, err_k = SyncEngine.restore_from_backup(backup_dir, "KoboReader.sqlite", kobo_db, use_golden)

    if ok_s and ok_k then
        UIManager:show(Notification:new{
            text = _("Databases restored successfully from ") .. (use_golden and ".golden.bak" or ".bak.1"),
        })
    else
        UIManager:show(ConfirmBox:new{
            text = _("Restore error:\n") .. tostring(err_s or err_k),
        })
    end
end

function KoboStatsMerge:addToMainMenu(menu_items)
    menu_items.kobostatsmerge = {
        sorting_hint = "more_tools",
        text = _("Kobo ↔ KOReader Stats Sync"),
        sub_item_table = {
            {
                text = _("Sync now (2-Way Kobo ↔ KOReader)"),
                keep_menu_open = false,
                callback = function()
                    self:sync(false)
                end,
            },
            {
                text = _("Auto-sync when closing book"),
                checked_func = function()
                    return self.settings:isTrue("auto_sync_on_book_close", true)
                end,
                callback = function()
                    local cur = self.settings:isTrue("auto_sync_on_book_close", true)
                    self.settings:saveSetting("auto_sync_on_book_close", not cur):flush()
                end,
            },
            {
                text = _("Auto-sync on KOReader startup"),
                checked_func = function()
                    return self.settings:isTrue("auto_sync_on_startup", true)
                end,
                callback = function()
                    local cur = self.settings:isTrue("auto_sync_on_startup", true)
                    self.settings:saveSetting("auto_sync_on_startup", not cur):flush()
                end,
            },
            {
                text = _("Auto-sync on device suspend"),
                checked_func = function()
                    return self.settings:isTrue("auto_sync_on_suspend", false)
                end,
                callback = function()
                    local cur = self.settings:isTrue("auto_sync_on_suspend", false)
                    self.settings:saveSetting("auto_sync_on_suspend", not cur):flush()
                end,
            },
            {
                text = _("Show sync notifications"),
                checked_func = function()
                    return self.settings:isTrue("show_notifications", true)
                end,
                callback = function()
                    local cur = self.settings:isTrue("show_notifications", true)
                    self.settings:saveSetting("show_notifications", not cur):flush()
                end,
            },
            {
                text = _("Verify database integrity"),
                keep_menu_open = false,
                callback = function()
                    self:verifyIntegrity()
                end,
            },
            {
                text = _("Restore databases from backup..."),
                keep_menu_open = false,
                callback = function()
                    self:restoreBackupDialog()
                end,
            },
        },
    }
end

return KoboStatsMerge
