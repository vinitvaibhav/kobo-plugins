--[[
    Twixtle Move Validation Engine & Dictionary for KOReader
    Provides O(1) word lookups, anagram checks, homophone matching (with suffix propagation),
    closed compound matching, and verb inflection mapping.
--]]

local Dictionary = {
    words = {},
    homo_map = {},
    comp_map = {},
    verb_by_word = {},
    verb_groups = {},
    initialized = false,
}

local VOWELS = {
    a = true, e = true, i = true, o = true, u = true,
}

local function should_double(base)
    local len = #base
    if len < 2 then return false end
    local last = base:sub(len, len)
    local prev = base:sub(len - 1, len - 1)
    if VOWELS[last] or not VOWELS[prev] then return false end
    if len >= 3 and VOWELS[base:sub(len - 2, len - 2)] then return false end
    if last == "w" or last == "x" or last == "y" then return false end
    return true
end

local function sort_string(s)
    local chars = {}
    for i = 1, #s do
        chars[i] = s:sub(i, i)
    end
    table.sort(chars)
    return table.concat(chars)
end

function Dictionary:init(plugin_dir)
    if self.initialized then return end

    local dir = plugin_dir or "."

    -- 1. Load words.txt
    local words_file = io.open(dir .. "/words.txt", "r")
    if not words_file then
        error("Twixtle error: Cannot open words.txt at " .. dir .. "/words.txt")
    end
    for line in words_file:lines() do
        local w = line:gsub("%s+", ""):lower()
        if #w > 0 then
            self.words[w] = true
        end
    end
    words_file:close()

    -- 2. Load dict_data.lua
    local dict_data = dofile(dir .. "/dict_data.lua")

    -- Homophones
    for _, g in ipairs(dict_data.homophones or {}) do
        for _, w in ipairs(g) do
            local lw = w:lower()
            if not self.homo_map[lw] then
                self.homo_map[lw] = {}
            end
            for _, other in ipairs(g) do
                local lo = other:lower()
                if lo ~= lw then
                    self.homo_map[lw][lo] = true
                end
            end
        end
    end

    -- Compounds
    for _, pair in ipairs(dict_data.compounds or {}) do
        local a = pair[1]:lower()
        local b = pair[2]:lower()
        if not self.comp_map[a] then self.comp_map[a] = {} end
        self.comp_map[a][b] = true
        if not self.comp_map[b] then self.comp_map[b] = {} end
        self.comp_map[b][a] = true
    end

    -- Helper to add verb group
    local function add_verb_group(forms)
        local clean = {}
        local seen = {}
        for _, f in ipairs(forms) do
            local lf = f:lower()
            if self.words[lf] and not seen[lf] then
                seen[lf] = true
                table.insert(clean, lf)
            end
        end
        if #clean >= 2 then
            local g_idx = #self.verb_groups + 1
            self.verb_groups[g_idx] = seen
            for _, w in ipairs(clean) do
                if not self.verb_by_word[w] then
                    self.verb_by_word[w] = {}
                end
                self.verb_by_word[w][g_idx] = true
            end
        end
    end

    -- Irregular verbs
    for _, forms in ipairs(dict_data.irregular_verbs or {}) do
        add_verb_group(forms)
    end

    -- Regular verbs inflection expansion
    for _, base in ipairs(dict_data.regular_verbs or {}) do
        local b = base:lower()
        local forms = { b }

        -- 3rd person singular
        if b:match("[sxz]$") or b:match("ch$") or b:match("sh$") then
            table.insert(forms, b .. "es")
        elseif b:match("[^aeiou]y$") and #b > 1 then
            table.insert(forms, b:sub(1, -2) .. "ies")
        else
            table.insert(forms, b .. "s")
        end

        -- Past / past participle
        if b:match("e$") then
            table.insert(forms, b .. "d")
        elseif b:match("[^aeiou]y$") and #b > 1 then
            table.insert(forms, b:sub(1, -2) .. "ied")
        elseif should_double(b) then
            table.insert(forms, b .. b:sub(-1) .. "ed")
        else
            table.insert(forms, b .. "ed")
        end

        -- -ing
        if b:match("ie$") then
            table.insert(forms, b:sub(1, -3) .. "ying")
        elseif b:match("e$") and not b:match("ee$") and not b:match("oe$") and not b:match("ye$") then
            table.insert(forms, b:sub(1, -2) .. "ing")
        elseif should_double(b) then
            table.insert(forms, b .. b:sub(-1) .. "ing")
        else
            table.insert(forms, b .. "ing")
        end

        add_verb_group(forms)
    end

    self.initialized = true
end

function Dictionary:is_valid_word(w)
    return not not self.words[w:lower()]
end

function Dictionary:is_anagram(w1, w2)
    if #w1 ~= #w2 then return false end
    return sort_string(w1) == sort_string(w2)
end

function Dictionary:is_homophone(w1, w2)
    local alts = self.homo_map[w1]
    if alts and alts[w2] then return true end

    -- Suffix propagation (-s, -ed, -ing)
    local suffixes = { "s", "ed", "ing" }
    for _, suf in ipairs(suffixes) do
        local slen = #suf
        if #w1 > slen + 1 and #w2 > slen + 1 then
            if w1:sub(-slen) == suf and w2:sub(-slen) == suf then
                local b1 = w1:sub(1, -slen - 1)
                local b2 = w2:sub(1, -slen - 1)
                local b_alts = self.homo_map[b1]
                if b_alts and b_alts[b2] then
                    return true
                end
            end
        end
    end
    return false
end

function Dictionary:is_compound(w1, w2)
    local alts = self.comp_map[w1]
    return not not (alts and alts[w2])
end

function Dictionary:infer_compound_partner(prev, input)
    if not prev or not input then return nil end
    prev = prev:lower():gsub("%s+", "")
    input = input:lower():gsub("%s+", "")
    if #input <= #prev or input == prev then return nil end
    local partners = self.comp_map[prev]
    if not partners then return nil end
    if input:sub(1, #prev) == prev then
        local cand = input:sub(#prev + 1)
        if cand ~= "" and partners[cand] then return cand end
    end
    if input:sub(-#prev) == prev then
        local cand = input:sub(1, -#prev - 1)
        if cand ~= "" and partners[cand] then return cand end
    end
    return nil
end

function Dictionary:is_verb_form(w1, w2)
    local g1 = self.verb_by_word[w1]
    local g2 = self.verb_by_word[w2]
    if not g1 or not g2 then return false end
    for g_idx, _ in pairs(g1) do
        if g2[g_idx] then return true end
    end
    return false
end

function Dictionary:is_valid_step(w1, w2, move_type)
    w1 = w1:lower():gsub("%s+", "")
    w2 = w2:lower():gsub("%s+", "")
    if w1 == w2 then return false end
    if not self:is_valid_word(w1) or not self:is_valid_word(w2) then
        return false
    end

    if move_type == "anagram" then
        return self:is_anagram(w1, w2)
    elseif move_type == "homophone" then
        return self:is_homophone(w1, w2)
    elseif move_type == "compound" then
        return self:is_compound(w1, w2)
    elseif move_type == "verb" then
        return self:is_verb_form(w1, w2)
    end
    return false
end

return Dictionary
