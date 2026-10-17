--[[
    Twixtle Comprehensive Test & Stress Test Suite
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
print("          TWIXTLE TEST & STRESS SUITE                  ")
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
-- Suffix propagation: -s, -ed, -ing
assert_true(Dictionary:is_valid_step("bears", "bares", "homophone"), "bears -> bares suffix -s valid")
assert_false(Dictionary:is_valid_step("bare", "bare", "homophone"), "Identical word homophone must fail")
assert_false(Dictionary:is_valid_step("apple", "banana", "homophone"), "Unrelated words must fail")

-- 6. Verb Inflection Tests (Irregular & Regular)
print("[+] Testing Verb Form Logic & Inflections...")
-- Irregular verbs
assert_true(Dictionary:is_valid_step("run", "ran", "verb"), "run -> ran is valid verb form")
assert_true(Dictionary:is_valid_step("sing", "sang", "verb"), "sing -> sang is valid verb form")
assert_true(Dictionary:is_valid_step("sing", "sung", "verb"), "sing -> sung is valid verb form")
assert_true(Dictionary:is_valid_step("singing", "sings", "verb"), "singing -> sings is valid verb form")
-- Regular verbs with doubling
assert_true(Dictionary:is_valid_step("drop", "dropped", "verb"), "drop -> dropped (consonant doubling) is valid")
assert_true(Dictionary:is_valid_step("drop", "dropping", "verb"), "drop -> dropping is valid")
-- Regular verbs ending in -ie (die, tie, lie)
assert_true(Dictionary:is_valid_step("die", "dying", "verb"), "die -> dying is valid verb form")
assert_true(Dictionary:is_valid_step("dying", "dies", "verb"), "dying -> dies is valid verb form")
assert_true(Dictionary:is_valid_step("tie", "tying", "verb"), "tie -> tying is valid verb form")
assert_true(Dictionary:is_valid_step("lie", "lying", "verb"), "lie -> lying is valid verb form")
-- Regular verbs ending in -y
assert_true(Dictionary:is_valid_step("carry", "carried", "verb"), "carry -> carried is valid verb form")
assert_true(Dictionary:is_valid_step("carry", "carries", "verb"), "carry -> carries is valid verb form")
-- Non-verbs or unrelated verbs
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

-- 8. Engine Simulation & Progression Tests
print("\n[+] Testing Engine Mechanics & Level Progression...")
local test_settings = "/tmp/twixtle_test_settings.lua"
os.remove(test_settings)

Engine:init("twixtle.koplugin", test_settings)
assert_equal(Engine.current_level, 1, "Starts at level 1")
assert_equal(Engine.unlocked_level, 1, "Unlocked level starts at 1")
assert_false(Engine.is_solved, "New level must not be solved")

-- Test invalid word rejection
Engine:handleKey("Z")
Engine:handleKey("Z")
Engine:handleKey("Z")
Engine:handleKey("ENTER")
assert_false(Engine.is_solved, "Invalid word 'ZZZ' must not advance")
assert_true(Engine.is_error, "Must show error for invalid word")

-- Test backspace
Engine:handleKey("BACKSPACE")
Engine:handleKey("BACKSPACE")
Engine:handleKey("BACKSPACE")
assert_equal(Engine.row_inputs[1], "", "Backspace must clear row input")

-- Test correct step 1 for Level 1 (arc -> car via anagram)
for i = 1, #"car" do
    Engine:handleKey(("car"):sub(i, i))
end
Engine:handleKey("ENTER")
assert_equal(Engine.row_inputs[1], "car", "Row 1 should be 'car'")
assert_equal(Engine.active_step, 2, "Active step should advance to 2")

-- Test correct step 2 for Level 1 (car -> side via compound)
for i = 1, #"side" do
    Engine:handleKey(("side"):sub(i, i))
end
Engine:handleKey("ENTER")
assert_equal(Engine.row_inputs[2], "side", "Row 2 should be 'side'")
assert_equal(Engine.active_step, 3, "Active step should advance to 3")

-- Test correct step 3 for Level 1 (side -> sighed via homophone, and sighed -> sigh via verb)
for i = 1, #"sighed" do
    Engine:handleKey(("sighed"):sub(i, i))
end
Engine:handleKey("ENTER")
assert_true(Engine.is_solved, "Level 1 must be solved after step 3 completes chain to 'sigh'")
assert_equal(Engine.unlocked_level, 2, "Level 2 must be unlocked")
assert_true(Engine.solved_map[1].solved, "Level 1 marked solved in solved_map")
assert_true(Engine.solved_map[1].perfect, "Level 1 without hints must be marked PERFECT ★")

-- Test hint reveal
Engine:loadLevel(2)
assert_false(Engine.revealed_moves[1], "Move 1 starts unrevealed")
Engine:revealMove(1)
assert_true(Engine.revealed_moves[1], "Move 1 must be revealed")
assert_true(Engine.hints_used, "Hints used must be true after revealing move")

-- 9. Memory & Playthrough Stress Test (Simulate All 550 Levels in a Loop)
print("\n[+] Stress Testing Memory & Garbage Collection (All 550 Levels End-to-End)...")
collectgarbage("collect")
local mem_before = collectgarbage("count")

for lvl = 1, #Puzzles do
    Engine:loadLevel(lvl)
    local sol = Engine.puzzle.solution
    -- Play full solution
    Engine.row_inputs[1] = sol[2]
    Engine.row_inputs[2] = sol[3]
    Engine.row_inputs[3] = sol[4]
    Engine:checkSolvedStatus()
    assert_true(Engine.is_solved, "Level " .. lvl .. " must solve correctly")
    assert_true(Engine.solved_map[lvl].solved, "Level " .. lvl .. " recorded in storage")
end

collectgarbage("collect")
local mem_after = collectgarbage("count")
local mem_diff = (mem_after - mem_before) / 1024
print(string.format("[✓] Simulated all 550 levels. Memory diff after GC: %.2f MB (Initial: %.2f MB, Final: %.2f MB)", mem_diff, mem_before / 1024, mem_after / 1024))
assert_true(math.abs(mem_diff) < 2.0, "Memory must remain stable without leaks")

-- Clean up test file
os.remove(test_settings)

print("\n=======================================================")
print(string.format("ALL TESTS PASSED! (%d/%d assertions passed with 0 errors)", tests_passed, tests_run))
print("=======================================================")
