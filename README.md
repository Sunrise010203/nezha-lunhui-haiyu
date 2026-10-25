# 哪吒 · 轮回海域

Godot 4.6 制作的 2.5D 横版动作游戏（个人项目 · AI 辅助美术）。
目前包含**四章**：
1. 第一章「东海 碎潮回廊」
2. 第二章「龙宫深狱」
3. 第三章「归墟虚空 · 海眼」（新增：**混天绫摆荡 / 缠敌** + 海眼引力井 + 三核 Boss）
4. 第四章「龙骨沉殿 · 潮心」（新增：**G 定潮 / 卸 · 架 · 引潮** + 潮脉水流 + 潮纹碑）

四章**互相独立**，在选关界面自由选择；**四章场景刻意做成不同风格**：
第一章是青蓝的龙宫外廊（石柱、海草、水面），第二章是铁灰暗红的深海牢狱（铁栏、狱火），
第三章是**归墟虚空**——没有天空、没有水面、没有宫殿，只有黑色虚空、漂浮的封印石板、残骸与光柱。
第四章是**龙骨沉殿**——玉青 + 骨白 + 朽金，鲸骨拱、椎骨天顶、潮纹碑与缓慢流动的潮脉。

敌人共 9 种，各关阵容不同：
- 第一关：潮汐爬行者（地面巡逻/扑咬）、渊喉浮母（悬浮射击）、**分潮**（地面，死亡后裂成两只子体）
- 第二关：**狱卒**（举盾重甲，正面普攻免伤 65%，重击或背后才有效）、**囚晶**（固定炮台，预警后三连发）、渊喉浮母
- 第三关：**潮魇**（悬浮突进，预警后高速冲刺）、**渊爆水母**（贴身后引爆）、分潮
- 第四关：**潮生**（扑咬有 0.4s 起手，可被「架」）、潮魇、渊喉浮母、渊爆水母、分潮、囚晶、爬行者

---

## 模式

- **闯关模式**（主菜单「开始游戏」）：第一章 → 第二章 → 第三章 → 第四章连续闯关。
  - 初始只有 **Q 三昧真火**。
  - 每集满一章的 **3 枚龙魂残片**，解锁一个新技能：第一章 → **E 乾坤圈**，第二章 → **V 风火轮**（最多两个）。首章 E 的解锁条件保持原样：**本章残片集满 3 枚**，不改收集系统。
  - 章节奖励每章只发一次（重打同一章不会刷技能）。
  - **死亡规则（闯关）**：任意一章死亡后弹出「命陨潮渊」，选「重新挑战本章」= **本章整章重来**：从本章出生点重新开始，本章进度/残片/临时战斗状态清零，**已解锁技能保留**，不会退回第一章。
- **选关模式**（主菜单「选择关卡」）：全部技能解锁，四章独立任选；**死亡后在当前关莲台复活**，已激活的莲台与当前灵力保留。

## 灵力与恢复

- 上限 100。消耗：Q 真火 50、E 乾坤圈 25、V 风火轮 60、引潮 20。
- **缓慢恢复**：脱战 **3 秒**后开始，每秒恢复 `MAX_ENERGY` 的 **5%**（5 点/秒）。受击、攻击、施法都会立刻重置这 3 秒延迟；**暂停与死亡期间不恢复**。
- 莲台/检查点复活**保留当前灵力值**（不回满），只清除临时战斗状态（冲刺、蓄力、飞行中的乾坤圈、场景内临时特效等）。
- 首次进关会在出生点附近显示**一次性输入教学**（A/D 移动、空格跳跃、Shift 冲刺、J/K 攻击、E 乾坤圈），不阻塞操作。

## 运行

```powershell
# 编辑器打开
& 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe' --path 'E:\godot_game_by_fable\001' -e

# 直接运行
& 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe' --path 'E:\godot_game_by_fable\001'
```

- 启动即为 1920×1080 窗口；**F11** 切换全屏。
- 流程：主菜单 →（开始游戏：序章三页，可跳过）→ **闯关模式第一章**；主菜单「选择关卡」直接进选关界面。
- 死亡规则见上文「模式」：闯关模式=整章重来，选关模式=当前关莲台复活；暂停里的「重新挑战本关」只重开当前这一关。
- 通关记录保存在 `user://progress.cfg`：记录"哪章已通关 + 每章最快通关时间"，选关界面会显示「✓ 已通关 · 最快 MM:SS」。

## 操作

| 操作 | 键位 |
|---|---|
| 移动 | A / D 或 ← / → |
| 跳跃（二段跳） | 空格 / W / ↑ |
| 冲刺（瞬身无敌） | Shift / L |
| 连击 | J / 鼠标左键 |
| 重击 / 空中下砸 | K / 鼠标右键 |
| 乾坤圈（25 灵力） | E / I（闯关模式集满第一章龙魂后解锁）—— 按住蓄力 1 秒：距离 8.5→16.5、伤害 16→25，命中普通敌人定身 0.5s（Boss 免疫）；点按为原版效果 |
| 三昧真火（50 灵力） | Q / U（闯关模式初始技能） |
| **风火轮（60 灵力）** | **V / C** —— 向上腾空到很高；腾空期间按 K 下砸，伤害翻倍（24→48）（闯关模式集满第二章龙魂后解锁） |
| **混天绫（第三章）** | **F / R** —— 抓铜环摆荡；**松手后 0.35 秒内再按 F** 可换到下一个铜环（连抓）；对敌使用则拉近并定身 |
| **定潮（第四章）** | **G / T** —— 点按：架起潮纹，把飞来的潮弹「卸」回去 / 把带起手的近战「架」住；按住 0.2 秒：**引潮**，把周围潮弹吸过来再齐射出去（耗 20 灵力）。需要潮纹：打中敌人才攒，满 3 格 |
| 暂停 | Esc |
| 全屏切换 | F11 |

## 目录

```
001/
├─ autoload/game.gd        全局单例：输入、音频、转场/加载屏、材质与特效工厂、特效预热
├─ scripts/
│  ├─ level_base.gd        关卡基类：环境/地形积木/装饰/检查点/竞技场/Boss 流程/生死循环
│  ├─ level_1.gd           第一章编排（地形 + 装饰 + 遭遇战）
│  ├─ level_2.gd           第二章编排 + 狱火喷口机关
│  ├─ level_3.gd           第三章编排 + 混天绫锚点 / 海眼引力井
│  ├─ level_4.gd           第四章编排 + 潮脉 / 潮纹碑 / 两处竞技场
│  ├─ boss_maw.gd          第一章 Boss「归墟之喉 · 渊狱兽」
│  ├─ boss_warden.gd       第二章 Boss「棘狱守卫」
│  ├─ boss_sea_eye.gd      第三章 Boss「归墟海眼」三核 → 巨瞳二阶段
│  ├─ boss_chiwen.gd       第四章 Boss「潮心 · 螭吻」三段 100×3
│  ├─ enemy_spawnling.gd   潮生：带 0.4s 起手的近战（第四章，可被「架」）
│  ├─ tide_stele.gd        潮纹碑：被卸回的潮弹照亮，点亮后掉灵力
│  ├─ swing_anchor.gd      混天绫摆荡锚点（龙宫铜环）
│  ├─ player.gd            玩家：移动/二段跳/冲刺/三连击/重击/下砸/三个技能/混天绫/程序化骨骼动画
│  ├─ enemy_base.gd        敌人基类（生命/受击/击退/灼烧/束缚/坠渊判定/轮廓光）
│  ├─ enemy_crawler.gd     潮汐爬行者（第一关）
│  ├─ enemy_shooter.gd     渊喉浮母（第一/二关）
│  ├─ enemy_divider.gd     分潮：死亡后分裂（第一/三关）
│  ├─ enemy_guard.gd       狱卒：举盾重甲（第二关）
│  ├─ enemy_turret.gd      囚晶：固定炮台（第二关）
│  ├─ enemy_wraith.gd      潮魇：悬浮突进（第三关）
│  ├─ enemy_bomber.gd      渊爆水母：自杀爆炸（第三关）
│  ├─ hud.gd               战斗 HUD（技能解锁/锁定）/ 暂停 / 死亡 / 胜利
│  ├─ player_camera.gd     侧视跟随相机（Boss 战双目标取景）
│  ├─ level_select.gd      选关模式（全技能 + 通关标记 + 最快时间）
│  ├─ projectile.gd / ring_throw.gd / pickup.gd / breakable.gd / falling_platform.gd
│  └─ audio_synth.gd       程序化音效合成器（离线烘焙用）
├─ scenes/                 七个场景都是"根节点 + 脚本"，内容由脚本构建
├─ shaders/                天空 / 水面 / 晕影 / 菜单特效 / 轮廓光 / 远景贴片淡出
├─ audio/                  离线烘焙好的音效资源（*.res）
├─ art/                    AI 生成美术（GLB 模型 / 立绘 / 背景 / 贴图）
└─ tools/                  开发工具脚本（见下）
```

## 工具（`001/tools/`）

```powershell
$G='E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'

# 1) 重新烘焙音效（改了 audio_synth.gd 的参数后执行一次）
& $G --headless --path 'E:\godot_game_by_fable\001' --script res://tools/bake_audio.gd

# 2) 截图（真实渲染器）：场景 / 输出路径 / 传送 x / 等待帧数 / normal|boss
& $G --path 'E:\godot_game_by_fable\001' --script res://tools/capture.gd -- `
    res://scenes/level_1.tscn 'E:\godot_game_by_fable\_shots\shot.png' 30 260 normal

# 3) 性能复测（旧探针：构建耗时 / 规模 / draw call / 三角形 / 显存 / 帧时间）
& $G --path 'E:\godot_game_by_fable\001' --script res://tools/perf_probe.gd -- `
    res://scenes/level_1.tscn

# 4) 可玩样板性能采样（本文件下方「性能基线」就是它跑出来的）：
#    时间轴采样 4–10s，输出 avg/p50/p95/p99/1% low/max、BUILD_MS、draw/prim/VRAM
#    参数：场景 x(传送坐标，-9999=不传送) 标签 [flags，可含 vfxoff]
& $G --path 'E:\godot_game_by_fable\001' --resolution 1920x1080 --position 0,0 `
    --script res://tools/perf_slice.gd -- res://scenes/level_1.tscn 140 ch1_boss_active

# 5) 玩法回归（74 条断言：落水/死亡菜单/灵力恢复/输入教学/存档字段等）
& $G --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_gameplay_states.gd
& $G --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_ch1_hybrid.gd

# 6) 第四章自动走查（分段落地 / 竞技场 / 碑 / 敌人数 / Boss 三阶段 / 弹反 / 死亡重置）
& $G --headless --path 'E:\godot_game_by_fable\001' res://tools/probe_ch4.tscn
```

## 当前性能基线（2026-10-22 实测 · RTX 5070 Laptop · D3D12 Forward+ · 1920×1080 · VSync 关闭）

口径：`tools/perf_slice.gd` 时间轴采样 4–10 s（物理 60 Hz，渲染不锁帧）；下表是**CPU 主线程帧时间与上限 fps**，
`GPU_TIME_API=unavailable`——Godot 4.6 没有公开的 GPU pass 计时 API，因此不能把下表当成 GPU 耗时，也不能据此定位瓶颈在 CPU 还是 GPU。
"1% low" = 最差 1% 帧的平均**帧时间（ms）**，同列括号内给出等价 fps（=1000/ms）；"加载"= `BUILD_MS`（从启动到关卡可操作，本机热缓存）。
表内每一行都可在同目录 `_review/playable_slice/perf_t6_*.txt` 原日志中逐项核对。

| 场景 | avg | p50 | p95 | p99 | 1% low (ms / fps) | max | 上限 fps | draw | 三角形 | 显存 |
|---|---|---|---|---|---|---|---|---|---|---|
| 第一章出生点 | 2.56 ms | 2.50 | 2.78 | 2.78 | 2.84 / 352 | 3.31 | 390 | 108 | 39.8 万 | 772 MB |
| 第二章出生点 | 1.82 ms | 1.85 | 1.85 | 2.13 | 2.87 / 348 | 14.42 | 550 | 110 | 31.5 万 | 718 MB |
| 第三章出生点 | 1.55 ms | 1.52 | 1.67 | 1.85 | 2.10 / 476 | 5.88 | 643 | 107 | 53.7 万 | 686 MB |
| 第四章出生点 | 1.56 ms | 1.52 | 1.67 | 1.67 | 1.69 / 592 | 2.17 | 641 | 89 | 45.5 万 | 686 MB |
| 第一章 Boss 激活（x=140） | 2.69 ms | 2.78 | 2.78 | 3.03 | 3.60 / 278 | 6.99 | 372 | 121 | 87.7 万 | 772 MB |
| 第一章 Boss · 粒子节点关 | 2.65 ms | 2.78 | 2.78 | 3.03 | 3.21 / 312 | 4.78 | 377 | 117 | 87.2 万 | 772 MB |
| 第一章竞技场（x=60，刷怪） | 2.52 ms | 2.38 | 2.78 | 2.78 | 3.27 / 306 | 6.85 | 396 | 139 | 106.5 万 | 772 MB |
| 第一章竞技场 · 粒子节点关 | 2.08 ms | 2.08 | 2.24 | — | — | 9.35 | 481 | 136 | 108.8 万 | 772 MB |
| 第一章断桥水面（x=105） | 2.62 ms | 2.78 | 2.78 | 3.03 | 3.25 / 308 | 7.55 | 382 | 151 | 115.1 万 | 772 MB |

- 加载：`BUILD_MS` 111–165 ms（第一章 165 ms，第四章 128 ms）；这是脚本化关卡构建时间，不含引擎/着色器预热。
- 粒子对照（`vfxoff` 只把 13 个 `GPUParticles3D`/`CPUParticles3D` 节点的 `emitting` 与 `visible` 置 false，**不是 CombatVFX 全关**：爆发特效的着色器/网格/`Node3D` 特效实例仍在）：
  - Boss 场景：372 → 377 fps（+1.3%），1% low 3.60 → 3.21 ms，变化在噪声量级；
  - 竞技场：396 → 481 fps（**+21.5%**），是全部采样里最大的粒子相关差异；
  - 结论只能是"这两个场景对 13 个粒子节点的开关敏感度不同"，**不能**推广为"粒子不是瓶颈"，也不等同于整章特效开销结论。
- 单帧尖峰：第二章 14.4 ms、竞技场粒子关 9.35 ms 属首次资源/着色器上载或 GC，稳定后回落；1% low 最差为 Boss 3.60 ms（278 fps）。
- **覆盖缺口**：四章只实测了出生点；Boss 激活 / 竞技场刷怪 / 断桥水面只有第一章，第二至四章的这些负载**未实测**，不得外推。
- 历史表格（≈88/92/75/82 draw、21/14/29/33 万三角形、610/546/610/788 MB）来自旧探针口径，**不可与上表直接对比**。

## 模型与动画现状

- 玩家：`art/models/nezha_arp.glb`（ARP 绑定），由 `scripts/nezha_motion.gd` 重定向 14 个动画剪辑：
  `Idle / FightIdle / Run / Jump / Fall / Plunge / Land / Roll / Stab / Slash / ThrustSlash / UpwardThrust / Hit / Death`。
- 动作映射：atk1→Stab、atk2→Slash、atk3→ThrustSlash、重击→UpwardThrust、受击→Hit、死亡→Death；
  循环剪辑 Idle/FightIdle/Run/Fall，其余按 DURATIONS（0.30–1.0 s）覆盖播放。
- 移动、命中窗口、无敌帧仍由 `player.gd` 逻辑控制，动画只负责表现；武器挂点用 GRIP/GRIP_FRAMES 做逐帧校姿。
- 敌人/Boss 用 `enemy_motion.gd` / `boss_motion.gd` 的程序化骨骼摆动（无外部动画剪辑）。

## 导出与试玩包

`001/export_presets.cfg` 已存在：Windows Desktop / x86_64 / `embed_pck=true`，产物写到 `builds/playable-slice/`。

```powershell
$G='E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
# 需要 4.6.3.stable 的导出模板：%APPDATA%\Godot\export_templates\4.6.3.stable\
& $G --headless --path 'E:\godot_game_by_fable\001' --export-release "Windows Desktop" `
    'E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable.exe'
```

- `builds/` 是导出产物目录、**不入库**（2026-10-25 清理时已删除，需要时按上面的命令重新导出），清理清单见 `CLEANUP-REPORT.md`。
- 包内已含第一章远景贴图 `res://art/ref/ch1_palace_far.png`；若打包过滤误删，`ch1_ruins.gd` 会 `push_error` 并退化为水下雾色渐变（不会再出现白色矩形）。
- 导出过滤只排除开发专用资源（`tools/*`、`*.py`、showcase 场景/脚本、`art/models/glb_game/*`、`art/tmp/*`、`art_source/*`、`_artgen/*`），不删除源资产。
- 模型贴图 `.import` 本轮共 106 个状态项：**97 个 tracked 修改**（原设置可从 `git show HEAD:<path>` 取回）＋ **9 个未跟踪新增资源**（本来就没有历史版本，谈不上"恢复原设置"）。只改导入参数（`size_limit=2048` / `compress/mode=2` / normal map 压缩），源 PNG/GLB 未动；`baseline-t6/imports/diffs` 是差异证据，不是原始副本。
- 真程序 HUD 截图方法（客户区精确尺寸 + 真实点击，不裁图）：`_review/playable_slice/verify_t7/launch_capture.py`，见该目录 `report.md`。

## 已知未做（下一步可继续）

- 关卡内进度存档（只保存"哪章已通关 + 最快时间"，检查点/残片仍只在内存）
- 设置页（音量总线、分辨率、按键改绑）与手柄支持
- 战斗数值平衡（灵力经济、攻击缓冲等仍按当前数值）
- 键位提示贴左缘裁切：这是 t6 之前 1920×1080 截图的历史观察；r2 包在 1920×1080 / 1600×900 / 1280×720 三档客户区截图（`verify_t7/`）**均未复现**，暂不作为现存缺陷
- 导出模板不随仓库提供，换机需按官方 4.6.3.stable 模板安装到 `%APPDATA%\Godot\export_templates\`
