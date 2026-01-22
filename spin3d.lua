obs = obslua

source_name = ""
speed = 2500   -- full rotation time in ms (2.5 seconds)
timer_step = 16 -- ~60fps

current_angle = 0

------------------------------------------------------------
-- Get scene item
------------------------------------------------------------
function get_item()
    local scene_source = obs.obs_frontend_get_current_scene()
    local scene = obs.obs_scene_from_source(scene_source)
    local item = obs.obs_scene_find_source(scene, source_name)
    obs.obs_source_release(scene_source)
    return item
end

------------------------------------------------------------
-- Animation loop
------------------------------------------------------------
function spin_step()
    local item = get_item()
    if item == nil then return end

    -- progress 0 → 1
    local progress = (current_angle % speed) / speed

    -- scaleX curve for 3D spin illusion
    local scale = math.cos(progress * math.pi * 2)

    local vec = obs.vec2()
    vec.x = scale
    vec.y = 1

    obs.obs_sceneitem_set_scale(item, vec)

    current_angle = current_angle + timer_step
end

------------------------------------------------------------
-- Start animation
------------------------------------------------------------
function script_update(settings)
    source_name = obs.obs_data_get_string(settings, "source")
    speed = obs.obs_data_get_int(settings, "speed_ms")

    obs.timer_remove(spin_step)
    obs.timer_add(spin_step, timer_step)
end

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

    return props
end

function script_description()
    return "3D-style spinning animation for any image source."
end