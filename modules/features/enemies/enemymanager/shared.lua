local LowViolenceMode = _G.LowViolenceMode
local EnemyManagerFeature = LowViolenceMode.EnemyManagerFeature or {}
LowViolenceMode.EnemyManagerFeature = EnemyManagerFeature

function EnemyManagerFeature.FallbackCorpseLimit()
    if managers and managers.user and managers.user.get_setting then
        return managers.user:get_setting("corpse_limit") or 8
    end

    return 8
end

function EnemyManagerFeature.NumericOr(value, fallback)
    return type(value) == "number" and value or fallback
end

function EnemyManagerFeature.RememberValues(enemy_manager)
    if not enemy_manager or rawget(enemy_manager, "_low_violence_original_values") then
        return
    end

    enemy_manager._low_violence_original_values = {
        max_magazines = EnemyManagerFeature.NumericOr(enemy_manager._MAX_MAGAZINES, 30),
        shield_disposal_lifetime = EnemyManagerFeature.NumericOr(enemy_manager._shield_disposal_lifetime, 60),
        max_shields = EnemyManagerFeature.NumericOr(enemy_manager._MAX_NR_SHIELDS, 8),
        max_corpses = EnemyManagerFeature.NumericOr(enemy_manager._MAX_NR_CORPSES, EnemyManagerFeature.FallbackCorpseLimit())
    }
end
