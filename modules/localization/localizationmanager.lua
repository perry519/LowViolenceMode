local key = ModPath .. "\t" .. RequiredScript
if _G[key] then
    return
else
    _G[key] = true
end

local function load_localization(loc)
    dofile(ModPath .. "modules/localization/localization.lua")

    local localization = _G.LowViolenceModeLocalization
    if localization and localization.Load then
        localization:Load(loc)
    end
end

Hooks:Add("LocalizationManagerPostInit", "LowViolenceMode_LocalizationManagerPostInit", function(loc)
    load_localization(loc)
end)

load_localization()
