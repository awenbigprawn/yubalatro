-- Run only in the disposable QA build: regression for stepper layout corruption.
local original_load, original_update = love.load, love.update
local elapsed, step = 0, 0
local overlay, button
local failed, pending
local function report(message)
    local f = assert(io.open('ui-layout-result.txt', 'a'))
    f:write(message .. '\n'); f:close()
end
local function screenshot(name)
    love.graphics.captureScreenshot(function(data)
        local f = assert(io.open(name .. '.png', 'wb'))
        f:write(data:encode('png'):getString()); f:close()
    end)
end
local function visible_text(node)
    if node.UIT == G.UIT.T and node.config.text and node.config.text ~= '' then
        local t = node.VT
        assert(t.x >= -0.1 and t.y >= -0.1 and t.x + t.w <= G.ROOM.T.w + 0.1
            and t.y + t.h <= G.ROOM.T.h + 0.1,
            'offscreen: ' .. node.config.text .. ' at ' .. t.x .. ',' .. t.y .. ' size ' .. t.w .. ',' .. t.h)
    end
    for _, child in pairs(node.children or {}) do visible_text(child) end
end
local function check(name)
    screenshot(name)
    assert(G.OVERLAY_MENU == overlay, 'overlay replaced')
    assert(overlay:get_UIE_by_ID('yubalatro_hand_size_plus') == button, 'button replaced')
    visible_text(overlay.UIRoot)
    report(name .. ' OK')
end
local function press(callback)
    local before = G.ROOM.jiggle
    callback()
    assert(G.ROOM.jiggle == before, 'stepper bounced the room')
end
love.load = function()
    assert(love.filesystem.getIdentity() == 'YubalatroQA')
    love.filesystem.write('yubalatro-settings.txt', 'hand_size=\nhands=\ndollars=\n')
    original_load()
end
love.update = function(dt)
    original_update(dt)
    -- Let captureScreenshot render the checked state before the next edit.
    if pending then
        local action = pending; pending = nil
        local ok, err = pcall(action)
        if not ok then report('FAIL: ' .. tostring(err)); failed = true end
        return
    end
    elapsed = elapsed + dt
    if elapsed < 2 then return end
    elapsed = 0; step = step + 1
    if failed then love.event.quit(1); return end
    local ok, err = pcall(function()
        if step == 1 then G:main_menu('game')
        elseif step == 2 then
            G.FUNCS.yubalatro_settings()
            overlay = G.OVERLAY_MENU
            button = overlay:get_UIE_by_ID('yubalatro_hand_size_plus')
        elseif step == 3 then
            check('ui-before-plus')
            pending = function() press(G.FUNCS.yubalatro_hand_size_plus) end
        elseif step == 4 then
            check('ui-after-plus')
            assert(YUBALATRO.draft.hand_size == '9')
            pending = function() press(G.FUNCS.yubalatro_hand_size_plus) end
        elseif step == 5 then
            check('ui-two-digits')
            assert(YUBALATRO.draft.hand_size == '10')
            pending = function()
                press(G.FUNCS.yubalatro_hands_plus)
                press(G.FUNCS.yubalatro_discards_plus)
                press(G.FUNCS.yubalatro_dollars_plus)
            end
        elseif step == 6 then
            check('ui-all-fields')
            assert(YUBALATRO.draft.discards == '5')
            pending = function() press(G.FUNCS.yubalatro_reset) end
        elseif step == 7 then
            check('ui-after-reset')
            pending = function()
                G.FUNCS.select_text_input(overlay:get_UIE_by_ID('yubalatro_dollars'))
                for c in ('999999998'):gmatch('.') do G.FUNCS.text_input_key({key = c}) end
            end
        elseif step == 8 then
            check('ui-typing-nine-digits')
            assert(YUBALATRO.draft.dollars == '999999998')
            pending = function() press(G.FUNCS.yubalatro_dollars_plus) end
        elseif step == 9 then
            check('ui-nine-digits-plus')
            assert(YUBALATRO.draft.dollars == '999999999')
            pending = function()
                for i = 1, 20 do
                    press(G.FUNCS.yubalatro_hand_size_plus)
                    press(G.FUNCS.yubalatro_hand_size_minus)
                end
                press(G.FUNCS.yubalatro_reset)
            end
        elseif step == 10 then
            check('ui-repeated-clicks-reset')
            report('PASS'); pending = function() love.event.quit() end
        end
    end)
    if not ok then report('FAIL: ' .. tostring(err)); failed = true end
end
