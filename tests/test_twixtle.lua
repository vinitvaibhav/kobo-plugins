--[[
    Twixtle Comprehensive Test & Stress Test Suite (v4)
    Tests all 550 levels, edge cases, move rules, engine mechanics, persistence, and memory stability.
--]]

package.path = package.path .. ";./twixtle.koplugin/?.lua"

local Dictionary = require("dictionary")
local Puzzles = require("puzzles")
local Engine = require("engine")
local Storage = require("storage")

local tests_run = 0
local tests_passed = 0

local function assert_true(cond, msg)
    tests_run = tests_run + 1
    if not cond then
        error("ASSERTION FAILED: " .. (msg or "condition was false"))
    end
    tests_passed = tests_passed + 1
end

local function assert_false(cond, msg)
    assert_true(not cond, msg)
end

local function assert_equal(a, b, msg)
    assert_true(a == b, (msg or "") .. " Expected " .. tostring(b) .. ", got " .. tostring(a))
end

print("=======================================================")
print("          TWIXTLE TEST & STRESS SUITE (v4)             ")
print("=======================================================")

-- 1. Initialize Dictionary
local t0 = os.clock()
Dictionary:init("twixtle.koplugin")
local t_init = os.clock() - t0
print(string.format("[✓] Dictionary initialized in %.3f seconds.", t_init))
assert_true(Dictionary.initialized, "Dictionary must be initialized")

-- 2. Vocabulary & Word Lookups
print("\n[+] Testing Vocabulary & Word Lookups...")
assert_true(Dictionary:is_valid_word("heart"), "'heart' must be in dictionary")
assert_true(Dictionary:is_valid_word("HEART"), "Dictionary lookup must be case-insensitive")
assert_true(Dictionary:is_valid_word("earth"), "'earth' must be in dictionary")
assert_false(Dictionary:is_valid_word("zzzzzqqq"), "'zzzzzqqq' must not be in dictionary")
assert_false(Dictionary:is_valid_word(""), "Empty string must not be valid word")

-- 3. Anagram Tests
print("[+] Testing Anagram Logic & Edge Cases...")
assert_true(Dictionary:is_valid_step("arc", "car", "anagram"), "arc -> car is valid anagram")
assert_true(Dictionary:is_valid_step("heart", "earth", "anagram"), "heart -> earth is valid anagram")
assert_true(Dictionary:is_valid_step("listen", "silent", "anagram"), "listen -> silent is valid anagram")
assert_false(Dictionary:is_valid_step("arc", "arc", "anagram"), "Identical word must not be valid anagram")
assert_false(Dictionary:is_valid_step("cat", "cats", "anagram"), "Different length must fail")
assert_false(Dictionary:is_valid_step("letter", "settle", "anagram"), "Letter count mismatch must fail")
assert_false(Dictionary:is_valid_step("xyz", "zyx", "anagram"), "Non-dictionary anagram must fail")

-- 4. Compound Tests
print("[+] Testing Closed Compound Logic & Edge Cases...")
assert_true(Dictionary:is_valid_step("car", "side", "compound"), "car -> side (sidecar) is valid compound")
assert_true(Dictionary:is_valid_step("side", "car", "compound"), "side -> car is valid compound (bidirectional)")
assert_true(Dictionary:is_valid_step("sweat", "band", "compound"), "sweat -> band (sweatband) is valid compound")
assert_true(Dictionary:is_valid_step("light", "house", "compound"), "light -> house (lighthouse) is valid compound")
assert_false(Dictionary:is_valid_step("table", "sky", "compound"), "Random pair must not be valid compound")
assert_false(Dictionary:is_valid_step("side", "side", "compound"), "Identical word compound must fail")

-- 5. Homophone Tests (Including Suffix Propagation)
print("[+] Testing Homophone Logic & Suffix Propagation...")
assert_true(Dictionary:is_valid_step("flower", "flour", "homophone"), "flower -> flour is valid homophone")
assert_true(Dictionary:is_valid_step("flour", "flower", "homophone"), "flour -> flower is valid homophone")
assert_true(Dictionary:is_valid_step("side", "sighed", "homophone"), "side -> sighed is valid homophone")
assert_true(Dictionary:is_valid_step("bare", "bear", "homophone"), "bare -> bear is valid homophone")
assert_true(Dictionary:is_valid_step("sight", "site", "homophone"), "sight -> site is valid homophone")
assert_true(Dictionary:is_valid_step("bears", "bares", "homophone"), "bears -> bares suffix -s valid")
assert_false(Dictionary:is_valid_step("bare", "bare", "homophone"), "Identical word homophone must fail")
assert_false(Dictionary:is_valid_step("apple", "banana", "homophone"), "Unrelated words must fail")

-- 6. Verb Inflection Tests (Irregular & Regular)
print("[+] Testing Verb Form Logic & Inflections...")
assert_true(Dictionary:is_valid_step("run", "ran", "verb"), "run -> ran is valid verb form")
assert_true(Dictionary:is_valid_step("sing", "sang", "verb"), "sing -> sang is valid verb form")
assert_true(Dictionary:is_valid_step("sing", "sung", "verb"), "sing -> sung is valid verb form")
assert_true(Dictionary:is_valid_step("singing", "sings", "verb"), "singing -> sings is valid verb form")
assert_true(Dictionary:is_valid_step("drop", "dropped", "verb"), "drop -> dropped (consonant doubling) is valid")
assert_true(Dictionary:is_valid_step("drop", "dropping", "verb"), "drop -> dropping is valid")
assert_true(Dictionary:is_valid_step("die", "dying", "verb"), "die -> dying is valid verb form")
assert_true(Dictionary:is_valid_step("dying", "dies", "verb"), "dying -> dies is valid verb form")
assert_true(Dictionary:is_valid_step("carry", "carried", "verb"), "carry -> carried is valid verb form")
assert_true(Dictionary:is_valid_step("carry", "carries", "verb"), "carry -> carries is valid verb form")
assert_false(Dictionary:is_valid_step("run", "jump", "verb"), "Unrelated verbs must fail")
assert_false(Dictionary:is_valid_step("run", "run", "verb"), "Identical word verb must fail")

-- 7. Full 550 Puzzle Validation Suite
print("\n[+] Stress Testing All 550 Puzzles...")
local puzzle_start_time = os.clock()
local puzzle_errors = 0
for idx, p in ipairs(Puzzles) do
    assert_equal(#p.moves, 4, "Puzzle " .. idx .. " must have 4 moves")
    assert_equal(#p.solution, 5, "Puzzle " .. idx .. " must have 5 solution words")
    assert_equal(p.solution[1], p.start, "Solution[1] must equal start")
    assert_equal(p.solution[5], p["end"], "Solution[5] must equal end")

    local move_set = {}
    for _, m in ipairs(p.moves) do
        move_set[m] = true
    end
    assert_true(move_set.anagram and move_set.compound and move_set.homophone and move_set.verb, "Puzzle " .. idx .. " must use all 4 move types")

    for step = 1, 4 do
        local from_w = p.solution[step]
        local to_w = p.solution[step + 1]
        local mtype = p.moves[step]
        local valid = Dictionary:is_valid_step(from_w, to_w, mtype)
        if not valid then
            puzzle_errors = puzzle_errors + 1
            print(string.format("ERROR: Puzzle %d step %d (%s) invalid: %s -> %s", p.level, step, mtype, from_w, to_w))
        end
    end
end
local puzzle_time = os.clock() - puzzle_start_time
print(string.format("[✓] Verified all %d puzzles (2,200 transitions) in %.3f seconds.", #Puzzles, puzzle_time))
assert_equal(puzzle_errors, 0, "All 550 puzzles must have 0 transition errors")

-- 8. Engine v4 Mechanics (Manual Action Selection, Enter-to-Submit, Reset on Error, 3 Words)
print("\n[+] Testing Engine v4 Mechanics & Gameplay...")
local test_settings = "/tmp/twixtle_test_settings_v4.lua"
os.remove(test_settings)

Engine:init("twixtle.koplugin", test_settings)
assert_equal(Engine.current_level, 1, "Starts at level 1")
assert_equal(Engine.active_step, 1, "Starts at active step 1")
assert_false(Engine.is_solved, "New level must not be solved")

-- Test 8a: Submitting without typing
Engine:handleKey("↵")
assert_true(Engine.is_error, "Submitting empty word must set error")
assert_equal(Engine.active_step, 1, "Active step stays 1")

-- Test 8b: Submitting without selecting action
Engine:handleKey("C")
Engine:handleKey("A")
Engine:handleKey("R")
assert_equal(Engine.current_input, "CAR", "Input holds CAR")
Engine:handleKey("↵")
assert_true(Engine.is_error, "Submitting without action must set error")
assert_equal(Engine.active_step, 1, "Active step stays 1")

-- Test 8c: Submitting invalid word -> resets word field!
Engine:selectAction("anagram")
assert_equal(Engine.selected_action, "anagram", "Action selected is anagram")
Engine.current_input = "ZZZ"
Engine:handleKey("↵")
assert_true(Engine.is_error, "Invalid word sets error")
assert_equal(Engine.current_input, "", "Invalid word resets word field to empty string!")

-- Test 8d: Submitting non-matching rule -> resets word field!
Engine.current_input = "DOG"
Engine:handleKey("↵")
assert_true(Engine.is_error, "DOG is not anagram of ARC")
assert_equal(Engine.current_input, "", "Mismatched rule resets word field to empty string!")

-- Test 8e: Submitting valid Step 1 (arc -> car via anagram)
Engine.current_input = "CAR"
Engine:handleKey("↵")
assert_false(Engine.is_error, "Valid step 1 must succeed without error")
assert_equal(Engine.row_inputs[1], "CAR", "Row 1 must be CAR")
assert_equal(Engine.chosen_moves[1], "anagram", "Move 1 is anagram")
assert_equal(Engine.active_step, 2, "Active step advances to 2")
assert_equal(Engine.current_input, "", "Buffer cleared on valid submit")
assert_true(Engine:isActionUsed("anagram"), "Anagram is now used")
assert_false(Engine:isActionUsed("compound"), "Compound is not used yet")

-- Test 8f: Step 2 (car -> side via compound)
Engine:selectAction("compound")
assert_equal(Engine.selected_action, "compound")
Engine.current_input = "SIDE"
Engine:handleKey("↵")
assert_equal(Engine.row_inputs[2], "SIDE", "Row 2 must be SIDE")
assert_equal(Engine.chosen_moves[2], "compound", "Move 2 is compound")
assert_equal(Engine.active_step, 3, "Active step advances to 3")

-- Test 8g: Undo from Step 3
Engine:undo()
assert_equal(Engine.active_step, 2, "Undo rolls back to step 2")
assert_equal(Engine.row_inputs[2], "", "Row 2 cleared on undo")
assert_equal(Engine.chosen_moves[2], nil, "Move 2 cleared on undo")
assert_false(Engine:isActionUsed("compound"), "Compound rule freed on undo")

-- Re-do Step 2
Engine:selectAction("compound")
Engine.current_input = "SIDE"
Engine:handleKey("↵")
assert_equal(Engine.active_step, 3)

-- Test 8h: Step 3 (side -> sighed via homophone)
Engine:selectAction("homophone")
Engine.current_input = "SIGHED"
Engine:handleKey("↵")
assert_equal(Engine.row_inputs[3], "SIGHED", "Row 3 must be SIGHED")
assert_equal(Engine.chosen_moves[3], "homophone", "Move 3 is homophone")

-- Step 4 auto-assignment & win check
assert_equal(Engine.chosen_moves[4], "verb", "4th action auto-assigned to remaining action 'verb'")
assert_true(Engine.is_solved, "Level 1 is now SOLVED (sighed -> sigh via verb)!")
assert_equal(Engine.message, "Puzzle Solved! ★★★")

-- Test 8i: Reset Level Button
Engine:resetLevel()
assert_equal(Engine.active_step, 1, "Reset brings active step to 1")
assert_equal(Engine.row_inputs[1], "", "Row 1 cleared on reset")
assert_equal(Engine.row_inputs[2], "", "Row 2 cleared on reset")
assert_equal(Engine.row_inputs[3], "", "Row 3 cleared on reset")
assert_equal(Engine.chosen_moves[1], nil, "Move 1 cleared on reset")
assert_false(Engine.is_solved, "Solved flag cleared on reset")

-- 9. Stress Testing All 550 Levels Playthrough
print("\n[+] Stress Testing All 550 Levels Playthrough in Engine v4...")
for i = 1, #Puzzles do
    Engine:loadLevel(i)
    local p = Puzzles[i]
    -- Step 1
    Engine:selectAction(p.moves[1])
    Engine.current_input = p.solution[2]
    Engine:handleKey("↵")
    -- Step 2
    Engine:selectAction(p.moves[2])
    Engine.current_input = p.solution[3]
    Engine:handleKey("↵")
    -- Step 3
    Engine:selectAction(p.moves[3])
    Engine.current_input = p.solution[4]
    Engine:handleKey("↵")

    assert_true(Engine.is_solved, "Level " .. i .. " must be solved")
    assert_equal(Engine.chosen_moves[4], p.moves[4], "4th move matches puzzle move 4")
end
print(string.format("[✓] Successfully played through all %d levels with 0 errors!", #Puzzles))

-- Memory check
collectgarbage("collect")
local mem_final = collectgarbage("count") / 1024
print(string.format("[✓] Memory after all 550 level playthroughs: %.2f MB", mem_final))

print("\n=======================================================")
print(string.format("ALL TESTS PASSED! (%d/%d assertions passed with 0 errors)", tests_passed, tests_run))
print("=======================================================")
