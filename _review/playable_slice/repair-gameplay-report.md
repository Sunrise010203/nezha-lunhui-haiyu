# gameplay 修复报告 · F3 蓄力回灵 + F2 动画测试时序

日期：2026-10-22
执行者：gameplay（AgentTeams / nezha-playable-slice，task t5）
依据：[`final-review.md`](final-review.md) 的 **F3（medium）** 与 **F2（medium）**
范围：只动 `001/scripts/player.gd`、`001/tools/test_gameplay_states.gd`、`001/tools/test_nezha_motion.gd`；
新增日志写在 `_review/playable_slice/verify/`。**原失败证据（`final-review.md`、`probe_t4a.log`、`probe_motion_start.log`、t2 的 `gameplay-report.md`）未改动一个字节。**

---

## 0. 结论

| Finding | 状态 | 一句话证据 |
|---|---|---|
| **F3** E 蓄力期间仍回灵 | ✅ 已修 | 复核探针同一处：`ECHARGE act=charge_ring energy=10.0 idle=0.0`（旧：`energy=12.5 idle=3.5`），`T4_PROBE_A checks=36 fails=0` |
| **F2** 动画测试时序竞态 | ✅ 已修 | 按状态边界轮询后 headless ×12、真实窗口 ×3 全绿，`checks` 仍为 **80**（没有删断言、没有放宽断言、没有改生产动画） |

本轮**没有**触碰 F1（导出缺远景贴图）与 F4（HUD 截图证据），那是导出/交付侧的事，不在本任务范围。

---

## 1. F3：E 起手蓄力必须算战斗态

### 根因（复核确认）

- `player.gd::_start_ring_charge()` 旧实现只做 `act = "charge_ring"`，**不重置脱战计时**；
- 灵力是在松手时（`_process_ring_charge()`）才扣 25；
- 于是从"已脱战满 3 秒"起手，`energy_idle` 继续累加，蓄力期间按 5/s 回灵——违反"蓄力是战斗动作"。

### 改法（两处，最小改动）

1. `_start_ring_charge()` 第一行加 `_reset_energy_idle()`（与 `_start_action()` 一致）。松手扣 25 时 `energy < _energy_prev` 的数值兜底会再重置一次。
2. `_tick_energy_regen()` 增加"战斗态不回灵"闸门——这是关键补充：只重置起手那一帧还不够，**按住 E 超过 3 秒仍会开始回灵**。

```gdscript
	# 战斗动作（蓄力 / 出招 / 硬直 / 摆荡 / 擒拿）期间不算脱战：计时归零不累积，
	# 动作结束回到 free 之后才重新开始数 3 秒。act == "free" 是唯一"完全可控"的状态。
	if act != "free":
		energy_idle = 0.0
		return
```

`act` 的全部取值（`player.gd` 内赋值）为 `free / dead / hurt / charge_ring / swing / pull` 加 `_start_action()` 的 `atk1/2/3/heavy/plunge/skill`，因此"只有 `free` 才累计脱战"正好覆盖蓄力、出招、硬直、摆荡、擒拿，且不需要在每处手动调 `_reset_energy_idle()`（以后新增动作也不会漏）。死亡分支在此之前已单独 `return`，行为不变。

### 新增断言（`test_gameplay_states.gd`，+13 项 → 74 项）

| 断言 | 覆盖的验收点 |
|---|---|
| `E 起手蓄力立刻重置脱战计时` | 开始蓄力即重置 |
| `蓄力 0.5 秒不回灵（旧实现 +2.5 → 42.5，实际 40.00）` | 蓄力期间不回灵（F3 原场景复现：`energy_idle = 3.0` 起手） |
| `蓄力中仍是战斗态` | 状态语义 |
| `受击打断蓄力` | 中断 |
| `蓄力被打断后 0.5 秒内不回灵` | 中断后不回灵 |
| `蓄力被打断后重新数脱战（0.5s 内只累计 0.xx 秒）` | 中断后重新计 3 秒 |
| `蓄力结束后 1.6 秒内仍不回灵` | 结束≠立即回灵 |
| `蓄力结束满 3 秒后按既定 5/s 恢复（1 秒实测 +5.00）` | 结束后仍走 3 秒延迟 |
| `按住 E 进入蓄力（真实输入路径）` | 走 `Input` 而不是只调内部函数 |
| `松手扣 25 灵力（40 → 15.0）` | 释放 |
| `松手后脱战计时从零开始` | 释放后重新计 |
| `出招期间不回灵` | 普攻同样算战斗态 |
| `蓄力中暂停不回灵` / `蓄力中死亡不回灵且不累计脱战` | 暂停 / 死亡 |

真实输入路径那条会临时 `game.skills["E"] = true`（首章默认锁 E），跑完立刻还原为 `false`，**没有改解锁逻辑**。

### 实测

```powershell
$g = 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_gameplay_states.gd
```

```
run1: GAMEPLAY_STATES checks=74 failures=0
run2: GAMEPLAY_STATES checks=74 failures=0
run3: GAMEPLAY_STATES checks=74 failures=0
```

用**复核者自己的探针**复跑（不改探针、只写新日志 `verify/probe_t4a_after_fix.log`）：

```powershell
& $g --headless --path 'E:\godot_game_by_fable\001' --script 'E:\godot_game_by_fable\_review\playable_slice\verify\probe_t4a.gd' > _review/playable_slice/verify/probe_t4a_after_fix.log
```

| | 旧 `probe_t4a.log`（证据，未动） | 新 `probe_t4a_after_fix.log` |
|---|---|---|
| ECHARGE 行 | `act=charge_ring energy=12.5 idle=3.5` | `act=charge_ring energy=10.0 idle=0.0` |
| charge 检查 | `FAIL charge: no regen while charging (12.50)` | `PASS charge: no regen while charging (10.00)` |
| 汇总 | `T4_PROBE_A checks=36 fails=1` | `T4_PROBE_A checks=36 fails=0` |

---

## 2. F2：动画测试的固定帧数竞态

### 根因（复核已给出，这里补上量化）

`nezha_motion.gd:68` 落地时 `_land_left = 0.28`，每物理帧减 `delta`（1/60≈0.0167），
`nezha_motion.gd:115` 要求 `_land_left <= 0.14` 才回 `Idle` → **Land 本身要约 8~9 帧**；
再加上出生后落地前的那一两帧，**从 `add_child` 到 `Idle` 实测第 11 个物理步**。
旧测试固定 `await frames(8)`（`test_nezha_motion.gd:49`），必然停在 `Land` 上，
于是 `:73 "breathing idle selected"` 红——这是测试计时问题，不是 t2 的动画改动。

本轮在测试里直接打印实测边界距离（`NEZHA_WAIT_FRAMES`，多次运行完全一致）：

```
NEZHA_WAIT_FRAMES {"grounded":1,"Idle":9,"Jump":1,"Plunge":1,"Roll":1,"Hit":1,"Death":1,...}
```

即：第 1 个物理步落地，落地后**再等 9 帧**才进 Idle → 共约 11 帧。`frames(8)` 比真实边界早 3 帧。

### 改法：等状态边界 + 超时，不放松断言

新增两个按真实物理步推进的等待器（**只改等待方式，不动任何断言与生产动画**）：

```gdscript
func wait_state(state: String, max_frames := 120) -> bool   # 轮询到 actor._motion.current == state
func wait_until(predicate: Callable, max_frames := 180) -> bool
```

替换清单（左旧 → 右新）：

| 检查 | 旧写法 | 新写法 |
|---|---|---|
| grounded / breathing idle（F2 失败点） | `frames(8)` | 先计数等 `is_on_floor()`（≤120 帧），再 `wait_state("Idle", 90)` |
| run moves collider | `frames(20)` | `wait_until(Run 且前进 >0.5m, 120)` |
| left facing | `frames(20)` | `wait_until(facing<0 且朝向≈π, 120)` |
| jump takeoff | `frames(4)` | `wait_state("Jump",60)` + `frames(2)` 让姿势落到骨架 |
| fall to landing sequence | 固定 70 帧 | 边记录 Fall/Land 边等 `is_on_floor()`，上限 240 帧 |
| double jump / state atk*/heavy/skill | `frames(3)/(4)` | `wait_state(<目标 clip>, 60)` |
| plunge entry | `frames(6)` | `wait_state("Plunge",60)` + `frames(2)` |
| plunge exits on impact | `frames(65)` | `wait_until(is_on_floor() 且 act=="free", 240)` |
| combat idle after attacks | `frames(45)` | 额外 `wait_until(FightIdle, 120)` |
| dash roll / roll recovery / hit | `frames(4)/(35)/(3)` | `wait_state` / `wait_until`，上限 60~180 帧 |
| death / respawn | `frames(8)/(80)` | `wait_state("Death",60)` / `wait_until(Idle 且 gfx.visible, 240)` |

保留固定帧的地方都是**语义本身**：`death advances`（40 帧看骨骼位移）、overlay 不累积的 90 次 `update(0.0)` 采样。
**没有删任何断言，`checks` 仍是 80**；`check(...)` 的判定条件与原版逐字一致（只是等到了边界再判）。

### 实测（多次运行，消除竞态）

```powershell
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_nezha_motion.gd          # headless
& $g             --path 'E:\godot_game_by_fable\001' --script res://tools/test_nezha_motion.gd          # 真实窗口
```

| 模式 | 次数 | 结果 |
|---|---:|---|
| headless | 3（最终版本）+ 9（改法定型后累计） | 全部 `{"checks":80,"passed":true}` |
| 真实窗口（无 `--headless`） | 3 | 全部 `{"checks":80,"passed":true}`，日志 `verify/motion_windowed_after_fix.log` |

`grip_error_m`：headless `7.45e-09`，窗口 `1.20e-07`（判定阈值 0.002，余量 4 个数量级）。

---

## 3. 回归（证明 F3 的闸门没伤到别的机制）

`player.gd` 的灵力闸门会影响"什么时候回灵"，所以重点复跑了与灵力/战斗相关的套件：

| 命令 | 结果 |
|---|---|
| `--script res://tools/test_combat_vfx.gd` | `"passed":true`（13 项，含"轻/重击伤害与能量不变""风火轮仍耗 60 灵力"） |
| `--script res://tools/test_ch1_hybrid.gd` | `CH1_HYBRID failures=0` |
| `res://tools/probe_walk.tscn -- res://scenes/level_1.tscn 0:14 20:29 67:77 101:121` | 四段全 OK、`WALK DONE`，**无 SCRIPT ERROR** |

> 注：`probe_walk` 的 `hp` 数值每次运行会浮动（探针是定时输入 + 敌人 AI，受帧时序影响；例如本轮 `67:77` 段 hp=100、`101:121` 段结束 hp=76）。不变量是"四段都 `OK` 且无脚本错误"，不是具体 hp 数字，故不写死。

---

## 4. 需要下游知道的两件事

1. **t2 报告里"9 套全绿"中的 `test_nezha_motion {checks:80,passed:true}` 在当时那一跑是真，但不可复现**（F2）。以本报告 §2 的多次运行结果为准；t2 报告是已完成任务的产物，本轮不覆盖它。
2. **F1/F4 未处理**（导出远景贴图、HUD 截图证据），仍按 `final-review.md` 的结论卡在导出/交付侧。

## 5. 复跑清单

```powershell
$g = 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
# F3：蓄力/出招不回灵，结束仍走 3 秒
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_gameplay_states.gd   # 期望 checks=74 failures=0
# F2：动画时序，headless 与真实窗口各跑两次
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_nezha_motion.gd       # 期望 checks=80 passed=true
& $g             --path 'E:\godot_game_by_fable\001' --script res://tools/test_nezha_motion.gd       # 期望 checks=80 passed=true
# 复核者探针（F3 原证据点）
& $g --headless --path 'E:\godot_game_by_fable\001' --script 'E:\godot_game_by_fable\_review\playable_slice\verify\probe_t4a.gd'  # 期望 fails=0
```
