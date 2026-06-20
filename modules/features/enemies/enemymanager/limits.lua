local LowViolenceMode = _G.LowViolenceMode
local EnemyManagerFeature = LowViolenceMode.EnemyManagerFeature
local numeric_or = EnemyManagerFeature.NumericOr
local fallback_corpse_limit = EnemyManagerFeature.FallbackCorpseLimit
local remember_enemy_manager_values = EnemyManagerFeature.RememberValues

local low_violence_original_enemy_manager_init = EnemyManager.init
local low_violence_original_shield_limit = EnemyManager.shield_limit
local low_violence_original_corpse_limit = EnemyManager.corpse_limit
local low_violence_original_corpse_limit_changed_clbk = EnemyManager.corpse_limit_changed_clbk

function LowViolenceMode.ApplyEnemyManagerSettings(enemy_manager)
    if not enemy_manager then
        return
    end

    remember_enemy_manager_values(enemy_manager)

    local original = rawget(enemy_manager, "_low_violence_original_values") or {}

    enemy_manager._MAX_MAGAZINES = LowViolenceMode:IsEnabled("blockMagazines") and 0 or numeric_or(original.max_magazines, 30)
    enemy_manager._shield_disposal_lifetime = LowViolenceMode:IsEnabled("blockShields") and 0 or numeric_or(original.shield_disposal_lifetime, 60)
    enemy_manager._MAX_NR_SHIELDS = LowViolenceMode:IsEnabled("blockShields") and 0 or numeric_or(original.max_shields, 8)
    enemy_manager._MAX_NR_CORPSES = LowViolenceMode:IsEnabled("blockCorpses") and 0 or numeric_or(original.max_corpses, fallback_corpse_limit())

    if EnemyManagerFeature.ApplyDeferredCorpsePolicy then
        EnemyManagerFeature.ApplyDeferredCorpsePolicy(enemy_manager)
    end
end

function EnemyManager:init(...)
    low_violence_original_enemy_manager_init(self, ...)
    LowViolenceMode.ApplyEnemyManagerSettings(self)
end

function EnemyManager:shield_limit(...)
    if LowViolenceMode:IsEnabled("blockShields") then
        return 0
    end

    return numeric_or(low_violence_original_shield_limit(self, ...), 8)
end

function EnemyManager:corpse_limit(...)
    if LowViolenceMode:IsEnabled("blockCorpses") then
        return 0
    end

    local original = rawget(self, "_low_violence_original_values") or {}
    return numeric_or(low_violence_original_corpse_limit(self, ...), numeric_or(original.max_corpses, fallback_corpse_limit()))
end

function EnemyManager:corpse_limit_changed_clbk(setting_name, old_limit, new_limit)
    remember_enemy_manager_values(self)
    new_limit = numeric_or(new_limit, fallback_corpse_limit())

    if rawget(self, "_low_violence_original_values") then
        self._low_violence_original_values.max_corpses = new_limit
    end

    if low_violence_original_corpse_limit_changed_clbk then
        local result = low_violence_original_corpse_limit_changed_clbk(self, setting_name, old_limit, LowViolenceMode:IsEnabled("blockCorpses") and 0 or new_limit)
        LowViolenceMode.ApplyEnemyManagerSettings(self)

        return result
    end

    LowViolenceMode.ApplyEnemyManagerSettings(self)
end
