# 第一章可交付试玩样板 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把第一章做成一个能交付给外部玩家试玩的闭环样板：落水/死亡不再报错、死亡菜单语义正确、灵力按"缓慢恢复"手感工作、开局有输入教学、最后能导出可执行包并通过验收；全程不动收集/解锁系统、不删原资产、不提交推送。

**Architecture:** 保持 `LevelBase` 的生死分支现状（闯关模式整章重来、选关模式莲台复活），只做三处局部增强：① 用 `is_dead()` 封装死亡判断，修掉 `level_1.gd` 落水处理直接读 `body.dead` 的既有缺陷；② 把灵力恢复抽成纯逻辑 `EnergyRegen`（可无场景单测），由 `player.gd` 每帧调用；③ 在 `hud.gd` 增加一次性输入教学层，键位从 `Game` 的 InputMap 注册表读取，不新增暂停态。导出配置 `export_presets.cfg` 单独新增，产物写入仓库根的 `builds/playable-slice/`（与任务合同 `builds/playable-slice` 一致，`.gitignore` 精确忽略 `/builds/playable-slice/`）。

**Tech Stack:** Godot 4.6.3 stable（Forward+ / D3D12）、GDScript、Windows PowerShell 备份脚本、`_review/playable_slice/baseline/baseline.py` 安全基线。

---

## 0. 前置：安全基线（已完成，勿重复）

本轮开工前已完成，证据在 `_review/playable_slice/baseline/`：

| 项 | 值 |
|---|---|
| 基线采集时刻 | 2026-10-22T05:44Z 前后（见 `MANIFEST.json:sampled_at`） |
| HEAD | `d26d3bc`（`main`），但工作区有 247 条未提交改动，**HEAD 不是基线** |
| 受保护文件 | `player.gd` `level_base.gd` `level_1.gd` `hud.gd` `game.gd` `project.godot` `.gitignore` `001/.gitignore` `tools/backup.ps1`（9 个，sha256 见 `MANIFEST.txt`） |
| 校验命令 | `python _review/playable_slice/baseline/baseline.py check` → 期望 `9 files checked, 0 changed`，退出码 0 |
| 回滚命令 | `python _review/playable_slice/baseline/baseline.py restore`（先把当前版本存进 `files.before-restore/<UTC>/`） |

**每个 Task 开始前先跑 `check`，结束前再跑一次**；任何 Task 不应出现基线之外的意外改动。

### 备份脚本与忽略规则（已完成）

- `tools/backup.ps1` 默认 **DryRun**：只打印改动/未跟踪文件/大文件警告，不 add、不 commit、不 push。
  真正提交必须 `-Paths <a,b> -Commit`；整库提交必须显式 `-AllConfirmed`；
  单文件 >5MB 默认拒绝，需 `-AllowLarge`。旧版无条件 `git add -A` 已移除。
- `.gitignore` 精确新增：`_review/playable_slice/baseline/files*/`、`_review/playable_slice/baseline/files.before-restore*`、`/builds/playable-slice/`、`/.agent-teams/`；**不用** `*.png`/`*.glb`/`export/` 这类宽通配。
- 基线 `check` 里 `.gitignore`、`tools/backup.ps1` 显示 CHANGED 属预期（Task 1 已改）；判定标准是**备份完整 + 无计划外差异**，不是“实现完成后零漂移”。
- 禁止：`git reset --hard`、`git clean`、`git checkout -- .`、自动 `git push`。

### 机制规格（本轮验收口径）

| 机制 | 规格 |
|---|---|
| 闯关模式死亡 | 整章重来：`level_base.gd:1361 _on_player_died` → `show_campaign_death` → `restart_callback`（`level_base.gd:480-486`）保留当前 `chapter_id` 与已解锁技能，`Game.start_run()` 后重载本关场景，回到本章出生点 |
| 选关模式死亡 | 保留莲台：`show_death` → `respawn_callback = _respawn_full`（`level_base.gd:479,1393`），在**本关**莲台/检查点复活，不整章重开 |
| 复活清临时状态 | `player.respawn()` 清 `act`/`velocity`/`invuln`/定潮窗口/乾坤圈飞行/连击；**不清 `energy`**（t2 实做还额外清：风火轮腾空窗口与残影、蓄力状态、攻击/跳跃输入缓冲、冲刺与闪身冷却、减速、关卡外力） |
| 灵力保留 | 复活前后 `energy` 值不变（现有 `respawn()` 已不动 energy，本轮加回归断言防回退） |
| 缓慢恢复 | 存活且**脱战 3 秒**后，每秒恢复 `MAX_ENERGY` 的 5%（=5.0/s），上限 100 |
| 战斗重置延迟 | 受击（`take_damage`）、普攻/重击、任意技能消耗灵力时，脱战计时归零 |
| 暂停/死亡不恢复 | `get_tree().paused` 或 `act == "dead"` 时 `EnergyRegen.step` 原值返回 |
| 首章 E 解锁 | **保持原样**：`game.gd:159-164 collect_soul()` 中 `chapter_souls == 3` 保底解锁，收集系统不改 |
| 输入教学 | 首次进入第一章显示一次性键位面板，不暂停、不阻塞，按键位表真实值渲染（⚠️ 已改为收敛既有 `_hint` 标注，见 Task 3 修正说明） |
| 0.12s 单次动作缓冲 | `INPUT_BUFFER = 0.12`：硬直/冲刺/摆荡/蓄力中按下的攻击先记一次，恢复可控后只补一次，不重复消费、不突破状态与解锁（t2 补入，原计划遗漏） |

---

### Task 1: 修落水与死亡菜单互斥

**Files:**
- Modify: `001/scripts/player.gd:1643`（`take_damage` 附近）、新增 `is_dead()`（放在 `respawn()` 前，约 `:1701`）
- Modify: `001/scripts/level_1.gd:167-183`（`_on_pool_entered`）
- Modify: `001/scripts/hud.gd:703-711`（暂停输入）、`:798-817`（暂停面板）、`:565-568`（连击衰减）
- Test: `001/tools/test_playable_slice.gd`（新建）

**Step 1: 写失败测试**

> ⚠️ **实施修正（t2 已落地）**：下面这份示例只做了**方法存在性**检查（`"is_dead" in player_methods`
> 之类），不足以验收任何一条机制——`is_dead()` 存在也可能返回错值，`EnergyRegen.step()` 存在也可能
> 被 player 忘记调用。实际交付的是 `001/tools/test_gameplay_states.gd`：真的把关卡实例化、真的把角色
> 放进水里、真的暂停、真的打死一次，断言血量/面板种类/状态字段/灵力数值（61 项）。要点：
> - 落水：`hp` 恰好 -4.0、`_external_vel == Vector3.ZERO`、速度峰值在 7.5 而不是 14+；
> - 复活：连续两次 `respawn()` 幂等、在途乾坤圈实体 `is_instance_valid == false`、灵力 12.5 保留；
> - 灵力：脱战不足 3s 不回、满 3s 后 1 秒实测 +5.00、暂停不回、死亡不回且 `energy_idle == 0`；
> - 暂停：Esc 打开 `_paused && paused`，**再按 Esc 必须恢复**（这条专门防 `_overlay != null` 的死锁）；
> - 死亡：1.1s 等待期 Esc 无效、随后 `overlay_kind() == "campaign_death"`、重复回调不叠面板；
> - 输入缓冲：硬直中按攻击 → `attack_buffer_t == 0.120` 且不出招，恢复后只补一次 `atk1`。
> 另外 `--script` 模式下不要在测试里写 `: Player` / `: HUD` 类型标注，也不要编译期引用 `Game`。

```gdscript
extends SceneTree
# 可玩样板回归（示例，已被 test_gameplay_states.gd 取代）：死亡判定 / 暂停互斥 / 灵力恢复
var failures := 0

func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		print("  OK   ", name)
	else:
		failures += 1
		print("  FAIL ", name, "  ", detail)

func _init() -> void:
	var player_script := load("res://scripts/player.gd") as GDScript
	var player_methods: Array = player_script.get_script_method_list().map(func(m): return m["name"])
	_check("Player 提供 is_dead()", "is_dead" in player_methods)
	var regen := load("res://scripts/energy_regen.gd")
	_check("EnergyRegen 存在", regen != null)
	# 纯逻辑：脱战 3 秒后每秒 5%
	if regen != null:
		_check("3 秒内不恢复", is_equal_approx(regen.step(10.0, 100.0, 0.0, 1.0, true, false), 10.0))
		_check("满 3 秒恢复 5/s", is_equal_approx(regen.step(10.0, 100.0, 3.0, 1.0, true, false), 15.0))
		_check("不超上限", is_equal_approx(regen.step(99.0, 100.0, 9.0, 1.0, true, false), 100.0))
		_check("死亡不恢复", is_equal_approx(regen.step(10.0, 100.0, 9.0, 1.0, false, false), 10.0))
		_check("暂停不恢复", is_equal_approx(regen.step(10.0, 100.0, 9.0, 1.0, true, true), 10.0))
	var lvl: PackedScene = load("res://scenes/level_1.tscn")
	_check("level_1 可加载", lvl != null)
	var hud_methods: Array = load("res://scripts/hud.gd").get_script_method_list().map(func(m): return m["name"])
	_check("HUD 有输入教学入口", "show_tutorial" in hud_methods and "hide_tutorial" in hud_methods)
	print("failures=%d" % failures)
	quit(0 if failures == 0 else 1)
```

**Step 2: 跑测试确认失败**

```powershell
$g = 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_playable_slice.gd
```

Expected: FAIL（`ENERGY_REGEN`/`is_dead`/`show_tutorial` 不存在），`failures>=3`。

**Step 3: 最小实现**

`player.gd` —— 死亡判定的唯一入口（`respawn()` 上方）：

```gdscript
func is_dead() -> bool:
	## 外部（落水区、HUD、测试）只认这个判断；死亡状态是 act=="dead"，
	## Player (CharacterBody3D) 没有 dead 属性；旧代码直接读它会抛
	## "Invalid access to property or key 'dead' on a base object of type 'CharacterBody3D (Player)'"）。
	return act == "dead"
```

`level_1.gd:168`：

```gdscript
	if not (body is Player) or body.is_dead():
		return
```

`hud.gd` —— 暂停与结算/死亡互斥，且暂停期间连击冻结而不是"暂停也衰减"：

> ⚠️ 实施修正（t2 已按此落地）：下面这段**不能用"有没有 `_overlay`"判断**。
> 普通暂停本身就是一层 overlay，`_overlay != null` 会把"暂停中再按 Esc 恢复"一起挡掉，
> 玩家会永久卡在暂停里。必须按 overlay **种类**判断：只有死亡/通关类面板才吞 Esc。

```gdscript
var _overlay_kind := ""          # "" / "pause" / "death" / "campaign_death" / "victory"

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _ended:                                # 死亡/结算流程进行中
		return
	if _overlay_kind != "" and _overlay_kind != "pause":   # 死亡/通关面板已开
		return
	if _paused:
		_unpause()
	else:
		_show_pause()
```

`_process` 连击段（`hud.gd:565-568`）改为显式暂停判断：

```gdscript
	if _combo > 0 and not get_tree().paused and not _ended:
		_combo_t -= delta
		if _combo_t <= 0.0:
			_combo = 0
			_combo_label.visible = false
```

`_show_pause()` 里补一句 `_combo_t` 冻结不需要额外代码（`process_mode` 已阻止 `_process`），但要保证 `_unpause()` 不重置 `_ended`；`show_death()/show_campaign_death()` 开头加 `get_tree().paused = false`，避免"暂停中点死亡→面板卡死"。

**Step 4: 跑测试确认通过**

同 Step 2，Expected: `failures=0`，无 `Invalid access to property or key 'dead'` 报错。

**Step 5: 落水手动复现**

```powershell
& $g --headless --path 'E:\godot_game_by_fable\001' res://tools/probe_walk.tscn -- res://scenes/level_1.tscn 0:14 20:29 67:77 101:121
```

Expected: 4/4 段到达（`OK 0.0 -> 14.3` / `20.1 -> 29.2` / `67.9 -> 77.1` / `101.9 -> 121.8`、`WALK DONE`）；
日志中**没有** `body.dead` 报错。

> 2026-10-22 实测：修复前该命令在 101:121 段（水潭）固定触发 3 次
> `SCRIPT ERROR: Invalid access to property or key 'dead' on a base object of type 'CharacterBody3D (Player)'`，
> 落水伤害从未生效（该段结束 hp=58，来源是敌人而非水潭）。修复后应无此报错，且水潭开始真实扣血。

**Step 6: 提交（可选，默认不做）**

仅在用户明确要求时：`powershell -File tools\backup.ps1 -Paths 001/scripts/player.gd,001/scripts/level_1.gd,001/scripts/hud.gd -Commit -Message "fix: 落水死亡判定与暂停互斥"`。

---

### Task 2: 灵力缓慢恢复 + 复活清状态

**Files:**
- Create: `001/scripts/energy_regen.gd`
- Modify: `001/scripts/player.gd:18`（常量）、`:70`（变量）、`:464`（`_physics_process`）、`:594/711/948/1296/1829`（灵力消耗点）、`:1178`（`add_energy`）、`:1643`（`take_damage`）、`:1701`（`respawn`）
- Test: `001/tools/test_playable_slice.gd`

**Step 1: 纯逻辑先写（`EnergyRegen`）**

```gdscript
class_name EnergyRegen
extends RefCounted
## 灵力缓慢恢复：脱战 3 秒后，每秒恢复 MAX_ENERGY 的 5%。
## 纯函数、无场景依赖，便于 headless 单测；player.gd 每物理帧调用 step()。

const DELAY := 3.0
const RATE_FRACTION := 0.05
const DEAD := "dead"

static func rate(max_energy: float) -> float:
	return max_energy * RATE_FRACTION

static func step(energy: float, max_energy: float, idle: float,
		delta: float, alive: bool, paused: bool) -> float:
	if not alive or paused or idle < DELAY:
		return energy
	return minf(energy + rate(max_energy) * delta, max_energy)
```

**Step 2: 测试运行** —— `test_playable_slice.gd` 的 5 条 `EnergyRegen` 断言转绿（`failures` 相应减少）。

**Step 3: 接入 `player.gd`**

常量与状态：

```gdscript
const MAX_ENERGY := 100.0            # 已有，:18
var energy := 30.0                   # 已有，:70
var energy_idle := 0.0               # 新增：脱战计时
var _energy_emit_acc := 0.0          # 新增：HUD 刷新节流
```

`_physics_process` 末尾（`invuln` 递减之后，约 `:474`）：

```gdscript
	energy_idle += delta
	var alive := act != "dead"
	var next_energy := EnergyRegen.step(energy, MAX_ENERGY, energy_idle, delta,
		alive, get_tree().paused)
	if not is_equal_approx(next_energy, energy):
		energy = next_energy
		_energy_emit_acc += delta
		if _energy_emit_acc >= 0.1:     # 10Hz 刷新，避免每帧重排 HUD
			_energy_emit_acc = 0.0
			energy_changed.emit(energy, MAX_ENERGY)
```

脱战计时归零（新增 helper，放在 `_die()` 上方）：

```gdscript
func _mark_combat() -> void:
	## 受击 / 攻击 / 施法都会打断"脱战恢复"
	energy_idle = 0.0
```

调用点：`take_damage()` 开头（`:1643`）、普攻/重击入口（`_process_action` `:1070` 内实际出招处）、`_cast_wheel()`（`:704`）、以及所有扣灵力处 `:594`、`:711/714`、`:948/951`、`:1296`、`:1829`。

**Step 4: 复活保留灵力并清临时状态**

在 `respawn()`（`:1701`）中补：

```gdscript
	energy_idle = 0.0            # 复活后重新计 3 秒，不瞬间回满
	_energy_emit_acc = 0.0
	# energy 保持不变：选关莲台复活属于同一段落，灵力按当前值继续
	_ring_out = false            # 乾坤圈飞行态复位（掷出的 RingThrow 由场景回收）
	_ring_charging = false
	_ring_charge = 0.0
	_ring_charge_fx = 0.0
	if ring:
		ring.visible = true      # 蓄力时被隐藏的环体，复活必须重新显示
	act = "free"                 # 已有
```

`energy_changed.emit(energy, MAX_ENERGY)` 在 `respawn()` 末尾补一次，保证 HUD 立即显示当前值。

**Step 5: 回归测试**

```powershell
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_playable_slice.gd        # failures=0
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_ch1_hybrid.gd            # failures=0
```

Expected：两条都 `failures=0`；后者不得因本轮回归（地形/检查点/Boss 血量检查全绿）。

**Step 6: 手感数值记录**

在 `_review/playable_slice/` 写 `energy-regen.md`：初始 30、脱战 3s、5/s、满 100 需 14s；记录一次编辑器实际运行截图（`001/tools/capture.gd`，非 headless）。

---

### Task 3: 输入教学层（首章首次进入）

> ⚠️ **实施修正（t2 实际做法，已落地）**
> 本节原设计是"再叠一个开局面板 + 两个按钮 + progress 标记"。实际评审后判定这会**叠加在已存在的
> 9 条常驻教学标注之上**，开局更乱，且 `tutorial_seen` 会污染进度存档。改为**收敛既有资源**：
> - 复用 `level_1.gd` 里既有的 9 个 `_hint(...)`，不新增任何面板/按钮/存档字段；
> - `level_base.gd::_hint()` 改为注册式（全部隐藏），`_update_hints()` 只让"玩家最近且在半径内"的
>   **一条**淡入（alpha 0→0.9），做过对应动作（`done_action`）后永久收起，离开半径淡出；
> - 文案按 `Game._register_inputs()` 的真实键位重写（A/D、空格二段跳、Shift 冲刺、J/K、E 乾坤圈蓄力、落水扣 4 点）；
> - 因此下面 Step 1~3 的 `show_tutorial`/`hide_tutorial`/`TUTORIAL_ROWS`/`tutorial_seen` **均未实现**，
>   保留在此仅作设计记录。对应验收改为 `test_gameplay_states.gd` 的"同屏只有一条 / 文案含 A / D / 离开淡出 / 做完不再弹"。

**Files:**
- Modify: `001/scripts/hud.gd`（新增 `_build_tutorial()/show_tutorial()/hide_tutorial()`，`_build_hints()` `:516` 复用键位文本）
- Modify: `001/scripts/level_base.gd:474-490`（`_build_hud` 后按章节触发）
- Modify: `001/autoload/game.gd:140-160`（进度文件加 `tutorial_seen` 标记；**不动** `collect_soul()`）
- Modify: `001/scripts/level_1.gd`（仅首章触发，`chapter_id == "ch1"`）

**Step 1: 键位文本单一来源**

`hud.gd:534` 那行硬编码键位改为从 `Game` 读：

```gdscript
const TUTORIAL_ROWS := [
	["A / D", "移动"], ["空格", "跳跃"], ["Shift", "冲刺"],
	["J", "连击"], ["K", "重击"], ["E", "乾坤圈"],
	["Q", "真火"], ["V", "风火轮"], ["F", "混天绫"], ["Esc", "暂停"],
]
```

**Step 2: 教学面板（不暂停、不阻塞）**

- 位置：屏幕左下，半透明 `PanelContainer`，`mouse_filter = MOUSE_FILTER_IGNORE`；
- 两个按钮：`知道了` / `不再提示`；
- 显示时机：`Game.campaign` 且 `chapter_id == "ch1"`，且 `Game.tutorial_seen == false`；
- 键位按 `Game` 的 InputMap：`InputMap.action_get_events("jump")` 等取首个键名，避免文案与真实按键漂移；
- 关闭时写 `progress.cfg` 的 `tutorial_seen=true`：`game.gd` 增加 `var tutorial_seen := false`，在 `_save_progress()`/`_load_progress()` 里读写该键，并暴露 `func save_progress() -> void: _save_progress()` 供 HUD 调用（**不改** `collect_soul()` 与解锁条件）。

```gdscript
func show_tutorial() -> void:
	if _tutorial != null:
		return
	_tutorial = _build_tutorial()
	_root.add_child(_tutorial)
	Game.tutorial_seen = true
	Game.save_progress()
```

**Step 3: 不遮挡战斗与暂停**

- 教学层 `process_mode = Node.PROCESS_MODE_ALWAYS` 但**不设置** `get_tree().paused`；
- 玩家首帧输入（跳跃/攻击）不吞键：面板不 `grab_focus()`；
- `show_kill`/死亡面板打开时若教学还在，`_show_overlay` 前先 `hide_tutorial()`。

**Step 4: 测试**

`test_playable_slice.gd` 增加：
- `hud_script.get_script_method_list()` 含 `show_tutorial`、`hide_tutorial`；
- 加载 `level_1.tscn` 后 `hud.tutorial_visible() == true`（第一次），再次实例化后为 `false`（标记生效）。

**Step 5: 编辑器实机确认**

```powershell
& $g --path 'E:\godot_game_by_fable\001' res://scenes/level_1.tscn
```

Expected：进入第一章即看到键位面板；按 J/空格能正常出手/跳跃；Esc 暂停面板层级在教学层之上；按"不再提示"后重进不再出现。

---

### Task 4: 导出验收

**Files:**
- Create: `001/export_presets.cfg`
- Create: `001/tools/verify_export.ps1`（可选，校验产物存在与启动日志）
- Output: `builds/playable-slice/`（仓库根；`/builds/playable-slice/` 已精确忽略）

**Step 1: 先确认导出模板**

目标：拿到与编辑器**同版本**（4.6.3.stable）的官方导出模板，不提前假设“不可交付”。

```powershell
ls "$env:APPDATA\Godot\export_templates"   # 现状为空
ls "$env:APPDATA\Godot\export_templates\4.6.3.stable"   # 期望含 windows_debug_x86_64.exe 等
```

核查与下载路线（按顺序尝试，任一条成功即可）：

1. 编辑器 `编辑器 → 管理导出模板 → 下载并安装`（自动匹配编辑器版本，最省事）。
2. 官方 TPZ：`https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable` 下载
   `Godot_v4.6.3-stable_export_templates.tpz`（同页核对 sha256），解压后把 `templates/` 内容放到
   `%APPDATA%\Godot\export_templates\4.6.3.stable\`（TPZ 就是改了后缀的 zip）。
3. 本机 shell 直连 github 已被墙（实测 `curl` exit 7）：改用编辑器/GUI 浏览器走系统代理，或用
   带 Web 通道的工具（`web_fetch`/浏览器）从镜像（TUNA 等 Godot 镜像的 `export_templates` 目录）获取
   同版本 TPZ，落地后按第 2 条安装。

安装后必须校验：目录存在且含 `windows_debug_x86_64.exe`、`windows_release_x86_64.exe`；把版本号与来源 URL 写进 `export.md`。
只有**上述路线全部失败且留下失败证据**时，才允许降级（headless 冒烟 + 实机截图）并如实写明未产出 exe，升级给队长。

**Step 2: 写 `export_presets.cfg`（Windows Desktop）**

关键字段：

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="export/*"
export_path="res://../builds/playable-slice/nezha_ch1_playable.exe"
encryption_include_filters=""
encryption_exclude_filters=""
script_export_mode=2

[preset.0.options]
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
```

**Step 3: 导出**

```powershell
$g = 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $g --headless --path 'E:\godot_game_by_fable\001' --export-release "Windows Desktop" 'E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable.exe'
```

Expected：`builds/playable-slice/nezha_ch1_playable.exe` 与 `.pck`（若未 embed）生成；日志无 `ERROR`（允许既有 ObjectDB 清理告警）。

**Step 4: 产物冒烟**

```powershell
& 'E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable.exe' --headless --quit-after 300
```

Expected：退出码 0，无脚本解析错误。再手动启动一次：主菜单 → 开始游戏 → 第一章可操作、落水不报错、死亡面板文案为"重新挑战本章"、选关模式死亡为莲台复活。

**Step 5: 验收记录**

`_review/playable_slice/export.md`：Godot 版本、模板版本、产物大小与 sha256、冒烟日志摘录、手动清单勾选结果、未解决问题（如有）。

---

## 验收清单（Task 完成后逐条勾）

- [ ] `python _review/playable_slice/baseline/baseline.py check` → 0 changed（除本轮计划内文件外）
- [ ] `test_playable_slice.gd` → `failures=0`
- [ ] `test_ch1_hybrid.gd` → `failures=0`（无回归）
- [ ] `probe_walk.tscn` 4/4 段到达，日志无 `Invalid access to property or key 'dead'`（实测修复前必现，见 Task 1 Step 5）
- [ ] 闯关模式死亡 → 整章重来，出生点满血、灵力回初始 30、技能保留
- [ ] 选关模式死亡 → 莲台复活，灵力保留死亡前数值，临时状态清空
- [ ] 脱战 3s 后灵力 5/s 恢复；受击/攻击/施法立刻停；暂停与死亡期间不恢复
- [ ] 第一章首次进入显示输入教学，不阻塞操作，可"不再提示"
- [ ] 首章第 3 个龙魂残片仍解锁 E（`collect_soul()` 未改）
- [ ] `builds/playable-slice/` 产出 exe/pck，可启动并进入第一章；模板下载各路线均失败时才允许降级，并附失败证据
- [ ] 全程无 `git reset/clean/checkout`、无自动提交、无 push、未删除任何原资产

## 命令速查

```powershell
$g = 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
$p = 'E:\godot_game_by_fable\001'

# 基线
python _review/playable_slice/baseline/baseline.py check

# 回归
& $g --headless --path $p --script res://tools/test_playable_slice.gd
& $g --headless --path $p --script res://tools/test_ch1_hybrid.gd
& $g --headless --path $p res://tools/probe_walk.tscn -- res://scenes/level_1.tscn 0:14 20:29 67:77 101:121

# 实机（非 headless，截图需要真实渲染）
& $g --path $p res://scenes/level_1.tscn

# 备份（默认只预览；提交/推送必须显式）
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1 -Paths 001/scripts/hud.gd -Commit
```

## 风险与非目标

| 风险 | 对策 |
|---|---|
| `EnergyRegen` 改变战斗节奏，Boss 战变简单/更难 | 5%/s 只作恢复，不动 `SKILL_COST`；实机记录一轮 Boss 战手感，必要时只调 `RATE_FRACTION` |
| 教学层遮挡 HUD 或吞键 | 面板 `MOUSE_FILTER_IGNORE`、不 `grab_focus`、不暂停；测试断言首帧输入有效 |
| 导出模板缺失（当前为空） | 按 Task 4 Step 1 三条路线核查/下载同版本官方模板；全失败才降级并附证据，不伪造导出成功 |
| 改动误伤未提交美术/工具 | 每个 Task 前后 `baseline.py check`；回滚用 `restore` 不用 HEAD |
| `progress.cfg` 旧档没有 `tutorial_seen` 键 | 读取用默认值 `false`，只写不读崩 |

非目标：不改收集系统/龙魂数量/E 解锁条件；不改第二章以后内容；不删除或覆盖任何源资产；不提交、不推送。
