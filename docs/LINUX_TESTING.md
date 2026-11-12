# 在 Linux（Steam + Proton）上测试与调试

这份文档用于在 Linux 电脑上验证并调试本 Mod，重点是「空格加速动画」。首次安装方法见 [README 的 Linux 一节](../README.md#在-linux-steam-安装proton)。

## 当前验证状态

| 项目 | Windows（Lovely 0.9.0，游戏 1.0.1o-FULL） | Linux Proton |
| --- | --- | --- |
| 安装 / 更新脚本 | — | 仅在模拟目录中通过单元测试 |
| 自定义开局、分数预览 | 自动化实机测试通过 | **未实机验证** |
| 空格加速（计分、星球牌升级、开卡包） | 自动化实机测试通过，见 [VALIDATION.md](../tests/VALIDATION.md) | **未实机验证** |

`tests/verify.py` 和 `tests/build_qa.py` 只能在 Windows 上运行：它们通过 PowerShell 找游戏目录，用 `ctypes` 加载 Windows 版 `lua51.dll`，读取 `%APPDATA%`，并直接启动 `Balatro.exe`。在 Linux 上请按下面的步骤手动验证。

## 1. 更新到最新代码

关闭游戏后，在仓库目录运行：

```bash
git pull
python3 install-linux.py --check-only      # 确认检测到的游戏目录和存档目录
python3 install-linux.py --update          # 备份旧 Mod，再复制 mod/ 下的新文件
```

只运行 `git pull` 不会更新游戏加载的 Mod。路径不对时，按 README 加上 `--game-dir` / `--prefix`。Steam 启动选项需要包含：

```text
WINEDLLOVERRIDES="version=n,b" %command%
```

后续命令都会用到存档目录，可以先存进变量：

```bash
SAVE="$(python3 install-linux.py --check-only | sed -n 's/^Save\/config: //p')"
echo "$SAVE"     # 应以 .../pfx/drive_c/users/steamuser/AppData/Roaming/Balatro 结尾
```

## 2. 确认游戏加载的是新版本

```bash
# 已安装的 Mod 应包含新版加速逻辑（不再只限计分和结算状态）
grep -n "Any in-run state" "$SAVE/Mods/Yubalatro/yubalatro.lua"

# 启动一次游戏后再查看：Lovely 日志应显示 game.lua 应用了 2 个补丁
tail -n 50 "$(ls -t "$SAVE"/Mods/lovely/log/*.log | head -1)" | grep -i "applied"

# Lovely 会把打过补丁的游戏源码写到 dump；应能找到加速乘数这一行
grep -n "fast_forward_multiplier" "$SAVE/Mods/lovely/dump/game.lua"
```

| 检查结果 | 含义 |
| --- | --- |
| `log` 目录不存在或没有新日志 | Lovely 没有加载：检查启动选项，以及游戏目录中是否有 `version.dll` |
| 有日志，但没有 `Applied 2 patches to 'game.lua'` | 补丁锚点没有匹配，游戏版本可能不是 `1.0.1o-FULL`；在日志里查看警告 |
| 已安装的 `yubalatro.lua` 里没有 `Any in-run state` | 还是旧 Mod，重新运行 `install-linux.py --update` |

## 3. 手动测试清单

先在「选项 → 游戏」中把游戏速度设为 1 倍，这样加速最容易看出来。每项先正常做一次，再按住空格做一次。

| # | 场景 | 操作 | 预期 |
| --- | --- | --- | --- |
| 1 | 出牌计分 | 出一手触发多张小丑牌的牌 | 按住空格明显变快；得分与不加速时相同 |
| 2 | 回合结算 | 打过盲注后的结算动画和金钱累加 | 变快；获得的金钱不变 |
| 3 | 开卡包 | 在商店买天体包或塔罗包并打开 | 卡包展开和发牌动画变快 |
| 4 | 星球牌升级 | 使用星球牌（在卡包里或从消耗牌栏） | 牌型升级动画变快；等级只加 1 |
| 5 | 塔罗 / 幻灵牌 | 对手牌使用塔罗牌，例如强化 | 翻牌和强化动画变快；效果正确 |
| 6 | 跳过卡包 / 发牌 / 盲注选择 / 商店刷新 | 照常操作 | 都变快 |
| 7 | 松开空格 | 在任一动画中途松开 | 立即恢复正常速度 |
| 8 | 不应加速 | 按 Esc 暂停、打开设置、查看牌组、输入种子、在主菜单按空格 | 没有加速；按空格也不会输入或触发其他操作 |
| 9 | 失去焦点 | 按住空格时 Alt+Tab 切走 | 停止加速 |
| 10 | 保存的速度 | 测试后打开设置 | 游戏速度仍是原值（加速不会写入设置） |

Windows 上的参考耗时（游戏速度 4，按住空格时实际为 16 倍）：星球牌升级 1.568 s → 0.651 s；天体包打开、跳过并重新发牌 3.103 s → 1.335 s。帧和事件开销使实际耗时不会正好变为 1/4。

## 4. 调试

### 代码位置

- [mod/yubalatro.lua](../mod/yubalatro.lua) 的 `M.fast_forward_multiplier()`：判断是否加速，返回 4 或 1。
- [mod/lovely.toml](../mod/lovely.toml)：在原版 `game.lua` 计算 `self.SPEEDFACTOR` 的位置后，补丁加入 `self.SPEEDFACTOR = self.SPEEDFACTOR * YUBALATRO.fast_forward_multiplier()`。
- 原理：事件计时器 `G.TIMERS.TOTAL` 和卡牌动画都按 `G.SPEEDFACTOR` 推进，所以只放大这一个值，就能让开卡包、升级、结算等所有阻塞性动画一起变快。卡牌抖动、文字逐字弹出这类纯装饰动画使用真实时间，不受影响，也不会拖慢流程。

### 查看日志

游戏里的 `print(...)` 会写进 Lovely 日志，前缀为 `[G]`：

```bash
tail -f "$(ls -t "$SAVE"/Mods/lovely/log/*.log | head -1)"
```

需要 Proton / Wine 本身的日志时，把启动选项改为下面这样，日志会写到 `~/steam-2379780.log`：

```text
PROTON_LOG=1 WINEDLLOVERRIDES="version=n,b" %command%
```

### 临时调试输出

直接编辑**已安装的** `"$SAVE/Mods/Yubalatro/yubalatro.lua"` 并重启游戏即可生效，不需要重新安装。下面的代码只在结果变化时打印，避免刷屏：

```lua
function M.fast_forward_multiplier()
    local space = love.keyboard.isDown('space')
    local focus = love.window.hasFocus()
    local state = string.format('state=%s paused=%s overlay=%s wipe=%s text=%s focus=%s space=%s',
        tostring(G.STATE), tostring(G.SETTINGS.paused), tostring(G.OVERLAY_MENU ~= nil),
        tostring(G.screenwipe ~= nil), tostring(G.CONTROLLER and G.CONTROLLER.text_input_hook ~= nil),
        tostring(focus), tostring(space))
    if state ~= M._last_debug then print('[yubalatro] ' .. state); M._last_debug = state end
    -- 下面保留原函数体
    ...
end
```

`G.STATE` 的数字对应 `globals.lua` 中的 `self.STATES`（例如 1 = 选牌、2 = 计分、5 = 商店）。dump 只包含打过补丁的文件，所以要从游戏包里读取（`GAME` 为 `--check-only` 打印的 `Balatro:` 路径）：

```bash
GAME="$(python3 install-linux.py --check-only | sed -n 's/^Balatro: //p')"
unzip -p "$GAME/Balatro.exe" globals.lua | grep -n -A20 "self.STATES = {"
```

调试结束后，把仓库里的改动同步回 `mod/`，或重新运行 `install-linux.py --update` 覆盖临时修改。

### 常见问题

| 现象 | 排查 |
| --- | --- |
| 按住空格完全没变化 | 先完成第 2 节的检查；再看调试输出里 `space` 是否为 `true` |
| `space=true` 但 `focus=false` | Proton / 窗口管理器没有报告窗口焦点（全屏、gamescope 或 Steam Deck 游戏模式可能出现）。可临时把 `love.window.hasFocus()` 条件去掉来确认；如果确实是这个原因，再为 Linux 加备用判断 |
| `space` 一直为 `false` | 输入法或 Steam Input 拦截了空格。先关闭输入法，或在 Steam 中关闭该游戏的 Steam Input 再试 |
| Steam Deck / 手柄 | 手柄没有空格键：在 Steam Input 中把一个按键映射为键盘空格 |
| 只有部分动画变快 | 看调试输出中的 `paused`、`overlay`、`wipe`：这些为 `true` 时按设计不加速 |
| 游戏启动即报错 | 查看 Lovely 日志末尾的 Lua 报错；回退到 `backups/linux-mod-update-*/Yubalatro` 中的旧版 Mod |

## 5. 记录结果

测试完成后，在 [tests/VALIDATION.md](../tests/VALIDATION.md) 顶部追加一段 Linux 记录，写明发行版、Proton 版本、Steam 安装方式（常规或 Flatpak）、通过和失败的清单项，以及遇到的问题。提交后在 Windows 上 `git pull` 即可看到。
