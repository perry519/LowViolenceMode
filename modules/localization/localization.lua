local Localization = rawget(_G, "LowViolenceModeLocalization") or {}
_G.LowViolenceModeLocalization = Localization

Localization.ModPath = Localization.ModPath or ModPath

local function read_json_strings()
    if not Localization.ModPath or not io or not json or not json.decode then
        return nil
    end

    local file = io.open(Localization.ModPath .. "loc/en.json", "r")
    if not file then
        return nil
    end

    local contents = file:read("*all")
    file:close()

    local success, data = pcall(json.decode, contents)
    if success and type(data) == "table" then
        return data
    end
end

function Localization:Strings()
    if not self.strings then
        self.strings = read_json_strings() or {}
    end

    return self.strings
end

function Localization:Text(key)
    local strings = self:Strings()
    return strings[key] or key
end

function Localization:Load(loc)
    loc = loc or managers and managers.localization or LocalizationManager
    if not loc then
        return
    end

    if loc.add_localized_strings then
        pcall(loc.add_localized_strings, loc, self:Strings(), true)
    end

    if self.ModPath and loc.load_localization_file then
        pcall(loc.load_localization_file, loc, self.ModPath .. "loc/en.json", false)
    end
end

return Localization
