dofile(ModPath .. "modules/settings.lua")

local LowViolenceMode = _G.LowViolenceMode
local low_violence_original_spawn_head_gadget = CopDamage._spawn_head_gadget

function CopDamage:_spawn_head_gadget(...)
    if LowViolenceMode:IsEnabled("blockHelmets") then
        return
    end

    return low_violence_original_spawn_head_gadget(self, ...)
end
