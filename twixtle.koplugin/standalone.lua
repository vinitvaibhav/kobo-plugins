--[[
    Twixtle Standalone Launcher for NickelMenu
    Boots Twixtle directly using KOReader's e-ink runtime without entering FileManager.
--]]

require("setupkoenv")

-- Initialize core defaults and settings
G_defaults = require("luadefaults"):open()
local DataStorage = require("datastorage")
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")

-- Initialize device and screen hardware abstraction
local Device = require("device")
local CanvasContext = require("document/canvascontext")
CanvasContext:init(Device)

-- Initialize UI Manager and Font subsystem
local UIManager = require("ui/uimanager")
local Font = require("ui/font")

-- Locate Twixtle plugin directory
local script_dir = arg[0]:match("^(.*)/[^/]+$") or "."
package.path = script_dir .. "/?.lua;" .. script_dir .. "/?/init.lua;" .. package.path

local Engine = require("engine")
local TwixtleScreen = require("twixtle_screen")

local settings_dir = DataStorage:getSettingsDir()
local settings_file = settings_dir .. "/twixtle_settings.lua"

Engine:init(script_dir, settings_file)

local screen = TwixtleScreen:new{}
UIManager:show(screen)

-- Main event loop
local exit_code = UIManager:run()

-- Clean shutdown
Device:exit()
os.exit(exit_code or 0)
