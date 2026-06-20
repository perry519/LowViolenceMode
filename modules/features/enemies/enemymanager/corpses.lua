local LowViolenceMode = _G.LowViolenceMode
local EnemyManagerFeature = LowViolenceMode.EnemyManagerFeature
local numeric_or = EnemyManagerFeature.NumericOr
local fallback_corpse_limit = EnemyManagerFeature.FallbackCorpseLimit

local low_violence_original_on_enemy_died = EnemyManager.on_enemy_died
local low_violence_original_on_civilian_died = EnemyManager.on_civilian_died
local low_violence_original_add_delayed_clbk = EnemyManager.add_delayed_clbk
local low_violence_corpse_ragdoll_freeze_delay = 1.5
local low_violence_corpse_deferred_hide_fallback_delay = 3.1
local low_violence_freeze_ragdoll_prefix = "freeze_rag"
local low_violence_deferred_corpse_prefix = "low_violence_hide_corpse"
local low_violence_timer_corpse_prefix = "low_violence_timer_corpse"

local function low_violence_is_whisper_mode()
    local groupai_state = managers and managers.groupai and managers.groupai:state()
    return groupai_state and groupai_state.whisper_mode and groupai_state:whisper_mode()
end

local function low_violence_now()
    local timer = TimerManager and TimerManager.game and TimerManager:game()
    return timer and timer.time and timer:time()
end

local function low_violence_should_hide_corpse_after_ragdoll()
    return LowViolenceMode:IsEnabled("blockCorpses") and LowViolenceMode:GetMode("corpsesMode") == "after_ragdoll"
end

local function low_violence_should_hide_corpse_on_timer()
    return LowViolenceMode:IsEnabled("blockCorpses") and LowViolenceMode:GetMode("corpsesMode") == "timer" and LowViolenceMode:GetNumber("corpseTimerSeconds") > 0
end

local function low_violence_should_defer_corpse()
    return low_violence_should_hide_corpse_after_ragdoll() or low_violence_should_hide_corpse_on_timer()
end

local function low_violence_freeze_ragdoll_key(id)
    id = tostring(id or "")

    if id:sub(1, #low_violence_freeze_ragdoll_prefix) ~= low_violence_freeze_ragdoll_prefix then
        return nil
    end

    return id:sub(#low_violence_freeze_ragdoll_prefix + 1)
end

local function low_violence_unit_key(unit)
    if not unit or not unit.key then
        return nil
    end

    local success, key = pcall(function()
        return unit:key()
    end)

    if success then
        return key
    end
end

local function low_violence_corpse_data_by_key(enemy_manager, corpse_key)
    local enemy_data = enemy_manager and enemy_manager._enemy_data
    local corpses = enemy_data and enemy_data.corpses

    if not corpses or not corpse_key then
        return nil
    end

    local numeric_key = tonumber(corpse_key)
    local corpse_data = numeric_key and corpses[numeric_key]

    if corpse_data then
        return corpse_data
    end

    corpse_data = corpses[corpse_key]
    if corpse_data then
        return corpse_data
    end

    for key, data in pairs(corpses) do
        if tostring(key) == tostring(corpse_key) then
            return data
        end
    end
end

local function low_violence_deferred_corpse_limit(enemy_manager)
    local original = enemy_manager and rawget(enemy_manager, "_low_violence_original_values") or {}
    return math.max(numeric_or(original.max_corpses, fallback_corpse_limit()), 0)
end

local function low_violence_collect_deferred_corpses(enemy_manager)
    local enemy_data = enemy_manager and enemy_manager._enemy_data
    local corpses = enemy_data and enemy_data.corpses
    local deferred_corpses = {}

    if not corpses then
        return deferred_corpses
    end

    for key, corpse_data in pairs(corpses) do
        if corpse_data.low_violence_deferred_disposal then
            if corpse_data.no_dispose and alive(corpse_data.unit) then
                deferred_corpses[#deferred_corpses + 1] = {
                    key = key,
                    data = corpse_data,
                    death_t = numeric_or(corpse_data.death_t, 0)
                }
            else
                corpse_data.low_violence_deferred_disposal = nil
            end
        end
    end

    table.sort(deferred_corpses, function(left, right)
        if left.death_t == right.death_t then
            return tostring(left.key) < tostring(right.key)
        end

        return left.death_t < right.death_t
    end)

    return deferred_corpses
end

local function low_violence_release_deferred_corpse(enemy_manager, corpse_data)
    local corpse_unit = corpse_data and corpse_data.unit

    if not enemy_manager or not corpse_data or not corpse_data.low_violence_deferred_disposal then
        return false
    end

    if not corpse_data.no_dispose or not alive(corpse_unit) or not enemy_manager.enable_disposal_on_corpse then
        corpse_data.low_violence_deferred_disposal = nil
        corpse_data.low_violence_deferred_mode = nil
        return false
    end

    corpse_data.low_violence_deferred_disposal = nil
    corpse_data.low_violence_deferred_mode = nil
    enemy_manager:enable_disposal_on_corpse(corpse_unit)

    return true
end

local function low_violence_release_deferred_corpse_by_key(enemy_manager, corpse_key)
    low_violence_release_deferred_corpse(enemy_manager, low_violence_corpse_data_by_key(enemy_manager, corpse_key))
end

EnemyManagerFeature.ApplyDeferredCorpsePolicy = function(enemy_manager)
    local deferred_corpses = low_violence_collect_deferred_corpses(enemy_manager)
    local mode = LowViolenceMode:GetMode("corpsesMode")

    if #deferred_corpses == 0 then
        return
    end

    if not low_violence_should_defer_corpse() then
        for _, item in ipairs(deferred_corpses) do
            low_violence_release_deferred_corpse(enemy_manager, item.data)
        end

        return
    end

    for _, item in ipairs(deferred_corpses) do
        if item.data.low_violence_deferred_mode ~= mode then
            low_violence_release_deferred_corpse(enemy_manager, item.data)
        end
    end

    if mode ~= "after_ragdoll" and mode ~= "timer" then
        return
    end

    deferred_corpses = low_violence_collect_deferred_corpses(enemy_manager)

    local disposals_needed = #deferred_corpses - low_violence_deferred_corpse_limit(enemy_manager)

    for index = 1, disposals_needed do
        low_violence_release_deferred_corpse(enemy_manager, deferred_corpses[index].data)
    end
end

local function low_violence_unqueue_corpse_disposal_if_unneeded(enemy_manager)
    local corpse_disposal_id = enemy_manager and enemy_manager._corpse_disposal_id
    local enemy_data = enemy_manager and enemy_manager._enemy_data

    if not corpse_disposal_id or not enemy_data then
        return
    end

    if numeric_or(enemy_data.nr_corpses, 0) <= enemy_manager:corpse_limit() then
        enemy_manager._corpse_disposal_id = nil
        pcall(enemy_manager.unqueue_task, enemy_manager, corpse_disposal_id)
    end
end

local low_violence_schedule_deferred_corpse_fallback
local low_violence_schedule_timer_corpse_release

local function low_violence_defer_corpse_disposal(enemy_manager, dead_unit)
    local corpse_key = low_violence_unit_key(dead_unit)
    local mode = LowViolenceMode:GetMode("corpsesMode")

    if not low_violence_should_defer_corpse() or not corpse_key then
        return
    end

    local enemy_data = enemy_manager and enemy_manager._enemy_data
    local corpse_data = low_violence_corpse_data_by_key(enemy_manager, corpse_key)

    if not enemy_data or not corpse_data or corpse_data.no_dispose then
        return
    end

    corpse_data.no_dispose = true
    corpse_data.low_violence_deferred_disposal = true
    corpse_data.low_violence_deferred_mode = mode
    enemy_data.nr_corpses = math.max(numeric_or(enemy_data.nr_corpses, 0) - 1, 0)

    low_violence_unqueue_corpse_disposal_if_unneeded(enemy_manager)
    if mode == "after_ragdoll" and low_violence_schedule_deferred_corpse_fallback then
        low_violence_schedule_deferred_corpse_fallback(enemy_manager, corpse_key)
    elseif mode == "timer" and low_violence_schedule_timer_corpse_release then
        low_violence_schedule_timer_corpse_release(enemy_manager, corpse_key)
    end

    EnemyManagerFeature.ApplyDeferredCorpsePolicy(enemy_manager)
end

local function low_violence_enable_deferred_corpse_disposal(enemy_manager, delayed_clbk_id)
    local corpse_key = low_violence_freeze_ragdoll_key(delayed_clbk_id)

    low_violence_release_deferred_corpse_by_key(enemy_manager, corpse_key)
end

low_violence_schedule_deferred_corpse_fallback = function(enemy_manager, corpse_key)
    local execute_t = low_violence_now()

    if not enemy_manager or not execute_t or not corpse_key then
        return
    end

    local id = low_violence_deferred_corpse_prefix .. tostring(corpse_key)

    if enemy_manager:is_clbk_registered(id) then
        return
    end

    enemy_manager:add_delayed_clbk(id, function()
        local freeze_id = low_violence_freeze_ragdoll_prefix .. tostring(corpse_key)

        if not enemy_manager:is_clbk_registered(freeze_id) then
            low_violence_enable_deferred_corpse_disposal(enemy_manager, freeze_id)
        end
    end, execute_t + low_violence_corpse_deferred_hide_fallback_delay)
end

low_violence_schedule_timer_corpse_release = function(enemy_manager, corpse_key)
    local execute_t = low_violence_now()

    if not enemy_manager or not execute_t or not corpse_key then
        return
    end

    local id = low_violence_timer_corpse_prefix .. tostring(corpse_key)

    if enemy_manager:is_clbk_registered(id) then
        return
    end

    enemy_manager:add_delayed_clbk(id, function()
        if low_violence_should_hide_corpse_on_timer() then
            low_violence_release_deferred_corpse_by_key(enemy_manager, corpse_key)
        end
    end, execute_t + LowViolenceMode:GetNumber("corpseTimerSeconds"))
end

local function low_violence_wrap_freeze_ragdoll_clbk(enemy_manager, id, clbk)
    return function(...)
        local result = clbk(...)

        if not enemy_manager:is_clbk_registered(id) then
            low_violence_enable_deferred_corpse_disposal(enemy_manager, id)
        end

        return result
    end
end

function EnemyManager:on_enemy_died(dead_unit, ...)
    local result = low_violence_original_on_enemy_died(self, dead_unit, ...)
    low_violence_defer_corpse_disposal(self, dead_unit)

    return result
end

function EnemyManager:on_civilian_died(dead_unit, ...)
    local result = low_violence_original_on_civilian_died(self, dead_unit, ...)
    low_violence_defer_corpse_disposal(self, dead_unit)

    return result
end

function EnemyManager:add_delayed_clbk(id, clbk, execute_t, ...)
    if LowViolenceMode:IsEnabled("blockCorpses") and low_violence_freeze_ragdoll_key(id) and not low_violence_is_whisper_mode() then
        if low_violence_should_hide_corpse_after_ragdoll() and clbk then
            clbk = low_violence_wrap_freeze_ragdoll_clbk(self, id, clbk)
        end

        local now = low_violence_now()

        if now and type(execute_t) == "number" then
            execute_t = math.min(execute_t, now + low_violence_corpse_ragdoll_freeze_delay)
        elseif type(execute_t) == "number" then
            execute_t = execute_t - (3 - low_violence_corpse_ragdoll_freeze_delay)
        end
    end

    return low_violence_original_add_delayed_clbk(self, id, clbk, execute_t, ...)
end
