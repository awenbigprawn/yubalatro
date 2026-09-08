-- Score preview UI and isolation for the bundled Divvy simulation library.
-- Licensed under GPL-3.0; see LICENSE and vendor/divvy/NOTICE.md.
YUBALATRO.preview = {score_text = '', total_text = '', elapsed = 0}
local P = YUBALATRO.preview

local function tr(zh, en)
    local lang = G.SETTINGS.language
    return (lang == 'zh_CN' or lang == 'zh_TW') and zh or en
end

-- luaopen_math creates independent LuaJIT PRNG closures. Keep the game's math
-- library intact and use the extra pair exclusively for scoring predictions.
function P.prepare_rng()
    if P.random then return end
    local open_math = assert(package.loadlib(love.filesystem.getSourceBaseDirectory() .. '/lua51.dll', 'luaopen_math'))
    local original, saved = math, {}
    local loaded = package.loaded.math
    for key, value in pairs(original) do saved[key] = value end
    local ok, result = pcall(open_math)
    local isolated_random = ok and result.random
    local isolated_seed = ok and result.randomseed
    for key in pairs(original) do original[key] = nil end
    for key, value in pairs(saved) do original[key] = value end
    _G.math, package.loaded.math = original, loaded
    assert(ok and isolated_random and isolated_random ~= math.random, 'Independent preview RNG unavailable')
    P.random, P.randomseed = isolated_random, isolated_seed
end

function P.evaluate()
    if not G.hand or #G.hand.highlighted == 0 then return nil end
    for _, joker in ipairs(G.jokers.cards) do
        if not DV.SIM.JOKERS['simulate_' .. joker.config.center.key:sub(3)] then
            return nil, 'unsupported'
        end
    end
    P.prepare_rng()
    local random, randomseed = math.random, math.randomseed
    local rng = DV.SIM.deep_copy(G.GAME.pseudorandom)
    local hands = DV.SIM.deep_copy(G.GAME.hands)
    local triggered = G.GAME.blind.triggered
    local highlighted = G.hand.highlighted
    -- The simulator sorts the selection; sort a temporary list, never the real one.
    local selected = {}
    for i, card in ipairs(highlighted) do selected[i] = card end
    G.hand.highlighted = selected
    math.random, math.randomseed = P.random, P.randomseed
    local ok, result = pcall(DV.SIM.run)
    math.random, math.randomseed = random, randomseed
    G.hand.highlighted = highlighted
    G.GAME.blind.triggered = triggered
    -- Restore even if the library throws halfway through a calculation.
    DV.SIM.deep_update(G.GAME.pseudorandom, rng)
    DV.SIM.deep_update(G.GAME.hands, hands)
    if not ok then return nil, result end
    local score = result and result.score and result.score.exact
    if type(score) ~= 'number' or score ~= score or score == math.huge then return nil, 'overflow' end
    return math.floor(score)
end

function P.refresh()
    P.score = nil
    if not G.hand or not G.GAME or G.STATE ~= G.STATES.SELECTING_HAND then
        P.score_text, P.total_text = '', ''
        return
    end
    if #G.hand.highlighted == 0 then
        P.score_text = tr('选择手牌查看得分', 'Select cards to preview')
        P.total_text = ''
        return
    end
    if #G.hand.highlighted > 5 or G.GAME.blind.block_play then
        P.score_text, P.total_text = tr('当前无法出牌', 'Cannot play this hand'), ''
        return
    end
    local ok, score, err = pcall(P.evaluate)
    if not ok or score == nil then
        P.score_text = tr('暂时无法预览', 'Preview unavailable')
        P.total_text = ''
        local detail = tostring(ok and err or score)
        if P.last_error ~= detail then print('[Yubalatro preview] ' .. detail); P.last_error = detail end
        return
    end
    P.score = score
    P.score_text = tr('本次得分：', 'Hand score: ') .. number_format(score)
    P.total_text = tr('回合合计：', 'Round total: ') .. number_format(G.GAME.chips + score)
end

local update = love.update
love.update = function(dt)
    update(dt)
    P.elapsed = P.elapsed + dt
    if P.elapsed >= 0.15 then
        P.elapsed = 0
        if not G.SETTINGS.paused then P.refresh() end
    end
end

local create_hud = create_UIBox_HUD
create_UIBox_HUD = function()
    local definition = create_hud()
    -- Locate the existing chips/mult section by ID, instead of fixed node indices.
    local function find(node, parent, grandparent)
        if node.config and node.config.id == 'hand_chip_area' then return grandparent end
        for _, child in ipairs(node.nodes or {}) do
            local found = find(child, node, parent)
            if found then return found end
        end
    end
    local section = find(definition)
    if section then
        for _, key in ipairs({'score_text', 'total_text'}) do
            section.nodes[#section.nodes + 1] = {n = G.UIT.R, config = {
                align = 'cm', minh = 0.35, maxw = 4.2, padding = 0.015,
            }, nodes = {{n = G.UIT.T, config = {
                id = 'yubalatro_' .. key, ref_table = P, ref_value = key,
                scale = key == 'score_text' and 0.32 or 0.25,
                colour = key == 'score_text' and G.C.GOLD or G.C.UI.TEXT_LIGHT,
            }}}}
        end
    end
    return definition
end
