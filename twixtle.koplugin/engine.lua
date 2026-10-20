--[[
    Twixtle Game Engine
    Manages gameplay state, validation transitions, auto-submit, hints, and level progression.
--]]

local Dictionary = require("dictionary")
local Puzzles = require("puzzles")
local Storage = require("storage")

local Engine = {
    unlocked_level = 1,
    current_level = 1,
    puzzle = nil,
    active_step = 1, -- 1, 2, 3, or 4
    current_input = "", -- live buffer typed in active step
    row_inputs = { "", "", "", "" }, -- words confirmed for steps 1..4
    revealed_moves = { false, false, false, false },
    hints_used = false,
    solved_map = {},
    message = "",
    is_error = false,
    is_solved = false,
}

function Engine:init(plugin_dir, settings_path)
    Dictionary:init(plugin_dir)
    Storage:init(settings_path)

    self.unlocked_level = Storage:get("unlocked_level", 1)
    self.current_level = Storage:get("current_level", 1)
    self.solved_map = Storage:get("solved_map", {})

    self:loadLevel(self.current_level)
end

function Engine:loadLevel(level_num)
    if level_num < 1 then level_num = 1 end
    if level_num > #Puzzles then level_num = #Puzzles end

    self.current_level = level_num
    Storage:save("current_level", self.current_level)

    self.puzzle = Puzzles[self.current_level]
    self.active_step = 1
    self.current_input = ""
    self.row_inputs = { "", "", "", "" }
    self.revealed_moves = { false, false, false, false }
    self.hints_used = false
    self.is_solved = false
    self.message = ""
    self.is_error = false

    local saved_state = Storage:get("state_" .. self.current_level, nil)
    if saved_state then
        self.row_inputs = {
            saved_state.row_inputs and saved_state.row_inputs[1] or "",
            saved_state.row_inputs and saved_state.row_inputs[2] or "",
            saved_state.row_inputs and saved_state.row_inputs[3] or "",
            saved_state.row_inputs and saved_state.row_inputs[4] or "",
        }
        self.revealed_moves = {
            saved_state.revealed_moves and saved_state.revealed_moves[1] or false,
            saved_state.revealed_moves and saved_state.revealed_moves[2] or false,
            saved_state.revealed_moves and saved_state.revealed_moves[3] or false,
            saved_state.revealed_moves and saved_state.revealed_moves[4] or false,
        }
        self.hints_used = saved_state.hints_used or false
        self.active_step = saved_state.active_step or 1

        -- Restore first empty step
        for i = 1, 4 do
            if self.row_inputs[i] == "" then
                self.active_step = i
                break
            end
        end

        if self.row_inputs[4] ~= "" then
            self.is_solved = true
        end
    end

    if self.solved_map[self.current_level] and self.solved_map[self.current_level].solved then
        self.is_solved = true
        -- If solved, populate solution words
        self.row_inputs = {
            self.puzzle.solution[2],
            self.puzzle.solution[3],
            self.puzzle.solution[4],
            self.puzzle.solution[5],
        }
        self.active_step = 4
    end
end

function Engine:saveCurrentState()
    Storage:save("state_" .. self.current_level, {
        row_inputs = self.row_inputs,
        revealed_moves = self.revealed_moves,
        hints_used = self.hints_used,
        active_step = self.active_step,
    })
end

function Engine:getPrevWord(step_idx)
    local s = step_idx or self.active_step
    if s == 1 then
        return self.puzzle.start
    else
        return self.row_inputs[s - 1]
    end
end

function Engine:getTargetWord(step_idx)
    local s = step_idx or self.active_step
    if self.puzzle and self.puzzle.solution then
        return self.puzzle.solution[s + 1]
    end
    return nil
end

function Engine:handleKey(key)
    if self.is_solved then return end

    if key == "BACKSPACE" or key == "⌫" then
        if #self.current_input > 0 then
            self.current_input = self.current_input:sub(1, -2)
            self.message = ""
            self.is_error = false
        end
    elseif type(key) == "string" and #key == 1 and key:match("[A-Za-z]") then
        if #self.current_input < 16 then
            self.current_input = self.current_input .. key:lower()
            self.message = ""
            self.is_error = false
            self:checkAutoSubmit()
        end
    end
end

function Engine:checkAutoSubmit()
    if self.is_solved then return end
    local target = self:getTargetWord(self.active_step)
    if not target then return end

    local cand = self.current_input:lower()
    local prev_word = self:getPrevWord(self.active_step)

    -- Auto-infer compound partner if full compound was typed
    local partner = Dictionary:infer_compound_partner(prev_word, cand)
    if partner and partner == target:lower() then
        cand = partner
    end

    if cand == target:lower() then
        -- Correct word typed! Auto-submit!
        self.row_inputs[self.active_step] = target
        self.current_input = ""
        self.message = ""
        self.is_error = false

        if self.active_step < 4 then
            self.active_step = self.active_step + 1
            self:saveCurrentState()
        else
            -- Puzzle Solved!
            self.is_solved = true
            local is_perfect = not self.hints_used
            self.solved_map[self.current_level] = {
                solved = true,
                perfect = is_perfect,
                timestamp = os.time(),
            }
            if self.current_level >= self.unlocked_level and self.current_level < #Puzzles then
                self.unlocked_level = self.current_level + 1
            end
            Storage:save("unlocked_level", self.unlocked_level)
            Storage:save("solved_map", self.solved_map)
            self:saveCurrentState()
        end
    end
end

function Engine:undo()
    if self.is_solved then return end

    if #self.current_input > 0 then
        self.current_input = ""
        self.message = ""
        self.is_error = false
    elseif self.active_step > 1 then
        self.active_step = self.active_step - 1
        self.row_inputs[self.active_step] = ""
        self.current_input = ""
        self.message = ""
        self.is_error = false
        self:saveCurrentState()
    end
end

function Engine:hint()
    if self.is_solved then return end
    local move_type = self.puzzle.moves[self.active_step]
    self.revealed_moves[self.active_step] = true
    self.hints_used = true
    self.message = string.format("Hint: Step %d is a %s move", self.active_step, move_type:upper())
    self.is_error = false
    self:saveCurrentState()
end

function Engine:getHCAVStatus()
    local status = {
        homophone = false,
        compound = false,
        anagram = false,
        verb = false,
    }
    if not self.puzzle or not self.puzzle.moves then return status end

    for i = 1, 4 do
        if self.row_inputs[i] ~= "" or self.revealed_moves[i] then
            local m = self.puzzle.moves[i]
            if m then
                status[m] = true
            end
        end
    end
    return status
end

function Engine:resetLevel()
    self.active_step = 1
    self.current_input = ""
    self.row_inputs = { "", "", "", "" }
    self.revealed_moves = { false, false, false, false }
    self.hints_used = false
    self.is_solved = false
    self.message = ""
    self.is_error = false
    self:saveCurrentState()
end

function Engine:giveUp()
    self.hints_used = true
    self.row_inputs = {
        self.puzzle.solution[2],
        self.puzzle.solution[3],
        self.puzzle.solution[4],
        self.puzzle.solution[5],
    }
    self.revealed_moves = { true, true, true, true }
    self.active_step = 4
    self.is_solved = true
    self.current_input = ""

    self.solved_map[self.current_level] = {
        solved = true,
        perfect = false,
        timestamp = os.time(),
    }
    if self.current_level >= self.unlocked_level and self.current_level < #Puzzles then
        self.unlocked_level = self.current_level + 1
    end
    Storage:save("unlocked_level", self.unlocked_level)
    Storage:save("solved_map", self.solved_map)
    self:saveCurrentState()
end

return Engine
