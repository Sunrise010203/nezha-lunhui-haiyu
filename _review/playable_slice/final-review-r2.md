# 第一章可玩样板 · 第二轮独立验收（r2）

- 验收人：verifier（独立复核，不修改实现）
- 日期：2026-10-22
- 首轮报告保留在 `_review/playable_slice/final-review.md`；本文件只记录 r2。
- 结论：**不通过（needs_revision）**。F1/F2/F3 已在源码与打包内容中修复并通过独立复跑；
  但 t6 提供的“最终 exe 实机”截图与其自身的 HUD 运行期数据矛盾，真实 exe 的 HUD 未能独立验收；
  t6 性能报告的粒子对照结论与原始日志不一致。代码与 PCK 内容已达到可试玩状态，发布证据尚不完整。

## 1. 产物校验

| 项 | 结果 |
|---|---|
| `builds/playable-slice/nezha_ch1_playable_r2.exe` | 557,508,232 B，SHA256 `5551152b922f7dd02dde168eaf93b0730439f2ee7305608257c07e10c371ca35`，与 t6 报告一致 |
| 内嵌 PCK | 起点 104,559,616，长度 452,948,604，尾部 `[u64 size][GDPC]` 结构有效；已抽出 `_review/playable_slice/verify_r2_embedded.pck` |
| `art/ref/ch1_palace_far.png` | **已进包**：`res=true`，`load()` 为 `CompressedTexture2D`，尺寸 1536×1024（`verify/probe_pck_r2.log`） |
| `art/ref` 条目 | 2 条（`ch1_palace_far`、`ch1_corridor`）；`tools/capture.gd`、`env_ch1_showcase.tscn`、`glb_game` 未进包 |
| `ch1_ruins.gd` / `level_1.tscn` | 已进包且可加载 |
| 工作区 | HEAD `d26d3bc`，未 commit/push；baseline 9 文件中 6 个为计划内变更（player/level_base/level_1/hud + t1 的 `.gitignore`/`backup.ps1`），无新增资产删除 |

## 2. 独立复跑（r2 工作区，非引用 t6 日志）

| 命令 | 结果 |
|---|---|
| `Godot_console --headless --path 001 --script res://tools/test_gameplay_states.gd` | `checks=74 failures=0` |
| `... --script res://tools/test_nezha_motion.gd` | `{"checks":80,...,"passed":true}`，`NEZHA_WAIT_FRAMES {"grounded":1,"Idle":9,...}` |
| `... --script _review/.../verify/probe_t4a.gd` | `T4_PROBE_A checks=36 fails=0` |
| `... --script _review/.../verify/probe_t4b.gd` | `T4_PROBE_B checks=35 fails=0` |
| `... --script _review/.../verify/probe_t4c.gd` | 硬直中按 E 不进入攻击缓冲、不施放；空挥后 `energy_idle=0` |
| `probe_walk`（4 段） | 4/4 OK：hp 100/88/100/76，无 `Invalid access ... 'dead'` |
| 回归套件 | `test_ch1_hybrid` failures=0；`test_combat_vfx` passed=true（13 项）；`test_huojianqiang` 34/true；`test_boss_levels`/`test_enemy_levels`/`test_boss_motion`/`test_enemy_motion`(174)/`test_flash` 全部 FAILED=false/PASS |
| **打包内容行为**：`--main-pack r2.pck --script probe_t4a.gd` | `T4_PROBE_A checks=36 fails=0`，`ECHARGE act=charge_ring energy=10.0 idle=0.0`——t5 的蓄力修复确在包内生效 |

日志在 `_review/playable_slice/verify_r2_*.log`。

## 3. F1/F2/F3 复核

### F1 远景贴图（首轮 blocker）— 已修

- `001/export_presets.cfg:11` 已移除 `art/ref/*`；PCK 探针确认贴图进包并可加载。
- `001/scripts/ch1_ruins.gd:216-229` 增加缺图 `push_error` + `_fallback_far_texture()`；`001/shaders/ch1_far_matte.gdshader:4` 使用 `hint_default_black`。
- `verify_t6/r2_start.png` 目检：无白矩形，远景为青蓝柱廊；`r2_fallback_missing_tex.png` 为雾色渐变，不是白色。
- 结论：**通过**（源码、PCK、截图三层证据一致）。

### F2 `test_nezha_motion` — 已修

- 当前测试改为 `wait_state/wait_until` 轮询，不再固定 `frames(8)`；80 项、`passed:true`，无断言删除。
- 首轮“79/false”的 8 帧竞态已不再出现；结论：**通过**。

### F3 蓄力回灵 — 已修

- `001/scripts/player.gd:1337` `_start_ring_charge()` 首行 `_reset_energy_idle()`；`_tick_energy_regen()` 对非 `free` 动作直接归零（`player.gd:679`）。
- `test_gameplay_states` 74 项含蓄力中断/死亡断言；`probe_t4a` 与 PCK 内 `probe_t4a` 均 `energy=10.0 idle=0.0`。结论：**通过**。

## 4. 发现（按严重度）

### F4（high，验收证据不足）最终 exe 的 HUD 证据自相矛盾

- `_review/playable_slice/verify_t6/r2_exe_game.png` 顶部含 **Windows 窗口标题栏**（“哪吒·轮回海域”），不是 1920×1080 客户区纯净截图；画面中 **底部键位条** 与 **右上“龙魂残片 0/3”** 不可见。
- 同一包的 `pack_check.txt` 明确记录：`hint_vis=true (36,1036,878,25)`、`soul_vis=true (1590,26,290,40)`、viewport 1920×1080；`r2_start.png` 也完整显示两者。两者不能同时成立。
- `export-fix-report.md:52` 仍把该图描述为“最终 exe … HUD”；`README-试玩包.md:74-75` 据此声称实机 HUD 正常。
- 这不等于已证明产品 HUD 缺失（可能是窗口截图裁剪/缩放），但也**不能作为通过证据**。要求重拍 **不含窗口边框的客户端 1920×1080** 截图，附启动二进制 SHA256/控制台日志；至少再测 1600×900、1280×720。若客户端仍缺，则修 HUD 锚点后重导。
- 本会话直接启动 r2 exe 时进程以 `0xC0000005` 退出（日志 `Failed to open 'user://logs/...log'`），与 t6“可运行”环境不同；真实 exe 的菜单→选关→第一章仍属**未覆盖人工流程**。

### F5（medium）性能结论超出数据

- t6 报告 `export-fix-report.md:97` 与 README:70 用 Boss 场景 372→377 fps 得出“粒子不是瓶颈”；但同目录 `perf_t6_ch1_arena_vfxoff.txt` 显示竞技场 **396.2→481.5 fps（约 +21%）**，且该行未进入报告表（报告 8 行，日志 9 份）。
- `vfxoff` 仅关闭 `GPUParticles3D/CPUParticles3D` 的 emitting/visible（`001/tools/perf_slice.gd:141-153`），不是完整 CombatVFX 开关，不能外推“整个特效非瓶颈”。
- `export-fix-report.md:96` 称“1% low 均 < 3.3 ms”，但同表 Boss 激活为 **3.60 ms**；`low1%` 是帧时间 ms，不是 fps（README 口径本身正确）。
- 要求：报告同时列 `arena_vfxoff` 与 Boss 对照，明确“仅粒子系统”；删除“均 <3.3 ms”与“粒子不是瓶颈”的过强结论；无 GPU 时间则只报 CPU 帧吞吐。

### F6（low）`.import` 数量与可恢复性表述

- `git diff --name-only -- '*.import'` 为 **97** 个 tracked 修改；另有 9 个未跟踪新增，共 106 个状态项。`baseline-t6/imports/classification.md` 自己也写“tracked 97 / 新增 9 = 106”；`export-fix-report.md:112` 的“121 个已跟踪修改”不准确。
- t1 基线只覆盖 9 个计划文件，未保存 `.import` 原件；原设置只能从 **git HEAD**（`git show HEAD:<path>`）恢复，`baseline-t6/imports/diffs` 是差异证据而非原始副本。本轮未执行回滚，符合“不删除资产”约束；需在报告中改正数量与恢复口径。

### F7（low）提示左缘裁切未在 r2 复现

- `probe_hints_screen.log`：9 条提示中，出生点第一条在镜头贴近时的最小屏幕 x≈71；断桥长提示 x≈436；`r2_bridge.png` 中长提示从 x≈360 开始，均未裁切。
- `README:83` 仍保留“个别镜头被屏幕左缘裁切”的限制；当前 1920×1080 证据不支持，建议删除或标注为旧版本问题。该条不影响操作，不阻断。

## 5. 范围说明与未覆盖

- **Boss 重播开场**：t2 报告已明确未实现；本轮不将其作为阻断项，属计划外范围说明。
- 未覆盖/未独立完成：真实 exe 菜单→选关→第一章全流程；第一章完整通关（含 Boss 战、胜利结算、章节切换）；真实键鼠手动操作与手柄；四章完整跑图；音频/窗口缩放/多分辨率；GPU 时间与完整 CombatVFX 对照；Boss 重播。
- 已自动化覆盖：四章提示注册 9/5/5/9、Boss 启动、campaign_death 面板；选关莲台复活/能量保留；闯关重开整章、技能保留；暂停/Esc/死亡面板互斥；E 蓄力不回灵；硬直缓冲仅普攻。

## 6. 交付判断

- **源码与打包内容**：F1/F2/F3 已解决，PCK 可加载远景与 t5 回灵修复，`probe_t4a` 在包内 36/36。
- **可发布性**：**暂不判定可交付**。F4 的 exe HUD 证据必须补齐（或由人工在目标机确认）；F5/F6 的报告口径需修正后才能作为验收材料。若 F4 只是截图裁剪，重拍即可；若实机确实缺 HUD，则必须修复后重导。

## 7. 证据索引

- 产物 hash/PCK：`_review/playable_slice/verify_r2_embedded.pck`、`verify/probe_pck_r2.log`
- 测试：`_review/playable_slice/verify_r2_gameplay.log`、`verify_r2_motion.log`、`verify_r2_t4a.log`、`verify_r2_t4b.log`、`verify_r2_walk.log`、`verify_r2_test_*.log`、`verify_r2_pck_t4a.log`
- 截图：`_review/playable_slice/verify_t6/r2_start.png`、`r2_bridge.png`、`r2_boss.png`、`r2_exe_game.png`、`r2_fallback_missing_tex.png`
- 性能：`_review/playable_slice/perf_t6_*.txt`（9 份）
- 报告：`_review/playable_slice/export-fix-report.md`、`repair-gameplay-report.md`、`builds/playable-slice/README-试玩包.md`
