local LowViolenceMode = rawget(_G, "LowViolenceMode") or {}
_G.LowViolenceMode = LowViolenceMode

LowViolenceMode.ModPath = LowViolenceMode.ModPath or ModPath
LowViolenceMode.SaveFile = LowViolenceMode.SaveFile or SavePath .. "LowViolenceMode.json"
LowViolenceMode.default_settings = LowViolenceMode.default_settings or {
    bloodEffectsMode = "both",
    blockBloodDecals = true,
    blockBloodSplatter = true,
    blockBulletDecals = true,
    blockBulletHitEffects = true,
    blockCorpses = true,
    blockDozerFallenPlates = true,
    blockHelmets = true,
    blockMagazines = true,
    blockShields = true,
    bulletEffectsMode = "both",
    corpseTimerSeconds = 3,
    corpsesMode = "after_ragdoll",
    hideCorpsesAfterRagdoll = true,
    reduceShotgunSpam = true
}
LowViolenceMode.settings = LowViolenceMode.settings or {}
LowViolenceMode._original_crew_rays = LowViolenceMode._original_crew_rays or {}
LowViolenceMode.mode_values = LowViolenceMode.mode_values or {
    bloodEffectsMode = {
        off = true,
        decals = true,
        splatter = true,
        both = true
    },
    bulletEffectsMode = {
        off = true,
        decals = true,
        hit_effects = true,
        both = true
    },
    corpsesMode = {
        off = true,
        after_ragdoll = true,
        timer = true
    }
}

local function normalize_corpse_timer_seconds(value)
    value = tonumber(value) or LowViolenceMode.default_settings.corpseTimerSeconds
    value = math.floor(value * 100 + 0.5) / 100

    return math.max(0, math.min(value, 5))
end

function LowViolenceMode:ApplyDefaults()
    for key, value in pairs(self.default_settings) do
        if self.settings[key] == nil then
            self.settings[key] = value
        end
    end

    self.settings.corpseTimerSeconds = normalize_corpse_timer_seconds(self.settings.corpseTimerSeconds)
end

function LowViolenceMode:IsModeSetting(key)
    return type(self.default_settings[key]) == "string" and self.mode_values[key] ~= nil
end

function LowViolenceMode:NormalizeModeValue(key, value)
    if type(value) == "string" and self.mode_values[key] and self.mode_values[key][value] then
        return value
    end

    return self.default_settings[key]
end

function LowViolenceMode:ApplyModeToBooleans(key)
    local mode = self:NormalizeModeValue(key, self.settings[key])
    self.settings[key] = mode

    if key == "corpsesMode" then
        self.settings.blockCorpses = mode ~= "off"
        self.settings.hideCorpsesAfterRagdoll = mode == "after_ragdoll"
    elseif key == "bulletEffectsMode" then
        self.settings.blockBulletDecals = mode == "decals" or mode == "both"
        self.settings.blockBulletHitEffects = mode == "hit_effects" or mode == "both"
    elseif key == "bloodEffectsMode" then
        self.settings.blockBloodDecals = mode == "decals" or mode == "both"
        self.settings.blockBloodSplatter = mode == "splatter" or mode == "both"
    end
end

function LowViolenceMode:UpdateModeFromBooleans(key)
    if key == "blockCorpses" or key == "hideCorpsesAfterRagdoll" then
        if not self.settings.blockCorpses then
            self.settings.corpsesMode = "off"
        elseif self.settings.hideCorpsesAfterRagdoll then
            self.settings.corpsesMode = "after_ragdoll"
        else
            self.settings.corpsesMode = "timer"
            self.settings.corpseTimerSeconds = 0
        end
    elseif key == "blockBulletDecals" or key == "blockBulletHitEffects" then
        if self.settings.blockBulletDecals and self.settings.blockBulletHitEffects then
            self.settings.bulletEffectsMode = "both"
        elseif self.settings.blockBulletDecals then
            self.settings.bulletEffectsMode = "decals"
        elseif self.settings.blockBulletHitEffects then
            self.settings.bulletEffectsMode = "hit_effects"
        else
            self.settings.bulletEffectsMode = "off"
        end
    elseif key == "blockBloodDecals" or key == "blockBloodSplatter" then
        if self.settings.blockBloodDecals and self.settings.blockBloodSplatter then
            self.settings.bloodEffectsMode = "both"
        elseif self.settings.blockBloodDecals then
            self.settings.bloodEffectsMode = "decals"
        elseif self.settings.blockBloodSplatter then
            self.settings.bloodEffectsMode = "splatter"
        else
            self.settings.bloodEffectsMode = "off"
        end
    end
end

local function has_loaded_value(data, key)
    return type(data) == "table" and data[key] ~= nil
end

function LowViolenceMode:SynchronizeModeSettings(loaded_data)
    if not has_loaded_value(loaded_data, "corpsesMode") then
        self:UpdateModeFromBooleans("blockCorpses")
    end

    if not has_loaded_value(loaded_data, "bulletEffectsMode") then
        self:UpdateModeFromBooleans("blockBulletDecals")
    end

    if not has_loaded_value(loaded_data, "bloodEffectsMode") then
        self:UpdateModeFromBooleans("blockBloodDecals")
    end

    self:ApplyModeToBooleans("corpsesMode")
    self:ApplyModeToBooleans("bulletEffectsMode")
    self:ApplyModeToBooleans("bloodEffectsMode")
    self.settings.corpseTimerSeconds = normalize_corpse_timer_seconds(self.settings.corpseTimerSeconds)
end

function LowViolenceMode:Load()
    self:ApplyDefaults()

    local file = io.open(self.SaveFile, "r")
    if not file then
        self:Save()
        return
    end

    local contents = file:read("*all")
    file:close()

    local success, data = pcall(json.decode, contents)
    if success and type(data) == "table" then
        for key, value in pairs(data) do
            if self.default_settings[key] ~= nil then
                if type(self.default_settings[key]) == "boolean" then
                    self.settings[key] = value == true
                elseif self:IsModeSetting(key) then
                    self.settings[key] = self:NormalizeModeValue(key, value)
                elseif key == "corpseTimerSeconds" then
                    self.settings[key] = normalize_corpse_timer_seconds(value)
                end
            end
        end

        if data.blockBloodSplatter == nil and data.blockBloodDecals ~= nil then
            self.settings.blockBloodSplatter = data.blockBloodDecals == true
        end
    end

    self:ApplyDefaults()
    self:SynchronizeModeSettings(success and type(data) == "table" and data or nil)
end

function LowViolenceMode:Save()
    self:ApplyDefaults()
    self:SynchronizeModeSettings(self.settings)

    local file = io.open(self.SaveFile, "w+")
    if not file then
        return
    end

    file:write(json.encode(self.settings))
    file:close()
end

function LowViolenceMode:IsEnabled(key)
    self:ApplyDefaults()
    return self.settings[key] ~= false
end

function LowViolenceMode:GetMode(key)
    self:ApplyDefaults()
    return self:NormalizeModeValue(key, self.settings[key])
end

function LowViolenceMode:GetNumber(key)
    self:ApplyDefaults()
    return self.settings[key]
end

function LowViolenceMode:Set(key, value)
    if self.default_settings[key] == nil then
        return
    end

    if type(self.default_settings[key]) == "boolean" then
        self.settings[key] = value == true
        self:UpdateModeFromBooleans(key)
    elseif self:IsModeSetting(key) then
        self.settings[key] = self:NormalizeModeValue(key, value)
        self:ApplyModeToBooleans(key)
    elseif key == "corpseTimerSeconds" then
        self.settings[key] = normalize_corpse_timer_seconds(value)
    else
        return
    end

    self:Save()
    self:ApplyRuntimeSettings()
end

function LowViolenceMode:ApplyWeaponSettings(weapon_data)
    if not weapon_data then
        return
    end

    for key, value in pairs(weapon_data) do
        if type(key) == "string" and type(value) == "table" and key:find("_crew", 1, true) and (value.is_shotgun or value.rays) then
            if not self._original_crew_rays[value] then
                self._original_crew_rays[value] = {
                    rays = value.rays
                }
            end

            if self:IsEnabled("reduceShotgunSpam") then
                value.rays = 1
            else
                value.rays = self._original_crew_rays[value].rays
            end
        end
    end
end

function LowViolenceMode:ApplyRuntimeSettings()
    if managers and managers.enemy and self.ApplyEnemyManagerSettings then
        self.ApplyEnemyManagerSettings(managers.enemy)
    end

    if managers and managers.game_play_central and self.ApplyGamePlayCentralSettings then
        self.ApplyGamePlayCentralSettings(managers.game_play_central)
    end

    if tweak_data and tweak_data.weapon then
        self:ApplyWeaponSettings(tweak_data.weapon)
    end
end

if not LowViolenceMode._settings_loaded then
    LowViolenceMode:Load()
    LowViolenceMode._settings_loaded = true
end
