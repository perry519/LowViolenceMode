local mod_path = ModPath
local key = mod_path .. "\t" .. RequiredScript
if _G[key] then
    return
else
    _G[key] = true
end

dofile(mod_path .. "modules/settings.lua")

core:module("CoreSequenceManager")

local LowViolenceMode = _G.LowViolenceMode

local dozer_fallen_plate_parts = {
    "_back",
    "_chest",
    "_helmet_plate",
    "_neck",
    "_stomache",
    "_throat"
}

local function resource_name_string(name)
    if not name then
        return nil
    end

    if type(name) == "string" then
        return name
    end

    local success, value = pcall(function()
        return name:s()
    end)

    if success and value then
        return tostring(value)
    end

    return tostring(name)
end

local function is_dozer_fallen_plate_unit(name)
    local resource_name = resource_name_string(name)
    if not resource_name then
        return false
    end

    local unit_name = resource_name:lower()
    local unit_basename = unit_name:match("([^/\\]+)$") or unit_name

    if not unit_basename:find("ene_acc_", 1, true) or not unit_basename:find("dozer", 1, true) then
        return false
    end

    for _, part in ipairs(dozer_fallen_plate_parts) do
        if unit_basename:find(part, 1, true) then
            return true
        end
    end

    return false
end

if SpawnUnitElement and SpawnUnitElement.activate_callback then
    local low_violence_original_spawn_unit_activate_callback = SpawnUnitElement.activate_callback

    function SpawnUnitElement:activate_callback(env)
        if LowViolenceMode:IsEnabled("blockDozerFallenPlates") and is_dozer_fallen_plate_unit(self:run_parsed_func(env, self._name)) then
            return
        end

        return low_violence_original_spawn_unit_activate_callback(self, env)
    end
end
