# 试玩包 F1/F4 修复报告（t6）

任务：修复 `_review/playable_slice/final-review.md` 的 F1（导出包第一章远景贴图缺失、出生点白块）
与 F4（HUD/提示缺失、看不见残片与 Boss 血条）。范围：`001/export_presets.cfg`、必要的导入设置、
`001/tools/`、`001/scripts/ch1_ruins.gd`、`001/shaders/ch1_far_matte.gdshader`、根 `README.md`、
`_review/playable_slice/` 报告；不改动游戏玩法脚本。

## F1 根因

t3 导出预设的 `exclude_filter` 含 `art/ref/*`，把第一章远景贴图
`res://art/ref/ch1_palace_far.png` 排除出包。`001/scripts/ch1_ruins.gd` 的
`Game.tex(...)` 返回 `null`，`ShaderMaterial` 的 `sampler2D palace` 采样未绑定纹理，
在 `ch1_far_matte.gdshader` 里呈整块白色（出生点背后 520×160 的远景 QuadMesh）。

## 修复

1. `001/export_presets.cfg`
   - 删除 `exclude_filter` 中的 `art/ref/*`（其余开发目录过滤保留）。
   - 产物名改为 `nezha_ch1_playable_r2.exe`，避免旧包误分发。
2. `001/shaders/ch1_far_matte.gdshader`
   - `uniform sampler2D palace : hint_default_black`（缺纹理时不再白色）。
3. `001/scripts/ch1_ruins.gd`
   - `build_depth()` 显式检查 `Game.tex()`：为 `null` 时 `push_error(...)` 并调用
     `_fallback_far_texture()`（256×64 水下雾色渐变 `GradientTexture2D`），再喂给着色器。
   - 无远景贴图时仍然渲染深青雾色，不会白块；错误进日志与 stderr。

## 证据（全部来自最终 exe 或最终工程的真实渲染器）

### 1) 包内资源可解析

`_review/playable_slice/verify_t6/pack_check.gd`（编辑器/无头运行）：

- 定位 exe 尾部 PCK 布局 `[exe][pck][u64 pck_size][GDPC]`，偏移 `104,559,616`、大小 `452,948,604`，
  `ProjectSettings.load_resource_pack()` 成功。
- 用 `--main-pack` 把抽出的 PCK 直接交给 Godot 真实渲染并读运行期状态，原始输出见
  `verify_t6/pack_check.txt`：
  - `HUD hint_vis=true hint_rect=[P:(36,1036) S:(878,25)]`
  - `HUD soul_vis=true soul_rect=[P:(1590,26) S:(290,40)] text=龙魂残片　0 / 3`
  - `VIEWPORT [P:(0,0) S:(1920,1080)]`
  - `FAR_TEX (res://art/ref/ch1_palace_far.png):<CompressedTexture2D#...>`
  - `SHOT_SAVED .../r2_pack_start.png (1920,1080)`
  - `BOSS state=dormant hp=480.0 started=false`
  - 包内确无 `tools/capture.gd`、`scenes/env_ch1_showcase.tscn`（t3 已验证，过滤规则未变）

### 2) 真实渲染 (1920×1080, D3D12 Forward+)

| 文件 | 内容 |
|---|---|
| `verify_t6/r2_start.png` | 第一章出生点：远景贴图完整（青蓝宫殿柱廊），无白块；HUD 完整 |
| `verify_t6/r2_bridge.png` | 断桥水廊：远景随镜头连续，无白块 |
| `verify_t6/r2_boss.png` | Boss「归墟之喉 · 渊狱兽」：480 HP、Boss 血条与名牌可见 |
| `verify_t6/r2_exe_game.png` | **最终 exe** 从主菜单进闯关第一章的实机画面（远景正常、教学提示、HUD） |
| `verify_t6/r2_fallback_missing_tex.png` | 变体包（故意排除远景贴图）：雾色渐变而非白色 |

### 3) 缺贴图容错实测

变体导出（临时预设 + 临时 `main_scene`，导出后已还原；`project.godot` 与备份逐字节一致）：

```
ERROR: ch1_ruins: 缺少远景贴图 res://art/ref/ch1_palace_far.png，已用程序化雾色兜底
   at: push_error (core/variant/variant_utility.cpp:1024)
```

画面见 `verify_t6/r2_fallback_missing_tex.png`：远景是深青雾色渐变，无白矩形。

## F4：HUD 与提示

- 出生点 HUD（1920×1080，真实渲染 + `pack_check.txt` 运行期矩形）：
  - 残片计数 `龙魂残片 0 / 3`，矩形 `(1590,26,290,40)`，可见；
  - 底部键位帮助条 `(36,1036,878,25)`，可见；
  - 灵力条 `(132,94,288,18)`，右侧恢复提示由 `hud.gd` 定位在 `x=132+280+22=434, y=92`（14 px，实测未与技能槽重叠）；
  - 技能槽 58×58 位于 `y=126`，x=132/200/268，与提示行不重叠。
- 教学提示：改为**单条最近提示**，不再叠字；出生点显示
  `A / D 移动 · 空格 跳跃（空中再按一次二段跳）`。
- Boss 血条：`r2_boss.png` 中「归墟之喉 · 渊狱兽」480 HP 条与名牌完整。
- 左缘裁切：t6 之前在 `ch1_bridge.png` 有该历史观察；r2 包真实 exe 三档客户区截图（`verify_t7/`）均未复现，改为"未复现的历史观察"，不再作为现存缺陷声明。

## 性能实测（r2 包同源工程）

`001/tools/perf_slice.gd`：禁用 VSync、时间轴 4–10 s 采样、物理 60 Hz、渲染不锁帧；
输出 avg/p50/p95/p99/1% low/max、`BUILD_MS`、draw call、三角形、VRAM。
Godot 4.6 不提供 GPU pass 计时 API（`GPU_TIME_API=unavailable`），下表是 **CPU 主线程帧时间 + 上限 fps**。

| 场景 | avg | p95 | p99 | 1% low ms | 1% low fps | max | 上限 fps | draw | prim | VRAM |
|---|---|---|---|---|---|---|---|---|---|---|
| ch1 出生点 | 2.56 | 2.78 | 2.78 | 2.84 | 352 | 3.31 | 390 | 108 | 397,994 | 772 MB |
| ch2 出生点 | 1.82 | 1.85 | 2.13 | 2.87 | 348 | 14.42 | 550 | 110 | 314,802 | 718 MB |
| ch3 出生点 | 1.55 | 1.67 | 1.85 | 2.10 | 476 | 5.88 | 643 | 107 | 537,293 | 686 MB |
| ch4 出生点 | 1.56 | 1.67 | 1.67 | 1.69 | 592 | 2.17 | 641 | 89 | 454,572 | 686 MB |
| ch1 Boss 激活 (x=140) | 2.69 | 2.78 | 3.03 | 3.60 | 278 | 6.99 | 372 | 121 | 876,660 | 772 MB |
| ch1 Boss · 粒子节点关 | 2.65 | 2.78 | 3.03 | 3.21 | 312 | 4.78 | 377 | 117 | 872,284 | 772 MB |
| ch1 竞技场 (x=60) | 2.52 | 2.78 | 2.78 | 3.27 | 306 | 6.85 | 396 | 139 | 1,065,149 | 772 MB |
| ch1 竞技场 · 粒子节点关 | 2.08 | 2.24 | — | — | — | 9.35 | 481 | 136 | 1,087,693 | 772 MB |
| ch1 断桥 (x=105) | 2.62 | 2.78 | 3.03 | 3.25 | 308 | 7.55 | 382 | 151 | 1,150,617 | 772 MB |

- 全部数字逐行取自 `_review/playable_slice/perf_t6_*.txt` 原日志；日志缺 p99 / 1% low 的格子（arena_vfxoff）留 `—`，不推算。
- `BUILD_MS` 93–165 ms（脚本化关卡构建；不含引擎/着色器预热）。日志中的 `SCENE_READY_MS≈11.3 s` 是探针固定等待窗口，不是可操作时间。
- 单帧尖峰：ch2 14.4 ms、arena_vfxoff 9.35 ms，出现在采样早期，未复现为稳定负载；1% low 最差为 Boss 3.60 ms（278 fps）。
- 粒子对照：`vfxoff` 仅把 13 个 `GPUParticles3D`/`CPUParticles3D` 节点的 `emitting`+`visible` 置 false（**不是 CombatVFX 全关**，爆发特效的着色器/网格仍在）。
  Boss 372→377 fps（+1.3%，噪声量级）；竞技场 396→481 fps（+21.5%）。→ 只能说明两场景对粒子节点开关敏感度不同，**不能**得出"粒子不是瓶颈"，也不能外推到整章特效。
- 无 GPU pass 计时 API，故不判断瓶颈在 CPU 还是 GPU，只报 CPU 主线程帧吞吐。
- 覆盖缺口：四章只测出生点；Boss/竞技场/断桥只测第一章，二至四章对应负载未实测。

## 包与模板

- 最终包：`builds/playable-slice/nezha_ch1_playable_r2.exe`，
  557,508,232 B，SHA-256 `5551152b922f7dd02dde168eaf93b0730439f2ee7305608257c07e10c371ca35`。
- 旧 t3 包与旧 README 已移入 `builds/playable-slice/_rejected_t3/`（保留证据，不删除）。
- 导出模板：官方 4.6.3.stable Windows x86_64 模板，安装到
  `%APPDATA%\Godot\export_templates\4.6.3.stable\`（release 104,659,456 B / debug 100,787,712 B /
  console 各 188,928 B / icu 4,797,072 B），下载后逐文件 crc32 校验；`version.txt` = `4.6.3.stable`。

## 资源与导入设置（遵守 captain 裁决）

- **未执行** `git checkout -- 001/art` 或任何整目录回滚。
- `.import` 状态项 **106 个** = 97 个 tracked 修改 + 9 个未跟踪新增资源（不是 121 个 tracked；121 是当时工作区 modified 总数，含脚本）。t6 没有新增 art 修改。
- 证据归档：`_review/playable_slice/baseline-t6/imports/`
  （`manifest.tsv`、`keychanges.tsv`、`current/`、`head/`、`classification.md`；
  106 个有差异文件：156 处有意 size_limit/压缩设置 + 573 处 Godot 自动元数据 + 27 处自动补字段，
  0 处无法归因）。
- 有意优化保留并经画面验证（`verify_t6/r2_*.png`、`verify_t7/*/ch1.png`）——未见模糊、错位或白块。
- 可恢复性口径：97 个 tracked 的原设置只能从 `git show HEAD:<path>` 取（`baseline-t6/imports/head/` 存了字节副本）；9 个未跟踪新增资源**没有历史原版**，只能保留现状或删除（不删除资产）。`baseline-t6/imports/diffs` 是差异证据，不是原件。

## 未完成/限制

- GPU 侧无官方计时 API，只能用"VSync 关上限 fps + CPU 帧时间"证明未饱和。
- 远景兜底只在"缺贴图"时触发；正常包始终使用 `ch1_palace_far.png`。
- 提示左缘裁切未复现，不作为待修项；若后续在别的镜头看到，再用 `verify_t7/launch_capture.py` 以客户区截图复现后再报。
