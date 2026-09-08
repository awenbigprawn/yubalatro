# Yubalatro：Balatro 自定义开局与分数预览 Mod

为 Steam 版 Balatro 添加「选项 → 自定义开局」，使用原版游戏和原存档。支持 Windows 安装，以及 Linux Steam 通过 Proton 运行 Windows 版游戏的安装方式。

选中手牌时，左侧筹码和倍率下方会显示「本次得分」及出牌后的「回合合计」。

## 使用

1. 从 Steam 启动 Balatro。
2. 点击「选项 → 自定义开局」。英文界面对应 `Options → Custom start`。
3. 点击数值两侧的 `−` / `+` 每次减一或加一，也可以直接输入数字。点击「保存设置」，然后开始一局新游戏。

| 设置 | 范围 | 含义 |
| --- | --- | --- |
| 手牌上限 | 1–52 | 同时持有的手牌数量上限，不是一次打出的牌数 |
| 每回合出牌次数 | 1–99 | 每个盲注开始时可出牌的次数 |
| 初始金钱 | 0–999999999 | 新开局拥有的钱 |

例如：手牌上限 `12`、出牌次数 `8`、初始金钱 `1000`。

设置页显示已保存的数值；未自定义的项目会用灰色数字显示当前牌组的原版开局值，例如红色牌组为 `8`、`4`、`4`。加减按钮从显示的数值开始调整，并自动限制在允许范围内。
各项留空时保留原版数值。首次安装全部留空，点击「恢复原版设置」可清空所有覆盖值并重新显示原版开局值。
填写的数值在牌组和挑战的开局规则处理后应用，例如黄色牌组填写 `1000` 后开局为 `$1000`。
开局后的小丑牌、优惠券、Boss 等效果仍可改变手牌上限和出牌次数。手牌上限也受剩余可抽牌数量限制。
一次最多选择五张牌的原版规则保持不变。

点击「保存设置」才会写入配置；直接返回会放弃未保存编辑。
加减按钮和恢复原版设置只更新现有输入框，不重新打开窗口。
修改设置只影响新开局，继续已有对局不会重置手牌、出牌次数或金钱。
此 Mod 直接使用原档案，游玩进度会正常写入原存档。

## 分数预览

选中 1–5 张牌后自动计算，不需要额外点击。预览会随选择、手牌顺序、小丑牌顺序及消耗牌效果更新，刷新间隔约 0.15 秒。

- 「本次得分」：这一手完成计分后的得分，包括原版小丑牌、强化、版本、蜡封、留手效果及盲注规则。
- 「回合合计」：当前回合分数加上这一手得分。
- 随机效果按当前种子的结果模拟；重复查看不会推进正式游戏的随机数或改动牌与手型等级。
- 未选牌时显示选牌提示，禁止出牌时显示相应提示。未识别的小丑牌或模拟出错时显示「暂时无法预览」。

适配本机原版内容和本 Mod 的开局设置；不保证其他 Mod 新增计分机制的兼容性。预览使用副本与独立随机数发生器，实际出牌仍由原版计分流程处理。

## 文件位置

- 游戏：Steam 中右键 Balatro → 管理 → 浏览本地文件
- Mod：`%APPDATA%\Balatro\Mods\Yubalatro`
- 配置：`%APPDATA%\Balatro\yubalatro-settings.txt`
- 安装记录：工作区 `installation.json`
- 安装前游戏和存档备份：工作区 `backups`，具体目录见安装记录

工作区 `mod` 是可编辑的源文件，游戏实际加载上面的已安装目录。

## 安装与卸载

### 在另一台 Windows 电脑安装

1. 在 Steam 安装 Balatro，至少启动一次，再关闭游戏。
2. 从 [仓库页面](https://github.com/awenbigprawn/yubalatro)选择 **Code → Download ZIP** 并解压，或执行 `git clone https://github.com/awenbigprawn/yubalatro.git`。
3. 在解压后的项目目录打开 PowerShell，运行下面的安装命令。脚本会自动寻找 Steam 各库中的 Balatro，不要求两台电脑盘符相同。
4. 安装完成后正常从 Steam 启动游戏，进入「选项 → 自定义开局」；选牌后即可看到分数预览。

Mod 和分数预览使用 Windows x64 版游戏的 DLL；Linux 请按下节通过 Proton 运行，macOS、Linux 原生 LÖVE 运行方式尚未适配。已验证游戏版本为 `1.0.1o-FULL`。

安装脚本会先备份游戏目录和全部 Balatro 存档，再安装 Lovely 0.9.0 和本 Mod。
游戏主程序本身不修改。已有 `version.dll` 或同名 Mod 时脚本停止，以保留现有安装。

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

若自动检测失败，使用 Steam「浏览本地文件」显示的目录手动指定，例如：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Balatro"
```

只检查自动找到的目录，不安装任何文件：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -CheckOnly
```

安装无需 Python 或 Git，也无需额外安装 Steamodded。Windows 上从 Steam 正常启动即可，目录规则见 [Lovely 官方说明](https://github.com/ethangreen-dev/lovely-injector#manual-installation)。

### 在 Linux Steam 安装（Proton）

本方案面向 x86_64 Linux 电脑，使用 **Windows 版游戏 + Proton + Windows 版 Lovely**。无需运行 PowerShell，也不用另装系统 LÖVE。安装脚本需要 Python 3.8 或更新版本，以及 `pgrep`（通常由 `procps` / `procps-ng` 包提供）；不要使用 `sudo` 运行安装脚本。

1. Steam 中右键 Balatro → **属性 → 兼容性**，勾选强制使用 Steam Play 兼容工具，选择已安装的 Proton（例如 Proton Experimental）。等待 Steam 完成必要的下载，启动一次游戏，然后关闭，以生成 Proton 存档目录。
2. [下载仓库 ZIP](https://github.com/awenbigprawn/yubalatro/archive/refs/heads/main.zip) 并解压；或在终端执行：

   ```bash
   git clone https://github.com/awenbigprawn/yubalatro.git
   cd yubalatro
   ```

3. 在项目目录的终端执行安装：

   ```bash
   python3 install-linux.py
   ```

   脚本会识别常规 Steam、Flatpak Steam 和 `libraryfolders.vdf` 中的额外游戏库，备份游戏和 Proton 中的 Balatro 存档，下载并校验 Lovely 0.9.0，安装 DLL 和 Mod。安装时会打印实际存档路径，并将记录保存在项目目录的 `installation-linux.txt`，备份位于 `backups/linux-*`。

4. Steam → Balatro → **属性 → 通用 → 启动选项**，填写：

   ```text
   WINEDLLOVERRIDES="version=n,b" %command%
   ```

   这是 [Lovely 官方的 Proton 加载要求](https://github.com/ethangreen-dev/lovely-injector#manual-installation)。已有其他启动选项时需合并，保留原来的参数。

5. 从 Steam 启动游戏。进入「选项 → 自定义开局」，并选牌查看分数预览。

如果安装检测到多个目录或无法找到目录，可先运行 `python3 install-linux.py --check-only` 查看结果，再手动指定。例如（将路径换成你的实际目录）：

```bash
python3 install-linux.py \
  --game-dir "/mnt/games/SteamLibrary/steamapps/common/Balatro" \
  --prefix "/mnt/games/SteamLibrary/steamapps/compatdata/2379780/pfx"
```

`--game-dir` 应含 `Balatro.exe` 和 `lua51.dll`；`--prefix` 应含 `drive_c`。自定义 `STEAM_COMPAT_DATA_PATH` 时，需用 `--prefix` 指向其下的 `pfx`。默认 Proton 路径示例：

| Steam 安装方式 | Balatro 存档与配置目录 |
| --- | --- |
| 常规 Steam | `~/.local/share/Steam/steamapps/compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro` |
| Flatpak Steam | `~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro` |
| 其他游戏库 | 对应库的 `steamapps/compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro` |

以安装脚本检测并打印的路径为准。Mod 位于存档目录的 `Mods/Yubalatro`，自定义配置是存档目录的 `yubalatro-settings.txt`。

**已有 Lovely：** 脚本不会覆盖现有 `version.dll`。确认使用兼容的 Windows 版 Lovely（本项目验证版本为 0.9.0）后，手动将仓库的整个 `mod` 文件夹复制到上述存档目录的 `Mods` 下并改名为 `Yubalatro`，使文件层级为 `Mods/Yubalatro/lovely.toml`；再设置第 4 步的启动选项。其他 Mod 的计分机制不保证兼容。

**更新 / 卸载：** 关闭游戏，将已安装的 `Mods/Yubalatro` 文件夹移到 `Mods` 之外备份；更新时再复制最新版 `mod` 文件夹并改名为 `Yubalatro`。卸载时不必恢复旧存档；如果没有其他 Mod 依赖 Lovely，且游戏目录的 `version.dll` 是本脚本安装的版本，也可将该 DLL 移到游戏目录之外，并撤去对应的启动选项。`installation-linux.txt` 记录了安装路径和 DLL 哈希。

Linux 安装流程已通过 WSL/Linux 中的模拟目录测试；目前未在真实 Linux Steam / Proton 游戏进程中验证计分与界面。

### 存档和自定义设置

仓库只分发 Mod 源码、脚本和测试，不包含 Balatro 游戏本体或个人存档。另一台电脑使用自己的 Steam 游戏安装与本机档案；如果使用 Steam 云存档，启动前先等待同步完成。

Mod 需要在每台电脑分别安装。若要把自定义开局数值也带过去，在两边游戏关闭时，将原电脑的 `%APPDATA%\Balatro\yubalatro-settings.txt` 复制到另一台电脑相同位置；也可以直接在游戏中重新设置。

Windows → Linux 时，将该文件复制到上节安装脚本打印的 Proton 存档目录下。不要把 Windows 的 `installation.json` 或整个游戏目录复制过去。

### 卸载

保留安装时的项目文件夹及其中的 `installation.json` 和 `backups`，不要移动它们，以便卸载脚本读取本机安装记录。

关闭游戏后，在此工作区运行以下命令卸载：

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

卸载会将本 Mod 移入备份目录，保留最新存档和配置；未检测到其他 Mod 时，也会移走本次安装的 Lovely DLL。
卸载不会自动回滚游玩进度。若要恢复安装前进度，可在关闭游戏后从备份的 `save` 目录恢复所需文件。

## 实现与验证

- 已验证 Windows Steam Balatro `1.0.1o-FULL`。
- `python3 -m unittest discover -s tests -p 'test_linux_installer.py'`：使用临时目录核对 Linux Steam / Flatpak / 外置库检测、路径歧义、备份、安装和拒绝覆盖已有加载器。
- 仅依赖 [Lovely 0.9.0](https://github.com/ethangreen-dev/lovely-injector/releases/tag/v0.9.0)，无需 Steamodded。
- 按 [Lovely 官方安装与补丁文档](https://github.com/ethangreen-dev/lovely-injector)使用运行时补丁。
- 计分库随 Mod 附带，基于 [Divvy's Simulation](https://github.com/DivvyCr/Balatro-Simulation)，上游版本与本地修正见 [NOTICE](mod/vendor/divvy/NOTICE.md)。Mod 按 [GPL-3.0](mod/LICENSE)提供完整源码。
- `py -3.12 tests/verify.py`：使用游戏自带 LuaJIT 检查补丁定位、Lua 编译、参数边界、配置保存及默认行为。默认自动检测游戏目录，也可通过环境变量 `BALATRO_GAME_DIR` 指定。
- `py -3.12 tests/build_qa.py`：从本机游戏构建仅用于测试的副本，使用独立 `YubalatroQA` 存档目录；其自动测试驱动不会安装进正式 Mod。
- `py -3.12 tests/build_qa.py --lovely --scoring`：使用实际 Lovely 加载和自动出牌测试，核对预览与实际得分，以及正常和异常路径上的状态恢复。运行 QA 副本时使用 `--mod-dir` 指向测试 Mod 目录。

`backups`、`.qa` 和 `.cache` 含本机游戏、个人存档或下载文件，已加入 `.gitignore`，不属于 Mod 源码。
