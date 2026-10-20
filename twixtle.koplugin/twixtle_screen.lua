--[[
    Twixtle Full-Screen UI Widget for KOReader
    High-contrast monochrome Carta 1300 E-Ink interface with touch keyboard and level selector.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local Menu = require("ui/widget/menu")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = Device.screen

local Engine = require("engine")
local Puzzles = require("puzzles")

local TwixtleScreen = InputContainer:extend{
    covers_fullscreen = true,
}

local function format_spaced_word(w)
    if not w or w == "" then return "" end
    local chars = {}
    for i = 1, #w do
        table.insert(chars, w:sub(i, i):upper())
    end
    return table.concat(chars, "   ")
end

function TwixtleScreen:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }

    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end

    self:buildUI()
end

function TwixtleScreen:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    if self[1] then
        local offset_x = math.floor((self.dimen.w - self[1]:getSize().w) / 2)
        local offset_y = math.floor((self.dimen.h - self[1]:getSize().h) / 2)
        self[1]:paintTo(bb, offset_x, offset_y)
    end
end

function TwixtleScreen:buildUI()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    local board_w = math.min(screen_w - 40, 1020)
    local p = Engine.puzzle

    -- 1. Header Bar
    local is_solved = not not (Engine.solved_map[Engine.current_level] and Engine.solved_map[Engine.current_level].solved)
    local is_perfect = is_solved and Engine.solved_map[Engine.current_level].perfect

    local title_text = "TWIXTLE #" .. Engine.current_level
    if is_perfect then
        title_text = title_text .. " ★"
    elseif is_solved then
        title_text = title_text .. " ✓"
    end

    local header_left = TextWidget:new{
        text = title_text,
        face = Font:getFace("tfont", 26),
        bold = true,
    }

    local nav_prev = Button:new{
        text = " ◀ ",
        text_font_face = "tfont",
        text_font_size = 20,
        bordersize = 2,
        radius = 4,
        padding = 8,
        enabled = Engine.current_level > 1,
        callback = function()
            Engine:loadLevel(Engine.current_level - 1)
            self:refresh()
        end,
    }

    local nav_level = Button:new{
        text = string.format(" %d / %d ▾ ", Engine.current_level, #Puzzles),
        text_font_face = "tfont",
        text_font_size = 20,
        bordersize = 2,
        radius = 4,
        padding = 8,
        callback = function()
            self:openLevelSelectMenu()
        end,
    }

    local nav_next = Button:new{
        text = " ▶ ",
        text_font_face = "tfont",
        text_font_size = 20,
        bordersize = 2,
        radius = 4,
        padding = 8,
        enabled = Engine.current_level < #Puzzles and (Engine.current_level < Engine.unlocked_level or is_solved),
        callback = function()
            Engine:loadLevel(Engine.current_level + 1)
            self:refresh()
        end,
    }

    local nav_close = Button:new{
        text = " ✕ ",
        text_font_face = "tfont",
        text_font_size = 20,
        bordersize = 2,
        radius = 4,
        padding = 8,
        callback = function()
            self:onClose()
        end,
    }

    local header_right = HorizontalGroup:new{
        nav_prev,
        HorizontalSpan:new{ width = 6 },
        nav_level,
        HorizontalSpan:new{ width = 6 },
        nav_next,
        HorizontalSpan:new{ width = 14 },
        nav_close,
    }

    local header_space = board_w - header_left:getSize().w - header_right:getSize().w
    local header_bar = HorizontalGroup:new{
        header_left,
        HorizontalSpan:new{ width = math.max(10, header_space) },
        header_right,
    }

    -- 2. Board Elements
    local start_widget = CenterContainer:new{
        dimen = Geom:new{ w = board_w, h = 48 },
        TextWidget:new{
            text = "START:   " .. format_spaced_word(p.start),
            face = Font:getFace("tfont", 28),
            bold = true,
        }
    }

    local function makeArrow()
        return CenterContainer:new{
            dimen = Geom:new{ w = board_w, h = 26 },
            TextWidget:new{
                text = "↓",
                face = Font:getFace("cfont", 22),
            }
        }
    end

    local function makeRow(num)
        local is_active = (Engine.active_step == num and not Engine.is_solved)
        local confirmed_word = Engine.row_inputs[num]
        local display_text = ""

        if confirmed_word ~= "" then
            display_text = format_spaced_word(confirmed_word)
        elseif is_active then
            if Engine.current_input ~= "" then
                display_text = format_spaced_word(Engine.current_input) .. "   |"
            else
                display_text = "|________________________________"
            end
        else
            display_text = "________________________________"
        end

        local line_group = HorizontalGroup:new{
            HorizontalSpan:new{ width = 40 },
            TextWidget:new{
                text = num .. ".  ",
                face = Font:getFace("tfont", 24),
                bold = true,
            },
            TextWidget:new{
                text = display_text,
                face = Font:getFace("tfont", 24),
                bold = true,
            },
        }

        return CenterContainer:new{
            dimen = Geom:new{ w = board_w, h = 48 },
            line_group,
        }
    end

    local row1 = makeRow(1)
    local row2 = makeRow(2)
    local row3 = makeRow(3)
    local row4 = makeRow(4)

    local end_widget = CenterContainer:new{
        dimen = Geom:new{ w = board_w, h = 48 },
        TextWidget:new{
            text = "END:   " .. format_spaced_word(p["end"]),
            face = Font:getFace("tfont", 28),
            bold = true,
        }
    }

    -- 3. Action Bar (UNDO | HCAV Status Box | HINT)
    local undo_btn = Button:new{
        text = "[ UNDO ]",
        text_font_face = "tfont",
        text_font_size = 20,
        text_font_bold = true,
        bordersize = 2,
        radius = 6,
        width = 175,
        height = 80,
        enabled = not Engine.is_solved,
        callback = function()
            Engine:undo()
            self:refresh()
        end,
    }

    local hint_btn = Button:new{
        text = "[ HINT ]",
        text_font_face = "tfont",
        text_font_size = 20,
        text_font_bold = true,
        bordersize = 2,
        radius = 6,
        width = 175,
        height = 80,
        enabled = not Engine.is_solved,
        callback = function()
            Engine:hint()
            self:refresh()
        end,
    }

    local hcav_status = Engine:getHCAVStatus()
    local homo_icon = hcav_status.homophone and "◉ " or "Ⓗ "
    local comp_icon = hcav_status.compound and "◉ " or "Ⓒ "
    local anag_icon = hcav_status.anagram and "◉ " or "Ⓐ "
    local verb_icon = hcav_status.verb and "◉ " or "Ⓥ "

    local hcav_top = HorizontalGroup:new{
        Button:new{
            text = homo_icon .. "HOMOPHONE",
            text_font_face = "tfont",
            text_font_size = 18,
            bordersize = 0,
            width = 240,
            height = 36,
            callback = function()
                self:showRuleDialog("homophone")
            end,
        },
        HorizontalSpan:new{ width = 10 },
        Button:new{
            text = comp_icon .. "COMPOUND",
            text_font_face = "tfont",
            text_font_size = 18,
            bordersize = 0,
            width = 240,
            height = 36,
            callback = function()
                self:showRuleDialog("compound")
            end,
        },
    }

    local hcav_bot = HorizontalGroup:new{
        Button:new{
            text = anag_icon .. "ANAGRAM",
            text_font_face = "tfont",
            text_font_size = 18,
            bordersize = 0,
            width = 240,
            height = 36,
            callback = function()
                self:showRuleDialog("anagram")
            end,
        },
        HorizontalSpan:new{ width = 10 },
        Button:new{
            text = verb_icon .. "VERB",
            text_font_face = "tfont",
            text_font_size = 18,
            bordersize = 0,
            width = 240,
            height = 36,
            callback = function()
                self:showRuleDialog("verb")
            end,
        },
    }

    local hcav_box = FrameContainer:new{
        bordersize = 2,
        radius = 6,
        padding = 6,
        margin = 0,
        VerticalGroup:new{
            align = "center",
            hcav_top,
            VerticalSpan:new{ width = 4 },
            hcav_bot,
        }
    }

    local action_bar = CenterContainer:new{
        dimen = Geom:new{ w = board_w, h = 92 },
        HorizontalGroup:new{
            undo_btn,
            HorizontalSpan:new{ width = 18 },
            hcav_box,
            HorizontalSpan:new{ width = 18 },
            hint_btn,
        }
    }

    -- 4. Auto-submits strip & Feedback Message
    local banner_text = "[ Auto-submits on correct word ]"
    if Engine.message and Engine.message ~= "" then
        banner_text = Engine.message
    end

    local auto_strip = CenterContainer:new{
        dimen = Geom:new{ w = board_w, h = 34 },
        FrameContainer:new{
            bordersize = 1,
            radius = 4,
            padding = 4,
            background = Blitbuffer.COLOR_WHITE,
            TextWidget:new{
                text = banner_text,
                face = Font:getFace("cfont", 18),
                bold = (Engine.message and Engine.message ~= ""),
            }
        }
    }

    -- 5. Touch Keyboard (QWERTY)
    local function makeKey(ch, w)
        return Button:new{
            text = ch,
            text_font_face = "tfont",
            text_font_size = 24,
            text_font_bold = true,
            bordersize = 2,
            radius = 6,
            width = w,
            height = 76,
            enabled = not Engine.is_solved,
            callback = function()
                Engine:handleKey(ch)
                self:refresh()
                if Engine.is_solved then
                    self:showVictoryDialog()
                end
            end,
        }
    end

    local kb_r1_keys = {}
    local r1_letters = { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" }
    for i, ch in ipairs(r1_letters) do
        if i > 1 then table.insert(kb_r1_keys, HorizontalSpan:new{ width = 6 }) end
        table.insert(kb_r1_keys, makeKey(ch, 94))
    end
    local kb_r1 = CenterContainer:new{
        dimen = Geom:new{ w = board_w, h = 80 },
        HorizontalGroup:new(kb_r1_keys),
    }

    local kb_r2_keys = {}
    local r2_letters = { "A", "S", "D", "F", "G", "H", "J", "K", "L" }
    for i, ch in ipairs(r2_letters) do
        if i > 1 then table.insert(kb_r2_keys, HorizontalSpan:new{ width = 6 }) end
        table.insert(kb_r2_keys, makeKey(ch, 94))
    end
    local kb_r2 = CenterContainer:new{
        dimen = Geom:new{ w = board_w, h = 80 },
        HorizontalGroup:new(kb_r2_keys),
    }

    local kb_r3_keys = {}
    local r3_letters = { "Z", "X", "C", "V", "B", "N", "M" }
    for i, ch in ipairs(r3_letters) do
        if i > 1 then table.insert(kb_r3_keys, HorizontalSpan:new{ width = 6 }) end
        table.insert(kb_r3_keys, makeKey(ch, 94))
    end
    table.insert(kb_r3_keys, HorizontalSpan:new{ width = 6 })
    table.insert(kb_r3_keys, makeKey("⌫", 136))
    local kb_r3 = CenterContainer:new{
        dimen = Geom:new{ w = board_w, h = 80 },
        HorizontalGroup:new(kb_r3_keys),
    }

    local keyboard = VerticalGroup:new{
        align = "center",
        kb_r1,
        VerticalSpan:new{ width = 6 },
        kb_r2,
        VerticalSpan:new{ width = 6 },
        kb_r3,
    }

    self.layout = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = 20 },
        header_bar,
        VerticalSpan:new{ width = 16 },
        start_widget,
        makeArrow(),
        row1,
        makeArrow(),
        row2,
        makeArrow(),
        row3,
        makeArrow(),
        row4,
        makeArrow(),
        end_widget,
        VerticalSpan:new{ width = 20 },
        action_bar,
        VerticalSpan:new{ width = 10 },
        auto_strip,
        VerticalSpan:new{ width = 14 },
        keyboard,
        VerticalSpan:new{ width = 20 },
    }

    self[1] = self.layout
end

function TwixtleScreen:refresh()
    self:buildUI()
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function TwixtleScreen:onClose()
    UIManager:close(self)
    if self.plugin and self.plugin.onScreenClosed then
        self.plugin:onScreenClosed()
    else
        UIManager:quit(0)
    end
    return true
end

function TwixtleScreen:openLevelSelectMenu()
    local items = {}
    for i = 1, #Puzzles do
        local is_unlocked = i <= Engine.unlocked_level
        local solved_entry = Engine.solved_map[i]
        local prefix = ""
        if not is_unlocked then
            prefix = "🔒 "
        elseif solved_entry and solved_entry.solved then
            prefix = solved_entry.perfect and "★ ✓ " or "✓ "
        else
            prefix = "   "
        end

        local lvl_num = i
        table.insert(items, {
            text = string.format("%sLevel %d: %s ➔ %s", prefix, i, Puzzles[i].start:upper(), Puzzles[i]["end"]:upper()),
            enabled = is_unlocked,
            callback = function()
                UIManager:close(self.level_menu)
                Engine:loadLevel(lvl_num)
                self:refresh()
            end,
        })
    end

    self.level_menu = Menu:new{
        title = string.format("Select Level (1 - %d)", #Puzzles),
        item_table = items,
        width = math.floor(Screen:getWidth() * 0.9),
        height = math.floor(Screen:getHeight() * 0.85),
        show_parent = self,
    }
    UIManager:show(self.level_menu)
end

function TwixtleScreen:showRuleDialog(rule_type)
    local titles = {
        homophone = "HOMOPHONE Rule",
        compound = "COMPOUND Rule",
        anagram = "ANAGRAM Rule",
        verb = "VERB FORM Rule",
    }
    local descs = {
        homophone = "Find a word that sounds identical in English but is spelled differently.\n\nExamples:\n• write ➔ right\n• sea ➔ see\n• thyme ➔ time\n• side ➔ sighed",
        compound = "Jump to a word that pairs with the current word to form a single closed compound word.\n\nExamples:\n• sea ➔ horse (seahorse)\n• watch ➔ tower (watchtower)\n• worm ➔ book (bookworm)\n• time ➔ table (timetable)",
        anagram = "Rearrange all the letters into a different valid English word.\n\nExamples:\n• heart ➔ earth\n• table ➔ bleat\n• shore ➔ horse\n• arc ➔ car",
        verb = "Switch to a different grammatical inflection of the same verb.\n\nExamples:\n• bleat ➔ bleated\n• walk ➔ walks, walked, walking\n• write ➔ writes, wrote, written\n• run ➔ ran, running",
    }

    local dialog
    dialog = ButtonDialog:new{
        title = titles[rule_type] or "Twixtle Rule",
        title_align = "center",
        content = TextWidget:new{
            text = descs[rule_type] or "",
            face = Font:getFace("smallinfofont"),
            width = math.floor(Screen:getWidth() * 0.8),
        },
        buttons = {
            {
                {
                    text = _("Got it!"),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function TwixtleScreen:showVictoryDialog()
    local p = Engine.puzzle
    local solved_info = Engine.solved_map[Engine.current_level]
    local is_perfect = solved_info and solved_info.perfect

    local chain_lines = {
        is_perfect and "★ PERFECT SOLVE! No hints used.\n" or "✓ Level Solved!\n",
        string.format("1. %s ➔ %s (%s)", p.solution[1]:upper(), p.solution[2]:upper(), p.moves[1]:upper()),
        string.format("2. %s ➔ %s (%s)", p.solution[2]:upper(), p.solution[3]:upper(), p.moves[2]:upper()),
        string.format("3. %s ➔ %s (%s)", p.solution[3]:upper(), p.solution[4]:upper(), p.moves[3]:upper()),
        string.format("4. %s ➔ %s (%s)", p.solution[4]:upper(), p.solution[5]:upper(), p.moves[4]:upper()),
    }

    local dialog
    dialog = ButtonDialog:new{
        title = is_perfect and "★ Perfect Solve! ★" or "Puzzle Solved!",
        title_align = "center",
        content = TextWidget:new{
            text = table.concat(chain_lines, "\n"),
            face = Font:getFace("smallinfofont"),
            width = math.floor(Screen:getWidth() * 0.8),
        },
        buttons = {
            {
                {
                    text = _("Next Level ▶"),
                    callback = function()
                        UIManager:close(dialog)
                        Engine:loadLevel(Engine.current_level + 1)
                        self:refresh()
                    end,
                },
                {
                    text = _("Level Select"),
                    callback = function()
                        UIManager:close(dialog)
                        self:openLevelSelectMenu()
                    end,
                },
                {
                    text = _("Replay ↺"),
                    callback = function()
                        UIManager:close(dialog)
                        Engine:resetLevel()
                        self:refresh()
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

return TwixtleScreen
