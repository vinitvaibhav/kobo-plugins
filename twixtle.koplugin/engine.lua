--[[
    Twixtle Game Engine (v4)
    Manages gameplay state, free-form word validation, HCAV selection, enter-to-submit,
    undo stack, hint reveal, and level progression.
--]]

local Dictionary = require("dictionary")
local Puzzles = require("puzzles")
local Storage = require("storage")

local ALL_MOVES = { "homophone", "compound", "anagram", "verb" }

local Engine = {
    unlocked_level = 1,
    current_level = 1,
    puzzle = nil,
    active_step = 1, -- 1, 2, or 3
    current_input = "", -- live buffer typed in active step
    row_inputs = { "", "", "" }, -- words confirmed for steps 1..3
    chosen_moves = { nil, nil, nil, nil }, -- actions for steps 1..4
    selected_action = nil, -- currently selected action for active step
    revealed_moves = { false, false, false, false },
    hints_used = false,
    solved_map = {},
    message = "",
    is_error = false,
    is_solved = false,
}

function Engine:init(plugin_dir, settings_path)
    self.plugin_dir = plugin_dir
    Dictionary:init(plugin_dir)
    Storage:init(settings_path)

    self.unlocked_level = Storage:get("unlocked_level", 1)
    self.current_level = Storage:get("current_level", 1)
    self.solved_map = Storage:get("solved_map", {})

    self:loadLevel(self.current_level)
end

function Engine:loadLevel(level_num)
    if not self.unlocked_level or self.unlocked_level < 1 then
        self.unlocked_level = 1
    end
    if level_num < 1 then level_num = 1 end
    if level_num > #Puzzles then level_num = #Puzzles end
    if level_num > self.unlocked_level then
        level_num = self.unlocked_level
    end

    self.current_level = level_num
    Storage:save("current_level", self.current_level)

    self.puzzle = Puzzles[self.current_level]
    self.active_step = 1
    self.current_input = ""
    self.row_inputs = { "", "", "" }
    self.chosen_moves = { nil, nil, nil, nil }
    self.selected_action = nil
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
        }
        self.chosen_moves = {
            saved_state.chosen_moves and saved_state.chosen_moves[1] or nil,
            saved_state.chosen_moves and saved_state.chosen_moves[2] or nil,
            saved_state.chosen_moves and saved_state.chosen_moves[3] or nil,
            saved_state.chosen_moves and saved_state.chosen_moves[4] or nil,
        }
        self.hints_used = saved_state.hints_used or false
        self.active_step = saved_state.active_step or 1

        -- Restore first empty step
        for i = 1, 3 do
            if self.row_inputs[i] == "" then
                self.active_step = i
                break
            end
        end

        if self.row_inputs[3] ~= "" and self.chosen_moves[4] then
            -- Verify if solved
            if Dictionary:is_valid_step(self.row_inputs[3], self.puzzle["end"], self.chosen_moves[4]) then
                self.is_solved = true
            end
        end
    end

    if self.solved_map[self.current_level] and self.solved_map[self.current_level].solved then
        self.is_solved = true
        self.row_inputs = {
            self.puzzle.solution[2]:upper(),
            self.puzzle.solution[3]:upper(),
            self.puzzle.solution[4]:upper(),
        }
        self.chosen_moves = {
            self.puzzle.moves[1],
            self.puzzle.moves[2],
            self.puzzle.moves[3],
            self.puzzle.moves[4],
        }
        self.active_step = 3
    end
end

function Engine:saveCurrentState()
    Storage:save("state_" .. self.current_level, {
        row_inputs = self.row_inputs,
        chosen_moves = self.chosen_moves,
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

function Engine:isActionUsed(action_name)
    for i = 1, self.active_step - 1 do
        if self.chosen_moves[i] == action_name then
            return true
        end
    end
    return false
end

function Engine:selectAction(action_name)
    if self.is_solved then return end
    if self:isActionUsed(action_name) then return end

    self.selected_action = action_name
    self.message = ""
    self.is_error = false
end

function Engine:getRemainingAction()
    local used = {}
    for i = 1, 3 do
        if self.chosen_moves[i] then
            used[self.chosen_moves[i]] = true
        end
    end
    for _, a in ipairs(ALL_MOVES) do
        if not used[a] then
            return a
        end
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
    elseif key == "ENTER" or key == "RETURN" or key == "↵" or key == "↵ ENTER" then
        self:submit()
    elseif type(key) == "string" and #key == 1 and key:match("[A-Za-z]") then
        if #self.current_input < 16 then
            self.current_input = self.current_input .. key:upper()
            self.message = ""
            self.is_error = false
        end
    end
end

function Engine:submit()
    if self.is_solved then return end

    local raw = self.current_input:gsub("%s+", ""):lower()
    if #raw == 0 then
        self.message = "Type a word before submitting!"
        self.is_error = true
        return
    end

    if not self.selected_action then
        self.message = "Select a rule (Homophone, Compound, Anagram, Verb) above first!"
        self.is_error = true
        return
    end

    local prev_word = self:getPrevWord(self.active_step):lower()
    local cand = raw

    -- If compound, check if full compound was typed (e.g. sidecar when prev was car)
    if self.selected_action == "compound" then
        local partner = Dictionary:infer_compound_partner(prev_word, cand)
        if partner then
            cand = partner
        end
    end

    -- 1. Check if word exists in dictionary
    if not Dictionary:is_valid_word(cand) then
        self.message = "'" .. cand:upper() .. "' is not in the dictionary!"
        self.is_error = true
        self.current_input = "" -- Reset the word field on error as requested
        return
    end

    -- 2. Check if valid step from prev_word
    local valid = Dictionary:is_valid_step(prev_word, cand, self.selected_action)
    if not valid then
        self.message = "'" .. cand:upper() .. "' is not a valid " .. self.selected_action:upper() .. " of '" .. prev_word:upper() .. "'!"
        self.is_error = true
        self.current_input = "" -- Reset the word field on error as requested
        return
    end

    -- Commit step
    self.row_inputs[self.active_step] = cand:upper()
    self.chosen_moves[self.active_step] = self.selected_action
    self.selected_action = nil
    self.current_input = ""
    self.message = ""
    self.is_error = false

    if self.active_step < 3 then
        self.active_step = self.active_step + 1
        self:saveCurrentState()
    else
        -- Step 3 submitted! Auto-fill 4th action with remaining unused rule
        local rem_action = self:getRemainingAction()
        self.chosen_moves[4] = rem_action

        -- Check if row 3 leads to END word via remaining action
        local end_word = self.puzzle["end"]:lower()
        local win = Dictionary:is_valid_step(cand, end_word, rem_action)
        if win then
            self.is_solved = true
            self.message = "Puzzle Solved! ★★★"
            self:markSolved()
            self:saveCurrentState()
        else
            self.message = "'" .. cand:upper() .. "' does not lead to '" .. self.puzzle["end"]:upper() .. "' via " .. rem_action:upper() .. "!"
            self.is_error = true
            self:saveCurrentState()
        end
    end
end

function Engine:markSolved()
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
end

function Engine:undo()
    if self.is_solved then return end

    if #self.current_input > 0 then
        self.current_input = ""
        self.message = ""
        self.is_error = false
    elseif self.active_step == 3 and self.row_inputs[3] ~= "" then
        -- Stuck on step 3 / end word
        self.row_inputs[3] = ""
        self.chosen_moves[3] = nil
        self.chosen_moves[4] = nil
        self.selected_action = nil
        self.current_input = ""
        self.message = ""
        self.is_error = false
        self:saveCurrentState()
    elseif self.active_step > 1 then
        self.active_step = self.active_step - 1
        self.row_inputs[self.active_step] = ""
        self.chosen_moves[self.active_step] = nil
        self.selected_action = nil
        self.current_input = ""
        self.message = ""
        self.is_error = false
        self:saveCurrentState()
    end
end

function Engine:resetLevel()
    self.active_step = 1
    self.current_input = ""
    self.row_inputs = { "", "", "" }
    self.chosen_moves = { nil, nil, nil, nil }
    self.selected_action = nil
    self.hints_used = false
    self.is_solved = false
    self.message = ""
    self.is_error = false
    self:saveCurrentState()
end

function Engine:hint()
    if self.is_solved then return end

    if self.active_step <= 3 then
        local canonical_action = self.puzzle.moves[self.active_step]
        if not self.selected_action then
            -- Select canonical action
            self.selected_action = canonical_action
            self.hints_used = true
            self.message = "Hint: Rule is " .. canonical_action:upper()
        else
            -- Reveal first or next letter of target word
            local target = self.puzzle.solution[self.active_step + 1]:upper()
            local next_len = math.min(#self.current_input + 1, #target)
            self.current_input = target:sub(1, next_len)
            self.hints_used = true
            self.message = "Hint: Word starts with " .. self.current_input
        end
    end
    self.is_error = false
    self:saveCurrentState()
end

return Engine
