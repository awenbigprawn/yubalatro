-- Disposable runtime integration tests: preview, then actually play each hand.
local load_game, update_game = love.load, love.update
local elapsed, stage, index, pending = 0, 0, (YUBALATRO_QA_FROM or 1) - 1, nil
local P
local fast_test = YUBALATRO_QA_FAST_FORWARD
local space_held, sampled_speed = false, nil
local boost_frames, normal_frames, durations = 0, 0, {}
local starting_rng, normal_scores = {}, {}
local cases = {
    {name = 'high card', ranks = {'H_A'}},
    {name = 'pair', ranks = {'H_5', 'S_5'}},
    {name = 'flush', ranks = {'H_2', 'H_4', 'H_6', 'H_8', 'H_T'}},
    {name = 'add then multiply', ranks = {'H_A'}, jokers = {'j_joker', 'j_cavendish'}},
    {name = 'multiply then add', ranks = {'H_A'}, jokers = {'j_cavendish', 'j_joker'}},
    {name = 'glass retriggers', ranks = {'H_K'}, enhancements = {'m_glass'}, seals = {'Red'}, jokers = {'j_sock_and_buskin', 'j_hanging_chad'}},
    {name = 'steel baron mime', ranks = {'H_2'}, held = 'S_K', held_enhancement = 'm_steel', jokers = {'j_baron', 'j_mime'}},
    {name = 'blueprint photograph', ranks = {'H_K'}, jokers = {'j_blueprint', 'j_photograph', 'j_sock_and_buskin'}},
    {name = 'brainstorm triboulet', ranks = {'H_K', 'S_Q'}, jokers = {'j_triboulet', 'j_brainstorm'}},
    {name = 'card editions', ranks = {'H_2', 'H_4', 'H_6', 'H_8', 'H_T'}, editions = {'foil', 'holo', 'polychrome'}},
    {name = 'debuffed joker edition', ranks = {'H_A'}, jokers = {'j_joker'}, joker_edition = 'holo', debuff_joker = true},
    {name = 'debuffed played face', ranks = {'H_K'}, jokers = {'j_photograph', 'j_sock_and_buskin'}, blind = 'bl_plant', debuff_card = true},
    {name = 'lucky bloodstone misprint', ranks = {'H_A', 'H_K', 'H_Q', 'H_J', 'H_T'}, enhancements = {'m_lucky','m_lucky','m_lucky','m_lucky','m_lucky'}, jokers = {'j_bloodstone', 'j_misprint', 'j_lucky_cat'}},
    {name = 'flint', ranks = {'H_A'}, blind = 'bl_flint', jokers = {'j_joker'}},
    {name = 'psychic blocked hand', ranks = {'H_A'}, blind = 'bl_psychic'},
    {name = 'eye repeated hand', ranks = {'H_A'}, blind = 'bl_eye', repeated_hand = true},
    {name = 'arm hand level', ranks = {'H_A'}, blind = 'bl_arm', level = 3},
    {name = 'hook steel discard', ranks = {'H_2'}, blind = 'bl_hook', held = 'S_K', held_enhancement = 'm_steel', jokers = {'j_baron', 'j_mime'}},
    {name = 'plasma deck', ranks = {'H_A'}, plasma = true, jokers = {'j_joker'}},
    {name = 'hiker retrigger', ranks = {'H_2'}, seals = {'Red'}, jokers = {'j_hiker', 'j_hanging_chad'}},
    {name = 'stone splash', ranks = {'H_2', 'S_A'}, enhancements = {'m_stone'}, jokers = {'j_splash'}},
    {name = 'hook hit the road', ranks = {'H_2'}, held_all = 'S_J', blind = 'bl_hook', jokers = {'j_hit_the_road'}},
    {name = 'hook mail bootstraps', ranks = {'H_2'}, held_all = 'S_J', blind = 'bl_hook', mail = true, jokers = {'j_mail', 'j_bootstraps'}},
    {name = 'last hand dusk acrobat', ranks = {'H_K'}, jokers = {'j_dusk', 'j_acrobat'}, last_hand = true},
}
local function report(text)
    local f = assert(io.open(fast_test and 'fast-forward-result.txt' or 'scoring-result.txt', 'a')); f:write(text .. '\n'); f:close()
end
if fast_test then
    local selected = {}
    for _, i in ipairs({6, 13, 18}) do
        for _, mode in ipairs({'normal', 'held', 'toggle'}) do
            local case = {}
            for k, v in pairs(cases[i]) do case[k] = v end
            case.speed_mode, case.base_name = mode, case.name
            case.name = case.name .. ' / ' .. mode
            selected[#selected + 1] = case
        end
    end
    cases = selected
end
local function capture(name)
    love.graphics.captureScreenshot(function(data)
        local f = assert(io.open(name .. '.png', 'wb')); f:write(data:encode('png'):getString()); f:close()
    end)
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
love.load = function()
    assert(love.filesystem.getIdentity() == 'YubalatroQA')
    for _, name in ipairs({'settings.jkr', '1/profile.jkr', '1/meta.jkr'}) do
        love.filesystem.createDirectory('1')
        love.filesystem.write(name, assert(love.filesystem.read('qa_save/' .. name)))
    end
    love.filesystem.write('yubalatro-settings.txt', 'hand_size=8\nhands=99\ndollars=100\n')
    G.F_NO_ACHIEVEMENTS = true
    load_game()
    G.SETTINGS.GAMESPEED = 4
    P = YUBALATRO.preview
    if fast_test then
        local isDown = love.keyboard.isDown
        love.keyboard.isDown = function(key, ...) if key == 'space' then return space_held end; return isDown(key, ...) end
        love.window.hasFocus = function() return true end -- Hidden QA window only.
        local multiplier = YUBALATRO.fast_forward_multiplier
        YUBALATRO.fast_forward_multiplier = function()
            local factor = multiplier()
            sampled_speed = G.SPEEDFACTOR * factor
            if G.STATE == G.STATES.HAND_PLAYED then
                if factor == 4 then boost_frames = boost_frames + 1 else normal_frames = normal_frames + 1 end
            end
            return factor
        end
    end
    report('START scoring integration')
end
local function setup(case)
    if fast_test then
        if case.speed_mode == 'normal' then
            starting_rng[case.base_name] = DV.SIM.deep_copy(G.GAME.pseudorandom)
        else
            DV.SIM.deep_update(G.GAME.pseudorandom, starting_rng[case.base_name])
        end
    end
    G.hand:unhighlight_all()
    for i = #G.jokers.cards, 1, -1 do
        local card = G.jokers.cards[i]; card:remove_from_deck(); card:remove()
    end
    G.GAME.selected_back = Back(G.P_CENTERS[case.plasma and 'b_plasma' or 'b_red'])
    G.GAME.blind:set_blind(G.P_BLINDS[case.blind or 'bl_small'], false, true)
    assert(G.GAME.blind.name == G.P_BLINDS[case.blind or 'bl_small'].name)
    G.GAME.blind.chips = 1e100
    G.GAME.blind.chip_text = number_format(1e100)
    G.GAME.current_round.hands_left = case.last_hand and 1 or 99
    if case.mail then G.GAME.current_round.mail_card.id = 11 end
    if case.repeated_hand then G.GAME.blind.hands['High Card'] = true end
    local h = G.GAME.hands['High Card']
    h.level = case.level or 1; h.chips = h.s_chips + (h.level - 1)*h.l_chips; h.mult = h.s_mult + (h.level - 1)*h.l_mult
    for i, card in ipairs(G.hand.cards) do
        if fast_test then card.sort_id = i end -- Stable Hook discard order across replayed inputs.
        card:set_base(G.P_CARDS[case.ranks[i] or case.held_all or (i == #case.ranks + 1 and case.held) or 'C_3'])
        card:set_ability(G.P_CENTERS[(case.enhancements and case.enhancements[i]) or (i == #case.ranks + 1 and case.held_enhancement) or 'c_base'], nil, true)
        card:set_edition(case.editions and case.editions[i] and {[case.editions[i]] = true} or nil, true, true)
        card:set_seal(case.seals and case.seals[i] or nil, true, true)
        card:set_debuff(case.debuff_card and i == 1 or false)
        card.ability.perma_bonus = 0
    end
    for _, key in ipairs(case.jokers or {}) do add_joker(key) end
    if case.joker_edition then G.jokers.cards[1]:set_edition({[case.joker_edition] = true}, true, true) end
    if case.debuff_joker then G.jokers.cards[1]:set_debuff(true) end
    for i = 1, #case.ranks do G.hand:add_to_highlighted(G.hand.cards[i], true) end
end
local function predict(case)
    if case.debuff_card then assert(G.hand.cards[1].debuff, 'test fixture lost playing-card debuff') end
    if case.debuff_joker then assert(G.jokers.cards[1].debuff, 'test fixture lost joker debuff') end
    local rng, hands = DV.SIM.deep_copy(G.GAME.pseudorandom), DV.SIM.deep_copy(G.GAME.hands)
    local triggered, dollars = G.GAME.blind.triggered, G.GAME.dollars
    local selected = G.hand.highlighted
    local originals = {}
    for i, card in ipairs(G.hand.cards) do originals[i] = DV.SIM.deep_copy(card.ability) end
    math.randomseed(12345); local expected_random = math.random()
    math.randomseed(12345)
    local result, err = P.evaluate()
    assert(result ~= nil, tostring(err))
    assert(math.random() == expected_random, 'preview consumed global RNG')
    assert(G.hand.highlighted == selected, 'preview replaced selection')
    assert(equal(rng, G.GAME.pseudorandom) and equal(hands, G.GAME.hands), 'preview changed run state')
    assert(triggered == G.GAME.blind.triggered and dollars == G.GAME.dollars, 'preview changed blind/money')
    for i, card in ipairs(G.hand.cards) do assert(equal(originals[i], card.ability), 'preview changed card ability') end
    assert(P.evaluate() == result, 'preview changed random result on repeat')
    P.refresh()
    assert(P.score == result, 'HUD preview mismatch')
    -- Exceptions must restore state, too.
    local simulate = DV.SIM.run
    DV.SIM.run = function() G.GAME.hands.Pair.level = 999; G.GAME.pseudorandom.test = 1; G.GAME.blind.triggered = true; error('intentional test failure') end
    local failed = P.evaluate()
    DV.SIM.run = simulate
    assert(failed == nil and equal(rng, G.GAME.pseudorandom) and equal(hands, G.GAME.hands) and triggered == G.GAME.blind.triggered)
    return result
end
love.update = function(dt)
    if fast_test then
        local mode = cases[index] and cases[index].speed_mode
        space_held = mode == 'held' or (mode == 'toggle' and pending and pending.started
            and math.floor((G.TIMERS.REAL - pending.started) / 0.2) % 2 == 1) or false
        sampled_speed = nil
    end
    update_game(dt)
    if fast_test and sampled_speed then
        if G.SPEEDFACTOR ~= sampled_speed or G.SETTINGS.GAMESPEED ~= 4 then
            report('FAIL speed multiplier / saved speed mismatch'); love.event.quit(1); return
        end
    end
    elapsed = elapsed + dt
    if elapsed < 0.3 then return end
    elapsed = 0
    local ok, err = pcall(function()
        if stage == 0 then G:main_menu('game'); stage = 1; elapsed = -1
        elseif stage == 1 then G.FUNCS.start_run(nil, {stake = 1, seed = 'SCOREQA'}); stage = 2; elapsed = -2
        elseif stage == 2 then
            if G.blind_select then G.FUNCS.select_blind({config = {ref_table = G.P_BLINDS.bl_small}}); stage = 3 end
        elseif stage == 3 and ((G.STATE == G.STATES.SELECTING_HAND and #G.hand.cards >= 5) or
                (pending and index == #cases and G.GAME.hands_played > pending.played and G.STATE ~= G.STATES.HAND_PLAYED)) then
            if pending then
                local actual = G.GAME.chips - pending.before
                assert(actual == pending.expected, pending.name .. ': preview=' .. pending.expected .. ' actual=' .. actual)
                report('PASS ' .. pending.name .. ' = ' .. actual)
                if fast_test then
                    local case = cases[index]
                    local duration = G.TIMERS.REAL - pending.started
                    report('DURATION ' .. case.name .. ' ' .. string.format('%.3f', duration)
                        .. 's; boosted=' .. boost_frames .. ' normal=' .. normal_frames)
                    if case.speed_mode == 'normal' then
                        assert(boost_frames == 0 and normal_frames > 0)
                        durations[case.base_name] = duration
                        normal_scores[case.base_name] = actual
                    else
                        assert(actual == normal_scores[case.base_name], 'speed changed score for identical seeded input')
                        assert(boost_frames > 0, 'space never accelerated scoring')
                        if case.speed_mode == 'held' then
                            assert(duration < durations[case.base_name], 'held space did not shorten scoring')
                        else assert(normal_frames > 0, 'release never restored normal speed') end
                    end
                end
                pending = nil
            end
            index = index + 1
            if not cases[index] then report('ALL SCORING TESTS PASS'); love.event.quit(); return end
            setup(cases[index]); stage = 4; elapsed = -0.6
        elseif stage == 4 then
            local case = cases[index]
            pending = {name = case.name, expected = predict(case), before = G.GAME.chips, played = G.GAME.hands_played}
            if index == 3 then capture('score-preview') end
            stage = 5; elapsed = -0.4
        elseif stage == 5 then
            if fast_test then pending.started = G.TIMERS.REAL; boost_frames, normal_frames = 0, 0 end
            G.FUNCS.play_cards_from_highlighted(nil)
            stage = 3; elapsed = -1
        end
    end)
    if not ok then report('FAIL ' .. tostring(err)); love.event.quit(1) end
end
