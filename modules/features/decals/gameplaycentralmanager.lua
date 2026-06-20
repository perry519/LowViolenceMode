dofile(ModPath .. "modules/settings.lua")

local LowViolenceMode = _G.LowViolenceMode

local low_violence_original_gameplay_central_manager_init = GamePlayCentralManager.init
local low_violence_original_play_bullet_hit = GamePlayCentralManager._play_bullet_hit
local low_violence_original_play_impact_flesh = GamePlayCentralManager.play_impact_flesh
local low_violence_original_play_impact_sound_and_effects = GamePlayCentralManager.play_impact_sound_and_effects
local low_violence_original_sync_play_impact_flesh = GamePlayCentralManager.sync_play_impact_flesh

local idstr_blood_spatter = Idstring("blood_spatter")
local idstr_blood_screen = Idstring("effects/particles/character/player/blood_screen")
local idstr_bullet_hit_blood = Idstring("effects/payday2/particles/impacts/blood/blood_impact_a")

local function remember_gameplay_central_values(gameplay_central)
    if not gameplay_central or gameplay_central._low_violence_original_values then
        return
    end

    gameplay_central._low_violence_original_values = {
        block_bullet_decals = gameplay_central._block_bullet_decals,
        block_blood_decals = gameplay_central._block_blood_decals
    }
end

function LowViolenceMode.ApplyGamePlayCentralSettings(gameplay_central)
    if not gameplay_central then
        return
    end

    remember_gameplay_central_values(gameplay_central)

    local original = gameplay_central._low_violence_original_values or {}

    gameplay_central._block_bullet_decals = LowViolenceMode:IsEnabled("blockBulletDecals") and true or original.block_bullet_decals
    gameplay_central._block_blood_decals = LowViolenceMode:IsEnabled("blockBloodDecals") and true or original.block_blood_decals
end

function GamePlayCentralManager:init(...)
    low_violence_original_gameplay_central_manager_init(self, ...)
    LowViolenceMode.ApplyGamePlayCentralSettings(self)
end

local function unit_in_slot(unit, slotmask)
    if not slotmask or not unit or not unit.in_slot then
        return false
    end

    local success, result = pcall(function()
        return unit:in_slot(slotmask)
    end)

    return success and result == true
end

local function unit_character_damage(unit)
    if not unit or not unit.character_damage then
        return nil
    end

    local success, damage_ext = pcall(function()
        return unit:character_damage()
    end)

    if success then
        return damage_ext
    end
end

local function is_flesh_impact(gameplay_central, params)
    local col_ray = params and params.col_ray
    local unit = col_ray and col_ray.unit

    if not alive(unit) then
        return false
    end

    if unit_in_slot(unit, gameplay_central._slotmask_flesh) then
        return true
    end

    local damage_ext = unit_character_damage(unit)
    return damage_ext and not damage_ext._no_blood
end

local function should_block_blood_decals()
    return LowViolenceMode:IsEnabled("blockBloodDecals")
end

local function should_block_blood_splatter()
    return LowViolenceMode:IsEnabled("blockBloodSplatter")
end

local function should_block_bullet_hit_effects()
    return LowViolenceMode:IsEnabled("blockBulletHitEffects")
end

local function project_local_blood_decal(gameplay_central, col_ray)
    if should_block_blood_decals() or not col_ray then
        return
    end

    local unit = col_ray.unit
    if not alive(unit) or not unit_in_slot(unit, gameplay_central._slotmask_flesh) then
        return
    end

    local overrides = gameplay_central._impact_override and gameplay_central._impact_override[unit:key()]
    if overrides and overrides.no_splatter_decal then
        return
    end

    local splatter_from = col_ray.position
    local splatter_to = col_ray.position + col_ray.ray * 1000
    local splatter_ray = unit:raycast("ray", splatter_from, splatter_to, "slot_mask", gameplay_central._slotmask_world_geometry)

    if splatter_ray then
        World:project_decal(idstr_blood_spatter, splatter_ray.position, splatter_ray.ray, splatter_ray.unit, nil, splatter_ray.normal)
    end
end

local function project_synced_blood_decal(gameplay_central, from, dir)
    if should_block_blood_decals() then
        return
    end

    local splatter_from = from
    local splatter_to = from + dir * 1000
    local splatter_ray = World:raycast("ray", splatter_from, splatter_to, "slot_mask", gameplay_central._slotmask_world_geometry)

    if splatter_ray then
        World:project_decal(idstr_blood_spatter, splatter_ray.position, splatter_ray.ray, splatter_ray.unit, nil, splatter_ray.normal)
    end
end

local function spawn_blood_screen_if_close(gameplay_central, position)
    if not managers or not managers.player or not managers.player.player_unit then
        return
    end

    local player_unit = managers.player:player_unit()
    if not alive(player_unit) or not player_unit.movement then
        return
    end

    local movement = player_unit:movement()
    if not movement or not movement.m_head_pos then
        return
    end

    if mvector3.distance_sq(position, movement:m_head_pos()) >= 40000 then
        return
    end

    gameplay_central._effect_manager:spawn({
        effect = idstr_blood_screen,
        position = Vector3(),
        rotation = Rotation()
    })
end

local function play_synced_flesh_splatter(gameplay_central, from, dir)
    if should_block_blood_splatter() then
        return
    end

    gameplay_central._effect_manager:spawn({
        effect = idstr_bullet_hit_blood,
        position = from,
        normal = dir
    })

    spawn_blood_screen_if_close(gameplay_central, from)

    local sound_source = gameplay_central:_get_impact_source()
    sound_source:stop()
    sound_source:set_position(from)
    sound_source:set_switch("materials", "flesh")
    sound_source:post_event("bullet_hit")
end

function GamePlayCentralManager:play_impact_sound_and_effects(params)
    if is_flesh_impact(self, params) then
        if should_block_blood_splatter() then
            return
        end

        if should_block_blood_decals() then
            params.no_decal = true
        end

        return low_violence_original_play_impact_sound_and_effects(self, params)
    end

    if LowViolenceMode:IsEnabled("blockBulletDecals") and params then
        params.no_decal = true
    end

    return low_violence_original_play_impact_sound_and_effects(self, params)
end

function GamePlayCentralManager:_play_bullet_hit(params)
    if not should_block_bullet_hit_effects() or is_flesh_impact(self, params) or not self._play_effects then
        return low_violence_original_play_bullet_hit(self, params)
    end

    local previous_effect_count = #self._play_effects
    local result = low_violence_original_play_bullet_hit(self, params)

    while #self._play_effects > previous_effect_count do
        table.remove(self._play_effects)
    end

    return result
end

function GamePlayCentralManager:play_impact_flesh(params)
    if should_block_blood_splatter() then
        project_local_blood_decal(self, params and params.col_ray)
        return
    end

    return low_violence_original_play_impact_flesh(self, params)
end

function GamePlayCentralManager:sync_play_impact_flesh(from, dir)
    if not should_block_blood_decals() and not should_block_blood_splatter() then
        return low_violence_original_sync_play_impact_flesh(self, from, dir)
    end

    project_synced_blood_decal(self, from, dir)
    play_synced_flesh_splatter(self, from, dir)
end

LowViolenceMode.ApplyGamePlayCentralSettings(GamePlayCentralManager)

if managers and managers.game_play_central then
    LowViolenceMode.ApplyGamePlayCentralSettings(managers.game_play_central)
end
