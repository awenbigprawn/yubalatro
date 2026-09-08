-- Standalone Lovely mod. No Steamodded dependency.
YUBALATRO = {path = 'yubalatro-settings.txt'}
local M = YUBALATRO
local fields = {'hand_size', 'hands', 'dollars'}
local limits = {hand_size = {1, 52}, hands = {1, 99}, dollars = {0, 999999999}}
local strings = {
    title = {'自定义开局', 'Custom start'},
    hand_size = {'手牌上限 (1-52)', 'Hand size (1-52)'},
    hands = {'每回合出牌次数 (1-99)', 'Hands per round (1-99)'},
    dollars = {'初始金钱 (0-999999999)', 'Starting money (0-999999999)'},
    hint = {'灰色数字为当前牌组的原版开局值；留空可恢复。', 'Grey numbers show vanilla starts for this deck; clear to restore.'},
    next_run = {'保存后仅对新开局生效，继续游戏保留原数值。', 'Saved settings apply to new runs; continued runs keep their values.'},
    effects = {'开局后的小丑牌、优惠券和盲注效果仍正常生效。', 'Later Joker, voucher and blind effects still apply.'},
    save = {'保存设置', 'Save settings'},
    reset = {'恢复原版设置', 'Restore vanilla settings'},
    saved = {'已保存，下次新开局生效。', 'Saved. Applies to your next new run.'},
    invalid = {'请输入范围内的整数，或留空。', 'Enter whole numbers within the ranges, or leave blank.'},
    failed = {'保存失败，请检查存档文件夹是否可写。', 'Save failed. Check that the save folder is writable.'},
    vanilla = {'原版', 'Vanilla'},
}

function M.text(key)
    local lang = G.SETTINGS and G.SETTINGS.language or 'en-us'
    return strings[key][(lang == 'zh_CN' or lang == 'zh_TW') and 1 or 2]
end

function M.parse(key, value)
    if value == nil or value == '' then return nil, true end
    local s = tostring(value)
    if not s:match('^%d+$') then return nil, false end
    local n = tonumber(s)
    local range = limits[key]
    if not n or n < range[1] or n > range[2] then return nil, false end
    return n, true
end

function M.load()
    local config = {}
    local data = love.filesystem.read(M.path) or ''
    for key, value in data:gmatch('([%a_]+)=([^\r\n]*)') do
        if limits[key] then
            local n, valid = M.parse(key, value)
            if valid then config[key] = n end
        end
    end
    return config
end

function M.apply(game)
    local config = M.load()
    for _, key in ipairs(fields) do
        if config[key] ~= nil then game.starting_params[key] = config[key] end
    end
end

function M.defaults()
    local values = get_starting_params()
    local game = G.GAME or {}
    local back = game.viewed_back or game.selected_back
    local config = back and back.effect and back.effect.config or {}
    for _, key in ipairs(fields) do
        values[key] = values[key] + (config[key] or 0)
    end
    local challenge = game.challenge_tab
    for _, rule in ipairs(challenge and challenge.rules and challenge.rules.modifiers or {}) do
        if limits[rule.id] then values[rule.id] = rule.value end
    end
    return values
end

function M.step(key, delta)
    local value, valid = M.parse(key, M.draft[key])
    if not valid then M.status = M.text('invalid'); return false end
    value = value or M.base_values[key]
    local range = limits[key]
    M.draft[key] = tostring(math.max(range[1], math.min(range[2], value + delta)))
    M.status = ''
    return true
end

local function row(text, scale)
    return {n = G.UIT.R, config = {align = 'cm', padding = 0.06}, nodes = {
        {n = G.UIT.T, config = {text = text, scale = scale or 0.3, colour = G.C.UI.TEXT_LIGHT}}
    }}
end

function M.ui()
    local contents = {row(M.text('title'), 0.55), row(M.text('hint'))}
    for _, key in ipairs(fields) do
        local input = create_text_input({ref_table = M.draft, ref_value = key,
            w = 2.8, h = 0.6, max_length = 9, text_scale = 0.4,
            prompt_text = tostring(M.base_values[key]), extended_corpus = true,
            yubalatro_numeric = true})
        -- Vanilla reserves global draw-layer slots 1 and 2 for its single seed
        -- field. Multiple inputs overwrite those slots; use normal tree order.
        input.config.draw_layer = nil
        input.nodes[1].config.draw_layer = nil
        input.nodes[1].config.id = 'yubalatro_' .. key
        -- Vanilla's flash callback resizes every cursor when ANY field is active,
        -- recursively recalculating this multi-input overlay partway through layout.
        -- Reserve a fixed cursor width and blink only the active field's cursor.
        for _, child in ipairs(input.nodes[1].nodes[1].nodes[1].nodes) do
            if child.config.id == 'position' then child.config.func = 'yubalatro_cursor' end
        end
        contents[#contents + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.10}, nodes = {
            {n = G.UIT.C, config = {align = 'cr', minw = 4.2}, nodes = {
                {n = G.UIT.T, config = {text = M.text(key), scale = 0.36, colour = G.C.UI.TEXT_LIGHT}}
            }},
            {n = G.UIT.B, config = {w = 0.2, h = 0.1}},
            UIBox_button({id = 'yubalatro_' .. key .. '_minus',
                button = 'yubalatro_' .. key .. '_minus', label = {'-'},
                col = true, minw = 0.55, minh = 0.55, scale = 0.4, colour = G.C.RED}),
            input,
            UIBox_button({id = 'yubalatro_' .. key .. '_plus',
                button = 'yubalatro_' .. key .. '_plus', label = {'+'},
                col = true, minw = 0.55, minh = 0.55, scale = 0.4, colour = G.C.BLUE}),
        }}
    end
    contents[#contents + 1] = row(M.text('next_run'), 0.27)
    contents[#contents + 1] = row(M.text('effects'), 0.27)
    contents[#contents + 1] = {n = G.UIT.R, config = {align = 'cm', minh = 0.4}, nodes = {
        {n = G.UIT.T, config = {ref_table = M, ref_value = 'status', scale = 0.3, colour = G.C.GOLD}}
    }}
    contents[#contents + 1] = UIBox_button({button = 'yubalatro_save', label = {M.text('save')}, minw = 5, colour = G.C.BLUE})
    contents[#contents + 1] = UIBox_button({button = 'yubalatro_reset', label = {M.text('reset')}, minw = 5})
    return create_UIBox_generic_options({back_func = 'options', contents = contents})
end

G.FUNCS.yubalatro_cursor = function(e)
    e.config.colour[4] = G.CONTROLLER.text_input_hook == e.parent
        and math.floor(G.TIMERS.REAL * 2) % 2 == 0 and 1 or 0
end

local function show_settings()
    G.FUNCS.overlay_menu({definition = M.ui()})
    -- Text fields update their prompt during construction. Recalculate once all
    -- siblings exist so the completed overlay has consistent child offsets.
    G.OVERLAY_MENU:recalculate()
end

function M.sync_input(key)
    local input = G.OVERLAY_MENU:get_UIE_by_ID('yubalatro_' .. key)
    local field = input.children[1].children[1]
    local args = field.config.ref_table
    local value = M.draft[key]
    for i = 1, args.max_length do args.text.letters[i] = value:sub(i, i) end
    args.current_prompt_text = value == '' and args.prompt_text or ''
    for _, child in ipairs(field.children) do
        if child.UIT == G.UIT.T then
            child.config.prev_value = nil
            child:update_text()
        end
    end
    -- Move the existing caret to the new end; retain the overlay and its buttons.
    G.CONTROLLER.text_input_hook = field
    TRANSPOSE_TEXT_INPUT(args.max_length)
    G.CONTROLLER.text_input_hook = nil
end

G.FUNCS.yubalatro_settings = function()
    local config = M.load()
    M.base_values = M.defaults()
    M.draft = {}
    for _, key in ipairs(fields) do M.draft[key] = config[key] and tostring(config[key]) or '' end
    M.status = ''
    G.SETTINGS.paused = true
    show_settings()
end

for _, key in ipairs(fields) do
    for _, direction in ipairs({'minus', 'plus'}) do
        local field, delta = key, direction == 'plus' and 1 or -1
        G.FUNCS['yubalatro_' .. key .. '_' .. direction] = function()
            if G.CONTROLLER.text_input_hook then G.FUNCS.text_input_key({key = 'return'}) end
            if M.step(field, delta) then M.sync_input(field) end
        end
    end
end

G.FUNCS.yubalatro_save = function()
    if G.CONTROLLER.text_input_hook then
        G.FUNCS.text_input_key({key = 'return'})
    end
    local lines = {}
    for _, key in ipairs(fields) do
        local n, valid = M.parse(key, M.draft[key])
        if not valid then M.status = M.text('invalid'); return end
        lines[#lines + 1] = key .. '=' .. (n and tostring(n) or '')
    end
    local ok = love.filesystem.write(M.path, table.concat(lines, '\n') .. '\n')
    M.status = M.text(ok and 'saved' or 'failed')
end

G.FUNCS.yubalatro_reset = function()
    G.CONTROLLER.text_input_hook = nil
    for _, key in ipairs(fields) do M.draft[key] = ''; M.sync_input(key) end
    G.FUNCS.yubalatro_save()
end

local original_text_input_key = G.FUNCS.text_input_key
G.FUNCS.text_input_key = function(args)
    local hook = G.CONTROLLER.text_input_hook
    local key = args and args.key
    if hook and hook.config.ref_table.yubalatro_numeric and key and #key == 1 then
        if not key:match('^%d$') then return end
        -- Numeric input should not become punctuation while Shift/Caps Lock is on.
        args = {key = key, caps = false}
        local capslock = G.CONTROLLER.capslock
        G.CONTROLLER.capslock = false
        original_text_input_key(args)
        G.CONTROLLER.capslock = capslock
        return
    end
    return original_text_input_key(args)
end
