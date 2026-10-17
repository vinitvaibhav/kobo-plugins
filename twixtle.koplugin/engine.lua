--[[
    Twixtle Game Engine
    Manages gameplay state, validation transitions, hints, and level progression.
--]]

local Dictionary = require("dictionary")
local Puzzles = require("puzzles")
local Storage = require("storage")

local Engine = {
    unlocked_level = 1,
    current_level = 1,
    puzzle = nil,
    active_step = 1, -- 1, 2, or 3 (Row 1, 2, or 3)
    row_inputs = { "", "", "" },
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
    self.is_solved = false
    self.message = ""
    self.is_error = false

    local saved_state = Storage:get("state_" .. self.current_level, nil)
    if saved_state then
        self.row_inputs = {
            saved_state.row_inputs and saved_state.row_inputs[1] or "",
            saved_state.row_inputs and saved_state.row_inputs[2] or "",
            saved_state.row_inputs and saved_state.row_inputs[3] or "",
        }
        self.revealed_moves = {
            saved_state.revealed_moves and saved_state.revealed_moves[1] or false,
            saved_state.revealed_moves and saved_state.revealed_moves[2] or false,
            saved_state.revealed_moves and saved_state.revealed_moves[3] or false,
            saved_state.revealed_moves and saved_state.revealed_moves[4] or false,
        }
        self.hints_used = not not saved_state.hints_used
    else
        self.row_inputs = { "", "", "" }
        self.revealed_moves = { false, false, false, false }
        self.hints_used = false
    end

    self:checkSolvedStatus()
end

function Engine:saveState()
    Storage:save("state_" .. self.current_level, {
        row_inputs = self.row_inputs,
        revealed_moves = self.revealed_moves,
        hints_used = self.hints_used,
    })
    Storage:flush()
end

function Engine:setMessage(msg, is_err)
    self.message = msg or ""
    self.is_error = not not is_err
end

function Engine:clearMessage()
    self.message = ""
    self.is_error = false
end

function Engine:handleKey(key)
    if self.is_solved then return end

    if key == "BACKSPACE" or key == "DEL" then
        local curr = self.row_inputs[self.active_step]
        if #curr > 0 then
            self.row_inputs[self.active_step] = curr:sub(1, -2)
            self:clearMessage()
            self:saveState()
        end
        return
    end

    if key == "ENTER" or key == "CHECK" then
        self:checkActiveStep()
        return
    end

    -- Letter key A-Z
    if type(key) == "string" and #key == 1 and key:match("[A-Za-z]") then
        local curr = self.row_inputs[self.active_step]
        if #curr < 15 then
            self.row_inputs[self.active_step] = curr .. key:lower()
            self:clearMessage()
            self:saveState()
        end
    end
end

function Engine:checkActiveStep()
    local input = self.row_inputs[self.active_step]:gsub("%s+", ""):lower()
    if #input == 0 then
        self:setMessage("Please type a word first.", true)
        return false
    end

    if not Dictionary:is_valid_word(input) then
        self:setMessage('"' .. input:upper() .. '" is not in dictionary.', true)
        return false
    end

    if self.active_step == 1 then
        local ok = Dictionary:is_valid_step(self.puzzle.start, input, self.puzzle.moves[1])
        if ok then
            self:setMessage("Valid " .. self.puzzle.moves[1]:upper() .. "!")
            self.active_step = 2
            self:saveState()
            self:checkSolvedStatus()
            return true
        else
            self:setMessage('"' .. input:upper() .. '" is not a valid ' .. self.puzzle.moves[1]:upper() .. " of " .. self.puzzle.start:upper() .. ".", true)
            return false
        end
    elseif self.active_step == 2 then
        local prev = self.row_inputs[1]:gsub("%s+", ""):lower()
        if not Dictionary:is_valid_step(self.puzzle.start, prev, self.puzzle.moves[1]) then
            self:setMessage("Solve Word 1 first.", true)
            self.active_step = 1
            return false
        end
        local ok = Dictionary:is_valid_step(prev, input, self.puzzle.moves[2])
        if ok then
            self:setMessage("Valid " .. self.puzzle.moves[2]:upper() .. "!")
            self.active_step = 3
            self:saveState()
            self:checkSolvedStatus()
            return true
        else
            self:setMessage('"' .. input:upper() .. '" is not a valid ' .. self.puzzle.moves[2]:upper() .. " of " .. prev:upper() .. ".", true)
            return false
        end
    elseif self.active_step == 3 then
        local prev = self.row_inputs[2]:gsub("%s+", ""):lower()
        if not Dictionary:is_valid_step(self.row_inputs[1], prev, self.puzzle.moves[2]) then
            self:setMessage("Solve Word 2 first.", true)
            self.active_step = 2
            return false
        end
        local ok3 = Dictionary:is_valid_step(prev, input, self.puzzle.moves[3])
        if not ok3 then
            self:setMessage('"' .. input:upper() .. '" is not a valid ' .. self.puzzle.moves[3]:upper() .. " of " .. prev:upper() .. ".", true)
            return false
        end

        local ok4 = Dictionary:is_valid_step(input, self.puzzle["end"], self.puzzle.moves[4])
        if not ok4 then
            self:setMessage("Valid " .. self.puzzle.moves[3]:upper() .. ", but doesn't lead to " .. self.puzzle["end"]:upper() .. " via " .. self.puzzle.moves[4]:upper() .. ".", true)
            self:saveState()
            return false
        end

        self:saveState()
        self:checkSolvedStatus()
        return true
    end
    return false
end

function Engine:checkSolvedStatus()
    local w0 = self.puzzle.start
    local w1 = self.row_inputs[1]
    local w2 = self.row_inputs[2]
    local w3 = self.row_inputs[3]
    local w4 = self.puzzle["end"]

    local v1 = Dictionary:is_valid_step(w0, w1, self.puzzle.moves[1])
    local v2 = v1 and Dictionary:is_valid_step(w1, w2, self.puzzle.moves[2])
    local v3 = v2 and Dictionary:is_valid_step(w2, w3, self.puzzle.moves[3])
    local v4 = v3 and Dictionary:is_valid_step(w3, w4, self.puzzle.moves[4])

    if v1 and v2 and v3 and v4 then
        self.is_solved = true
        local is_perfect = (not self.hints_used) and (not self.revealed_moves[1]) and (not self.revealed_moves[2]) and (not self.revealed_moves[3]) and (not self.revealed_moves[4])

        self.solved_map[self.current_level] = {
            solved = true,
            perfect = is_perfect,
            date = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
        Storage:save("solved_map", self.solved_map)

        if self.current_level >= self.unlocked_level and self.unlocked_level < #Puzzles then
            self.unlocked_level = self.current_level + 1
            Storage:save("unlocked_level", self.unlocked_level)
        end
        Storage:flush()
        return true
    end
    self.is_solved = false
    return false
end

function Engine:revealMove(step_idx)
    if step_idx >= 1 and step_idx <= 4 then
        if not self.revealed_moves[step_idx] then
            self.revealed_moves[step_idx] = true
            self.hints_used = true
            self:saveState()
            self:setMessage("Move " .. step_idx .. " revealed: " .. self.puzzle.moves[step_idx]:upper())
        end
    end
end

function Engine:provideWordHint()
    self.hints_used = true
    local target = self.puzzle.solution[self.active_step + 1]
    local curr = self.row_inputs[self.active_step]
    if #curr < #target then
        self.row_inputs[self.active_step] = target:sub(1, #curr + 1)
    else
        self.row_inputs[self.active_step] = target
    end
    self:saveState()
    self:setMessage('Hint: Word ' .. self.active_step .. ' starts with "' .. self.row_inputs[self.active_step]:upper() .. '"')
end

function Engine:clearActiveRow()
    self.row_inputs[self.active_step] = ""
    self:clearMessage()
    self:saveState()
end

function Engine:resetLevel()
    self.row_inputs = { "", "", "" }
    self.revealed_moves = { false, false, false, false }
    self.hints_used = false
    self.active_step = 1
    self.is_solved = false
    self:saveState()
    self:setMessage("Level reset.")
end

function Engine:giveUp()
    self.hints_used = true
    self.revealed_moves = { true, true, true, true }
    self.row_inputs = {
        self.puzzle.solution[2],
        self.puzzle.solution[3],
        self.puzzle.solution[4],
    }
    self:saveState()
    self:checkSolvedStatus()
end

return Engine
