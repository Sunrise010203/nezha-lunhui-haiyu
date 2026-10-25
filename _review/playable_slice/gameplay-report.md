# 第一章可玩性修复 · 实施报告（task 2 / gameplay）

日期：2026-10-22
执行者：gameplay（AgentTeams / nezha-playable-slice）
计划来源：[docs/plans/2026-10-22-playable-slice.md](../../docs/plans/2026-10-22-playable-slice.md)
基线：[`_review/playable_slice/baseline/`](baseline/README.md)

---

## 0. 一句话结论

第一章的**落水报错/重复击退**、**死亡面板会被 Esc 顶掉与重复叠加**、**复活后残留临时状态**、**灵力只减不回**、**教学提示 9 条同时飘在场景里**、**硬直中按键丢失**六个问题已修复，并补了一套**断言真实状态**的回归脚本（61 项，全绿）。地形、碰撞、收集、莲台数量与坐标、Boss 数值、闯关整章重来规则均未改动。

**未做**（计划里明确列为"可放弃"或依赖窗口渲染）：Boss 重复开场提示的收敛、以及所有需要真实窗口的像素级目视验收（本阶段 headless）。

---

## 1. 改动清单

| 文件 | 类型 | 改动要点 |
|---|---|---|
| `001/scripts/energy_regen.gd` | **新增** | 灵力自然恢复纯函数：`DELAY=3.0`、`RATE_FRACTION=0.05`、`step(...)` 跨阈值只补超出部分、暂停/死亡直接返回、不越过上限。**故意不用 `class_name`**（`--script` 模式下全局类缓存不可靠），改用 `preload` 引用 |
| `001/scripts/player.gd` | 修改 | ① `attack_buffer_t` + `INPUT_BUFFER = 0.12` 单次动作缓冲；② `energy_idle` / `_energy_prev` / `_tick_energy_regen()`，任何灵力下降都重置脱战计时；③ `is_dead()` 状态接口（替代外部直接读 `dead` 字段）；④ `_ring_throw` 记录在途乾坤圈；⑤ `respawn()` 全面重写：清理在途圈、蓄力、风火轮腾空窗口、输入队列、冲刺/连击冷却、减速、外力，**保留灵力数值**；⑥ `_die()` 清空输入队列 |
| `001/scripts/level_1.gd` | 修改 | ① `_on_pool_entered()` 用 `is_dead()` 判活，落水只结算一次伤害 + 一次水推（删掉 `apply_external_force`，消除双重击退）；② 9 条教学提示的文案按真实键位重写（A/D、Space 二段跳、Shift 冲刺、J/K、E 乾坤圈蓄力、落水扣 4 点），坐标不变 |
| `001/scripts/level_base.gd` | 修改 | ① `_hint()` 改为注册式：全部隐藏，**同屏只淡入"最近且未完成"的一条**，做出对应动作后永久收起，离开半径淡出；② `_respawning` / `_restarting` / `_death_pending` 三把幂等锁；③ `_process` 里驱动 `_update_hints()` |
| `001/scripts/hud.gd` | 修改 | ① `_overlay_kind`（`"" / pause / death / campaign_death / victory`）取代"有没有面板"判断：**死亡/结算面板期间 Esc 不再顶掉，普通暂停 Esc 正常恢复**；② `show_death` / `show_campaign_death` / `show_victory` 互斥 + `_paused=false; get_tree().paused=false`（否则整章重开后场景仍是暂停的）；③ 灵力条右侧新增一行小字"脱战 3 秒后缓慢回复" |
| `001/tools/test_gameplay_states.gd` | **新增** | 61 项行为断言（详见 §3） |
| `_review/playable_slice/gameplay-report.md` | **新增** | 本文件 |

未改动：`001/autoload/game.gd`、`001/project.godot`、任何场景 `.tscn`、任何美术资产、莲台与收集物坐标、`Game.start_campaign()` 的技能解锁（E 仍需首章收集解锁）。

### 关键设计选择

- **落水击退由关卡负责**：`take_damage()` 内部本来就把速度打成 `(dir*7, 5, 0)`，关卡再叠 `apply_external_force()` 会变成 14/s 的反复弹射并触发二次掉血。现在关卡只做"扣一次血 + 一次更明显的定向水推（`dir*7.5, 10.5`）"，外力通道留给真正的机关。
- **复活不重置灵力**：与"缓慢恢复"配套，`respawn()` 里只重置 `energy_idle` 与 `_energy_prev`，`energy` 数值原样保留（实测 12.5 → 12.5）。
- **教学收敛而非新增**：用的是原有的 9 个 `_hint`，只是把"全部常驻可见"换成"同一时刻至多一条 + 做完即消失"，因此没有新增任何 UI 层级。
- **灵力只在存活脱战恢复**：`_tick_energy_regen()` 在 `act == "dead"` 时**直接清零 `energy_idle`** 并 return，死亡等待面板的 1.1 秒不会被算成脱战时间。

---

## 2. 机制实现对照（任务书 → 代码）

| 任务要求 | 实现位置 |
|---|---|
| 落水用正确状态接口、不重复击退 | `level_1.gd::_on_pool_entered()` → `Player.is_dead()`；伤害与推力只执行一次 |
| 死亡/暂停/结算面板互斥 | `hud.gd::_input()` 用 `_overlay_kind`；`show_*` 首行互斥返回 |
| 复活防重复 | `level_base.gd::_respawn_full()` 的 `_respawning`；`_on_player_died()` 的 `_death_pending`；`restart_callback` 的 `_restarting` |
| 清理在途乾坤圈/输入队列/冷却/冲刺/风火轮/减速，保留解锁 | `player.gd::respawn()`（不清 `Game.skills`，E 解锁状态不受影响） |
| 闯关死亡整章重来 | 未改：`Game.campaign == true` 仍走 `show_campaign_death()` + `restart_callback`（重载本章） |
| 选关莲台复活 | 未改：`_on_player_died()` 非 campaign 分支仍 `call_deferred("_respawn_full")` |
| 灵力：脱战 3s 后每秒 +上限 5% | `player.gd::_tick_energy_regen()` + `energy_regen.gd::step()` |
| 攻击/施法/受击重置计时 | `_start_action()` 与 `take_damage()` 调 `_reset_energy_idle()`；另加 `energy < _energy_prev` 兜底（覆盖冲刺、真火、蓄力等不在 `_start_action` 里的消耗） |
| 0.12s 单次动作输入缓冲 | `player.gd::_physics_process()` 的 `attack_buffer_t` 登记 + `elif attack_buffer_t > 0.0 and act == "free"` 单次消费 |
| 教学单条邻近触发/完成或离开淡出 | `level_base.gd::_update_hints()` |
| 文案改为真实操作 | `level_1.gd::_build_tutorials()`（A/D、Space、Shift、J/K、E、落水说明） |
| HUD 说明灵力机制 | `hud.gd::_build_player_bars()` 的 `regen_hint_label` |

---

## 3. 行为回归：`001/tools/test_gameplay_states.gd`

设计原则：**不用 `has_method()` 之类的方法存在性检查**，而是把角色真的放进水里、真的暂停、真的打死一次，再断言血量/面板种类/状态字段/灵力数值。

```powershell
$g = 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_gameplay_states.gd
```

实测输出（2026-10-22 14:0x，退出码 0）：

```
GAMEPLAY_STATES checks=61 failures=0
```

覆盖项（按分组，全部 PASS）：

- **EnergyRegen 纯函数（9）**：阈值 3.0s、5%/s、未满 3 秒不回、跨阈值那一帧只补超出部分（实测 10.000→10.080）、满脱战 1 秒 +5.00、暂停不回、死亡不回、不越上限。
- **布局未被改动（2）**：`_checkpoints.size() == 5`、`_hints.size() == 9`。
- **教学（6）**：靠近时同屏仅 1 条淡入；最近一条 alpha > 0.8；文案含 `A / D`；走远后全部 alpha 归零；标记 `done` 后回到原处仍不弹出；`done` 标记保持。
- **落水（3）**：一次落水只掉 4.0 血；`_external_vel` 恒为零（无二次击退）；速度峰值 `vx = 7.50`（旧实现 14+）。
- **复活清理（13）**：回满血；回到 `free`；风火轮腾空窗口、蓄力/在途标记、输入队列与缓冲、冲刺/连击冷却、减速全部归零；**灵力 12.5 原样保留**；连续两次 `respawn()` 结果一致（幂等）。
- **在途乾坤圈（3）**：掷出后实体有效 → `respawn()` 后实体被 `queue_free`（`is_instance_valid == false`）→ `_ring_out == false` 可立即再掷。
- **复活互斥（2）**：连续两次 `_respawn_full()` 后 `_respawning == false`、状态仍干净。
- **灵力恢复（8）**：脱战 100 帧（1.6s）不回；脱战满 3 秒后 1 秒实测 `+5.00`；Esc 暂停 `_paused==true && paused==true` 且灵力停在 10.00；**再按一次 Esc 能恢复**（旧计划里 `if _overlay != null: return` 会永久卡在暂停）；死亡期间不回且 `energy_idle == 0.0`。
- **输入缓冲（5）**：硬直中按攻击 → `attack_buffer_t = 0.120` 且不强行出招；恢复可控后只补一次 `atk1` 并清空缓冲；超时（>0.12s）后不再补招。
- **死亡流程（9）**：致死伤害后 `is_dead()`；死亡等待 1.1s 期间 Esc 不打开暂停；之后弹出 `campaign_death` 面板（**不是**莲台复活）且 `_death_pending == true`；面板打开时 Esc 不改变面板、不重建；重复 `show_campaign_death()` 不叠第二个；面板期间 `paused == false`。

> 说明：退出时的 `ObjectDB instances leaked at exit` / `resources still in use` 是 headless 下 `--script` 直退的既有现象，`test_ch1_hybrid.gd` 同样出现，与本改动无关。

---

## 4. 其他回归（证明没有连带破坏）

```powershell
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_ch1_hybrid.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_combat_vfx.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_nezha_motion.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_huojianqiang.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_boss_levels.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_enemy_levels.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_boss_motion.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_enemy_motion.gd
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_flash.gd
```

| 套件 | 实测结果 |
|---|---|
| `test_ch1_hybrid.gd` | `CH1_HYBRID failures=0` |
| `test_combat_vfx.gd` | `"passed":true`（13 项，含"轻/重击伤害与灵力消耗不变"、"风火轮仍耗 60 灵力"） |
| `test_nezha_motion.gd` | `{"checks":80,...,"passed":true}`（含 "respawn exits death"、"respawn settles to visible idle"） |
| `test_huojianqiang.gd` | `{"checks":34,...,"passed":true}` |
| `test_boss_levels.gd` | `FAILED=false` |
| `test_enemy_levels.gd` | `FAILED=false` |
| `test_boss_motion.gd` | `FAILED=false` |
| `test_enemy_motion.gd` | `174 FAILED=false` |
| `test_flash.gd` | `[flash] RESULT=PASS` |

---

## 5. 原始 bug 的端到端复现验证

基线记录的原始报错（t1 复现）：

```
SCRIPT ERROR: Invalid access to property or key 'dead' on a base object of type 'CharacterBody3D (Player)'
```

同一段重放（走 4 段路，第 4 段 101→121 就是出问题的水廊）：

```powershell
& $g --headless --path 'E:\godot_game_by_fable\001' res://tools/probe_walk.tscn -- `
    res://scenes/level_1.tscn 0:14 20:29 67:77 101:121
```

实测输出（2026-10-22）：

```
=== WALK res://scenes/level_1.tscn ===
OK    0.0 -> 14.3  hp=100  y=0.54
OK    21.6 -> 29.8  hp=88  y=1.77
OK    67.9 -> 77.4  hp=88  y=7.18
OK    101.9 -> 121.3  hp=54  y=5.90
WALK DONE
```

- 四段全部 `OK`，**没有任何 `SCRIPT ERROR`**（旧版本这一段会连报 3 次并卡在落水逻辑）。
- 101→121 段掉血 34 点 = 落水 8 次 × 4 点（每次被冲回桥头再走，属于设计内的惩罚），不是一帧内多次结算。

---

## 6. 资产/布局未动的证据

```powershell
python _review/playable_slice/baseline/baseline.py check
```

```
CHANGED   001/scripts/player.gd      CHANGED   001/scripts/level_base.gd
CHANGED   001/scripts/level_1.gd     CHANGED   001/scripts/hud.gd
same      001/autoload/game.gd       same      001/project.godot
CHANGED   .gitignore（t1）           CHANGED   tools/backup.ps1（t1）
9 files checked, 6 changed
```

- 基线保护的 9 个文件里，只有本任务授权范围内的 4 个脚本变化，另 2 个是 t1 自己改的。
- `git status` 里其余的 `M`/`D`（boss_*.gd、enemy_*.gd、`*.md`、`*.png` 等）在 t1 采集 `baseline/git-state.txt` 时就已存在，**不是本任务产生**。
- 场景文件、美术资产、`001/project.godot` 均未修改；莲台数量（5）与收集坐标由测试断言守住。

---

## 7. 已知限制 / 留给 delivery 的事项

1. **纯逻辑验收，未做像素目视**：headless 下无法截图。灵力的新增小字（`hud.gd` 里 `regen_hint_label`，位置 `(bar_x + 280 + 22, 92)`，字号 14）需要 delivery 在带窗口的机器上确认不压住技能图标。
2. **Boss 重复开场提示未收敛**：计划里列为"能安全保留战斗语义才做"，本轮判断不值得在复盘前动 Boss 时间轴，保持原样。
3. **多次落水仍会多次扣血**：这是设计（每次落水 4 点、靠 `area.meta["cool"]` 2 秒冷却防连击），走位失误仍会掉血，符合"闯关有惩罚"。
4. **`--script` 模式的两个坑**（后续写测试的人会踩）：
   - 测试脚本里**不要**写 `var p: Player` / `var h: HUD` 类型标注，也不要在编译期引用 `Game`；autoload 与依赖脚本在 `--script` 下编译更早，会以 `Identifier not found: Game` 整链失败。用无类型变量 + `root.get_node_or_null("Game")`。
   - `await physics_frame` 在**物理步开始**处恢复，读状态要 `await physics_frame` 两次（或等 `process_frame`）才能看到本帧 `_physics_process` 的结果。

## 8. 复跑清单（给 delivery）

```powershell
$g = 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_gameplay_states.gd   # 期望 failures=0
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_ch1_hybrid.gd          # 期望 failures=0
& $g --headless --path 'E:\godot_game_by_fable\001' res://tools/probe_walk.tscn -- res://scenes/level_1.tscn 0:14 20:29 67:77 101:121  # 期望四段 OK、无 SCRIPT ERROR
python _review/playable_slice/baseline/baseline.py check                                            # 期望只有 4 个脚本 + t1 的 2 个文件 CHANGED
```
