--[[
    Twixtle Full-Screen UI Widget for KOReader
    High-contrast monochrome Carta 1300 E-Ink interface with touch keyboard and level selector.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local ButtonTable = require("ui/widget/buttontable")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local Menu = require("ui/widget/menu")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local Screen = Device.screen

local Engine = require("engine")
local Puzzles = require("puzzles")
local Dictionary = require("dictionary")

local TwixtleScreen = InputContainer:extend{
    covers_fullscreen = true,
}

function TwixtleScreen:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }

    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end

    self:buildUI()

    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function TwixtleScreen:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    if self.layout then
        local offset_x = math.floor((self.dimen.w - self.layout:getSize().w) / 2)
        local offset_y = math.floor((self.dimen.h - self.layout:getSize().h) / 2)
        self.layout:paintTo(bb, offset_x, offset_y)
    end
end

function TwixtleScreen:buildUI()
    local screen_w = Screen:getWidth()
    local board_w = math.min(math.floor(screen_w * 0.94), 560)
    local kb_w = math.min(math.floor(screen_w * 0.98), 620)

    -- 1. Header Bar
    local is_solved = not not (Engine.solved_map[Engine.current_level])
    local is_perfect = is_solved and Engine.solved_map[Engine.current_level].perfect

    local level_label = _("Level ") .. Engine.current_level .. " ▾"
    local badge_text = ""
    if is_perfect then
        badge_text = " ★ PERFECT "
    elseif is_solved then
        badge_text = " ✓ SOLVED "
    end

    local header_buttons = ButtonTable:new{
        width = board_w,
        shrink_unneeded_width = true,
        buttons = {
            {
                {
                    text = level_label,
                    text_font_bold = true,
                    callback = function()
                        self:openLevelSelectMenu()
                    end,
                },
                {
                    text = badge_text ~= "" and badge_text or "         ",
                    text_font_bold = true,
                    enabled = badge_text ~= "",
                    background = is_perfect and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
                    color = is_perfect and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
                    callback = function() end,
                },
                {
                    text = " ◀ ",
                    enabled = Engine.current_level > 1,
                    callback = function()
                        Engine:loadLevel(Engine.current_level - 1)
                        self:refresh()
                    end,
                },
                {
                    text = " ▶ ",
                    enabled = Engine.current_level < Engine.unlocked_level or is_solved,
                    callback = function()
                        Engine:loadLevel(Engine.current_level + 1)
                        self:refresh()
                    end,
                },
                {
                    text = " ↺ ",
                    callback = function()
                        Engine:resetLevel()
                        self:refresh()
                    end,
                },
                {
                    text = " ? ",
                    callback = function()
                        self:showRulesDialog()
                    end,
                },
                {
                    text = " ✕ ",
                    callback = function()
                        self:onClose()
                    end,
                },
            },
        },
    }

    -- 2. Word Chain Cards
    local p = Engine.puzzle

    -- Start Word Card
    local start_card = Button:new{
        text = _("START: ") .. p.start:upper(),
        text_font_bold = true,
        text_font_size = 20,
        width = board_w,
        bordersize = 2,
        background = Blitbuffer.COLOR_BLACK,
        color = Blitbuffer.COLOR_WHITE,
        callback = function() end,
    }

    -- Step 1 Connector
    local m1_text = Engine.revealed_moves[1] and (" • " .. p.moves[1]:upper() .. " • ") or _(" ? REVEAL MOVE 1 ")
    local pill1 = Button:new{
        text = m1_text,
        text_font_bold = true,
        text_font_size = 14,
        bordersize = 2,
        radius = 8,
        background = Engine.revealed_moves[1] and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
        color = Engine.revealed_moves[1] and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
        callback = function()
            Engine:revealMove(1)
            self:refresh()
        end,
    }

    -- Row 1 Word Card
    local w1_val = Engine.row_inputs[1]:upper()
    local w1_valid = Dictionary:is_valid_step(p.start, Engine.row_inputs[1], p.moves[1])
    local row1_btn = Button:new{
        text = (#w1_val > 0) and (w1_val .. (w1_valid and "  ✓" or "")) or _("[ Tap to type Word 1 ]"),
        text_font_bold = true,
        text_font_size = 18,
        width = board_w,
        bordersize = (Engine.active_step == 1) and 3 or 1,
        background = (Engine.active_step == 1) and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_WHITE,
        callback = function()
            Engine.active_step = 1
            self:refresh()
        end,
    }

    -- Step 2 Connector
    local m2_text = Engine.revealed_moves[2] and (" • " .. p.moves[2]:upper() .. " • ") or _(" ? REVEAL MOVE 2 ")
    local pill2 = Button:new{
        text = m2_text,
        text_font_bold = true,
        text_font_size = 14,
        bordersize = 2,
        radius = 8,
        background = Engine.revealed_moves[2] and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
        color = Engine.revealed_moves[2] and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
        callback = function()
            Engine:revealMove(2)
            self:refresh()
        end,
    }

    -- Row 2 Word Card
    local w2_val = Engine.row_inputs[2]:upper()
    local w2_valid = w1_valid and Dictionary:is_valid_step(Engine.row_inputs[1], Engine.row_inputs[2], p.moves[2])
    local row2_btn = Button:new{
        text = (#w2_val > 0) and (w2_val .. (w2_valid and "  ✓" or "")) or _("[ Tap to type Word 2 ]"),
        text_font_bold = true,
        text_font_size = 18,
        width = board_w,
        bordersize = (Engine.active_step == 2) and 3 or 1,
        callback = function()
            Engine.active_step = 2
            self:refresh()
        end,
    }

    -- Step 3 Connector
    local m3_text = Engine.revealed_moves[3] and (" • " .. p.moves[3]:upper() .. " • ") or _(" ? REVEAL MOVE 3 ")
    local pill3 = Button:new{
        text = m3_text,
        text_font_bold = true,
        text_font_size = 14,
        bordersize = 2,
        radius = 8,
        background = Engine.revealed_moves[3] and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
        color = Engine.revealed_moves[3] and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
        callback = function()
            Engine:revealMove(3)
            self:refresh()
        end,
    }

    -- Row 3 Word Card
    local w3_val = Engine.row_inputs[3]:upper()
    local w3_valid = w2_valid and Dictionary:is_valid_step(Engine.row_inputs[2], Engine.row_inputs[3], p.moves[3])
    local row3_btn = Button:new{
        text = (#w3_val > 0) and (w3_val .. (w3_valid and "  ✓" or "")) or _("[ Tap to type Word 3 ]"),
        text_font_bold = true,
        text_font_size = 18,
        width = board_w,
        bordersize = (Engine.active_step == 3) and 3 or 1,
        callback = function()
            Engine.active_step = 3
            self:refresh()
        end,
    }

    -- Step 4 Connector
    local m4_text = Engine.revealed_moves[4] and (" • " .. p.moves[4]:upper() .. " • ") or _(" ? REVEAL MOVE 4 ")
    local pill4 = Button:new{
        text = m4_text,
        text_font_bold = true,
        text_font_size = 14,
        bordersize = 2,
        radius = 8,
        background = Engine.revealed_moves[4] and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
        color = Engine.revealed_moves[4] and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
        callback = function()
            Engine:revealMove(4)
            self:refresh()
        end,
    }

    -- End Word Card
    local end_card = Button:new{
        text = _("END: ") .. p["end"]:upper(),
        text_font_bold = true,
        text_font_size = 20,
        width = board_w,
        bordersize = 2,
        background = Blitbuffer.COLOR_BLACK,
        color = Blitbuffer.COLOR_WHITE,
        callback = function() end,
    }

    -- 3. Message / Feedback Text
    local feedback_text = Engine.message
    if #feedback_text == 0 then
        feedback_text = _("Type word for Row ") .. Engine.active_step .. _(", then press CHECK.")
    end
    local msg_widget = TextWidget:new{
        text = feedback_text,
        face = Font:getFace("smallinfofont"),
        bold = Engine.is_error,
    }

    -- 4. Toolbar Actions
    local toolbar = ButtonTable:new{
        width = board_w,
        shrink_unneeded_width = true,
        buttons = {
            {
                {
                    text = _("💡 Hint"),
                    callback = function()
                        Engine:provideWordHint()
                        self:refresh()
                    end,
                },
                {
                    text = _("⌫ Clear Row"),
                    callback = function()
                        Engine:clearActiveRow()
                        self:refresh()
                    end,
                },
                {
                    text = _("👁 Solution"),
                    callback = function()
                        self:confirmGiveUp()
                    end,
                },
            },
        },
    }

    -- 5. QWERTY On-Screen Keyboard
    local function make_key(letter)
        return {
            text = letter,
            text_font_bold = true,
            text_font_size = 18,
            callback = function()
                Engine:handleKey(letter)
                self:refresh()
            end,
        }
    end

    local row1_keys = {}
    for _, ch in ipairs({ "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" }) do
        table.insert(row1_keys, make_key(ch))
    end

    local row2_keys = {}
    for _, ch in ipairs({ "A", "S", "D", "F", "G", "H", "J", "K", "L" }) do
        table.insert(row2_keys, make_key(ch))
    end

    local row3_keys = {
        {
            text = _("CHECK ↵"),
            text_font_bold = true,
            text_font_size = 14,
            callback = function()
                local solved_before = Engine.is_solved
                Engine:handleKey("ENTER")
                self:refresh()
                if not solved_before and Engine.is_solved then
                    self:showVictoryDialog()
                end
            end,
        },
    }
    for _, ch in ipairs({ "Z", "X", "C", "V", "B", "N", "M" }) do
        table.insert(row3_keys, make_key(ch))
    end
    table.insert(row3_keys, {
        text = " ⌫ ",
        text_font_bold = true,
        text_font_size = 18,
        callback = function()
            Engine:handleKey("BACKSPACE")
            self:refresh()
        end,
    })

    local keyboard = ButtonTable:new{
        width = kb_w,
        shrink_unneeded_width = false,
        buttons = {
            row1_keys,
            row2_keys,
            row3_keys,
        },
    }

    -- Assemble full layout
    self.layout = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = Size.span.vertical_small },
        header_buttons,
        VerticalSpan:new{ width = 6 },
        start_card,
        VerticalSpan:new{ width = 4 },
        pill1,
        VerticalSpan:new{ width = 4 },
        row1_btn,
        VerticalSpan:new{ width = 4 },
        pill2,
        VerticalSpan:new{ width = 4 },
        row2_btn,
        VerticalSpan:new{ width = 4 },
        pill3,
        VerticalSpan:new{ width = 4 },
        row3_btn,
        VerticalSpan:new{ width = 4 },
        pill4,
        VerticalSpan:new{ width = 4 },
        end_card,
        VerticalSpan:new{ width = 6 },
        msg_widget,
        VerticalSpan:new{ width = 6 },
        toolbar,
        VerticalSpan:new{ width = 8 },
        keyboard,
        VerticalSpan:new{ width = Size.span.vertical_small },
    }
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
        elseif solved_entry then
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
        title = _("Select Level (1 - ") .. #Puzzles .. ")",
        item_table = items,
        width = math.floor(Screen:getWidth() * 0.9),
        height = math.floor(Screen:getHeight() * 0.85),
        show_parent = self,
    }
    UIManager:show(self.level_menu)
end

function TwixtleScreen:showRulesDialog()
    local text = _([[Transform the START word into the END word in exactly 4 steps using each of the 4 move types once:

1. ANAGRAM: Rearrange letters into a new word.
   (e.g., ARC ➔ CAR, HEART ➔ EARTH)

2. COMPOUND: Pair with another word to form a single closed compound word.
   (e.g., CAR ➔ SIDE for sidecar, SWEAT ➔ BAND for sweatband)

3. HOMOPHONE: Swap for a word that sounds identical but spelled differently.
   (e.g., SIDE ➔ SIGHED, FLOWER ➔ FLOUR)

4. VERB: Change to another grammatical form of the same verb.
   (e.g., SIGHED ➔ SIGH, RUN ➔ RAN)

★ PERFECT MODE: Keep all move pills hidden as '?' and deduce the chain purely by logic to earn a Gold Star!]])

    local dialog
    dialog = ButtonDialog:new{
        title = _("How to Play Twixtle"),
        title_align = "center",
        content = TextWidget:new{
            text = text,
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

function TwixtleScreen:confirmGiveUp()
    local confirm = ConfirmBox:new{
        text = _("Reveal the solution for Level ") .. Engine.current_level .. _("?\n(This will display the solution chain)."),
        ok_text = _("Show Solution"),
        cancel_text = _("Keep Trying"),
        ok_callback = function()
            Engine:giveUp()
            self:refresh()
            self:showVictoryDialog()
        end,
    }
    UIManager:show(confirm)
end

function TwixtleScreen:showVictoryDialog()
    local p = Engine.puzzle
    local solved_info = Engine.solved_map[Engine.current_level]
    local is_perfect = solved_info and solved_info.perfect

    local chain_lines = {
        is_perfect and _("★ PERFECT SOLVE! No hints used.\n") or _("✓ Level Solved!\n"),
        string.format("1. %s ➔ %s (%s)", p.solution[1]:upper(), p.solution[2]:upper(), p.moves[1]:upper()),
        string.format("2. %s ➔ %s (%s)", p.solution[2]:upper(), p.solution[3]:upper(), p.moves[2]:upper()),
        string.format("3. %s ➔ %s (%s)", p.solution[3]:upper(), p.solution[4]:upper(), p.moves[3]:upper()),
        string.format("4. %s ➔ %s (%s)", p.solution[4]:upper(), p.solution[5]:upper(), p.moves[4]:upper()),
    }

    local dialog
    dialog = ButtonDialog:new{
        title = _("Puzzle Completed!"),
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
