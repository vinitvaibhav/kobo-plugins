--[[
    Twixtle Persistence & Progress Storage for KOReader
    Saves unlocked level, solved badges, star ratings, and in-progress boards.
--]]

local Storage = {
    settings_file = nil,
    settings = nil,
}

function Storage:init(settings_file_path)
    self.settings_file = settings_file_path
    local has_luasettings, LuaSettings = pcall(require, "luasettings")
    if has_luasettings then
        self.settings = LuaSettings:open(self.settings_file)
    else
        -- Fallback standalone loader for tests
        self.data = {}
        local f = io.open(self.settings_file, "r")
        if f then
            local content = f:read("*all")
            f:close()
            local chunk = loadstring("return " .. content)
            if chunk then
                self.data = chunk() or {}
            end
        end
    end
end

function Storage:get(key, default_val)
    if self.settings then
        local val = self.settings:readSetting(key)
        if val ~= nil then return val end
        return default_val
    elseif self.data then
        local val = self.data[key]
        if val ~= nil then return val end
        return default_val
    end
    return default_val
end

function Storage:save(key, val)
    if self.settings then
        self.settings:saveSetting(key, val)
        self.settings:flush()
    elseif self.data then
        self.data[key] = val
        local f = io.open(self.settings_file, "w")
        if f then
            -- Simple serialize for tests
            local function serialize(o)
                if type(o) == "number" or type(o) == "boolean" then
                    return tostring(o)
                elseif type(o) == "string" then
                    return string.format("%q", o)
                elseif type(o) == "table" then
                    local parts = {}
                    for k, v in pairs(o) do
                        local k_str = type(k) == "number" and "[" .. k .. "]" or "[" .. string.format("%q", k) .. "]"
                        table.insert(parts, k_str .. " = " .. serialize(v))
                    end
                    return "{ " .. table.concat(parts, ", ") .. " }"
                end
                return "nil"
            end
            f:write("return " .. serialize(self.data) .. "\n")
            f:close()
        end
    end
end

function Storage:flush()
    if self.settings and self.settings.flush then
        self.settings:flush()
    end
end

return Storage
