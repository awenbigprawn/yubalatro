-- Included only in the disposable QA build, never in the installed mod.
local qa_load, qa_update = love.load, love.update
local qa_clock, qa_step = 0, 0
local function report(message)
    local f = assert(io.open('result.txt', 'a'))
    f:write(message .. '\n'); f:close()
end
local function screenshot(name)
    love.graphics.captureScreenshot(function(data)
        local bytes = data:encode('png'):getString()
        local f = assert(io.open(name .. '.png', 'wb'))
        f:write(bytes); f:close()
    end)
end
love.load = function()
    assert(love.filesystem.getIdentity() == 'YubalatroQA')
    report('SAVE DIRECTORY: ' .. love.filesystem.getSaveDirectory())
    for _, name in ipairs({'settings.jkr', '1/profile.jkr', '1/meta.jkr', '2/profile.jkr', '2/meta.jkr'}) do
        local source = love.filesystem.read('qa_save/' .. name)
        if source then
            love.filesystem.createDirectory('1'); love.filesystem.createDirectory('2')
            love.filesystem.write(name, source)
        end
    end
    G.F_NO_ACHIEVEMENTS = true
    love.filesystem.write('yubalatro-settings.txt', 'hand_size=\nhands=\ndollars=\n')
    qa_load()
end
love.update = function(dt)
    qa_update(dt)
    qa_clock = qa_clock + dt
    if qa_clock < 3 then return end
    qa_clock = 0
    qa_step = qa_step + 1
    local ok, err = pcall(function()
        if qa_step == 1 then
            G:main_menu('game')
        elseif qa_step == 2 then
            G.FUNCS.options()
            report('OPTIONS UI OK')
        elseif qa_step == 3 then
            G.FUNCS.yubalatro_settings()
            assert(YUBALATRO.base_values.hand_size == 8 and YUBALATRO.base_values.hands == 4 and YUBALATRO.base_values.dollars == 4)
            assert(YUBALATRO.base_values.discards == 4, 'red deck discard default')
            for _, key in ipairs({'hand_size', 'hands', 'discards', 'dollars'}) do
                local input = G.OVERLAY_MENU:get_UIE_by_ID('yubalatro_' .. key)
                assert(input.children[1].children[1].config.ref_table.prompt_text == tostring(YUBALATRO.base_values[key]))
            end
        elseif qa_step == 4 then
            screenshot('settings')
            report('SETTINGS UI OK')
            local function inspect(node)
                if node.UIT == G.UIT.T and node.config.text ~= '' then
                    if node.VT.x >= G.ROOM.T.w then
                        local registered = false
                        for _, movable in pairs(G.MOVEABLES) do if movable == node then registered = true end end
                        report('OFFSCREEN id=' .. node.ID .. ' registered=' .. tostring(registered) .. ' paused=' .. tostring(node.created_on_pause) .. ' gamepaused=' .. tostring(G.SETTINGS.paused) .. ' move=' .. node.FRAME.MOVE .. '/' .. G.FRAMES.MOVE .. ' major=' .. tostring(node.role.major.ID) .. ' T=' .. node.T.x .. ',' .. node.T.y .. ' offset=' .. node.role.offset.x .. ',' .. node.role.offset.y)
                    end
                    assert(node.VT.x < G.ROOM.T.w and node.VT.y < G.ROOM.T.h, 'offscreen text: ' .. tostring(node.config.text))
                end
                for _, child in pairs(node.children) do inspect(child) end
            end
            inspect(G.OVERLAY_MENU.UIRoot)
        elseif qa_step == 5 then
            -- Drive the actual text field, including the vanilla zero conversion.
            local input = G.OVERLAY_MENU:get_UIE_by_ID('yubalatro_hand_size')
            G.FUNCS.select_text_input(input)
            for i = 1, 9 do G.FUNCS.text_input_key({key = 'backspace'}) end
            G.FUNCS.text_input_key({key = '1'})
            G.FUNCS.text_input_key({key = '0'})
            G.FUNCS.text_input_key({key = 'return'})
            assert(YUBALATRO.draft.hand_size == '10', 'numeric zero input failed')
            local overlay, jiggle = G.OVERLAY_MENU, G.ROOM.jiggle
            local old_button = overlay:get_UIE_by_ID('yubalatro_hand_size_plus')
            G.FUNCS.yubalatro_hand_size_plus()
            assert(YUBALATRO.draft.hand_size == '11')
            G.FUNCS.yubalatro_hand_size_minus()
            assert(YUBALATRO.draft.hand_size == '10')
            G.FUNCS.yubalatro_hands_plus()
            assert(YUBALATRO.draft.hands == '5')
            G.FUNCS.yubalatro_discards_plus()
            assert(YUBALATRO.draft.discards == '5')
            G.FUNCS.yubalatro_discards_minus()
            assert(YUBALATRO.draft.discards == '4')
            G.FUNCS.yubalatro_dollars_minus()
            assert(YUBALATRO.draft.dollars == '3')
            assert(G.OVERLAY_MENU == overlay and G.ROOM.jiggle == jiggle, 'stepper recreated or bounced overlay')
            assert(overlay:get_UIE_by_ID('yubalatro_hand_size_plus') == old_button, 'stepper replaced focused button')
            assert(YUBALATRO.load().hand_size == nil, 'button click saved without Save')
            local field = G.OVERLAY_MENU:get_UIE_by_ID('yubalatro_hand_size').children[1].children[1]
            assert(field.config.ref_table.text.letters[1] == '1' and field.config.ref_table.text.letters[2] == '0', 'input letters out of sync after clicking')
            report('DEFAULT VALUES AND PLUS/MINUS UI OK')
            YUBALATRO.draft = {hand_size = '12', hands = '8', discards = '6', dollars = '1000'}
            G.FUNCS.yubalatro_save()
            assert(YUBALATRO.load().dollars == 1000)
            G.FUNCS.exit_overlay_menu()
            G.FUNCS.start_run(nil, {stake = 1, seed = 'YUBATEST'})
        elseif qa_step == 6 then
            assert(G.hand.config.card_limit == 12, 'wrong hand size')
            assert(G.GAME.round_resets.hands == 8, 'wrong hands per round')
            assert(G.GAME.current_round.hands_left == 8, 'wrong current hands')
            assert(G.GAME.round_resets.discards == 6, 'wrong discards per round')
            assert(G.GAME.current_round.discards_left == 6, 'wrong current discards')
            assert(G.GAME.dollars == 1000, 'wrong starting money')
            report('NEW RUN OK: hand_size=12 hands=8 discards=6 dollars=1000')
            screenshot('new-run')
            G.GAME.dollars = 731
            G.GAME.current_round.discards_left = 4
            save_run()
        elseif qa_step == 7 then
            local saved = STR_UNPACK(get_compressed(G.SETTINGS.profile .. '/save.jkr'))
            assert(saved and saved.GAME.dollars == 731, 'save failed')
            love.filesystem.write(YUBALATRO.path, 'hand_size=20\nhands=10\ndiscards=20\ndollars=9999\n')
            G.FUNCS.start_run(nil, {savetext = saved})
        elseif qa_step == 8 then
            assert(G.hand.config.card_limit == 12, 'continued hand size overwritten')
            assert(G.GAME.round_resets.hands == 8, 'continued hands overwritten')
            assert(G.GAME.round_resets.discards == 6 and G.GAME.current_round.discards_left == 4, 'continued discards overwritten')
            assert(G.GAME.dollars == 731, 'continued money overwritten')
            report('CONTINUE OK: original hand_size=12 hands=8 discards=6 remaining=4 dollars=731 preserved')
            love.filesystem.write(YUBALATRO.path, 'hand_size=\nhands=\ndiscards=0\ndollars=0\n')
            G.FUNCS.start_run(nil, {stake = 1, seed = 'ZEROTEST'})
        elseif qa_step == 9 then
            assert(G.GAME.dollars == 0, 'zero money override failed')
            assert(G.GAME.round_resets.discards == 0 and G.GAME.current_round.discards_left == 0, 'zero discards override failed')
            report('ZERO MONEY AND ZERO DISCARDS OK')
            G.FUNCS.yubalatro_settings()
            assert(YUBALATRO.draft.dollars == '0')
            assert(YUBALATRO.draft.discards == '0')
            G.FUNCS.yubalatro_reset()
            assert(YUBALATRO.load().dollars == nil and YUBALATRO.draft.dollars == '')
            assert(YUBALATRO.load().discards == nil and YUBALATRO.draft.discards == '')
            assert(G.OVERLAY_MENU:get_UIE_by_ID('yubalatro_dollars').children[1].children[1].config.ref_table.prompt_text == '4')
        elseif qa_step == 10 then
            screenshot('settings-reset')
            report('RESET TO VANILLA DISPLAY OK')
        elseif qa_step == 11 then
            report('PASS')
            love.event.quit()
        end
    end)
    if not ok then report('FAIL: ' .. tostring(err)); love.event.quit(1) end
end
