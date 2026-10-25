# 第一章试玩样板 · t4 第三轮独立验收（final-review-r3）

- 验收人：verifier
- 时间：2026-10-22
- 任务：t4 attempt 3（attempt_id `d961832f-77ac-4759-96b7-77ecc04c9657`）
- 被测对象：`builds/playable-slice/nezha_ch1_playable_r2.exe`
- 大小/哈希：**557,508,232 B** / `5551152b922f7dd02dde168eaf93b0730439f2ee7305608257c07e10c371ca35`
- 代码基线：`001/scripts/player.gd` 等最后修改于 15:17–15:26；r2 exe 15:28；t7 只改验证脚本/截图/报告/README，**没有改 001 代码或 exe 本体**（t7 report:188-197）。
- 前两轮报告保留：`final-review.md`（首轮 needs_revision）、`final-review-r2.md`（r2 首验 needs_revision）。

## 1. 结论

**r2 包可交付（限本哈希，带下述未覆盖说明）。**

首轮 F1–F3 的代码/打包问题已修复并经本轮独立复跑；r2 首验的 F4–F7 已由 t7 的客户区实机截图、性能表纠正和 `.import` 口径纠正解决，本轮未发现新的阻断项。

仍未被本轮“亲手操作”覆盖的内容（不计为产品阻断，必须在交付说明中保留）：

1. 本会话内用 `launch_capture.py` 能启动真实 r2 exe 并拿到 1920×1080 客户区菜单截图，但 DSH 前台窗口抢焦点，自动鼠标点击未能推进到选关/第一章；因此 t7 的选关/第一章客户区截图是**审核其原始证据**，不是本轮重新生成的。真实键鼠完整通关、战斗、死亡/复活、四章跑图仍属**未覆盖**。
2. `GPU_TIME_API=unavailable`，性能只证明 CPU 主线程帧时间与 vsync-off 上限 fps，不定位 CPU/GPU 瓶颈。
3. 二至四章只测出生点；Boss/竞技场/水面高负载只测第一章。
4. Boss 重播开场未做（计划内非阻断）。

## 2. 本轮独立执行

全部日志在 `_review/playable_slice/verify_r3/`，使用 `E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe`：

| 命令/对象 | 结果 | 证据 |
|---|---|---|
| `test_gameplay_states` | `checks=74 failures=0` | `verify_r3/test_gameplay_states.log` |
| `test_nezha_motion` | `checks=80 passed=true` | `verify_r3/test_nezha_motion.log` |
| `probe_t4a`（选关复活/暂停/Esc/胜利/E 蓄力/闯关重开） | `checks=36 fails=0` | `verify_r3/probe_t4a.log` |
| `probe_t4b`（四章提示/Boss/死亡面板） | `checks=35 fails=0` | `verify_r3/probe_t4b.log` |
| `test_ch1_hybrid` | `failures=0` | `verify_r3/test_ch1_hybrid.log` |
| `test_combat_vfx` | 13 项 `passed=true` | `verify_r3/test_combat_vfx.log` |
| `test_huojianqiang` | 34 项 `passed=true` | `verify_r3/test_huojianqiang.log` |
| `test_boss_levels` / `test_enemy_levels` | `FAILED=false` | `verify_r3/*.log` |
| `test_boss_motion` / `test_enemy_motion` | `FAILED=false`（后者 174） | `verify_r3/*.log` |
| `test_flash` | `RESULT=PASS` | `verify_r3/test_flash.log` |
| `probe_shard_unlock`（第三残片解锁 E / 第二章解锁 V） | `checks=5 fails=0` | `verify_r3/probe_shard_unlock.log` |
| `probe_t4d`（四章定潮开关/定潮架/减速入口） | `checks=25 fails=0` | `verify_r3/probe_t4d.log` |
| `r2_embedded.pck` + `probe_t4a.gd` | `checks=36 fails=0`；`ECHARGE energy=10.0 idle=0.0` | `verify_r3/probe_t4a_pck.log` |
| `baseline.py check` | 9 文件 6 changed（4 授权脚本 + t1 的 2 文件） | 终端输出 |
| `git status` / `git diff` | 未 commit/push；97 tracked `.import` 修改 + 9 新增 = 106 | `export-fix-report.md:116` |

### 2.1 打包内容（F1）

- `r2_embedded.pck` 452,948,604 B，`probe_pck_r2.log`：`art/ref/ch1_palace_far.png` **res=true 1536×1024**；`tools/capture.gd`、`env_ch1_showcase.tscn`、`art/models/glb_game` 均 false。
- 真实渲染 `verify_t6/r2_start.png` / `r2_bridge.png` / `r2_boss.png` 目检：远景正常、无白矩形；`r2_fallback_missing_tex.png` 缺图时为雾色而非白色。
- 结论：F1 关闭。

### 2.2 真实 exe 客户区 HUD（F4）

- t7 证据：`verify_t7/1920x1080/ch1.png`、`1600x900/ch1.png`、`1280x720/ch1.png` 均为**真实 r2 exe 的客户区截图**；`launch.json` 记录同一个 exe hash、window_found=true、client 精确尺寸、D3D12 启动日志，`stderr` 仅证书存储警告。
- 本轮独立重跑 `hud_check.py`，三档均 PASS（soul 761/483/273 px，keys 2944/1539/662 px），菜单负对照 FAIL（soul=0），与 t7 `hud_check.json` 一致；1920 图目检右上“龙魂残片 0 / 3”、底部“A/D 移动 … Esc 暂停”、技能槽、灵力条完整，远景无白块。
- 本轮也实际启动 r2 exe：`verify_r3_exe/1920x1080/launch.json` 记录 `window_found=true`、`client_after_resize=[1920,1080]`、`exe_sha256` 同值；截图停在主菜单，`run_click.py`/`run_keys.py` 的输入未能推进（前台窗口为 DSH），故**未把 t7 的选关/第一章点击路径当成自己亲手复现**。
- 结论：F4 的证据问题关闭；真实完整键鼠流程仍为未覆盖项，不据此判定 HUD 逻辑缺陷。

### 2.3 性能口径（F5）

`export-fix-report.md:88-101` 与 `README-试玩包.md:63-75` 已改为 9 行日志口径：

- ch1 竞技场 396.2 → 粒子节点关 481.5 fps（**+21.5%**）已列入；Boss 372.2 → 377.0（+1.3%）并列，不再用 Boss 单场景得出“粒子不是瓶颈”。
- `vfxoff` 明确只关 13 个粒子节点的 `emitting`+`visible`，不是 CombatVFX 全关。
- `1% low` 明确是 **ms**（括号折算 fps），最差 Boss 3.60 ms / 278 fps；不再声称“均 <3.3 ms”。
- `GPU_TIME_API=unavailable`，只报 CPU 主线程吞吐，不定位瓶颈；二至四章高负载未测已写明。

### 2.4 `.import`（F6）与提示裁切（F7）

- `.import` 状态项 **106 = 97 tracked + 9 未跟踪新增**，不是 121；97 个原设置只能由 `git show HEAD:<path>` 取，`baseline-t6/imports/head/` 是字节副本、`diffs/` 是差异证据，不能说“t1 基线有 .import 原件”（`export-fix-report.md:116-122`）。
- 提示裁切：`probe` 中首条提示最小 x≈71、断桥提示 x≈360/436；r2 三档客户区截图未复现；README 已改为“历史观察、当前未复现”，不再作为待修项。

## 3. t2/t5 行为复核（本轮复跑）

- 落水：`level_1.gd` 单次 4 伤 + 7.5 推；`probe_walk` 四段 4/4 OK，无 `Invalid access ... 'dead'`。
- 选关死亡：`probe_t4a` 验证死亡面板、Esc 不换面板、莲台按钮、满血复活、**保留 12.5 能量**、清临时状态、锁释放。
- 闯关死亡：`campaign_death` → 按钮 → `change_scene_to_file` 新 level_1，`Game.campaign=true`、chapter ch1、E/V 技能保留、新实例 hp 100/energy 30、锁干净。
- 缓回：脱战满 3s 后 5/s；暂停/死亡不回；E 蓄力 `idle=0`、不回复（`probe_t4a` 36/0，PCK 内也 36/0）。
- 教学：四章提示 9/5/5/9 条；同屏单条淡入、真实按键完成、离开淡出；ch2–4 无 `done_action`、不会误自动完成；Boss 启动与四章 `campaign_death` 面板均通过（`probe_t4b` 35/0）。
- 输入缓冲：硬直中按攻击只补一次、过期不补；硬直中按 E 不缓冲/不施放；死亡清输入；空挥重置 `energy_idle=0`（`probe_t4c`）。
- 胜利面板：任意键不推进，重复调用幂等。

## 4. 验收矩阵

| 计划验收项 | 结果 | 说明 |
|---|---|---|
| baseline check 仅计划内文件 | PASS | 9 文件 6 changed（4 脚本 + t1 两文件） |
| `test_playable_slice`（现 `test_gameplay_states`）74/0 | PASS | 本轮复跑 |
| `test_ch1_hybrid` failures=0 | PASS | 本轮复跑 |
| `probe_walk` 4/4、无 dead 报错 | PASS | 本轮复跑 |
| 闯关死亡整章重来、技能保留 | PASS | `probe_t4a` 真实换场景 |
| 选关莲台复活、保留能量、清临时状态 | PASS | `probe_t4a` |
| 3s 后 5/s、暂停/死亡不回 | PASS | 纯函数 + 行为 |
| Ch1 教学非阻断、可完成 | PASS | `probe_t4b` |
| 第三残片解锁 E、第二章解锁 V、不重复发放 | PASS | `probe_shard_unlock` 5/0 |
| exe 启动并进入 Ch1、HUD/远景 | PASS（证据审核） | t7 三档客户区截图 + 本轮独立启动菜单；完整亲手点击未覆盖 |
| 无 git reset/clean/checkout/commit/push/删资产 | PASS | 本会话未执行；无提交 |
| 四章 Boss/死亡/定潮/减速 | PASS（自动） | `probe_t4b` 四章 Boss/死亡面板；`probe_t4d` 四章定潮开关/架/减速 25/0；完整手动跑图未覆盖 |
| 真实完整手工通关 | **未覆盖** | 上表已列，不冒充通过 |

## 5. 可交付建议

1. 只分发 `nezha_ch1_playable_r2.exe`（557,508,232 B，SHA-256 `5551152b…`），不要把 `_rejected_t3/` 当正式包。
2. 交付说明保留 README 的“未覆盖/已知限制”：无 GPU 计时、二至四章高负载未测、Boss 重播未做、完整手动流程建议用户实机走一遍。
3. 若用户反馈“按钮点不到/窗口无响应”，优先排查窗口焦点/前台，而不是 HUD；本轮沙箱前台被 DSH 抢占是已知验证环境问题。
4. 可选改进（非阻断）：补四章 Boss/竞技场性能、补音频/多分辨率手动检查、Boss 重播开场。

## 6. 结论

r2 包在**代码、打包资源、自动化行为、HUD 三档客户区证据、性能口径、导入设置口径**上均通过本轮独立复核；没有发现需要重新导出的阻断项。**可交付**，但必须把第 1 节的 4 项未覆盖范围如实告知用户。
