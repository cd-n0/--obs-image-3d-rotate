local obs = obslua
-- TODO account for cropping
-- TODO find out how to reset when quitting, the event and script_unload doesn't work for some reason

local source_name = ""
local speed = 2500   -- full rotation time in ms (2.5 seconds)
local timer_step = 16 -- ~60fps
local scene_item = nil
local original_item_scale = obs.vec2()
local original_item_pos = obs.vec2()
local original_width = 0

local active = false
local current_angle = 0
local spin_from_middle = false


--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Local Functions
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
local function restore_item()
    if not scene_item then return end
    obs.obs_sceneitem_set_scale(scene_item, original_item_scale)
    obs.obs_sceneitem_set_pos(scene_item, original_item_pos)
end

local function get_width(item)
    return obs.obs_source_get_width(obs.obs_sceneitem_get_source(item))
end

------------------------------------------------------------
-- Get scene item
------------------------------------------------------------
local function get_item()
    local source = obs.obs_frontend_get_current_scene()
    if not source then
        print("there is no current scene")
        return
    end

    local scene = obs.obs_scene_from_source(source)
    obs.obs_source_release(source)

    scene_item = obs.obs_scene_find_source_recursive(scene, source_name)
    if scene_item then
        obs.obs_sceneitem_get_scale(scene_item, original_item_scale)
        obs.obs_sceneitem_get_pos(scene_item, original_item_pos)
        original_width = get_width(scene_item) * original_item_scale.y
        return true
    end

    print(source_name .. " not found")
    return false
end

------------------------------------------------------------
-- Animation loop
------------------------------------------------------------
local function spin_step()
    if not scene_item or not active then return end

    local progress = (current_angle % speed) / speed

    local scale = math.sin(progress * math.pi * 2)

    local scale_vec = obs.vec2()
    scale_vec.x = scale * original_item_scale.x
    scale_vec.y = original_item_scale.y
    obs.obs_sceneitem_set_scale(scene_item, scale_vec)

    local position_vec = obs.vec2()
    position_vec.x = original_item_pos.x + original_width * .5
    position_vec.y = original_item_pos.y
    if spin_from_middle then
        local scaled_width = get_width(scene_item) * scale_vec.x
        position_vec.x = position_vec.x - (scaled_width * .5)
        obs.obs_sceneitem_set_pos(scene_item, position_vec)
    else
        obs.obs_sceneitem_set_pos(scene_item, position_vec)
    end

    current_angle = current_angle + timer_step
end

local function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        scene_changed()
    end
    if event == obs.OBS_FRONTEND_EVENT_EXIT or event == obs.OBS_FRONTEND_EVENT_SCRIPTING_SHUTDOWN then
        if active then
            restore_item()
        end
    end
end

local function toggle()
    if active then
        active = false
        restore_item()
        return
    end

    get_item()
    active = true
end

--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Global functions
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
function scene_changed()
    restore_item()
    get_item()
end

--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- API functions
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
------------------------------------------------------------
-- UI
------------------------------------------------------------
function script_properties()
    local props = obs.obs_properties_create()

    local p = obs.obs_properties_add_list(
        props, "source", "Image Source",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING
    )

    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, s in ipairs(sources) do
            local name = obs.obs_source_get_name(s)
            obs.obs_property_list_add_string(p, name, name)
        end
    end
    obs.source_list_release(sources)

    obs.obs_properties_add_int(props, "speed_ms", "Full Spin Time (ms)", 500, 5000, 100)
    obs.obs_properties_add_bool(props, "spin_from_middle", "Spin from middle")
    obs.obs_properties_add_button(props, "button", "Toggle", toggle)

    return props
end

function script_update(settings)
    source_name = obs.obs_data_get_string(settings, "source")
    speed = obs.obs_data_get_int(settings, "speed_ms")
    spin_from_middle = obs.obs_data_get_bool(settings, "spin_from_middle")

    obs.timer_remove(spin_step)
    obs.timer_add(spin_step, timer_step)
    obs.obs_frontend_add_event_callback(on_event)

    get_item()
end

function script_unload()
    obs.timer_remove(spin_step)
    restore_item()
end

function script_description()
    return "3D-style spinning animation for any image source."
end
