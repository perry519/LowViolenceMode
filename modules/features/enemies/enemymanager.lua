dofile(ModPath .. "modules/settings.lua")
dofile(ModPath .. "modules/features/enemies/enemymanager/shared.lua")
dofile(ModPath .. "modules/features/enemies/enemymanager/limits.lua")
dofile(ModPath .. "modules/features/enemies/enemymanager/corpses.lua")

if managers and managers.enemy then
    _G.LowViolenceMode.ApplyEnemyManagerSettings(managers.enemy)
end
