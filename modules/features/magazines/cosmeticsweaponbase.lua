dofile(ModPath .. "modules/settings.lua")

local LowViolenceMode = _G.LowViolenceMode
local low_violence_original_drop_magazine_object = NewRaycastWeaponBase.drop_magazine_object

function NewRaycastWeaponBase:drop_magazine_object(...)
    if LowViolenceMode:IsEnabled("blockMagazines") then
        return
    end

    return low_violence_original_drop_magazine_object(self, ...)
end
