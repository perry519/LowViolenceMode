dofile(ModPath .. "modules/settings.lua")

local LowViolenceMode = _G.LowViolenceMode
local low_violence_original_allow_dropped_magazines = HuskPlayerMovement.allow_dropped_magazines

function HuskPlayerMovement:allow_dropped_magazines(...)
    if LowViolenceMode:IsEnabled("blockMagazines") then
        return false
    end

    return low_violence_original_allow_dropped_magazines(self, ...)
end
