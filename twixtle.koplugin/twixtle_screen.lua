--[[
    Twixtle Full-Screen UI Widget for KOReader (v4.1)
    High-contrast monochrome Carta 1300 E-Ink interface matching user design mockup:
    - Balanced vertical layout utilizing the full screen
    - Keyboard pinned flush to the bottom
    - Clean top header with reset, level select, and close buttons on the top right
    - 3-step word chain with left-aligned numbered lines and underline across width
    - Clean horizontal action pills under active step
    - Enter key submission on keyboard (auto-submit removed)
    - Auto-reset word field on invalid submission
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
local InfoMessage = require("ui/widget/infomessage")
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

local ACTION_NAMES = {
    homophone = "Homophone",
    compound = "Compound",
    anagram = "Anagram",
    verb = "Verb",
}

local function format_spaced_word(w)
    if not w or w == "" then return "" end
    local chars = {}
    for i = 1, #w do
        table.insert(chars, w:sub(i, i):upper())
    end
    return table.concat(chars, "  ")
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
        self[1]:paintTo(bb, x, y)
    end
end

function TwixtleScreen:buildUI()
    local screen_w = self.dimen.w
    local screen_h = self.dimen.h
    local pad_x = 18
    local board_w = screen_w - (pad_x * 2)
    local p = Engine.puzzle

    -- 1. Top Header Bar
    local is_solved = not not (Engine.solved_map[Engine.current_level] and Engine.solved_map[Engine.current_level].solved)
    local is_perfect = is_solved and Engine.solved_map[Engine.current_level].perfect

    -- Cursive Title: "Twixtle"
    local cursive_face
    local plugin_dir = Engine.plugin_dir or "plugins/twixtle.koplugin"
    local font_candidate = plugin_dir .. "/fonts/DancingScript.ttf"
    if not font_candidate:match("^/") and not font_candidate:match("^%./") then
        font_candidate = "./" .. font_candidate
    end
    local ok_c, res_c = pcall(function()
        return Font:getFace(font_candidate, 38)
    end)
    if ok_c and res_c then
        cursive_face = res_c
    else
        cursive_face = Font:getFace("tfont", 28)
    end

    local title_widget = TextWidget:new{
        text = "Twixtle",
        face = cursive_face,
        bold = true,
    }

    -- Merged Level Button: "# 5 ▾" (opens level selector directly)
    local lvl_str = string.format(" #%d ▾ ", Engine.current_level)
    if is_perfect then
        lvl_str = string.format(" #%d ★ ▾ ", Engine.current_level)
    elseif is_solved then
        lvl_str = string.format(" #%d ✓ ▾ ", Engine.current_level)
    end

    local btn_level = Button:new{
        text = lvl_str,
        text_font_face = "tfont",
        text_font_size = 17,
        text_font_bold = true,
        bordersize = 1,
        radius = 4,
        padding = 5,
        callback = function()
            self:openLevelSelectMenu()
        end,
    }
    btn_level[1].background = Blitbuffer.COLOR_GRAY_E
    btn_level.label_widget.fgcolor = Blitbuffer.COLOR_BLACK

    local header_left = HorizontalGroup:new{
        title_widget,
        HorizontalSpan:new{ width = 10 },
        btn_level,
    }

    local btn_reset = Button:new{
        text = " ↺ RESET ",
        text_font_face = "tfont",
        text_font_size = 14,
        text_font_bold = true,
        bordersize = 1,
        radius = 4,
        padding = 5,
        callback = function()
            Engine:resetLevel()
            self:refresh()
        end,
    }
    btn_reset[1].background = Blitbuffer.COLOR_GRAY_E
    btn_reset.label_widget.fgcolor = Blitbuffer.COLOR_BLACK

    local btn_exit = Button:new{
        text = " ✕ EXIT ",
        text_font_face = "tfont",
        text_font_size = 14,
        text_font_bold = true,
        bordersize = 1,
        radius = 4,
        padding = 5,
        callback = function()
            self:onClose()
        end,
    }
    btn_exit[1].background = Blitbuffer.COLOR_GRAY_E
    btn_exit.label_widget.fgcolor = Blitbuffer.COLOR_BLACK

    local header_right = HorizontalGroup:new{
        btn_reset,
        HorizontalSpan:new{ width = 6 },
        btn_exit,
    }

    local header_gap = board_w - header_left:getSize().w - header_right:getSize().w
    local header_bar = HorizontalGroup:new{
        HorizontalSpan:new{ width = pad_x },
        header_left,
        HorizontalSpan:new{ width = math.max(6, header_gap) },
        header_right,
        HorizontalSpan:new{ width = pad_x },
    }

    -- 2. Word Chain Board Elements
    local board_items = {}

    -- Helper to build HCAV Action Pills
    local function build_action_pills(step_idx)
        local available_actions = {}
        local all = { "homophone", "compound", "anagram", "verb" }
        for _, act in ipairs(all) do
            local used = false
            for prev = 1, step_idx - 1 do
                if Engine.chosen_moves[prev] == act then
                    used = true
                    break
                end
            end
            if not used then
                table.insert(available_actions, act)
            end
        end

        local pill_gap = 12
        local total_gaps = (#available_actions - 1) * pill_gap
        local pill_w = math.min(230, math.floor((board_w - total_gaps) / #available_actions))
        local pill_h = 44

        local pill_widgets = {}
        for idx, act in ipairs(available_actions) do
            local is_selected = (Engine.selected_action == act)
            local btn = Button:new{
                text = ACTION_NAMES[act] or act,
                text_font_face = "tfont",
                text_font_size = 19,
                text_font_bold = true,
                width = pill_w,
                height = pill_h,
                bordersize = 2,
                radius = 8,
                padding = 4,
                callback = function()
                    Engine:selectAction(act)
                    self:refresh()
                end,
            }
            if is_selected then
                btn[1].background = Blitbuffer.COLOR_BLACK
                btn.label_widget.fgcolor = Blitbuffer.COLOR_WHITE
            else
                btn[1].background = Blitbuffer.COLOR_WHITE
                btn.label_widget.fgcolor = Blitbuffer.COLOR_BLACK
            end

            table.insert(pill_widgets, btn)
            if idx < #available_actions then
                table.insert(pill_widgets, HorizontalSpan:new{ width = pill_gap })
            end
        end

        return CenterContainer:new{
            dimen = Geom:new{ w = screen_w, h = pill_h },
            HorizontalGroup:new(pill_widgets),
        }
    end

    -- Helper to build locked committed badge
    local function build_committed_badge(action_name)
        local badge = Button:new{
            text = (ACTION_NAMES[action_name] or action_name):upper(),
            text_font_face = "tfont",
            text_font_size = 17,
            text_font_bold = true,
            width = math.min(200, math.floor(board_w / 3)),
            height = 36,
            bordersize = 2,
            radius = 6,
            padding = 4,
            enabled = false,
        }
        badge[1].background = Blitbuffer.COLOR_BLACK
        badge.label_widget.fgcolor = Blitbuffer.COLOR_WHITE

        return CenterContainer:new{
            dimen = Geom:new{ w = screen_w, h = 38 },
            badge,
        }
    end

    -- START Word
    table.insert(board_items, CenterContainer:new{
        dimen = Geom:new{ w = screen_w, h = 42 },
        TextWidget:new{
            text = "START:  " .. format_spaced_word(p.start),
            face = Font:getFace("tfont", 30),
            bold = true,
        },
    })

    table.insert(board_items, VerticalSpan:new{ width = 12 })
    if Engine.chosen_moves[1] then
        table.insert(board_items, build_committed_badge(Engine.chosen_moves[1]))
        table.insert(board_items, VerticalSpan:new{ width = 10 })
    end
    table.insert(board_items, CenterContainer:new{
        dimen = Geom:new{ w = screen_w, h = 26 },
        TextWidget:new{
            text = "↓",
            face = Font:getFace("tfont", 22),
            bold = true,
        },
    })
    table.insert(board_items, VerticalSpan:new{ width = 12 })

    -- Steps 1, 2, 3
    for s = 1, 3 do
        local is_current = (Engine.active_step == s and not Engine.is_solved)
        local is_filled = (Engine.row_inputs[s] ~= "")

        local num_widget = TextWidget:new{
            text = string.format("%d.", s),
            face = Font:getFace("tfont", 28),
            bold = true,
        }
        local num_w = num_widget:getSize().w
        local line_w = board_w - num_w - 14

        local word_text = " "
        if is_current then
            word_text = format_spaced_word(Engine.current_input) .. " |"
        elseif is_filled then
            word_text = format_spaced_word(Engine.row_inputs[s])
        end

        local word_widget = TextWidget:new{
            text = word_text,
            face = Font:getFace("tfont", 28),
            bold = true,
        }

        local underline = FrameContainer:new{
            bordersize = 0,
            background = Blitbuffer.COLOR_BLACK,
            width = line_w,
            height = 2,
            HorizontalSpan:new{ width = line_w },
        }

        local input_line_column = VerticalGroup:new{
            align = "left",
            word_widget,
            VerticalSpan:new{ width = 6 },
            underline,
        }

        local step_row = HorizontalGroup:new{
            HorizontalSpan:new{ width = pad_x },
            num_widget,
            HorizontalSpan:new{ width = 12 },
            input_line_column,
        }
        table.insert(board_items, step_row)

        if is_current then
            table.insert(board_items, VerticalSpan:new{ width = 14 })
            table.insert(board_items, build_action_pills(s))
            table.insert(board_items, VerticalSpan:new{ width = 14 })
        else
            table.insert(board_items, VerticalSpan:new{ width = 20 })
        end

        -- Down arrow & badge for next transition
        local next_action = (s < 3) and Engine.chosen_moves[s + 1] or Engine.chosen_moves[4]
        if next_action then
            table.insert(board_items, build_committed_badge(next_action))
            table.insert(board_items, VerticalSpan:new{ width = 10 })
        end
        table.insert(board_items, CenterContainer:new{
            dimen = Geom:new{ w = screen_w, h = 26 },
            TextWidget:new{
                text = "↓",
                face = Font:getFace("tfont", 22),
                bold = true,
            },
        })
        table.insert(board_items, VerticalSpan:new{ width = 12 })
    end

    -- END Word
    table.insert(board_items, CenterContainer:new{
        dimen = Geom:new{ w = screen_w, h = 42 },
        TextWidget:new{
            text = "END:  " .. format_spaced_word(p["end"]),
            face = Font:getFace("tfont", 30),
            bold = true,
        },
    })

    local board_group = VerticalGroup:new(board_items)

    -- 3. Action / Feedback Bar (Above Keyboard)
    local btn_undo = Button:new{
        text = " [ UNDO ] ",
        text_font_face = "tfont",
        text_font_size = 15,
        text_font_bold = true,
        bordersize = 1,
        radius = 4,
        padding = 5,
        enabled = (#Engine.current_input > 0 or Engine.active_step > 1) and not Engine.is_solved,
        callback = function()
            Engine:undo()
            self:refresh()
        end,
    }
    btn_undo[1].background = Blitbuffer.COLOR_GRAY_E
    btn_undo.label_widget.fgcolor = Blitbuffer.COLOR_BLACK

    local status_str = "[ Select rule above & type word, then tap ↵ ENTER ]"
    local status_color = Blitbuffer.COLOR_DARK_GRAY
    local status_bold = false

    if Engine.is_solved then
        status_str = "★ LEVEL SOLVED! ★"
        status_color = Blitbuffer.COLOR_BLACK
        status_bold = true
    elseif Engine.message ~= "" then
        status_str = (Engine.is_error and "⚠ " or "") .. Engine.message
        status_color = Blitbuffer.COLOR_BLACK
        status_bold = true
    elseif #Engine.current_input > 0 then
        if Engine.selected_action then
            status_str = string.format("[ %s selected • Tap ↵ ENTER to submit ]", (ACTION_NAMES[Engine.selected_action] or Engine.selected_action):upper())
        else
            status_str = "[ Select rule above, then tap ↵ ENTER ]"
        end
    end

    local status_widget = TextWidget:new{
        text = status_str,
        face = Font:getFace("smallinfofont", 16),
        fgcolor = status_color,
        bold = status_bold,
    }

    local btn_hint = Button:new{
        text = " [ HINT ] ",
        text_font_face = "tfont",
        text_font_size = 15,
        text_font_bold = true,
        bordersize = 1,
        radius = 4,
        padding = 5,
        enabled = not Engine.is_solved,
        callback = function()
            Engine:hint()
            self:refresh()
        end,
    }
    btn_hint[1].background = Blitbuffer.COLOR_GRAY_E
    btn_hint.label_widget.fgcolor = Blitbuffer.COLOR_BLACK

    local bar_gap = board_w - btn_undo:getSize().w - status_widget:getSize().w - btn_hint:getSize().w
    local action_bar = HorizontalGroup:new{
        HorizontalSpan:new{ width = pad_x },
        btn_undo,
        HorizontalSpan:new{ width = math.max(6, math.floor(bar_gap / 2)) },
        status_widget,
        HorizontalSpan:new{ width = math.max(6, math.floor(bar_gap / 2)) },
        btn_hint,
        HorizontalSpan:new{ width = pad_x },
    }

    -- 4. Dynamic Height Calculation for Keyboard
    local top_section = VerticalGroup:new{
        VerticalSpan:new{ width = 10 },
        header_bar,
        VerticalSpan:new{ width = 14 },
        board_group,
    }

    local top_h = top_section:getSize().h
    local action_bar_h = action_bar:getSize().h
    local bottom_pad = 16
    local action_to_kb_gap = 12
    local min_flex_spacer = 20

    local kb_pad_x = 8
    local kb_w = screen_w - (kb_pad_x * 2)
    local gap = 6

    local available_for_kb = screen_h - top_h - min_flex_spacer - action_bar_h - action_to_kb_gap - bottom_pad
    local key_h = math.min(100, math.max(76, math.floor((available_for_kb - 2 * gap) / 3)))

    -- Row 1: 10 keys (Q W E R T Y U I O P)
    local r1_keys = { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" }
    local r1_key_w = math.floor((kb_w - (9 * gap)) / 10)
    local r1_widgets = { HorizontalSpan:new{ width = kb_pad_x } }
    for i, k in ipairs(r1_keys) do
        table.insert(r1_widgets, Button:new{
            text = k,
            text_font_face = "tfont",
            text_font_size = 28,
            text_font_bold = true,
            width = r1_key_w,
            height = key_h,
            bordersize = 2,
            radius = 6,
            padding = 2,
            callback = function()
                Engine:handleKey(k)
                self:refresh()
            end,
        })
        if i < #r1_keys then
            table.insert(r1_widgets, HorizontalSpan:new{ width = gap })
        end
    end
    table.insert(r1_widgets, HorizontalSpan:new{ width = kb_pad_x })
    local row1_group = HorizontalGroup:new(r1_widgets)

    -- Row 2: 9 keys (A S D F G H J K L) centered
    local r2_keys = { "A", "S", "D", "F", "G", "H", "J", "K", "L" }
    local r2_key_w = r1_key_w
    local r2_indent = math.floor((kb_w - (9 * r2_key_w + 8 * gap)) / 2)
    local r2_widgets = { HorizontalSpan:new{ width = kb_pad_x + r2_indent } }
    for i, k in ipairs(r2_keys) do
        table.insert(r2_widgets, Button:new{
            text = k,
            text_font_face = "tfont",
            text_font_size = 28,
            text_font_bold = true,
            width = r2_key_w,
            height = key_h,
            bordersize = 2,
            radius = 6,
            padding = 2,
            callback = function()
                Engine:handleKey(k)
                self:refresh()
            end,
        })
        if i < #r2_keys then
            table.insert(r2_widgets, HorizontalSpan:new{ width = gap })
        end
    end
    table.insert(r2_widgets, HorizontalSpan:new{ width = kb_pad_x + r2_indent })
    local row2_group = HorizontalGroup:new(r2_widgets)

    -- Row 3: [ ⌫ BACK ]  Z  X  C  V  B  N  M  [ ↵ ENTER ]
    local r3_letters = { "Z", "X", "C", "V", "B", "N", "M" }
    local r3_let_w = r1_key_w
    local side_w = math.floor((kb_w - (7 * r3_let_w + 8 * gap)) / 2)

    local btn_back = Button:new{
        text = " ⌫ ",
        text_font_face = "tfont",
        text_font_size = 26,
        text_font_bold = true,
        width = side_w,
        height = key_h,
        bordersize = 2,
        radius = 6,
        padding = 2,
        callback = function()
            Engine:handleKey("⌫")
            self:refresh()
        end,
    }

    local btn_enter = Button:new{
        text = " ↵ ENTER ",
        text_font_face = "tfont",
        text_font_size = 20,
        text_font_bold = true,
        width = side_w,
        height = key_h,
        bordersize = 2,
        radius = 6,
        padding = 2,
        callback = function()
            Engine:handleKey("↵")
            self:refresh()
        end,
    }
    if #Engine.current_input > 0 and Engine.selected_action then
        btn_enter[1].background = Blitbuffer.COLOR_BLACK
        btn_enter.label_widget.fgcolor = Blitbuffer.COLOR_WHITE
    end

    local r3_widgets = {
        HorizontalSpan:new{ width = kb_pad_x },
        btn_back,
        HorizontalSpan:new{ width = gap },
    }
    for _, k in ipairs(r3_letters) do
        table.insert(r3_widgets, Button:new{
            text = k,
            text_font_face = "tfont",
            text_font_size = 28,
            text_font_bold = true,
            width = r3_let_w,
            height = key_h,
            bordersize = 2,
            radius = 6,
            padding = 2,
            callback = function()
                Engine:handleKey(k)
                self:refresh()
            end,
        })
        table.insert(r3_widgets, HorizontalSpan:new{ width = gap })
    end
    table.insert(r3_widgets, btn_enter)
    table.insert(r3_widgets, HorizontalSpan:new{ width = kb_pad_x })
    local row3_group = HorizontalGroup:new(r3_widgets)

    local keyboard_group = VerticalGroup:new{
        row1_group,
        VerticalSpan:new{ width = gap },
        row2_group,
        VerticalSpan:new{ width = gap },
        row3_group,
    }

    local bottom_section = VerticalGroup:new{
        action_bar,
        VerticalSpan:new{ width = action_to_kb_gap },
        keyboard_group,
        VerticalSpan:new{ width = bottom_pad },
    }

    local bot_h = bottom_section:getSize().h
    local flex_spacer_h = math.max(10, screen_h - top_h - bot_h)

    self.layout = VerticalGroup:new{
        top_section,
        VerticalSpan:new{ width = flex_spacer_h },
        bottom_section,
    }

    self.layout.dimen = self.dimen
    self[1] = self.layout

    if Engine.is_solved and not self._victory_dialog_shown then
        self._victory_dialog_shown = true
        UIManager:nextTick(function()
            self:showVictoryDialog()
        end)
    elseif not Engine.is_solved then
        self._victory_dialog_shown = false
    end
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
        local tag = ""
        if not is_unlocked then
            prefix = "🔒 "
            tag = "  [Locked]"
        elseif solved_entry and solved_entry.solved then
            prefix = solved_entry.perfect and "★ " or "✓ "
            tag = solved_entry.perfect and "  [★ Perfect]" or "  [✓ Solved]"
        elseif i == Engine.current_level then
            prefix = "▶ "
            tag = "  [Current]"
        else
            prefix = "○ "
            tag = "  [Unlocked]"
        end

        local lvl_num = i
        table.insert(items, {
            text = string.format("%sLevel %d: %s ➔ %s%s", prefix, i, Puzzles[i].start:upper(), Puzzles[i]["end"]:upper(), tag),
            enabled = is_unlocked,
            callback = function()
                if not is_unlocked then
                    UIManager:show(InfoMessage:new{
                        text = string.format(_("Level %d is locked!\nSolve Level %d first to unlock it."), lvl_num, lvl_num - 1),
                        timeout = 2,
                    })
                    return
                end
                UIManager:close(self.level_menu)
                Engine:loadLevel(lvl_num)
                self:refresh()
            end,
        })
    end

    self.level_menu = Menu:new{
        title = string.format(_("Select Level (1 - %d)"), #Puzzles),
        item_table = items,
        width = math.floor(Screen:getWidth() * 0.9),
        height = math.floor(Screen:getHeight() * 0.85),
        show_parent = self,
    }
    UIManager:show(self.level_menu)
end

function TwixtleScreen:showVictoryDialog()
    local p = Engine.puzzle
    local solved_info = Engine.solved_map[Engine.current_level]
    local is_perfect = solved_info and solved_info.perfect

    local chain_lines = {
        is_perfect and "★ PERFECT SOLVE! No hints used.\n" or "✓ Level Solved!\n",
        string.format("START: %s", p.start:upper()),
        string.format("1. %s (%s)", Engine.row_inputs[1], (Engine.chosen_moves[1] or ""):upper()),
        string.format("2. %s (%s)", Engine.row_inputs[2], (Engine.chosen_moves[2] or ""):upper()),
        string.format("3. %s (%s)", Engine.row_inputs[3], (Engine.chosen_moves[3] or ""):upper()),
        string.format("END: %s (%s)", p["end"]:upper(), (Engine.chosen_moves[4] or ""):upper()),
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
