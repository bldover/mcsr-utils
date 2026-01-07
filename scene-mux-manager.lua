--[[
    Scene MUX Manager

    Monitors the currentObsState value from scripts/customizable.storage
    and manages visibility of sources in the "Scene MUX" scene.
]]

obs = obslua

---- Variables ----

jingle_dir = os.getenv('UserProfile'):gsub('\\', '/') .. '/.config/Jingle/'
storage_file = jingle_dir .. 'scripts/customizable.storage'

last_state = ''
timers_activated = false

---- JSON Parsing ----

function parse_json(json_string)
    local success, result = pcall(function()
        local json = {}
        local function decode_value(str, pos)
            local first_char = str:sub(pos, pos)

            if first_char == '"' then
                local end_pos = str:find('"', pos + 1)
                while end_pos and str:sub(end_pos - 1, end_pos - 1) == '\\' do
                    end_pos = str:find('"', end_pos + 1)
                end
                return str:sub(pos + 1, end_pos - 1), end_pos + 1
            elseif first_char == '{' then
                local obj = {}
                pos = pos + 1
                while true do
                    pos = str:find('%S', pos)
                    if not pos then break end
                    if str:sub(pos, pos) == '}' then
                        return obj, pos + 1
                    end
                    if str:sub(pos, pos) == ',' then
                        pos = pos + 1
                    end
                    pos = str:find('%S', pos)
                    local key, new_pos = decode_value(str, pos)
                    pos = str:find(':', new_pos) + 1
                    pos = str:find('%S', pos)
                    local value
                    value, pos = decode_value(str, pos)
                    obj[key] = value
                end
                return obj, pos
            else
                local next_delim = str:find('[,}%]]', pos)
                if not next_delim then
                    return str:sub(pos), #str + 1
                end
                local value = str:sub(pos, next_delim - 1):match('^%s*(.-)%s*$')
                return value, next_delim
            end
        end

        local result, _ = decode_value(json_string, 1)
        return result
    end)

    if success then
        return result
    else
        return nil
    end
end

---- File Functions ----

function read_file(filename)
    local file = io.open(filename, 'r')
    if file == nil then
        return nil
    end
    local content = file:read('*all')
    file:close()
    return content
end

function get_current_state()
    local content = read_file(storage_file)
    if not content then
        return nil
    end

    local data = parse_json(content)
    if not data or not data['Resizing (Custom).lua'] then
        return nil
    end

    return data['Resizing (Custom).lua']['currentObsState']
end

---- OBS Functions ----

function get_source(name)
    return obs.obs_get_source_by_name(name)
end

function release_source(source)
    obs.obs_source_release(source)
end

function get_scene(name)
    local source = get_source(name)
    if source == nil then
        return nil
    end
    local scene = obs.obs_scene_from_source(source)
    release_source(source)
    return scene
end

function set_item_visible(scene_name, item_name, visible)
    local scene = get_scene(scene_name)
    if scene == nil then
        return
    end
    local item = obs.obs_scene_find_source_recursive(scene, item_name)
    if item == nil then
        return
    end
    obs.obs_sceneitem_set_visible(item, visible)
end

---- State Management ----

function update_source_visibility(state)
    local scene_name = 'Scene MUX'

    set_item_visible(scene_name, 'Minecraft', true)

    if state == 'Normal' then
        set_item_visible(scene_name, 'Wide View', false)
        set_item_visible(scene_name, 'Thin View', false)
        set_item_visible(scene_name, 'Eye Measure', false)
    elseif state == 'Wide' then
        set_item_visible(scene_name, 'Wide View', true)
        set_item_visible(scene_name, 'Thin View', false)
        set_item_visible(scene_name, 'Eye Measure', false)
    elseif state == 'Thin' then
        set_item_visible(scene_name, 'Wide View', false)
        set_item_visible(scene_name, 'Thin View', true)
        set_item_visible(scene_name, 'Eye Measure', false)
    elseif state == 'Eye' then
        set_item_visible(scene_name, 'Wide View', false)
        set_item_visible(scene_name, 'Thin View', false)
        set_item_visible(scene_name, 'Eye Measure', true)
    end
end

---- Loop ----

function loop()
    local state = get_current_state()

    if state == nil or state == last_state then
        return
    end

    last_state = state
    update_source_visibility(state)
end

---- Script Functions ----

function script_description()
    return [[
    <h1>Scene MUX Manager</h1>
    <p>Monitors currentObsState from scripts/customizable.storage and manages visibility of sources in "Scene MUX" projection.</p>
    ]]
end

function script_load()
    last_state = get_current_state() or 'Normal'
    update_source_visibility(last_state)
end

function script_update(settings)
    if timers_activated then
        return
    end

    timers_activated = true
    obs.timer_add(loop, 50)
end
