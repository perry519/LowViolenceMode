local key = ModPath .. "\t" .. RequiredScript
if _G[key] then
    return
else
    _G[key] = true
end

dofile(ModPath .. "modules/settings.lua")
dofile(ModPath .. "modules/localization/localization.lua")

local LowViolenceMode = _G.LowViolenceMode
local Localization = _G.LowViolenceModeLocalization
local MENU_ID = "low_violence_mode_options"
local MENU_TITLE = "low_violence_mode_options_title"
local MENU_DESC = "low_violence_mode_options_desc"

local MULTIPLE_CHOICE_ITEMS = {
    {
        id = "corpsesMode",
        title = "low_violence_mode_corpses_mode_title",
        desc = "low_violence_mode_corpses_mode_desc",
        items = {
            "low_violence_mode_choice_off",
            "low_violence_mode_choice_after_ragdoll",
            "low_violence_mode_choice_timer"
        },
        item_values = {
            "off",
            "after_ragdoll",
            "timer"
        },
        priority = 100
    },
    {
        id = "bulletEffectsMode",
        title = "low_violence_mode_bullet_effects_mode_title",
        desc = "low_violence_mode_bullet_effects_mode_desc",
        items = {
            "low_violence_mode_choice_off",
            "low_violence_mode_choice_decals",
            "low_violence_mode_choice_hit_effects",
            "low_violence_mode_choice_both"
        },
        item_values = {
            "off",
            "decals",
            "hit_effects",
            "both"
        },
        priority = 90
    },
    {
        id = "bloodEffectsMode",
        title = "low_violence_mode_blood_effects_mode_title",
        desc = "low_violence_mode_blood_effects_mode_desc",
        items = {
            "low_violence_mode_choice_off",
            "low_violence_mode_choice_decals",
            "low_violence_mode_choice_splatter",
            "low_violence_mode_choice_both"
        },
        item_values = {
            "off",
            "decals",
            "splatter",
            "both"
        },
        priority = 80
    }
}

local TOGGLE_ITEMS = {
    {
        id = "blockMagazines",
        title = "low_violence_mode_block_magazines_title",
        desc = "low_violence_mode_block_magazines_desc",
        priority = 70
    },
    {
        id = "blockShields",
        title = "low_violence_mode_block_shields_title",
        desc = "low_violence_mode_block_shields_desc",
        priority = 60
    },
    {
        id = "blockHelmets",
        title = "low_violence_mode_block_helmets_title",
        desc = "low_violence_mode_block_helmets_desc",
        priority = 50
    },
    {
        id = "blockDozerFallenPlates",
        title = "low_violence_mode_block_dozer_fallen_plates_title",
        desc = "low_violence_mode_block_dozer_fallen_plates_desc",
        priority = 40
    },
    {
        id = "reduceShotgunSpam",
        title = "low_violence_mode_reduce_shotgun_spam_title",
        desc = "low_violence_mode_reduce_shotgun_spam_desc",
        priority = 30
    }
}

local function load_localization(loc)
    if Localization and Localization.Load then
        Localization:Load(loc)
    end
end

local function menu_text(key)
    if Localization and Localization.Text then
        return Localization:Text(key)
    end

    return key
end

local function refresh_menu_node_from_item(item)
    local parameters

    if item and type(item.parameters) == "function" then
        local success, result = pcall(item.parameters, item)

        if success then
            parameters = result
        end
    end

    parameters = parameters or item and item._parameters

    local gui_node = parameters and parameters.gui_node
    if not gui_node then
        return
    end

    if gui_node.refresh_gui then
        pcall(gui_node.refresh_gui, gui_node, gui_node.node)
    end

    if gui_node.highlight_item then
        pcall(gui_node.highlight_item, gui_node, item, true)
    end
end

load_localization()

Hooks:Add("MenuManagerInitialize", "LowViolenceMode_MenuManagerInitialize", function(menu_manager)
    MenuCallbackHandler.LowViolenceModeChoice = function(_, item)
        local name = item:name()

        LowViolenceMode:Set(name, item:value())

        if name == "corpsesMode" then
            refresh_menu_node_from_item(item)
        end
    end

    MenuCallbackHandler.LowViolenceModeToggle = function(_, item)
        LowViolenceMode:Set(item:name(), item:value() == "on")
    end

    MenuCallbackHandler.LowViolenceModeSlider = function(_, item)
        LowViolenceMode:Set(item:name(), item:value())
    end

    MenuCallbackHandler.LowViolenceModeTimerVisible = function()
        return LowViolenceMode:GetMode("corpsesMode") == "timer"
    end

    MenuCallbackHandler.LowViolenceModeSave = function()
        LowViolenceMode:Save()
    end
end)

Hooks:Add("MenuManagerSetupCustomMenus", "LowViolenceMode_SetupCustomMenus", function()
    load_localization()
    MenuHelper:NewMenu(MENU_ID)
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "LowViolenceMode_PopulateCustomMenus", function()
    load_localization()
    LowViolenceMode:Load()

    for _, item in ipairs(MULTIPLE_CHOICE_ITEMS) do
        local choice_text = {}

        for index, text_id in ipairs(item.items) do
            choice_text[index] = menu_text(text_id)
        end

        MenuHelper:AddMultipleChoice({
            id = item.id,
            title = menu_text(item.title),
            desc = menu_text(item.desc),
            callback = "LowViolenceModeChoice",
            items = choice_text,
            item_values = item.item_values,
            value = LowViolenceMode:GetMode(item.id),
            menu_id = MENU_ID,
            priority = item.priority,
            localized = false,
            localized_items = false
        })
    end

    local timer_slider = MenuHelper:AddSlider({
        id = "corpseTimerSeconds",
        title = menu_text("low_violence_mode_corpse_timer_title"),
        desc = menu_text("low_violence_mode_corpse_timer_desc"),
        callback = "LowViolenceModeSlider",
        value = LowViolenceMode:GetNumber("corpseTimerSeconds"),
        min = 0,
        max = 5,
        step = 0.01,
        show_value = true,
        display_precision = 2,
        visible_callback = "LowViolenceModeTimerVisible",
        menu_id = MENU_ID,
        priority = 95,
        localized = false
    })

    if timer_slider then
        timer_slider._visible_callback_name_list = {
            "LowViolenceModeTimerVisible"
        }
    end

    for _, item in ipairs(TOGGLE_ITEMS) do
        MenuHelper:AddToggle({
            id = item.id,
            title = menu_text(item.title),
            desc = menu_text(item.desc),
            callback = "LowViolenceModeToggle",
            value = LowViolenceMode:IsEnabled(item.id),
            menu_id = MENU_ID,
            priority = item.priority,
            localized = false
        })
    end
end)

Hooks:Add("MenuManagerBuildCustomMenus", "LowViolenceMode_BuildCustomMenus", function(_, nodes)
    load_localization()

    nodes[MENU_ID] = MenuHelper:BuildMenu(MENU_ID, {
        back_callback = "LowViolenceModeSave"
    })

    local parent = nodes.blt_options or nodes.options
    if parent then
        local item = MenuHelper:AddMenuItem(parent, MENU_ID, menu_text(MENU_TITLE), menu_text(MENU_DESC))

        if item and item._parameters then
            item._parameters.localize = false
            item._parameters.localize_help = false
        end
    end
end)
