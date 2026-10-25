# 第一章试玩样板 · 独立验收报告（t4）

- 验收人：verifier
- 日期：2026-10-22
- 范围：计划 `docs/plans/2026-10-22-playable-slice.md`、t2 玩法改动、t3 导出包与截图/性能证据、baseline 保护集
- 结论：**不通过（needs_revision）**。核心玩法回归基本成立，但**导出包缺少第一章运行时远景贴图，出生点出现整块不透明白色矩形**；另有 E 蓄力期间仍回灵、`test_nezha_motion` 复跑红两项。当前包不应作为“可交付试玩包”发布。

## 1. 验收方法

1. 只读审查 plan、t2 报告、t3 README/截图/perf、diff、baseline 与导出预设；未改实现代码，未 commit/push。
2. 独立复跑 9 套历史回归 + `test_gameplay_states`（新玩法 61 项）；未采信历史结果。
3. 自写 3 个独立探针（均在 `_review/playable_slice/verify/`）：
   - `probe_t4a.gd`：选关死亡/莲台复活/暂停与死亡 Esc/复活锁/死亡态再受击/闯关整章重开/通关面板/E 蓄力回灵；
   - `probe_t4b.gd`：四章教学提示数量与真实按键完成、四章 Boss 启动、四章死亡面板；
   - `probe_pck.gd` + `probe_pck_hud.gd`：直接从 exe 抽出内嵌 PCK，验证资源是否存在、打包内容能否建 HUD。
4. 独立复核 `probe_walk`、性能日志、截图与 `.import` 改动口径。
5. 尝试真实启动 `builds/playable-slice/nezha_ch1_playable.exe`；本会话无法看到游戏窗口（详见 §5），真实 exe 内手动流程仍需人工复核。

## 2. 验收矩阵

| 验收项 | 结果 | 证据 |
|---|---|---|
| baseline 范围：只改计划内文件 | ✅ 通过（限定） | `baseline.py check`：9 个保护文件中 6 个变化，恰好是 `player.gd`/`level_base.gd`/`level_1.gd`/`hud.gd` + t1 的 `.gitignore`/`tools/backup.ps1`；`game.gd`、`project.godot`、`001/.gitignore` same |
| 无 git 破坏 / 无提交 | ✅ 通过 | HEAD 仍 `d26d3bc`，`git status -sb` 无 ahead；未执行 reset/clean/checkout/commit/push |
| 新玩法 61 项回归 | ✅ 通过 | `test_gameplay_states.log`：`checks=61 failures=0` |
| 历史套件 8/9 | ⚠️ 部分 | `test_ch1_hybrid` 0 fail、`test_combat_vfx` 13 pass、`test_huojianqiang` 34 pass、boss/enemy levels+motion pass、`test_flash` PASS；`test_nezha_motion` **79/false** |
| probe_walk 四段 | ✅ 通过 | `probe_walk.log`：4/4 OK，无 `Invalid access ... 'dead'`；hp 100/88/100/76 |
| 选关死亡 → 莲台复活 | ✅ 通过 | `probe_t4a.log`：按钮存在、满血、能量保留 12.5、临时状态清零、`_respawning`/`_death_pending` 释放 |
| 复活幂等 / 异步锁 | ✅ 通过 | 双调 `_respawn_full` 锁释放；死亡态再受击被 `act=="dead"` 入口忽略，不重复计死亡 |
| 闯关死亡 → 整章重开 | ✅ 通过 | `probe_t4a.log`：真正 `change_scene_to_file` 到新 `level_1`，章节 ch1、E/V 技能保留、hp=100/energy=30、锁干净 |
| 普通暂停 Esc / 死亡面板 Esc | ✅ 通过 | 普通 Esc 开/关暂停；death/campaign_death 面板下 Esc 不换面板、不恢复 |
| 缓慢回灵（3s/5%/s，暂停/死亡停） | ⚠️ 部分 | `test_gameplay_states` 与 `probe_t4a` 均验证 3s 后 5/s、暂停/死亡不回；**E 蓄力期间仍回灵（F3）** |
| 0.12s 缓冲仅普攻 | ✅ 通过（代码+测试） | `player.gd:499-512` 仅在 `attack` 且非 `free/atk1/atk2/atk3` 时登记；未把技能写成可缓冲 |
| 四章教学提示 / 不被任意键完成 | ✅ 通过（有限范围） | `probe_t4b`：ch1=9、ch2=5、ch3=5、ch4=9；ch1 jump 提示按 attack 不完成、按 jump 完成；ch2-4 无 done_action，永不自动完成 |
| 四章 Boss 启动 / 死亡面板 | ✅ 通过（探针级） | `probe_t4b`：四章 `_start_boss()` 调用后 `boss_started=true`；四章均能弹 `campaign_death` |
| 导出包资源完整 / 第一章画面 | ❌ **失败（blocker）** | 内嵌 PCK：`res://art/ref/ch1_palace_far.png` `res=false`、`load=null`；`export_ch1.png` 出生点大白块；README 却称“渲染正常” |
| 打包内容 HUD | ⚠️ 证据不一致 | PCK + 编辑器引擎跑 150 帧：hint/soul 均 visible；t3 `export_ch1.png` 却缺底部条/右上计数；无法复现，需重拍/解释 |
| 性能证据 | ⚠️ 仅部分 | `perf_slice.gd` 实渲染，spawn 448.6fps/2.23ms、boss 454.7fps/2.20ms，Boss 确实启动；无 GPU 时间、无四章/特效开关对比，不能据此断言 GPU 非瓶颈 |
| `.import` 可恢复 | ✅ 通过（口径需修正） | 97 个 tracked 修改 + 9 个新增未跟踪 = status 106；t3“106 tracked changed”不准确；原值可由 git HEAD 恢复，baseline 未覆盖 `.import` |
| Boss 重播开场 | ⚠️ 未做（非阻断） | t2 报告 §7.2 明确保留原样，计划列为可选项 |

## 3. Findings

### F1 — blocker：导出包排除了第一章运行时远景贴图，出生点出现整块白矩形

- **问题**：`001/export_presets.cfg:11` 的 `exclude_filter` 含 `art/ref/*`；但 `001/scripts/ch1_ruins.gd:216` 在 `build_depth()` 中调用 `Game.tex("res://art/ref/ch1_palace_far.png")`，并由 `001/scripts/level_1.gd:198` 在 Ch1 出生时调用。`001/autoload/game.gd:167-171` 在资源不存在时返回 `null`；`001/shaders/ch1_far_matte.gdshader:4` 的 `sampler2D palace` 无默认值，`texture(palace,...)` 取到未绑定 sampler 的白色，故整块 `DistantPalaceMatte` 变成不透明白矩形。
- **证据**：
  - 从 exe 抽出 `embedded.pck`，`probe_pck.log`：`res://art/ref/ch1_palace_far.png file=false res=false`，`PROBE_LOAD palace=<Object#null>`；同包 `art/backdrop.png` `res=true`，证明不是探针方法问题。
  - `_review/playable_slice/shots/export_ch1.png`（14:38）出生点左侧有整块白色矩形；`ch1_start_hud.png`（14:24，编辑器）同位置是淡青半透明带。
  - 用同一 PCK + 编辑器引擎重跑 `probe_pck_hud.gd` 的截图 `_review/playable_slice/verify/export_run/pck_editor_ch1.png` 仍然出现白带，说明是**包内容缺失**，不是 exe 窗口/抓图导致。
  - `builds/playable-slice/README-试玩包.md:40` 却写“进关渲染、HUD、技能特效正常”，与实际截图矛盾。
- **要求修复**：把 `art/ref/ch1_palace_far.png` 纳入导出（从 exclude 移除该文件，或将运行时要用的远景图移到非排除目录）；同时给 shader/调用方加程序化兜底（`Game.tex` 为 null 时用 `haze` 纯色或程序纹理，不能默认白）。重新导出后必须：① `probe_pck` 对 `ch1_palace_far.png` 返回 `res=true`；② 真实 exe 1920×1080 出生点截图无白块；③ 更新 README 的“已验证”表述。
- 文件：`001/export_presets.cfg:11`、`001/scripts/ch1_ruins.gd:211-218`、`001/shaders/ch1_far_matte.gdshader:4`、`001/autoload/game.gd:167-171`。

### F2 — medium：`test_nezha_motion` 复跑红，报告“80/true”不可复现

- **问题**：headless 与真实渲染窗口两种方式都得到 `{"checks":79,...,"passed":false}`，失败点 `001/tools/test_nezha_motion.gd:73 "breathing idle selected"`；`_review/playable_slice/gameplay-report.md:110` 声称 `{"checks":80,...,"passed":true}`。
- **根因**：测试在 `001/tools/test_nezha_motion.gd:49` 固定 `await frames(8)`，而角色出生落地后 `NezhaMotion` 的 `Land` 分支要求 `_land_left <= 0.14`（`001/scripts/nezha_motion.gd:115`）才回 `Idle`；探针 `probe_motion_start.log` 显示前 11 帧仍为 `Land`，第 12 帧才 `Idle`。固定 8 帧等待在“首帧物理步时序”不同的机器上会红，是**测试计时竞态**，不是 t2 动画改动。
- **验证**：复制测试仅把首处 `frames(8)` 改为 `frames(14)`，得到 `{"checks":80,...,"passed":true}`（`probe_motion_wait14.log`），证明改等待即可恢复。
- **要求修复**：把固定帧数改为轮询直到 `actor._motion.current == "Idle"`（上限 30 帧），或至少 `frames(14)`；在报告中如实写复跑结果，不要保留“9 套全绿”。
- 文件：`001/tools/test_nezha_motion.gd:49`、`:73`。

### F3 — medium：E 乾坤圈蓄力期间仍在脱战回灵

- **问题**：`_start_ring_charge()`（`001/scripts/player.gd:1328-1338`）只设 `act="charge_ring"`，**没有调用 `_reset_energy_idle()`**；灵力消耗在松手 `_process_ring_charge`（`001/scripts/player.gd:1354-1356`）才扣。于是从“已脱战 3 秒”状态起手蓄力，蓄力期间继续按 5/s 回灵。
- **证据**：`probe_t4a.log` 唯一 FAIL：能量 10、`energy_idle=3.0`，起手蓄力 30 个 physics 帧后能量 12.5（0.5s 回 2.5，正好 5/s），`act` 仍 `charge_ring`。违反“蓄力属于战斗动作，脱战才回灵”。
- **要求修复**：`_start_ring_charge()` 内调用 `_reset_energy_idle()`（与 `_start_action` 一致）；松手扣 25 后数值兜底也会重置。`test_gameplay_states` 增加“蓄力 0.5s 能量不增”的断言并复跑。
- 文件：`001/scripts/player.gd:1328-1338`、`:660`。

### F4 — low：导出截图的 HUD 证据与代码/打包内容不一致

- **问题**：`_review/playable_slice/shots/export_ch1.png` 缺底部键位条与右上“龙魂残片 0/3”；但 `001/scripts/hud.gd:72-84` 无条件构建 counters/hints，且同一 PCK 的 150 帧实测 `HINT vis=true rect=(36,1036,878,25)`、`SOUL vis=true rect=(1590,26,290,40)`（`pck_hud.log`、`pck_editor_ch1.png`）。无法用打包内容复现缺失。
- **影响**：不影响已证明的玩法，但说明 t3 的“HUD 正常”截图证据不可靠；若真实 exe 确实缺 HUD，则属于另一个 UI 构建/运行时错误。
- **要求**：修复 F1 重新导出后，用真实 exe 重拍 1920×1080 出生点截图，明确 HUD 是否完整；若仍缺，按 `hud.gd:72-84` 的构建顺序查运行时错误。
- 文件：`_review/playable_slice/shots/export_ch1.png`、`001/scripts/hud.gd:72-84`。

## 4. 已确认通过的关键行为

- **选关死亡**：`take_damage(20)` 后 hp=0，死亡延迟内 Esc 无效，`death` 面板出现；Esc 不会替换面板；按钮“莲台重生”存在。
- **莲台复活**：满血、`act=free`、能量保留 12.5（未回满）；`wheel_t/_ring_charging/attack_buffer/jump_buffer/combo_cd/dash_t/_slow_amount` 全清；`_respawning/_death_pending` 释放；面板清除。
- **死亡态再受击**：`player.gd:1706 if act == "dead": return`，`take_damage(999)` 被忽略，`Game.death_count` 不增，复活仍完成。
- **闯关死亡整章重来**：`restart_callback` → `Game.start_run()` + `change_scene_to_file`；新场景 ch1、E/V 技能保留、hp=100/energy=30、新实例锁干净。`_restarting` 不会跨场景泄漏。
- **暂停/死亡面板互斥**：普通 Esc 开/关暂停；death/campaign_death 下 Esc no-op。
- **通关面板**：`show_victory()` 后连发 attack/ui_accept/jump/dash 均不推进；重复调用幂等（`_overlay` 引用不变），不是“按任意键完成”。
- **0.12s 缓冲**：仅 `attack` 动作登记，未把技能/蓄力写成可缓冲；硬直/冲刺恢复后只补一次，过期丢弃。
- **四章教学**：ch1 9 条、ch2 5、ch3 5、ch4 9；ch1 jump 提示按 attack 不完成、按 jump 完成；ch2-4 无 done_action，永不自动完成；提示只在玩家进入半径时显示，离开淡出，不阻塞操作。
- **四章 Boss/死亡**：四章均能 `_start_boss()` 并 `boss_started=true`；四章均可弹 `campaign_death` 面板。
- **缓回**：3s 阈值、5%/s、暂停/死亡不回、不越上限；`test_gameplay_states` 61 项全绿。
- **落水**：单次 4 伤害 + 单次击退 `dir*7.5, 10.5`；`is_dead()` 守卫；`probe_walk` 四段无脚本错误。

## 5. 未覆盖 / 人工复核项

1. **真实 exe 手动流程未亲验**：本会话启动 exe 时，`user://` 目录预建后进程可启动，但桌面截图只见 DSH，未捕获游戏窗口；`window_probe.ps1` 执行超时且无输出文件；已确认无残留进程。PCK 内容用编辑器引擎加载验证，但“双击 exe → 主菜单 → 选关 → 操作”的手感/窗口行为仍需人工跑一遍。
2. **四章完整试玩未做**：只做四章 Boss 启动/死亡面板探针，未逐章跑完关卡、潮汐机制、减速/海眼、Boss 二阶段等。
3. **选关莲台是信号级点击**：探针用 `Button.emit_signal("pressed")` 触发，不是鼠标点击；按钮布局/可点区域未做像素级验证。
4. **教学提示“可关闭”未验证**：当前设计是靠近显示、离开淡出，没有独立关闭键；若产品要求“可手动关闭”，需另做。
5. **性能**：仅 Ch1 出生点/Boss 两个采样点，无 GPU 时间、无四章、无特效开关对比；只能报“实测帧吞吐 448.6/454.7fps”，不能推断 GPU 非瓶颈。
6. **Boss 重播开场**：t2 已明确未做，属非阻断范围说明。
7. **HUD 截图异常**：见 F4，需修复后重拍。

## 6. 复跑命令与产物

```powershell
$g = 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_gameplay_states.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_ch1_hybrid.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_combat_vfx.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_huojianqiang.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_boss_levels.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_enemy_levels.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_boss_motion.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_enemy_motion.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_flash.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_nezha_motion.gd   # 当前 79/false，见 F2
& $g --headless --path 'E:\godot_game_by_fable\001' --script E:/godot_game_by_fable/_review/playable_slice/verify/probe_t4a.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script E:/godot_game_by_fable/_review/playable_slice/verify/probe_t4b.gd
& $g --headless --path 'E:\godot_game_by_fable\001' res://tools/probe_walk.tscn -- res://scenes/level_1.tscn 0:14 20:29 67:77 101:121
& $g --headless --main-pack 'E:/godot_game_by_fable/_review/playable_slice/verify/export_run/embedded.pck' --script E:/godot_game_by_fable/_review/playable_slice/verify/probe_pck.gd
python _review/playable_slice/baseline/baseline.py check
```

关键产物：

- `_review/playable_slice/verify/probe_t4a.log`（36 checks / 1 fail）
- `_review/playable_slice/verify/probe_t4b.log`（35/0）
- `_review/playable_slice/verify/probe_walk.log`（4/4）
- `_review/playable_slice/verify/test_nezha_motion.log`、`test_nezha_motion_windowed.log`（79/false）
- `_review/playable_slice/verify/probe_motion_start.log`（Land 前 11 帧、第 12 帧 Idle）
- `_review/playable_slice/verify/probe_motion_wait14.log`（改为 14 帧后 80/true）
- `_review/playable_slice/verify/export_run/probe_pck.log`（palace res=false）
- `_review/playable_slice/verify/export_run/pck_hud.log` + `pck_editor_ch1.png`
- `_review/playable_slice/shots/export_ch1.png`、`ch1_start_hud.png`

## 7. 交付判断

**当前不可交付。** 先修 F1（blocker）并重新导出；同时修 F2/F3（可并行）；F4 随重新截图确认。修复后复跑本报告 §6 命令，并补一次真实 exe 手动冒烟（主菜单 → 选关 → 第一章出生点 → 暂停/死亡/复活）。Boss 重播开场与四章完整试玩可作为非阻断遗留项，但必须在交付说明中列出，不能写成“全部完成”。

--- 
（本报告只新增/修改 `_review/playable_slice/final-review.md` 与 `_review/playable_slice/verify/` 下的验证脚本/日志/截图；未改实现代码，未 commit/push。）
