# t7 报告：真程序 HUD 证据 + 性能口径纠正（r2 包）

任务：修 `_review/playable_slice/final-review-r2.md` 的 F4–F7。**没有修改任何玩法脚本**；
本轮只新增/更新验证脚本、截图、报告与 README 文案。

被测对象（未重新导出，验证的就是 t6 交付的 r2 exe）：

| 项 | 值 |
|---|---|
| exe | `builds/playable-slice/nezha_ch1_playable_r2.exe` |
| 大小 | 557,508,232 字节 |
| SHA-256 | `5551152b922f7dd02dde168eaf93b0730439f2ee7305608257c07e10c371ca35` |
| 引擎 | Godot 4.6.3.stable.official.7d41c59c4 / D3D12 12_0 / Forward+ |
| GPU | NVIDIA GeForce RTX 5070 Laptop GPU |
| 屏幕 | 2560×1600，150% 缩放（窗口 DPI 144；移到主屏原点后 GetDpiForWindow 报 120） |

---

## F4（blocker 级证据缺口）：真程序 HUD 截图

### 旧图为什么缺 HUD（F6 一并回答）

t6 的 `verify_t6/r2_exe_game.png` 是**全屏区域抓取**，不是客户区抓取：

- 抓取起点 `(11, -11)` 来自窗口客户区原点，截图里带上了标题栏「哪吒·轮回海域」和两侧边框；
- 标题栏占掉顶部约 30 px，正好盖住右上角 `龙魂残片 0 / 3`（HUD 内 y≈26–66）→ 顶栏在图上"消失"；
- 客户区被窗口边框裁到 1906×1042 后又被拉伸进 1920×1080 的图，底部键位条（HUD 内 y≈1036）落到图像边缘外；
- 同一屏幕区域若被其他窗口（DSH GUI）遮挡，抓到的就是别的程序。

结论：旧图缺 HUD 是**抓图方式**问题，不是 HUD 渲染问题；用节点矩形 `(1590,26,290,40)` 与 `(36,1036,878,25)` 无法替代真实截图证据。

### 现在的做法（可复制）

`_review/playable_slice/verify_t7/launch_capture.py`：

1. 以**进程级** `APPDATA` 启动真实 r2 exe（不动用户全局环境，见 F5）；
2. 找到该 PID 的窗口，`AdjustWindowRectEx` 反算边框，把**客户区**精确设为 1920×1080 / 1600×900 / 1280×720；
3. 二次校正客户区原点到屏幕 `(0,0)`（DPI 会让窗口在移动后自己缩到 1600×900，进关后再校正一次）；
4. 真实鼠标点击：菜单 `选择关卡`（0.5, 0.585）→ 选关第一张卡 `第一章`（0.5, 0.306），等待真实关卡渲染；
5. 截图前把窗口提为 `HWND_TOPMOST` + `SetForegroundWindow`，只抓客户区矩形；
6. 每档写 `launch.json`（pid/客户区尺寸/点击坐标/DPI/退出码/环境/exe hash）+ `menu.png`/`select.png`/`ch1.png` + stdout/stderr。

命令（PowerShell/cmd 均可，用任意 Python 3 + Pillow）：

```bat
python _review\playable_slice\verify_t7\launch_capture.py ^
  --exe   E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe ^
  --out   E:\godot_game_by_fable\_review\playable_slice\verify_t7 ^
  --appdata E:\godot_game_by_fable\_tmp_t7\appdata ^
  --size 1920x1080 --size 1600x900 --size 1280x720
```

### 结果（三档全部 PASS）

`_review/playable_slice/verify_t7/hud_check.json`（脚本 `hud_check.py`，阈值按面积归一化：

- 右上暖金文字 `soul` 像素数 ≥ max(30, 0.015% 面积)；
- 底部浅灰文字 `keys` 像素数 ≥ max(100, 0.03% 面积)；
- 图像尺寸必须等于该档客户区尺寸，且 20×20 网格颜色数 ≥ 40（排除纯色/空图）。

| 档位 | 图像尺寸 | soul 金色像素 | 占比 | keys 浅灰像素 | 占比 | 判定 |
|---|---|---|---|---|---|---|
| 1920×1080/ch1.png | 1920×1080 | 761 | 0.037% | 2944 | 0.142% | PASS |
| 1600×900/ch1.png | 1600×900 | 483 | 0.034% | 1539 | 0.107% | PASS |
| 1280×720/ch1.png | 1280×720 | 273 | 0.030% | 662 | 0.072% | PASS |
| 1920×1080/menu.png（负对照） | 1920×1080 | **0** | 0 | 743 | 0.036% | FAIL（符合预期：菜单没有龙魂计数） |

旧图的负对照：`negative_control.json` 对 `verify_t6/r2_exe_game.png` 的判定是 **soul=0 → FAIL**，
与"旧图顶部 HUD 被标题栏盖住"一致。

目检（三张 `ch1.png`）：右上 `龙魂残片 0 / 3` 完整、底部 `A/D 移动 … Esc 暂停` 完整、
技能槽三枚全亮（选关模式）、灵力条 + 「脱战 3 秒后缓慢恢复」在同一行不重叠，无裁切、无白块。

### 输入路径真实性

- 三档都不是编辑器场景、不是变体 PCK、不是 `--script` 截图：是 r2 exe 本体；
- 点击是 `SetCursorPos + mouse_event(LEFTDOWN/LEFTUP)` 的真实输入，`launch.json` 记录坐标；
- 三次运行的 `stdout.log` 均为 `Godot Engine v4.6.3 …` + `D3D12 … RTX 5070`，`stderr.log` 仅
  `Failed to read the root certificate store`（沙箱无根证书，与游戏逻辑无关）；
- 结束时由脚本 `terminate()`，退出码 1（被终止），并已 `taskkill` 兜底，没有残留 Godot 进程。

---

## F5：`user://` 写失败导致 0xC0000005 的规避

### 现象

把进程级 `APPDATA` 指向 `E:\godot_game_by_fable\_review\playable_slice\verify_t7\appdata` 时，exe 启动即崩：

```
exit=0xC0000005 (3221225477)
ERROR: Could not create directory: 'E:/godot_game_by_fable/_review/playable_slice/verify_t7/appdata/Godot/app_userdata'
ERROR: Error attempting to create data dir: .../app_userdata/哪吒·轮回海域.
ERROR: Could not create directory: 'user://logs'.
```

同一 shell 用 `cmd /c echo` 能在该目录写文件，`mkdir` 也能建目录；但 exe 自己建子目录失败 → Godot
`ensure_user_data_dir()` 失败后继续跑，最终访问空日志/数据目录崩溃。**不是包缺陷**，桌面用户默认
`%APPDATA%` 可写时不会触发；但验证环境必须规避。

### 规避（进程级，不改全局）

改用**工作区内的专用可写目录** `E:\godot_game_by_fable\_tmp_t7\appdata`
（`.` gitignore 里的 `_tmp_*` 已忽略，不会进仓库）。该目录下正常生成
`Godot/app_userdata/哪吒·轮回海域/{logs,shader_cache,vulkan}`，`godot.log` 内容为
`Godot Engine v4.6.3.stable.official…` + D3D12 + `Failed to read the root certificate store`，
**无 0xC0000005**。日志副本已放到 `verify_t7/userlog/`。

`launch_capture.py` 的 `launch.json` 记录了：

- `env_before`：`APPDATA=C:\Users\Sunrise\AppData\Roaming`（用户原环境，未改）；
- `env_override`：`APPDATA=E:\godot_game_by_fable\_tmp_t7\appdata`（只对子进程）；
- `cmd`、`cwd`、`pid`、`started`、`exit_after_terminate`、`exit_after_terminate_hex`、`exe_sha256`。

### 给 verifier 的注意

- 换机器/换会话时，只要把 `--appdata` 指到**当前用户可写、且允许子进程建目录**的路径即可；
  不要用 DSH 受限 ACL 的 `_review/**` 目录（本机 `_review` 对 `BUILTIN\Users` 只有 `(RX)`，
  `_tmp_*` 才带沙箱 SID 的可写 ACE）；也不要把 `APPDATA` 指到仓库外需要审批的路径。
- 若同机多人并行验证，请各自用不同 `--appdata`，避免 `progress.cfg` 互相覆盖。

---

## F6：DPI / window / viewport 的区别

- 屏幕物理 2560×1600、系统缩放 150%；游戏窗口是**窗口模式**，客户区被我们精确设为 1920×1080（或 1600×900、1280×720）物理像素。
- 游戏内部 viewport 固定 1920×1080（`project.godot` `window/size/viewport_width/height`，`stretch/mode=canvas_items`、`aspect=expand`），
  窗口变小时 Canvas 整体缩放，所以 HUD 不会因分辨率变小而丢元素（三档截图已验证）。
- DPI 不是 viewport 尺寸：移动窗口会让 Godot 按 DPI 比例重设窗口（观测到 1920×1080 → 1600×900），
  脚本在进关后再校正一次客户区尺寸，`launch.json` 里 `client_after_resize` 与 `client_after_ch1` 都记录实际值。
- 截图文件尺寸 = 客户区尺寸（`hud_check.py` 断言），不是窗口外框、不是 DPI 虚拟坐标。

---

## F7：性能表按 `perf_t6_*.txt` 原日志纠正

口径：`001/tools/perf_slice.gd` 时间轴 4–10 s 采样，Vsync 关、`Engine.max_fps=0`；
`GPU_TIME_API=unavailable`（Godot 4.6 没有 GPU pass 计时 API）→ **只报 CPU 主线程帧时间与 vsync-off 上限 fps，
不定位瓶颈在 CPU/GPU**。以下数字逐行来自 `_review/playable_slice/perf_t6_*.txt`（9 份日志 9 行，全部纳入）：

| 场景 | 日志 | avg ms | p95 | p99 | 1% low ms | 1% low fps | max | 上限 fps | draw | prim | VRAM |
|---|---|---|---|---|---|---|---|---|---|---|---|
| ch1 出生点 | perf_t6_ch1_spawn | 2.56 | 2.78 | 2.78 | 2.84 | 352 | 3.31 | 390 | 108 | 397,994 | 772 MB |
| ch2 出生点 | perf_t6_ch2_spawn | 1.82 | 1.85 | 2.13 | 2.87 | 348 | 14.42 | 550 | 110 | 314,802 | 718 MB |
| ch3 出生点 | perf_t6_ch3_spawn | 1.55 | 1.67 | 1.85 | 2.10 | 476 | 5.88 | 643 | 107 | 537,293 | 686 MB |
| ch4 出生点 | perf_t6_ch4_spawn | 1.56 | 1.67 | 1.67 | 1.69 | 592 | 2.17 | 641 | 89 | 454,572 | 686 MB |
| ch1 Boss 激活 x=140 | perf_t6_ch1_boss_active | 2.69 | 2.78 | 3.03 | 3.60 | 278 | 6.99 | 372 | 121 | 876,660 | 772 MB |
| ch1 Boss 粒子节点关 | perf_t6_ch1_boss_vfxoff | 2.65 | 2.78 | 3.03 | 3.21 | 312 | 4.78 | 377 | 117 | 872,284 | 772 MB |
| ch1 竞技场 x=60 | perf_t6_ch1_arena | 2.52 | 2.78 | 2.78 | 3.27 | 306 | 6.85 | 396 | 139 | 1,065,149 | 772 MB |
| ch1 竞技场 粒子节点关 | perf_t6_ch1_arena_vfxoff | 2.08 | 2.24 | — | — | — | 9.35 | 481 | 136 | 1,087,693 | 772 MB |
| ch1 断桥 x=105 | perf_t6_ch1_bridge | 2.62 | 2.78 | 3.03 | 3.25 | 308 | 7.55 | 382 | 151 | 1,150,617 | 772 MB |

纠正点（相对 t6 报告）：

1. **纳入 arena 粒子关**：396.2 → 481.5 fps（**+21.5%**），t6 报告漏了这一行，只引用了 Boss 的 372→377。
2. **`vfxoff` 语义收窄**：只关 13 个 `GPUParticles3D`/`CPUParticles3D` 节点的 `emitting`+`visible`，
   **不是 CombatVFX 全关**（爆发特效的着色器/网格/Node3D 实例仍在），不能外推到"整章特效开销"。
3. **删除过强结论**："粒子不是瓶颈"删除；正确表述是"两场景对粒子节点开关的敏感度不同（Boss +1.3%，竞技场 +21.5%）"。
4. **删除"1% low 均 < 3.3 ms"**：实际最差是 Boss 3.60 ms（278 fps），arena 3.27 ms（306 fps）。
5. **1% low 单位写清**：原日志列是**帧时间 ms**，括号折算 fps；日志没有 p99/1% low 的格子留 `—`，不推算。
6. **删除不存在的尖峰**："ch4 首轮 90 ms"在 perf_t6 日志里没有（ch4 max=2.17 ms），已删。
7. **覆盖缺口写明**：四章只实测出生点；Boss/竞技场/断桥只有第一章，二至四章对应负载**未实测**。
8. 日志里 `SCENE_READY_MS≈11.3 s` 是探针固定等待窗口，不是"加载 11 秒"，README 只引用 `BUILD_MS 93–165 ms`。

---

## `.import` 数量与可恢复性（纠正）

- 当前状态项 **106 个**：**97 个 tracked 修改** + **9 个未跟踪新增资源**。
  （t6 报告/README 曾写"121 个已跟踪修改"是错的：121 是工作区 modified 总数，含脚本等；`final-review.md` 也指出过。）
- 恢复能力：
  - 97 个 tracked 的**原设置**可用 `git show HEAD:<path>` 取回；`baseline-t6/imports/head/` 存了字节副本，
    `baseline-t6/imports/diffs/` 是差异证据（不是原件）；
  - 9 个未跟踪新增资源**没有历史原版**，谈不上"恢复原设置"，只能保留现状（本轮未删任何资产）；
  - t1 基线只覆盖 9 个计划文件，**不包含** `.import`，不能声称"有 t1 基线可完美恢复"。
- 本轮没有执行 `git checkout -- 001/art` 或任何整目录回滚（遵守 captain 裁决）；106 个变更全部保留现状，
  其中 156 处为有意的 `size_limit=2048` / `compress/mode=2` / normal map 压缩设置，画面已在三档截图验证。

---

## 左缘裁切（F7 附带）

`ch1_bridge.png`（t6 之前）曾见提示贴屏幕左缘被裁；r2 包三档客户区截图（本目录 `*/ch1.png`）
**均未复现**。已把 README/包说明中的"已知瑕疵"改为"历史观察、当前未复现"，不再作为待修项。

---

## 本轮改动的文件（全部在允许范围内）

- 新增：`_review/playable_slice/verify_t7/launch_capture.py`、`hud_check.py`、`report.md`、
  `hud_check.json`、`negative_control.json`、`{1920x1080,1600x900,1280x720}/{menu,select,ch1}.png`、
  `*/launch.json`、`*/stdout.log`、`*/stderr.log`、`userlog/`；
- 更新：`README.md`（性能表/口径/`.import`/左缘裁切/真程序截图入口）、
  `builds/playable-slice/README-试玩包.md`（同上 + 验证清单）、
  `_review/playable_slice/export-fix-report.md`（性能表 9 行、口径、`.import` 106、左缘裁切）；
- 未改：任何 `001/**` 玩法脚本/场景/预设、`001/export_presets.cfg`、r2 exe 本体。
- 未提交、未推送；无 `git add`、无 `git checkout`、无删除源资产。

## 未解决/限制

- 无 GPU 计时 API：帧时间只代表 CPU 主线程吞吐，不能得出"GPU 富余/瓶颈"的结论。
- 四章高负载（Boss/竞技场/水面）只测了第一章；要覆盖全四章需再跑 8 次探针（每章约 12 s 固定窗口），本轮未做。
- 验证机是 150% DPI 的 2560×1600 屏；三档客户区截图由脚本强设，普通笔记本默认窗口尺寸未逐一截图。
