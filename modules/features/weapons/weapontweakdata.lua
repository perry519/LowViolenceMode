dofile(ModPath .. "modules/settings.lua")

local LowViolenceMode = _G.LowViolenceMode
local low_violence_original_weapon_tweak_data_init = WeaponTweakData.init

function WeaponTweakData:init(...)
    low_violence_original_weapon_tweak_data_init(self, ...)
    LowViolenceMode:ApplyWeaponSettings(self)
end

if tweak_data and tweak_data.weapon then
    LowViolenceMode:ApplyWeaponSettings(tweak_data.weapon)
end
