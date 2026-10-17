--[[
    Twixtle KOReader Plugin - Main Lifecycle Entry Point
    Registers Twixtle under Tools -> Games, provides offline launcher and state management.
--]]

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local Engine = require("engine")
local TwixtleScreen = require("twixtle_screen")

local Twixtle = WidgetContainer:extend{
    name = "twixtle",
    screen = nil,
}

function Twixtle:init()
    -- Register in KOReader Main Menu
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function Twixtle:addToMainMenu(menu_items)
    menu_items.twixtle = {
        text = _("Twixtle"),
        sorting_hint = "tools",
        sub_item_table = false,
        callback = function()
            self:showGame()
        end,
    }
end

function Twixtle:showGame()
    if self.screen then
        return
    end

    local settings_dir = DataStorage:getSettingsDir()
    local settings_file = settings_dir .. "/twixtle_settings.lua"

    Engine:init(self.path, settings_file)

    self.screen = TwixtleScreen:new{
        plugin = self,
    }
    UIManager:show(self.screen)
end

function Twixtle:onScreenClosed()
    self.screen = nil
end

return Twixtle
