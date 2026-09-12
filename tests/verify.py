"""Run with py -3.12 tests/verify.py; use the game's actual LuaJIT runtime."""
import ctypes
import os
from pathlib import Path
import subprocess
import tomllib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
if os.environ.get('BALATRO_GAME_DIR'):
    GAME = Path(os.environ['BALATRO_GAME_DIR'])
else:
    detected = subprocess.check_output([
        'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', str(ROOT / 'install.ps1'), '-CheckOnly',
    ], text=True).strip()
    if not detected.startswith('Balatro: '):
        raise RuntimeError('Set BALATRO_GAME_DIR to the Steam Balatro directory.')
    GAME = Path(detected.removeprefix('Balatro: '))


def patched_sources():
    with zipfile.ZipFile(GAME / 'Balatro.exe') as z:
        sources = {name: z.read(name) for name in z.namelist() if name.endswith('.lua')}
    manifest = tomllib.loads((ROOT / 'mod/lovely.toml').read_text('utf-8'))
    for patch in manifest['patches']:
        if 'copy' in patch:
            p = patch['copy']
            for name in p['sources']:
                sources[p['target']] += b'\n' + (ROOT / 'mod' / name).read_bytes()
        else:
            p = patch['pattern']
            lines = sources[p['target']].decode().splitlines()
            found = [i for i, line in enumerate(lines) if line.strip() == p['pattern']]
            assert len(found) == 1, (p['target'], p['pattern'], found)
            i = found[0]
            indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
            payload = indent + p['payload']
            if p['position'] == 'before': lines.insert(i, payload)
            elif p['position'] == 'after': lines.insert(i + 1, payload)
            else: lines[i] = payload
            sources[p['target']] = '\n'.join(lines).encode()
    return sources


def verify():
    os.add_dll_directory(str(GAME))
    lua = ctypes.CDLL(str(GAME / 'lua51.dll'))
    lua.luaL_newstate.restype = ctypes.c_void_p
    state = lua.luaL_newstate()
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_openlibs(state)
    lua.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lua.lua_close.argtypes = [ctypes.c_void_p]

    def run(code, name, execute=False):
        result = lua.luaL_loadbuffer(state, code, len(code), name.encode())
        if result == 0 and execute: result = lua.lua_pcall(state, 0, 0, 0)
        if result: raise AssertionError(lua.lua_tolstring(state, -1, None).decode())
        lua.lua_settop(state, 0)

    sources = patched_sources()
    for name, code in sources.items(): run(code, name)
    run(b'''
        fake_disk = {}
        love = {filesystem = {
            read = function(path) return fake_disk[path] end,
            write = function(path, data) fake_disk[path] = data; return true end
        }}
        G = {FUNCS = {text_input_key = function() end}, CONTROLLER = {}, SETTINGS = {language = 'zh_CN'}}
    ''', 'setup', True)
    run((ROOT / 'mod/yubalatro.lua').read_bytes(), 'mod', True)
    run(b'''
        local M = YUBALATRO
        assert(select(2, M.parse('hand_size', '')))
        assert(M.parse('dollars', '0') == 0)
        for _, value in ipairs({'-1', '1.5', 'abc', '1e3', '1000000000'}) do
            assert(not select(2, M.parse('dollars', value)))
        end
        assert(not select(2, M.parse('hand_size', '0')))
        assert(not select(2, M.parse('hand_size', '53')))
        assert(not select(2, M.parse('hands', '100')))
        assert(M.parse('discards', '0') == 0 and M.parse('discards', '99') == 99)
        for _, value in ipairs({'-1', '100', '1.5', 'abc'}) do
            assert(not select(2, M.parse('discards', value)))
        end
        local game = {starting_params = {hand_size = 10, hands = 5, discards = 3, dollars = 14}}
        M.apply(game)
        assert(game.starting_params.hand_size == 10 and game.starting_params.dollars == 14)
        assert(game.starting_params.discards == 3, 'old config must retain vanilla discards')
        M.draft = {hand_size = '12', hands = '8', discards = '6', dollars = '1000'}
        G.FUNCS.yubalatro_save()
        M.apply(game)
        assert(game.starting_params.hand_size == 12 and game.starting_params.hands == 8 and game.starting_params.dollars == 1000)
        assert(game.starting_params.discards == 6 and M.load().discards == 6)
        local previous = fake_disk[M.path]
        M.draft.dollars = 'invalid'
        G.FUNCS.yubalatro_save()
        assert(fake_disk[M.path] == previous)
        M.draft = {hand_size = '', hands = '', discards = '0', dollars = '0'}
        G.FUNCS.yubalatro_save()
        game.starting_params.hand_size = 10
        M.apply(game)
        assert(game.starting_params.hand_size == 10 and game.starting_params.dollars == 0)
        assert(game.starting_params.discards == 0)
        fake_disk[M.path] = 'hand_size=999\\nhands=5\\ndollars=oops\\n'
        local config = M.load()
        assert(config.hand_size == nil and config.dollars == nil and config.hands == 5)
        get_starting_params = function() return {hand_size = 8, hands = 4, discards = 3, dollars = 4} end
        G.GAME = {selected_back = {effect = {config = {hand_size = 2, hands = 1, discards = 1, dollars = 10}}}}
        M.base_values = M.defaults()
        assert(M.base_values.hand_size == 10 and M.base_values.hands == 5 and M.base_values.dollars == 14)
        assert(M.base_values.discards == 4, 'red deck default')
        M.draft = {hand_size = '', hands = '', discards = '', dollars = ''}
        assert(M.step('discards', 1) and M.draft.discards == '5')
        M.draft.discards = '0'; M.step('discards', -1); assert(M.draft.discards == '0')
        M.draft.discards = '99'; M.step('discards', 1); assert(M.draft.discards == '99')
        assert(M.step('hand_size', 1) and M.draft.hand_size == '11')
        assert(M.step('hands', -1) and M.draft.hands == '4')
        assert(M.step('dollars', 1) and M.draft.dollars == '15')
        M.draft = {hand_size = '52', hands = '1', dollars = '0'}
        M.step('hand_size', 1); M.step('hands', -1); M.step('dollars', -1)
        assert(M.draft.hand_size == '52' and M.draft.hands == '1' and M.draft.dollars == '0')
        M.draft.dollars = '999999999'; M.step('dollars', 1)
        assert(M.draft.dollars == '999999999')
        M.draft.dollars = 'invalid'; assert(not M.step('dollars', 1))
        G.GAME.challenge_tab = {rules = {modifiers = {{id = 'dollars', value = 0}, {id = 'discards', value = 1}}}}
        assert(M.defaults().dollars == 0)
        assert(M.defaults().discards == 1)
        -- Physical key polling must also work while normal game input is locked.
        G.STAGES = {RUN = 1, MAIN_MENU = 2}
        G.STATES = {HAND_PLAYED = 1, NEW_ROUND = 2, ROUND_EVAL = 3, SELECTING_HAND = 4, SHOP = 5}
        G.STAGE = G.STAGES.RUN
        local held, focused = true, true
        love.keyboard = {isDown = function(key) assert(key == 'space'); return held end}
        love.window = {hasFocus = function() return focused end}
        G.CONTROLLER.locked = true
        G.SETTINGS.GAMESPEED = 2
        for _, state in ipairs({1, 2, 3}) do
            G.STATE = state; assert(M.fast_forward_multiplier() == 4)
        end
        held = false; assert(M.fast_forward_multiplier() == 1); held = true
        focused = false; assert(M.fast_forward_multiplier() == 1); focused = true
        G.SETTINGS.paused = true; assert(M.fast_forward_multiplier() == 1); G.SETTINGS.paused = false
        G.OVERLAY_MENU = {}; assert(M.fast_forward_multiplier() == 1); G.OVERLAY_MENU = nil
        G.CONTROLLER.text_input_hook = {}; assert(M.fast_forward_multiplier() == 1); G.CONTROLLER.text_input_hook = nil
        G.screenwipe = {}; assert(M.fast_forward_multiplier() == 1); G.screenwipe = nil
        for _, state in ipairs({4, 5}) do G.STATE = state; assert(M.fast_forward_multiplier() == 1) end
        G.STATE = 1; G.STAGE = G.STAGES.MAIN_MENU; assert(M.fast_forward_multiplier() == 1)
        assert(G.SETTINGS.GAMESPEED == 2, 'fast forward changed the saved speed')
    ''', 'behavior tests', True)
    lua.lua_close(state)
    print(f'PASS: {len(sources)} Lua sources compile; patch anchors, settings, and hold/release fast-forward guards verified.')


if __name__ == '__main__':
    verify()
