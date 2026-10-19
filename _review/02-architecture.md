# 《哪吒·轮回海域》代码架构 / Godot 工程规范 / 技术债评审

- 评审对象：`E:\godot_game_by_fable\001`（Godot 4.6.3 stable，Forward+，Jolt Physics，D3D12，1920×1080）
- 评审方式：**只读静态审查**。不运行 Godot、不修改项目任何文件、不初始化 git 仓库。
- 行号口径：本报告行号以 `[IO.File]::ReadAllLines()` 的结果为准（与编辑器、ripgrep 一致）。例：`player.gd` 1083 行、`level_1.gd` 1147 行、`hud.gd` 542 行、`boss_maw.gd` 517 行。注意：部分统计工具（如本机 PowerShell `Get-Content | .Count`）会少统计 2% 左右（`player.gd` 会报 1056 行），引用行号时不要用那套数字。
- 总览：16 个 GDScript 文件、5300 行；3 个 `.tscn`；5 个 shader；1 个 Theme；0 个第三方插件；美术 80.1 MB。

**一句话结论**：这是一个"可玩性已完成、工程成熟度仍停在原型后期"的项目。画面、手感、内容完整度都不像原型，但**版本控制、场景化、模块边界、发布配置**这四块是空的——继续叠加第二章/新敌人之前，先把这四块补上，否则每次迭代的边际成本会指数上升。

---

## 0. 事实核查（先确认"有没有"）

| 检查项 | 结论 | 证据 |
|---|---|---|
| 引擎/渲染 | Godot 4.6.3、Forward+、Jolt、D3D12 | `project.godot:15` `config/features=...("4.6","Forward Plus")`；`project.godot:36` Jolt；`project.godot:40` d3d12 |
| 脚本规模 | 16 个 `.gd`，5300 行；最大的 4 个文件占 62% | `player.gd` 1083、`level_1.gd` 1147、`hud.gd` 542、`boss_maw.gd` 517 |
| 场景 | 3 个 `.tscn`，全部只有"根节点 + 脚本"，没有任何子节点 | `scenes/level_1.tscn:5-6`、`scenes/main_menu.tscn:5-12`、`scenes/intro.tscn:5-12` |
| 预制体/PackedScene | 游戏代码中 **0 个** `PackedScene` 类型声明、**0 个** `preload()`、**0 个** `@export` | 全库 grep；只有 `autoload/game.gd:35-38` 为了加载 GLB 用了 `load(path) as PackedScene` |
| 输入映射 | `project.godot` 无 `[input]` 段（全文仅 42 行），9 个 action 全部在运行时注册 | `project.godot:1-42`；`autoload/game.gd:90-91`、`110-136` |
| 版本控制 | **无 `.git`**（`E:\godot_game_by_fable\.git`、`001\.git` 均不存在），但 `.gitignore`/`.gitattributes` 已备好 | `001\.gitignore:1-3`、`001\.gitattributes:1-2` |
| 导出预设 | **无 `export_presets.cfg`**，无 `build/`，无版本号字段 | 项目根目录；`project.godot:13-16` 无 `application/config/version` |
| README / 文档 | **无**（项目内 0 个 `.md`），只有 `art/chroma_key.py` 的脚本注释 | 全目录 |
| 测试 / CI | **无** tests、无 `addons/`（GUT/GdUnit 均未装）、无 `.github/` | 目录扫描 |
| 存档 / 设置 / 多语言 | **无**：0 处 `user://`、0 处 `ConfigFile`、0 处 `tr()` | 全库 grep |
| 美术体量 | 80.1 MB：`art/raw` 14.5（源图，重复）、`art/sprites` 7.7、`art/models` 31.6（4 个 GLB） | 磁盘统计 |
| 已有资产使用率 | 4 个 `art/sprites/*_3d.png`（3.26 MB）在代码中 0 引用；`nezha_jump.png`、`crawler_lunge.png` 被代码请求但**文件不存在** | 见 A-12/A-19 |
| 退出泄漏 | 本次评审**未运行 Godot**，无法复现确认；静态排查与复核步骤见 A-21 | — |
| 说明 | 工作区根目录的 `001\_dsh_probe.gd` 是评审用临时探针，**不属于项目代码**，提交前应删除 | `_dsh_probe.gd:1-2` |

---

## 1. 发现清单

优先级/工作量速览：

| 编号 | 标题 | 优先级 | 工作量 |
|---|---|---|---|
| A-01 | 没有版本控制——当前最大的工程风险 | P0 | 小 |
| A-02 | 没有导出预设，无法产出可分发包 | P0 | 小 |
| A-03 | 整个游戏用代码建场景，3 个 `.tscn` 都是空壳 | P0 | 大 |
| A-04 | 必须场景化的对象清单与场景骨架 | P0 | 中 |
| A-05 | `Game` 单例承担 9 类职责，被全部 15 个脚本引用 305 处 | P0 | 中 |
| A-06 | 输入映射在 `_init()` 运行时注册，不进 `project.godot` | P0 | 小 |
| A-07 | 玩家状态机用 `act: String` + 散落变量 | P0 | 中 |
| A-08 | 跨类访问"私有"字段（HUD 读 `player._ring_out` 等） | P1 | 小 |
| A-09 | 敌人基类与"GLB→精灵→程序化网格"三级兜底复制 4 份 | P1 | 中 |
| A-10 | 伤害/速度/坐标/颜色/层号硬编码分散 | P1 | 中 |
| A-11 | `player.gd`、`level_1.gd` 体量远超单文件合理规模 | P1 | 大 |
| A-12 | 运行期 `load()` + `ResourceLoader.exists` 探测，缺失资产静默降级 | P1 | 中 |
| A-13 | `await`/场景切换生命周期与 Tween/`queue_free` 竞争 | P1 | 中 |
| A-14 | 无存档：检查点、`souls`、`death_count` 全在内存 | P1 | 小 |
| A-15 | 无设置项（音量/分辨率/画质/按键） | P1 | 小 |
| A-16 | 无自动化测试、无 CI | P1 | 中 |
| A-17 | UI/文字依赖 Windows 系统字体（`SystemFont`） | P1 | 小 |
| A-18 | 无多语言，全中文硬编码在 Label 里 | P2 | 中 |
| A-19 | AI 资产管线与程序化兜底并存，缺清单与校验 | P2 | 中 |
| A-20 | 类型标注/命名/魔法数字一致性 | P2 | 小 |
| A-21 | `ObjectDB instances leaked at exit` 诊断（未运行，给复核方案） | P2 | 小 |
| A-22 | 其他小问题合集（死代码/键帽硬编码/逻辑瑕疵） | P2 | 小 |

---

### A-01 没有版本控制——当前最大的工程风险

- **位置**：`E:\godot_game_by_fable\.git` 不存在、`001\.git` 不存在；`001\.gitignore:1-3`、`001\.gitattributes:1-2` 已存在但从未 `git init`
- **问题**：5300 行代码 + 80 MB 资产，没有任何历史记录。作者是"个人开发者 + AI 辅助"，这种工作流最常见的事故是：让 AI "优化一下 player.gd"，它整文件重写，改坏了某段判定，而**没有任何东西能告诉你改了什么、也回不去**。`.gitignore` 和 `.gitattributes` 都已写好，说明这步本来打算做，只是没执行。
- **后果**：
  1. 无法回滚：一次误删/误覆盖（尤其 `art/`、`scenes/`）不可恢复；
  2. 无法定位回归：手感/数值改了以后说不清是哪次改的，没有 `git bisect`；
  3. 无法分支试验：新武器、新 Boss、第二章只能"在主分支上直接改"；
  4. 无法导出/CI：`export_presets.cfg` 与 CI 都依赖 VCS，A-02/A-16 无法落地；
  5. 无法安全重构：本报告建议的大规模拆分（A-03/A-11）在没有版本控制时**不应该开始**。
- **重构方案**：立即在仓库根初始化（本次评审按要求**不执行**，只给命令）。注意 `.godot/` 必须忽略、`*.import` 与 `*.uid` 必须提交（Godot 4.4+ 的 `.gd.uid` 是资源引用稳定性的关键，本项目 `scripts/*.gd.uid` 已在）：

```powershell
cd E:\godot_game_by_fable
git init
# 根级 .gitignore（001/.gitignore 只覆盖 001/ 子树，截图/评审文件要放根级）
@'
/_review/
/game_shot*.png
/shot_*.png
/nezha_*.png
/ref_*.png
/001/.godot/
/001/build/
/001/art/raw/
'@ | Set-Content .gitignore -Encoding utf8
git add -A
git commit -m "chore: 重构前快照（5300 行 GDScript + 80MB 资产）"
git tag baseline-pre-refactor
```

  补充两条针对本项目的事实：
  - 资产 80 MB，其中 `art/raw`（14.5 MB）是 `art/sprites` 的源图、`art/models`（31.6 MB）是 4 个 GLB。建议 `git lfs track "*.glb" "*.blend" "*.png"`，否则 clone/push 会很难受；至少把 `art/raw` 移出仓库或用 LFS。
  - `001/.gitignore` 里的 `.godot/` 写法只对 `001` 子树生效，放在根仓库时截图/临时文件仍需根级 `.gitignore`（如上）。
- **优先级**：P0　**工作量**：小（10 分钟）

---

### A-02 没有导出预设，无法产出可分发包

- **位置**：项目根目录无 `export_presets.cfg`；`project.godot:13-16`（只有 `config/name`、`run/main_scene`、`config/features`、`config/icon`，**无 `application/config/version`**）；无 `build/`
- **问题**：项目能跑，但只能"在编辑器里跑"。没有任何平台导出配置：目标平台、架构、导出模板、嵌入 PCK、图标、产品名/版本号、文件描述、rcedit 元数据、纹理压缩格式全部未设置。
- **后果**：
  1. 不能给任何人一个双击即玩的 `exe`（投资人、玩家、朋友试玩都只能装 Godot 编辑器）；
  2. 无法做"每次改动都出包"的迭代节奏，也无法在 Steam/itch 上架；
  3. 一旦临时补配置，会连踩：导出模板未下载、图标格式、`application/config/name` 含 `·` 与中文导致的控制台/文件名问题、`art/raw` 被一起导出（+14.5 MB）、`SystemFont` 在目标机上缺字体（A-17）等一串坑；
  4. 无版本号 → 无法标注"这是第几版"，反馈无法定位。
- **重构方案**：加 `export_presets.cfg`（Windows Desktop 为例）+ 版本号，并让 CI 使用同一条命令：

```ini
; export_presets.cfg（放 001/ 项目根，提交进仓库；不要提交 build/）
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="art/raw/*"
export_path="build/nezha_wheel.exe"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
application/product_name="哪吒·轮回海域"
application/file_description="2.5D 动作游戏 · 第一章"
application/product_version="0.1.0.0"
application/file_version="0.1.0.0"
application/icon="res://icon.svg"
application/console_wrapper_icon=""
```

```ini
; project.godot [application] 段补充
config/version="0.1.0"
```

```powershell
# 本机与 CI 同一条命令（先要在编辑器里装一次 Export Templates）
godot --headless --path 001 --export-release "Windows Desktop" build/nezha_wheel.exe
```

  验收：`build/nezha_wheel.exe` 双击可玩、窗口标题/图标/产品名正确、体积 ≈（资源 80 MB − raw 14.5 MB − 未引用 3.3 MB + 引擎）且不包含 `.gd` 源码（release 模板）。
- **优先级**：P0　**工作量**：小（半天，主要卡在导出模板下载）

---

### A-03 整个游戏用代码建场景，3 个 `.tscn` 都是空壳

- **位置**：
  - `scenes/level_1.tscn:5-6`（`[node name="Level1" type="Node3D"]` + script，无语境内容）
  - `scenes/main_menu.tscn:5-12`、`scenes/intro.tscn:5-12`（`Control` 根 + 脚本，UI 也全是 `new` 出来的）
  - 构建代码：`scripts/level_1.gd:51-65`（`_ready` 里依次 `_build_environment/_build_water/_build_player_and_camera/_build_hud/_build_terrain/_build_decor/_build_enemies_and_logic/_build_boss_arena`）、`100-165`（Environment/Sky/Sun/Water）、`170-219`（Player/Camera/HUD）、`224-390`（地形）、`394-675`（装饰）、`686-856`（莲台/封印门/触发区）、`861-896`（敌人）、`927-937`（Boss）；`scripts/main_menu.gd:25-201`；`scripts/intro.gd:33-115`；`scripts/hud.gd:41-334`
- **问题**：项目里**没有任何可复用的场景单元**。打开 `level_1.tscn` 只能看到一个空 `Node3D`；所有对象（WorldEnvironment、平行光、水面、26 根断柱、30 株海草、10 个瓮、12 块浮岩、玩家、相机、HUD、敌人、Boss、封印门、莲台、传送门……）都是 `_ready()` 里 `Node.new()` + 逐个赋属性。
- **后果**（按影响排序）：
  1. **没有编辑器可视化迭代**。改一个坐标（例如把 `scripts/level_1.gd:360` 的尖刺从 78.5 挪到 80）必须改代码、重跑、从头走到那个位置验证。2.5D 动作游戏恰恰是最吃"摆位手感"的类型，现在的迭代循环是"改代码 → 重启 → 玩到那里"，而不是"在视口里拖着看"。
  2. **无法做动画/粒子预制**。Godot 的 `AnimationPlayer`/`AnimationTree` 需要场景里的节点树与关键帧；本项目的动作全靠手写 Tween（`scripts/player.gd:923-947`、`936-947`）与程序化骨骼（`780-885`、`888-900`），没有可复用的动画片段。粒子参数全部硬编码（`autoload/game.gd:252-267`、`scripts/player.gd:321-337`、`scripts/level_1.gd:189-209`、`800-822`、`989-1012`、`scripts/boss_maw.gd:132-153`、`scripts/enemy_crawler.gd:90-110`、`scripts/ring_throw.gd:38-58`），无法在编辑器里实时调 `amount/lifetime/gravity/color_ramp`。
  3. **美术替换成本高**。模型尺寸/朝向/底部对齐以魔数形式写死：`scripts/player.gd:95`（1.9 m / 90°）、`scripts/enemy_crawler.gd:36`（1.1 / 180°）、`scripts/boss_maw.gd:53`（4.4 / 180°）、`scripts/enemy_shooter.gd:36`（1.6 / 0°）；骨骼名以字符串写死在 `scripts/player.gd:791-884`（`"upper_arm.R"`、`"chest"`、`"hips"`、`"shin.L"`…）。换一个模型或换一套骨架，就要改代码并祈祷尺寸对得上。美术也无法"只换模型"（不知该改哪、改完要重编译）。
  4. **无法被美术/策划独立编辑**。没有场景就没有职责边界：所有布局/数值/材质在代码里，只有作者 + AI 能动。这正是"个人开发者 + AI"最容易失控的地方——所有东西都汇聚到同一个人与同一批文件。
  5. **无法做场景继承/变体**。Boss 二阶段换场地、第二章复用装饰、试玩版裁掉一段关卡，都没有 `PackedScene` 可以继承/覆盖；`get_node()` 全项目 0 使用（节点引用全靠成员变量），跨场景复用必须改代码。
  6. **加载集中在 `_ready()`**。`level_1.gd` 一次性构造数百个节点（26 根断柱、30 株海草、12 块浮岩、3 组灵尘、鱼群、鲸鱼、10 个瓮、8 个敌人…）并做 100+ 次材质创建，进入关卡的卡顿无法拆分成"预加载 + 流式"。
  7. **编辑态不可保存**。所有对象 `owner == null`，无法 `Save Branch as Scene`；运行期调试出来的好摆位无法回存到场景。
- **重构方案**：确立一条原则——**"角色/可交互物/UI 一律用 `.tscn`；只有数量大、重复性强、纯装饰的几何（地形段、碎石、海草、鱼群）保留程序化生成"**。目录与场景骨架：

```
001/
  scenes/
    levels/level_1.tscn          # 手工编排：环境、地形根、装饰根、Gameplay 物件、Boss/玩家/相机/HUD 实例
    actors/player.tscn
    actors/enemy_crawler.tscn
    actors/enemy_shooter.tscn
    actors/boss_maw.tscn
    actors/projectile.tscn
    actors/ring_throw.tscn
    props/checkpoint_lotus.tscn
    props/seal_gate.tscn
    props/breakable_urn.tscn
    props/falling_platform.tscn
    props/pickup_energy.tscn / pickup_heal.tscn / pickup_soul.tscn
    props/return_portal.tscn
    props/hint_label.tscn
    vfx/vfx_ambient_motes.tscn / vfx_seal_particles.tscn / vfx_portal_particles.tscn
    ui/hud.tscn
    ui/environment_sea.tscn
    cameras/player_camera.tscn
  scripts/                      # 只放逻辑，不再建节点树
  resources/
    visual/*.tres               # VisualProfile（见 A-09）
    balance/*.tres              # 数值（见 A-10）
    level/level_1_config.tres   # 关卡参数（见 A-10）
```

  `level_1.tscn` 的目标结构（用编辑器搭，这里只是结构示意）：

```
Level1 (Node3D, level_1.gd ≈ 150 行：只做流程编排)
├─ Environment (WorldEnvironment)
├─ Sun (DirectionalLight3D) / Fill (DirectionalLight3D)
├─ Water (MeshInstance3D, ShaderMaterial)
├─ TerrainRoot (Node3D)      ← level_terrain.gd 程序化生成（保留代码）
├─ DecorRoot (Node3D)        ← level_decor.gd 程序化生成（保留代码）
├─ Gameplay (Node3D)         ← 手工摆：莲台 ×3、瓮 ×10、浮桥 ×4、拾取物 ×6、封印门 ×2、提示 Label3D ×8
├─ Enemies (Node3D)          ← enemy_crawler.tscn / enemy_shooter.tscn 实例
├─ Boss (boss_maw.tscn 实例)
├─ Player (player.tscn 实例)
├─ Camera (player_camera.tscn 实例)
└─ HUD (hud.tscn 实例)
```

  `player.tscn` 结构示意（对应 A-09/A-11）：

```
Player (CharacterBody3D, player.gd)
├─ CollisionShape3D (CapsuleShape3D)
├─ VisualMount (Node3D, actor_visual.gd)        # 运行时按 VisualProfile 挂 GLB/精灵/程序化网格
│   └─ ModelSlot (Node3D)
├─ Speaker (AudioStreamPlayer3D)
└─ HitboxPivot (Node3D, player_hitbox.gd)
```

  落地顺序建议（每一步都可独立验证）：① 先把 Player、HUD、Camera 场景化（改动面最大但收益最高）；② 再把敌人/Boss 场景化；③ 再把 6 类 props 场景化；④ 最后把 `level_1.tscn` 从"空壳"变成"手工编排 + 两个 builder 生成装饰"。
- **优先级**：P0　**工作量**：大（3–5 天，建议在 git 快照后分步做）

---

### A-04 必须场景化的对象清单与参数暴露

- **位置**：以下对象目前在代码中 `new` 出来；场景化后应把对应参数改成 `@export`（在 .tscn/.tres 里可视化编辑）

| 对象 | 当前代码位置 | 目标场景 | 需要 `@export` 的参数（现在写死在代码里） |
|---|---|---|---|
| 玩家 | `scripts/level_1.gd:171-174`、`scripts/player.gd:74-86` | `scenes/actors/player.tscn` | `stats: PlayerStats`（HP/速度/跳跃/冲刺/技能消耗）、`visual: VisualProfile` |
| 潮汐爬行者 | `scripts/level_1.gd:861-868`、`scripts/enemy_crawler.gd:17-24` | `scenes/actors/enemy_crawler.tscn` | `profile: EnemyProfile`（HP 55/接触 12/速度 4.2）、`patrol_min/patrol_max` |
| 渊喉浮母 | `scripts/level_1.gd:871-878`、`scripts/enemy_shooter.gd:16-25` | `scenes/actors/enemy_shooter.tscn` | HP 40/射速/保持距离 4–8、`range_min/range_max` |
| 归墟之喉 | `scripts/level_1.gd:928-933`、`scripts/boss_maw.gd:36-43` | `scenes/actors/boss_maw.tscn` | HP 480、`arena_min_x/arena_max_x/ground_y`、`profile: BossProfile` |
| 莲台检查点 | `scripts/level_1.gd:686-754` | `scenes/props/checkpoint_lotus.tscn` | `id: int`、`start_active: bool`、`is_boss_checkpoint: bool` |
| 封印门 | `scripts/level_1.gd:776-825` | `scenes/props/seal_gate.tscn` | `height`、材质/颜色 |
| 可碎瓮 | `scripts/level_1.gd:448-458`、`scripts/breakable.gd:8-42` | `scenes/props/breakable_urn.tscn` | `drop_heal: bool`、掉落表 |
| 碎裂浮桥 | `scripts/level_1.gd:364-368`、`scripts/falling_platform.gd:15-56` | `scenes/props/falling_platform.tscn` | `width`、`shake_time/fall_delay/respawn_time` |
| 拾取物 ×3 | `scripts/level_1.gd:679-683`、`scripts/pickup.gd:13-75` | `scenes/props/pickup_{energy,heal,soul}.tscn` | `kind`、`amount`（12/25/1）、贴图/颜色 |
| 归途之门 | `scripts/level_1.gd:972-1031` | `scenes/props/return_portal.tscn` | 半径、目标场景 |
| 3D 提示文字 | `scripts/level_1.gd:663-674` | `scenes/props/hint_label.tscn` | `text`（或 `text_key`）、字号、颜色 |
| HUD | `scripts/level_1.gd:213-219`、`scripts/hud.gd:41-197` | `scenes/ui/hud.tscn` | 全部 UI 布局/锚点/主题覆盖 |
| 敌投射物 | `scripts/projectile.gd:11-40` | `scenes/actors/projectile.tscn` | `dmg`、`tint`、`speed`、`life` |
| 乾坤圈 | `scripts/ring_throw.gd:20-59` | `scenes/actors/ring_throw.tscn` | `dmg`、`out_speed/back_speed/max_dist` |
| 环境（天空/雾/光/水） | `scripts/level_1.gd:100-165` | `scenes/ui/environment_sea.tscn` | Environment 全部参数、太阳角度/能量 |
| 环境粒子（灵尘/封印/传送门） | `scripts/level_1.gd:184-210`、`800-822`、`989-1012` | `scenes/vfx/*.tscn` | `amount/lifetime/gravity/color_ramp` |

- **问题**：这些对象的参数目前是 `_setup()` 里的赋值（如 `scripts/boss_maw.gd:37-43`：`max_hp = 480.0; knockout_resist = 0.96; add_hitbox(1.7, 3.4, 0.0)`），场景化后同类敌人想调一个数只能改代码，无法做"同一场景里放 3 种不同配置的爬行者"（变体）。
- **后果**：无法做难度变体、无法让策划/AI 在不读代码的情况下摆关卡、无法做"教程版/试玩版"的数值覆盖。
- **重构方案**：每个场景根节点的脚本声明 `@export` 参数（示例）：

```gdscript
# scripts/enemies/enemy_crawler.gd
class_name EnemyCrawler
extends EnemyBase

@export var profile: EnemyProfile
@export_range(0.0, 200.0, 1.0) var patrol_min := 0.0
@export_range(0.0, 200.0, 1.0) var patrol_max := 0.0
@export var visual: VisualProfile

func _ready() -> void:
    super._ready()
    if profile: apply_profile(profile)   # 在场景里换 .tres 即换难度
    if patrol_max <= patrol_min:
        patrol_min = global_position.x - 3.0
        patrol_max = global_position.x + 3.0
```

  场景化后 `level_1.tscn` 里"放一只爬行者"= 拖一个 `enemy_crawler.tscn` 实例并改 `patrol_min/max`，`scripts/level_1.gd:861-896` 那 36 行生成代码可以整体删除（改成 `_start_arena1` 里 `spawner.spawn(preload("res://scenes/actors/enemy_crawler.tscn"), pos)`）。
- **优先级**：P0（与 A-03 同一批工作）　**工作量**：中

---

### A-05 `Game` 单例承担 9 类职责，被全部 15 个脚本引用 305 处

- **位置**：`autoload/game.gd:1-486` 一个文件同时做：

| 职责 | 行号 | 依赖的子系统 |
|---|---|---|
| 全局状态（`souls/death_count/run_time/run_active/intro_target`） | `autoload/game.gd:10-19` | — |
| 运行时输入注册 | `90-91`、`110-136` | `InputMap` |
| 黑屏转场 + 场景切换 | `141-172`、`153-163` | `CanvasLayer`、`SceneTree` |
| hitstop / 震屏 | `177-186` | `Engine.time_scale`、`signal` |
| 材质工厂 `std_mat` / `add_mesh` | `191-214` | `RenderingServer` 资源 |
| 受击闪白 `flash_meshes` | `217-240` | 节点树遍历 + await |
| 粒子爆发 `burst` | `243-286` | `GPUParticles3D` + 材质 |
| 伤害数字 `spawn_dmg_text` | `289-308` | `Label3D` + `SystemFont` |
| 音效池 + 程序化合成 21 条音效/环境/主题 | `313-486` | `AudioServer`、`AudioStreamWAV` |

  用量（grep `Game.` 计数）：`player.gd` 87 次、`level_1.gd` 75 次、`boss_maw.gd` 34 次、`pickup.gd` 17 次、`main_menu.gd` 16 次、`hud.gd` 13 次、`enemy_crawler.gd` 12 次、其余 5–10 次；**15 个游戏脚本全部依赖它，合计 305 处调用**。
- **问题**：
  1. 职责无边界：输入、音频、UI、渲染资源、场景切换、全局进度全在一个 486 行的类里，任何改动都触碰全局；
  2. 启动成本：`_ready()`（`94-100`）无条件 `_build_audio()`，在 22 050 Hz 下用 GDScript 逐样本合成 21 条音效 + 8 秒环境 + 16 秒主题（`413-486`，其中 `_sweep` 对每个样本循环），主线程一次性完成；headless/编辑器/每次启动都要付；
  3. 逻辑与呈现耦合：Game 持有全屏 `ColorRect`、14 个 `AudioStreamPlayer`、字体。任何只想要逻辑的测试（例如"跑 1000 次伤害结算"）都被迫创建 UI/音频；A-16 的单元测试会因此难写；
  4. 反向依赖：`scripts/player.gd:1048` 直接 `Game.death_count += 1`，`scripts/enemy_base.gd:145` 直接 `player.add_energy(15.0)`，`scripts/level_1.gd:55` 直接 `Game.souls = 0` —— 层级方向已经乱了（场景/角色反向写全局）；
  5. 命名无信息量：`Game.burst`、`Game.tex`、`Game.hitstop` 混在一个命名空间里，读者无法从调用点判断分层；13 个脚本直接调用它使"能否单独复用某个工具"无法回答；
  6. `Game.change_scene` 自带 await（见 A-13），把"转场时序"这一场景管理职责也塞进了全局总线。
- **后果**：新增任何跨系统能力（成就、录像、统计、设置）最省事的做法都是继续往 `Game` 里塞；文件会从 486 行涨到 800+，305 处调用点变成 500 处。这是典型的 god object 演化路径，且与 A-11 的单文件体量问题叠加。
- **重构方案**：拆成 4 个 autoload + 3 个纯工具类 + 数据资源。建议先用"门面过渡"（`Game` 保留为薄壳、内部转调），这样不用一次性改 305 处调用：

```gdscript
# autoload/events.gd —— 只放信号，零逻辑
class_name Events
extends Node
signal shake_requested(strength: float)
signal soul_collected(total: int)
signal hit_landed(count: int)
signal boss_defeated
signal player_died

# autoload/audio_director.gd —— 音频池 + 资源 bank（音效改为离线烘焙，见下）
class_name AudioDirector
extends Node
const POOL := 16
var _players: Array[AudioStreamPlayer] = []
var _bank: Dictionary[StringName, AudioStream] = {}

func _ready() -> void:
    for i in POOL:
        var p := AudioStreamPlayer.new(); add_child(p); _players.append(p)
    _bank = preload("res://resources/audio/sfx_bank.tres").streams

func play(id: StringName, vol_db := 0.0, pitch := 1.0) -> void: ...
func start_ambient() -> void: ...
func play_theme(active: bool) -> void: ...

# autoload/scene_router.gd —— 唯一可以切场景的地方（带转场锁，见 A-13）
class_name SceneRouter
extends Node
func change_scene(path: String) -> void: ...
func flash_fade(dur := 0.35) -> void: ...

# autoload/game_state.gd —— 进度/统计/存档（见 A-14）
class_name GameState
extends Node
var souls := 0
var death_count := 0

# autoload/settings.gd —— 设置（见 A-15）
```

```gdscript
# tools/vfx_factory.gd —— 纯工厂，不注册 autoload，可被测试
class_name VfxFactory
static func burst(parent: Node, pos: Vector3, color: Color, count := 24) -> void: ...
static func hit_flash(root: Node3D, color := Color.WHITE, dur := 0.09) -> void: ...

# tools/material_lib.gd
class_name MaterialLib
static func std_mat(albedo: Color, emission := Color.BLACK, ...) -> StandardMaterial3D: ...
static func additive(color: Color) -> StandardMaterial3D: ...

# tools/hit_feedback.gd —— 一次命中要做的所有表现，调用方只写一行
class_name HitFeedback
static func impact(target: Node3D, dmg: float, heavy: bool) -> void:
    # hitstop + shake + flash + 伤害数字 + 音效 + 粒子（现在散在 scripts/player.gd:626-632 / scripts/enemy_base.gd:126-129 / scripts/boss_maw.gd:378-383）
    ...
```

  同时把**程序化音效合成移出运行期**：`_wav/_sweep/_noise_burst/_mix/_make_ambient/_make_theme`（`autoload/game.gd:353-486`）整体搬到 `tools/sfx_bake.gd`（`--script` 工具），离线生成 `resources/audio/*.wav` 并提交，运行期只 `preload` 一个 `SfxBank` Resource。这样：
  - 启动零合成成本；
  - 音色可在任意音频软件/Audacity 里二次加工；
  - 音效 bank 变成可替换资产（也是 A-19 资产管线的一部分）。
- **优先级**：P0　**工作量**：中（2–3 天，可分 3 次提交：先建新单例+门面、再迁音频、最后迁特效/伤害数字）

---

### A-06 输入映射在 `_init()` 运行时注册，不进 `project.godot`

- **位置**：`autoload/game.gd:90-91`（`_init()` → `_register_inputs()`）、`110-136`（9 个 action + 2 个鼠标事件）；使用点 `scripts/player.gd:369-453`；键名硬编码副本 `scripts/hud.gd:167`（"Q"）、`193`（"E"）、`329`（整条底栏提示）、`scripts/main_menu.gd:317-332`（操作面板）、`scripts/level_1.gd:340-383`（8 条 3D 提示，如 "A / D 移动　·　空格 跳跃（二段跳）"）；`project.godot:1-42` 无 `[input]` 段
- **问题**：
  1. 编辑器不可见：Project Settings → Input Map 是空的。读者/协作者无法确认有哪些 action、哪些键、是否冲突；
  2. 无法改键：没有重绑定界面，也没有配置存储。想加"改键"必须改代码重新发布；
  3. 无手柄：只创建了 `InputEventKey`（`autoload/game.gd:126-128`）与 `InputEventMouseButton`（`134-135`），没有 `InputEventJoypadButton/JoypadMotion`。`scripts/player.gd:369` 的 `Input.get_axis("move_left","move_right")` 对手柄轴没有死区/曲线处理；
  4. UI 提示与真实键位脱钩：键位文案在三个文件里各写一遍（HUD 底栏 `scripts/hud.gd:329`、菜单面板 `scripts/main_menu.gd:317-332`、关卡 3D 提示 `scripts/level_1.gd:340-383`），HUD 技能角标 `Q`/`E`（`scripts/hud.gd:167/193`）也是硬编码。改一次键要同步 5 处，必然漏；
  5. 重复注册风险：`_init()` 每次实例化都会 `InputMap.action_add_event`，只检查 `has_action`（`autoload/game.gd:123-124`）而不对**事件**去重。编辑器内脚本重载、工具场景、`Game` 被重新实例化时事件会累积（`action_get_events()` 变长；行为通常仍"能用"，但从此无法可靠地 `action_erase_events` / 显示键位）；
  6. 时机不对：在 autoload 的 `_init()` 里做输入注册，早于 `_ready` 与引擎的输入映射初始化顺序；一旦将来用到 `InputMap.load_from_project_settings()` 或编辑器插件，行为不可预期；
  7. `hud._input`（`scripts/hud.gd:403-410`）用 `event.is_action_pressed("pause")`，而玩家用 `Input.is_action_just_pressed`，两套输入路径混用；暂停时 `process_mode=ALWAYS` 的节点仍收事件，容易双触发（例如暂停瞬间又触发一次暂停）。
- **后果**：本项目最直接的损失是**手柄玩家完全不能玩**（动作游戏损失巨大），其次是"改键"这个所有商业动作游戏必备功能不可能实现。另外重复注册是一个会随时间恶化的隐藏地雷。
- **重构方案**：
  1. **默认映射写进 `project.godot`**（在编辑器 Input Map 面板里建好，保存后自动出现 `[input]` 段）。需要的 action 与事件：

| action | 键盘 | 手柄 |
|---|---|---|
| `move_left` / `move_right` | A/D、←/→ | 左摇杆 X（axis 0）、十字键 左/右 |
| `jump` | Space、W、↑ | A（JOY_BUTTON_A） |
| `attack` | J、鼠标左键 | X（JOY_BUTTON_X） |
| `heavy` | K、鼠标右键 | Y（JOY_BUTTON_Y） |
| `dash` | Shift、L | RB / B |
| `skill` | Q、U | LB |
| `skill2` | E、I | RT（axis 5 触发器） |
| `pause` | Esc | Start |

  2. **键位提示从 InputMap 反查**（单一事实来源）：

```gdscript
# autoload/input_labels.gd（或 tools/input_labels.gd）
class_name InputLabels
static func label(action: StringName) -> String:
    for ev in InputMap.action_get_events(action):
        if ev is InputEventKey and ev.physical_keycode != KEY_NONE:
            return OS.get_keycode_string(ev.physical_keycode)
        if ev is InputEventJoypadButton:
            return "手柄%s" % ev.button_index
        if ev is InputEventMouseButton:
            return "鼠标%s" % ev.button_index
    return "?"

# HUD 底栏改为动态拼接：
lbl.text = "%s/%s 移动　%s 跳跃　%s 冲刺　%s 连击　%s 重击　%s 乾坤圈　%s 三昧真火" % [
    InputLabels.label(&"move_left"), InputLabels.label(&"move_right"), ...]
```

  3. **改键只在 Settings 里做**：此时才允许运行时 `InputMap.action_erase_events()` + `action_add_event()`，并持久化到 `user://input.cfg`（见 A-15）。启动时读取并应用——这才是运行时注册的正确用途。
  4. 移除 `Game._init()` 的注册调用（`autoload/game.gd:90-91`），把 `_register_inputs()` 整个删除。
  5. 手柄体验：移动用 `Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")`（或仅水平轴 + deadzone 0.2）；`pause` 用 `ui_cancel` 兼容；必要时给攻击加"输入缓冲"（项目里已有 `jump_buffer`，可复用思路）。
- **优先级**：P0　**工作量**：小（1 天）

---

### A-07 玩家状态机用 `act: String` + 散落变量

- **位置**：`scripts/player.gd:29`（`var act := "free"`，注释列出 9 个状态）、`30-36`（`_ring_out/_pd_done/act_t/act_hit_done/attack_queued/combo_cd`）、`359-458`（主循环 7 处 `act == / act in [...]` 白名单判断，如 `407-410`、`418`、`428-453`）、`509-536`（`_start_action` 的 `match`）、`538-596`（`_process_action` 的 `match`）、`780-885`（`_pose_target` 的 `match`）、`950-1004`（`_update_anim` 的 `act in [...]`）；直接赋值绕过入口：`549/557/572/585/592/595/1030/1047/1063`；外部读取：`scripts/level_1.gd:1064,1069`、`scripts/pickup.gd:90`、`scripts/enemy_base.gd:88`
- **问题**：
  1. 字符串没有编译期校验：`"atk2"` 拼成 `"atk3"`/`"Attack2"` 不会报错，只会静默走 `_` 分支（默认姿势 + 默认移动），表现为"动作没动画/伤害不触发"，非常难查；
  2. 扩展成本高：加一个动作（例如"空中冲刺攻击"）要同步改 **6 处**——输入白名单 `428`、`_start_action` `513`、`_process_action` `539`、`_pose_target` `785`、`_update_anim` `954`、HUD 技能判断 `scripts/hud.gd:352-369`。漏一处就是"能动但没动画"或"能攻击但不掉血"；
  3. 状态与数据耦合：`act_t`/`act_hit_done`/`attack_queued`/`combo_cd` 是状态机的私有数据，却被 `_ready`/`_physics_process`/`_strike`/`_throw_ring`/`respawn`/`take_damage` 等 10+ 处直接读写；`_ring_out`（乾坤圈）其实是并行子状态机，与 act 毫无关系，却和 `attack_queued` 放在一起；
  4. 状态时长硬编码在判断里：`act_t >= 0.1`、`>= 0.3`、`>= 0.15`、`>= 0.42`、`>= 0.32`、`>= 0.6`、`>= 0.16`、`>= 0.55`、`>= 0.32`（`541-595`），没有表结构 → 无法实现"取消窗口 / 连段表 / 帧数据"这类动作游戏核心设计，调手感只能改数字再直觉验证；
  5. 直接赋值破坏一致性：`take_damage` 手写 `act = "hurt"; act_t = 0.0`（`1030-1031`），`respawn` 手写 `act = "free"`（`1063`），`_do_dash` 手写 `act = "free"`（`480`）——都不经过 `_start_action`，`act_hit_done` 与 `attack_queued` 是否重置靠人肉保证；
  6. 没有对外状态信号：HUD/音效/成就无法订阅"玩家进入了什么状态"，只能读字符串比较。
- **后果**：当前 9 个状态已让 `_process_action` 变成 60 行的 `match`，且每加一个技能都要复制一遍"时间判断 + 判定 + 收尾"三段式。第二章如果加"变身/连携/空中追击"，这个文件会迅速失控。这也是 A-11 中 `player.gd` 1083 行的根因之一。
- **重构方案**：两阶段，建议先做 A（低风险），再做 B。

  **方案 A：enum + 数据表（半天，先把字符串消掉）**

```gdscript
# scripts/player/player_state.gd
class_name PlayerState
enum Id { FREE, ATK1, ATK2, ATK3, HEAVY, PLUNGE, SKILL, HURT, DEAD }

# 每个动作的全部时序/数值集中在这里，新增动作只加一条
const ACTIONS := {
    Id.ATK1:  { dur=0.30, hit_at=0.10, cancel_at=0.30, dmg=10.0, size=Vector3(2.4,1.8,2.0), knock=4.0 },
    Id.ATK2:  { dur=0.30, hit_at=0.10, cancel_at=0.30, dmg=10.0, ... },
    Id.ATK3:  { dur=0.42, hit_at=0.15, cancel_at=0.42, dmg=18.0, ... },
    Id.HEAVY: { dur=0.60, hit_at=0.32, cancel_at=0.60, dmg=30.0, ... },
    Id.SKILL: { dur=0.55, hit_at=0.16, cancel_at=0.55, dmg=40.0, ... },
    Id.PLUNGE:{ dur=999.0, hit_at=-1.0, ... },
}
```

```gdscript
# 玩家内：单一入口 + 单一出口
var state := PlayerState.Id.FREE
var state_t := 0.0
var hit_done := false

signal state_changed(id: PlayerState.Id)

func _enter(id: PlayerState.Id) -> void:
    state = id
    state_t = 0.0
    hit_done = false
    state_changed.emit(id)

func _can_enter(id: PlayerState.Id) -> bool:
    return state == PlayerState.Id.FREE or (ACTIONS.has(state) and state_t >= ACTIONS[state].cancel_at)

func _tick_state(dt: float) -> void:
    var def: Dictionary = ACTIONS.get(state, {})
    if def.is_empty(): return
    state_t += dt
    if not hit_done and state_t >= def.hit_at:
        hit_done = true
        _do_hit(def)
    if state_t >= def.dur:
        _enter(PlayerState.Id.FREE)
```

  单点渲染：`_pose_for(state) -> Dictionary`、`_sprite_for(state) -> Texture2D`、HUD 订阅 `state_changed` 而不是每帧比较字符串。

  **方案 B：可执行状态对象（彻底，1–2 天）**

```gdscript
# scripts/player/action_state.gd
class_name ActionState
extends RefCounted

var id: PlayerState.Id
var dur := 0.3
func enter(p: Player) -> void: pass
func update(p: Player, dt: float) -> PlayerState.Id:  # 返回下一个状态或自身
    return id
func exit(p: Player) -> void: pass
func can_cancel_to(p: Player, to: PlayerState.Id) -> bool: return false

# scripts/player/actions/attack_state.gd
class_name AttackState
extends ActionState
var hit_at := 0.1
var dmg := 10.0
var next: PlayerState.Id = PlayerState.Id.FREE

func update(p: Player, dt: float) -> PlayerState.Id:
    if not p.hit_done and p.state_t >= hit_at:
        p.hit_done = true
        p.strike(dmg)
    return next if p.state_t >= dur else id
```

  状态注册表：`const STATES := {Id.ATK1: AttackState.new(...), ...}`；Player 只保留 `_machine.step(dt)` + 输入意图。配合 A-03 的 `player.tscn`，把 `ActionMachine` 做成子节点，`AnimationPlayer`/`AnimationTree` 可以按 state 名直接播片段（替代当前 200 行手工 Tween）。
- **优先级**：P0　**工作量**：中（方案 A 半天，方案 B 1–2 天）

---

### A-08 跨类访问"私有"字段

- **位置**：
  - `scripts/hud.gd:352`（`player.SKILL_COST`）、`355`、`360-369`（`player.SKILL2_COST`、**`player._ring_out`** 每帧读两次）
  - `scripts/level_1.gd:763`（`player.MAX_HP`）、`1030`（`player.invuln = 99.0` 魔法值）、`1064/1069`（`player.act == "dead"`）、`1072-1074`（直接写 `player.global_position = checkpoint_pos`、`player.velocity = Vector3.ZERO`、`player.invuln = ...`）
  - `scripts/pickup.gd:90`（`p.act != "dead"`）、`scripts/enemy_base.gd:88`（`player.act != "dead"`）、`scripts/boss_maw.gd:224/289`（直接 `player.take_damage`）
- **问题**：下划线是"私有"约定，说明作者知道不该外部访问，但 HUD 每帧读 `_ring_out`、关卡直接写 `player.invuln` 都绕过了约定。`act` 这个字符串被 3 个类当作公共 API；`MAX_HP/SKILL_COST` 常量被外部当数值表读。
- **后果**：A-07 一旦把 `act: String` 换成 `enum`，`hud.gd`、`level_1.gd`、`pickup.gd`、`enemy_base.gd` 全部要改（4 个文件、6 处），这就是"重构被跨层访问卡住"的典型；`player.invuln = 99.0`（`scripts/level_1.gd:1030`）本意是"通关后无敌"，但 99 秒后会失效，且无法区分"通关无敌"与"受击无敌"。
- **重构方案**：把外部真正需要的东西变成显式 API/信号，其余保持私有：

```gdscript
# scripts/player/player.gd
signal state_changed(id: PlayerState.Id)
signal ring_state_changed(out: bool)

func is_dead() -> bool: return state == PlayerState.Id.DEAD
func is_invulnerable() -> bool: return invuln > 0.0 or dash_t > 0.0
func is_ring_out() -> bool: return _ring_out
func set_invulnerable(dur: float) -> void: invuln = maxf(invuln, dur)
func set_immortal(enable: bool) -> void: _immortal = enable   # 通关用，替代 invuln=99
func teleport_to(pos: Vector3) -> void:
    global_position = pos
    velocity = Vector3.ZERO
    cam_reset_requested.emit()

func get_skill_cost(id: StringName) -> float: return stats.skill_cost if id == &"skill" else stats.skill2_cost
```

  调用侧改用：`player.is_dead()`、`player.is_ring_out()`、`player.set_invulnerable(1.0)`、`player.teleport_to(checkpoint_pos)`、`hud` 订阅 `state_changed`/`ring_state_changed` 而不是每帧读。`MAX_HP/SKILL_COST` 迁入 `PlayerStats`（A-10），HUD 用 `player.stats.max_hp` 或直接订阅 `hp_changed` 信号（已有）。
- **优先级**：P1　**工作量**：小（2–3 小时）

---

### A-09 敌人基类与"GLB→精灵→程序化网格"三级兜底复制 4 份

- **位置**：
  - 基类只做了一半：`scripts/enemy_base.gd:25-39`（`make_sprite`/`set_sprite_tex`），没有模型/程序化兜底的抽象
  - 四级复制：`scripts/player.gd:90-354`（`_build_gfx`/`_build_model_equipment`/`_build_sprite_gfx`/`_make_flame`）、`scripts/boss_maw.gd:46-161`（`_build_gfx` + `_add_aura`）、`scripts/enemy_crawler.gd:27-111`（`_build_gfx` + `_add_drip`）、`scripts/enemy_shooter.gd:28-89`
  - 每家都手搓 `const SPR_H`、`var model: Node3D`、`var spr: Sprite3D`、`gfx` 装配、`OmniLight3D`（`scripts/boss_maw.gd:156-161`、`scripts/enemy_crawler.gd:39-45`、`scripts/enemy_shooter.gd:40-55`、`scripts/player.gd:212-218/267-273/300-306`）
  - 粒子配置 6 段近似重复：`scripts/boss_maw.gd:129-153`、`scripts/enemy_crawler.gd:86-110`、`scripts/ring_throw.gd:35-58`、`scripts/level_1.gd:184-209/800-822/989-1012`、`scripts/player.gd:317-353`（都是"小球 Mesh + `ParticleProcessMaterial` unshaded + alpha + 颜色渐变"）
  - 分支同构：`_behave` 里 `if spr or model:`（`scripts/boss_maw.gd:184-189`、`scripts/enemy_shooter.gd:98-103`）；`_set_glow`/`_set_charge_visual` 的"精灵提亮 vs 材质自发光"二选一（`scripts/boss_maw.gd:309-318`、`scripts/enemy_shooter.gd:144-156`）
- **问题**：三级兜底本身是**好设计**（见"做得好的地方"），但它以复制粘贴的方式实现了 4 次。每个类各自决定"优先级、缩放、朝向、是否加灯光、是否加粒子"，彼此还不一致（shooter 在模型/精灵模式下各建一次灯，crawler 只在模型模式建灯）。
- **后果**：
  1. 加第 5 种敌人 = 复制第 5 份 120 行；改"受击闪白/蓄力发光"要改 5 处；
  2. 已经出现并发冲突：`Game.flash_meshes`（`autoload/game.gd:227-231`）会写 `spr.modulate` 并 `set_meta("base_mod")`，而 `boss_maw._set_glow`（`scripts/boss_maw.gd:313-314`）也写 `spr.modulate` 并覆盖同一个 meta → 闪白恢复时会恢复成"发光色"（见 A-13）；
  3. 美术只能通过代码切换模型/精灵，无法在编辑器里看到某个敌人当前用哪级资产、参数是多少；换资产要改多个文件（A-03）。
- **重构方案**：抽出 `ActorVisual` 子节点 + `VisualProfile` Resource，把"优先级 + 归一化 + 灯光/粒子/闪白/发光"收进一处：

```gdscript
# scripts/visual/visual_profile.gd
class_name VisualProfile
extends Resource

@export_group("L1 · 3D 模型")
@export var glb: PackedScene                    # 可空
@export var glb_height := 1.9
@export var glb_yaw_deg := 90.0
@export_group("L2 · 立绘精灵")
@export var sprite_idle: Texture2D              # 可空
@export var sprite_alt: Texture2D
@export var sprite_height := 2.0
@export_group("L3 · 程序化兜底")
@export var procedural_scene: PackedScene       # 自己也是 .tscn，可单独预览
@export_group("附加")
@export var light_color := Color(1.0, 0.6, 0.3)
@export var light_energy := 1.6
@export var light_range := 5.0
@export var ambient_vfx: PackedScene
```

```gdscript
# scripts/visual/actor_visual.gd
class_name ActorVisual
extends Node3D

enum Mode { NONE, MODEL, SPRITE, PROCEDURAL }
var mode := Mode.NONE
@export var profile: VisualProfile

var _base_modulate := Color.WHITE
var _flash := 0.0
var _glow := 0.0

func setup() -> void:
    if profile == null:
        push_error("ActorVisual 缺少 VisualProfile"); return
    if profile.glb and _mount_model(): mode = Mode.MODEL
    elif profile.sprite_idle and _mount_sprite(): mode = Mode.SPRITE
    elif profile.procedural_scene and _mount_procedural(): mode = Mode.PROCEDURAL
    else: push_error("VisualProfile 三级资产全部缺失: %s" % profile.resource_path)
    _add_light()

func flash(color: Color, dur := 0.09) -> void: ...
func set_glow(t: float) -> void: ...
func set_pose(id: StringName) -> void: ...
func _process(delta: float) -> void:
    # 单一写入者：合成 base * flash * glow，避免 A-13 的互相覆盖
    if mode == Mode.SPRITE:
        var c := _base_modulate
        c = c.lerp(Color.WHITE * 2.2, _flash)
        c = c * Color(1.0 + _glow, 1.0 + _glow * 0.5, 1.0 + _glow)
        (get_node("Sprite") as Sprite3D).modulate = c
```

  然后：
  - `enemy_base.gd` 在 `_ready` 中 `visual.setup()`（替代 `_build_gfx` 虚函数）；
  - `EnemyBase._on_hurt` 调 `visual.flash(Color.WHITE)`；`BossMaw._set_glow` 调 `visual.set_glow(c)`；
  - 新增敌人 = 写行为脚本（< 150 行）+ 一个 `resources/visual/xxx.tres`；
  - 4 个 `.tscn` 的 `VisualMount` 节点上拖 `VisualProfile`，美术可在编辑器里替换。

  按 A-04 的做法给 player/boss/crawler/shooter 各建一份 `.tres`，代码里只保留"行为"。
- **优先级**：P1　**工作量**：中（2 天，依赖 A-03 先场景化）

---

### A-10 伤害/速度/坐标/颜色/层号硬编码分散

- **位置**（抽样，均真实存在）：
  - 玩家数值：`scripts/player.gd:13-24`（HP 100、能量 100、速度 7.2、跳跃 11.8、重力 32、冲刺 17/0.18/0.75、技能 50/25）、`543`（10 伤害）、`554`（18）、`562`（30）、`577`（24）、`736`（新星半径 4.6）、`751`（新星 40 伤害）、`753`（灼烧 15）、`627`（回灵 +18/+10）、`1016`（完美闪身 +15）；
  - 敌人数值：`scripts/enemy_base.gd:10-13`（50 HP/12 接触伤害）、`122`（击退 10/5）、`103`（燃烧 2.5/0.5s）、`152`（掉落 2–3 个）；`scripts/enemy_crawler.gd:18-19`（55 HP/12 伤害）、`141`（4.2 速度）、`156`（扑咬 11）；`scripts/enemy_shooter.gd:17`（40 HP）、`134`（2.0–2.8s 冷却）、`167`（7.5 弹速）；`scripts/boss_maw.gd:37`（480 HP）、`224`（14 接触）、`289`（18 横扫）、`388`（22 砸地）、`392`（12 冲击波）、`409`（6.2/7.2 弹速）、`411/413`（扇形角度/伤害）、`425`（召唤 2）；
  - 投射物/法宝：`scripts/projectile.gd:6-8`（10 伤害/5s/颜色）、`scripts/ring_throw.gd:5-9`（16 伤害、16/19 速度、8.5 最大距离）、`scripts/ring_throw.gd:112`（回灵 6）；
  - 关卡：`scripts/level_1.gd:5`（坠亡线 -6.5）、`28-37`（4 段雾色/环境光/体积雾反照率）、`333`（尖刺 12 伤害）、`334`（坠渊 15 伤害）、`867-878`（生成器默认参数）、`955`（召唤位置 `138.0 + i * 18.0`）；坐标散布在 `336-390`、`419-424`、`448-453`、`948-1031`；
  - 拾取物：`scripts/pickup.gd:106`（灵珠 +12）、`111`（回春莲 +25）；
  - 物理层魔法数：`scripts/player.gd:10-11`、`scripts/enemy_base.gd:7-8`、`scripts/ring_throw.gd:5`、`scripts/breakable.gd:9`（layer 4）、`scripts/projectile.gd:13`（1|2）、`scripts/level_1.gd:229/318/742/843/1019` 等一长串 `collision_layer = 1/0/2`。
- **问题**：同一概念多处重复且不一致：接触伤害 12 同时出现在 `scripts/enemy_base.gd:12`、`scripts/level_1.gd:333`；弹幕伤害 10/12 在 `scripts/projectile.gd:6`、`scripts/boss_maw.gd:392/413` 各写一遍；回灵数值 10/18/6/15/12 分散在 5 个文件；颜色字面量 100+ 处，没有调色板（金色在 `scripts/hud.gd:5`、`scripts/player.gd:71`、`scripts/level_1.gd:81`、`scripts/ring_throw.gd:25` 各定义一次）。
- **后果**：
  1. 做数值平衡（本作的战斗手感调优）必须同时改 5–10 个文件，且改完无法确认是否改全；
  2. 无法做难度档（简单/普通/困难）、无法做"试玩版"覆盖；
  3. 策划/AI 无法安全参与：一个"把 Boss 血降到 400"的指令，AI 可能改到 `_setup()` 也可能改到 `reset_fight()`（`scripts/boss_maw.gd:459` 的 `hp = max_hp`，依赖 max_hp）——没有单一事实来源；
  4. 层号错一位就是"攻击打不到敌人/玩家掉出地形"，这类 bug 在重构时极易发生（A-03/A-11 都要动这些数据）。
- **重构方案**：把"设计数值"资源化，"引擎语义"常量化。

```gdscript
# scripts/data/player_stats.gd
class_name PlayerStats
extends Resource
@export_group("生存") @export var max_hp := 100.0
@export_group("移动")
@export var speed := 7.2
@export var jump_velocity := 11.8
@export var gravity := 32.0
@export var dash_speed := 17.0
@export var dash_time := 0.18
@export var dash_cooldown := 0.75
@export_group("攻击")
@export var atk1_damage := 10.0
@export var atk2_damage := 10.0
@export var atk3_damage := 18.0
@export var heavy_damage := 30.0
@export var plunge_damage := 24.0
@export_group("能量")
@export var max_energy := 100.0
@export var skill_cost := 50.0
@export var skill2_cost := 25.0
@export var energy_per_hit := 10.0
@export var energy_per_heavy := 18.0
```

```gdscript
# scripts/data/enemy_profile.gd
class_name EnemyProfile
extends Resource
@export var display_name := "潮汐爬行者"
@export var max_hp := 55.0
@export var touch_damage := 12.0
@export var knock_force := 5.0
@export var visual: VisualProfile
@export var loot_table: Array[PickupDrop]
```

```gdscript
# scripts/core/physics_layers.gd —— 层号只在这里出现一次
class_name PhysicsLayers
const WORLD    := 1 << 0   # 1
const PLAYER   := 1 << 1   # 2
const ENEMY    := 1 << 2   # 4
const HAZARD   := 1 << 3   # 8
```

  并在 `project.godot` 里命名层（编辑器可见）：

```ini
[layer_names]
3d_physics/layer_1="world"
3d_physics/layer_2="player"
3d_physics/layer_3="enemy"
3d_physics/layer_4="hazard"
```

  `level_1` 的关卡参数做成 `LevelConfig` Resource：`zone_stops: Array[ZoneStop]`（替代 `scripts/level_1.gd:28-37` 的四元数组与 `1104-1115` 的索引读取）、`spike_damage`、`fall_damage`、`kill_y`、`spawn_points`。`Player`/`Enemy` 上 `@export var stats/profile`，`.tscn` 里指定 `.tres`——从此"改数值"= 改 `.tres`，不动代码。
- **优先级**：P1　**工作量**：中（2 天，机械但量大；建议先用脚本把 `player.gd`/`enemy_*.gd` 的常量引用批量替换）

---

### A-11 `player.gd`、`level_1.gd` 体量远超单文件合理规模

- **位置**：`scripts/player.gd` **1083 行**、`scripts/level_1.gd` **1147 行**、`hud.gd` 542、`boss_maw.gd` 517（四个文件占全部 5300 行的 62%）。
  - `player.gd` 分区：`74-354` 外观/装备/粒子、`357-495` 移动/跳跃/冲刺/落地、`496-776` 攻击/技能/乾坤圈、`778-1005` 动画（姿势表 + 武器跟手 + 残影）、`1007-1083` 生命/复活
  - `level_1.gd` 分区：`100-165` 环境、`170-219` 玩家/相机/HUD、`224-390` 地形、`392-675` 装饰、`677-857` 互动物件、`859-1032` 敌人与 Boss、`1034-1147` 生死循环/氛围/野生动植物
- **问题**：Godot 的正常节奏是"一个场景 + 每类节点一个脚本"，本项目把"角色控制器 + 外观工厂 + 动画系统 + 战斗判定 + 关卡搭建 + 演出"都塞进两个文件。`_physics_process`（`scripts/player.gd:359-458`）一个函数 100 行，同时处理输入、状态推进、重力、移动、跳跃缓冲、4 种输入判定、动画更新。
- **后果**：
  1. 认知负担：人（和 AI）都难以在 1000 行里保持全局一致；改动画容易碰判定，改判定容易碰移动；
  2. git 冲突：所有改动都落在两个文件上（未来多人/多 AI 并行时必冲突）；
  3. 无法单测：一个文件依赖整个场景树、输入单例、Game 单例，测它的成本接近跑整局游戏；
  4. 编辑器卡顿：Godot 打开 1000+ 行脚本的编辑体验明显变差。
- **重构方案**：组合优于继承，拆分目标（依赖 A-03 的场景化）：

```
scripts/player/
  player.gd             # ≈180 行：生命周期、输入意图、受击入口、对外 API
  player_locomotion.gd  # 从 357-495 抽出：移动/跳跃/冲刺/落地（Node 子节点）
  player_actions.gd     # 从 496-596 抽出：状态机（A-07）
  player_combat.gd      # 从 598-776 抽出：_strike/_do_nova/乾坤圈
  player_visual.gd      # 从 778-1005 抽出：姿势表/武器跟手/残影/残像
  player_stats.gd       # 数据（A-10）
scripts/level/
  level_1.gd            # ≈150 行：只做流程编排（开始/竞技场/Boss/胜利）
  level_terrain.gd      # 224-390
  level_decor.gd        # 392-675
  level_props.gd        # 677-857（或完全由 .tscn 实例替代）
  level_encounters.gd   # 859-1032
  level_ambience.gd     # 100-165 + 1099-1147
  level_config.gd       # 数据（A-10）
scripts/ui/hud/
  hud.gd                # ≈150 行：绑定/信号转发
  hud_bars.gd / hud_boss_bar.gd / hud_overlay.gd / hud_combo.gd
```

  子节点通过场景唯一名（`%Player`、`%HUD`）或 `@export var player: Player` 拿到引用，不再靠共享成员变量。拆分顺序建议：先 `player_visual`（最独立、无逻辑风险）→ `player_combat` → `player_actions` → `player_locomotion`；每拆一步跑一次 A-16 的冒烟测试。
- **优先级**：P1　**工作量**：大（3–4 天；必须在 git 快照 + 场景化之后做）

---

### A-12 运行期 `load()` + `ResourceLoader.exists` 探测，缺失资产静默降级

- **位置**：
  - `autoload/game.gd:22-26`（`tex()`：`ResourceLoader.exists` → `load` → 失败返回 `null`，**无日志**）、`29-81`（`load_model()`：exists → `load` → `instantiate` → 遍历 AABB → 材质兜底 → 包装缩放）
  - 调用点 30+：`scripts/player.gd:95/100/279-281`、`scripts/boss_maw.gd:53/59`、`scripts/enemy_crawler.gd:36/48/50`、`scripts/enemy_shooter.gd:36/47`、`scripts/level_1.gd:88/398/635`、`scripts/hud.gd:89/221`、`scripts/main_menu.gd:26/292/301`、`scripts/intro.gd:141`
  - shader：`scripts/hud.gd:73`、`scripts/intro.gd:52`、`scripts/main_menu.gd:40/47/56`、`scripts/level_1.gd:105/160`
  - 全库 **0 个 `preload()`**、**0 个 `@export PackedScene/Texture2D`**
- **问题**：
  1. 编译器无法校验路径；路径拼错/资产缺失没有 `push_error`，只在运行期表现为"外观不对"；
  2. **已经踩坑的两个实例**：
     - `scripts/player.gd:281` 请求 `res://art/sprites/nezha_jump.png`，但 `art/sprites/` 下只有 10 个 png（`boss_3d/boss_idle/crawler_3d/crawler_idle/nezha_3d/nezha_attack/nezha_idle/nezha_run/shooter_3d/shooter_idle`），**没有 `nezha_jump.png`** → `_tex_jump` 被 `286-287` 行回退为跑步图 → "跳跃姿态"从未生效；
     - `scripts/enemy_crawler.gd:50` 请求 `crawler_lunge.png`，同样不存在 → `_spr_lunge == null` → `176-179` 行的"蓄力/扑咬换图"从未生效。
     这两个 bug 完全静默，正是"存在性探测 + 兜底"模式的副作用。
  3. `ResourceLoader.exists()` 是同步磁盘/PackedData 查询，`load()` 再查一次缓存；同一纹理在 4 个敌人实例上各探一次；
  4. GLB 每个实例都重新 `find_children` + AABB 合并 + 新建材质（`autoload/game.gd:41-80`）；同屏 6 只 crawler = 6 次 `load_model` 全流程；
  5. 导出后路径大小写/被 `export_filter` 过滤时同样静默降级，问题只在"上了别人的机器"才暴露。
- **后果**：资产问题被系统性隐藏；美术漏交一张图，程序不会报错，只会在某天被玩家发现"跳跃图不对"。对 AI 辅助开发尤其危险：AI 生成/替换资产时最容易出现"文件名对不上"。
- **重构方案**：
  1. 场景/资源一律用编辑器引用（`@export`，路径存在于 `.tscn/.tres` 中，导入阶段即可发现缺失）；`preload()` 用于确定存在的资源（shader、theme、音效 bank）。示例：

```gdscript
# scripts/visual/visual_profile.gd（A-09）里直接持有资源引用
@export var glb: PackedScene
@export var sprite_idle: Texture2D

# 玩家脚本
@export var stats: PlayerStats
@export var visual_profile: VisualProfile
```

  2. 保留 `Game.tex()` 作为"可选资产"兼容层，但必须显式报告：

```gdscript
func tex(path: String) -> Texture2D:
    if not ResourceLoader.exists(path):
        _report_missing(path)      # 收集到数组，启动时/退出时统一打印一次
        return null
    return load(path) as Texture2D

func _report_missing(path: String) -> void:
    if OS.is_debug_build():
        push_warning("缺失美术资源: " + path)
        _missing.append(path)
```

  3. 加一个 headless 校验工具，把"静默降级"变成"构建失败"（见 A-19/A-16）：

```gdscript
# tools/validate_assets.gd  (extends SceneTree，CI 里跑)
func _initialize() -> void:
    var bad := 0
    for res in DirAccess.get_files_at("res://resources/visual"): ...
        # 逐个检查 VisualProfile 的 glb/sprite/procedural 引用
    if bad > 0: quit(1)
```

  4. GLB 归一化（AABB/朝向/缩放/材质）改为导入期烘焙：`EditorPlugin` 或 `--script` 工具把 `.glb` 转成统一规格的 `.tscn`，运行期零计算；或至少把"路径 → 高度/朝向/是否有贴图"缓存为 Resource。
- **优先级**：P1　**工作量**：中（1–2 天；去掉 exists 探测后代码反而更短）

---

### A-13 `await`/场景切换生命周期与 Tween/`queue_free` 竞争

- **位置**：
  - `autoload/game.gd:153-163`（`change_scene` 内部 await tween 再切场景）、`166-172`（`flash_fade`）、`177-182`（`hitstop` await 后恢复 `Engine.time_scale`）、`217-240`（`flash_meshes` await 后恢复材质）
  - `scripts/hud.gd:519-530`（`show_death` await 1.1 秒再弹窗）、`scripts/hud.gd:392-398`（每次 `show_message` 新建 tween 写同一个 `_msg_label.modulate`）、`scripts/hud.gd:300-316`（每次命中新建 tween 写 `_combo_label.modulate`）
  - `scripts/level_1.gd:961-969`（Boss 死亡 await 1.8 秒后生成传送门）、`1055-1060`（复活 await 0.25 秒后传送）
  - 同属性多写者：`scripts/player.gd:490-493`（落地 tween 写 `gfx.scale`）vs `scripts/player.gd:969-972`（每帧 `gfx.scale.lerp`）；`scripts/player.gd:926-933/939-947`（枪的 tween）vs `scripts/player.gd:903-920`（每帧 `spear.global_transform.interpolate`）；`scripts/boss_maw.gd:309-318`（`spr.modulate`）vs `autoload/game.gd:227-231`（同一 modulate）
- **问题**：
  1. `Game.change_scene` 无重入保护：0.45 秒淡出期间再调用一次（暂停菜单"返回主菜单"连点、或死亡界面 + Esc）→ 两条 tween 同时写 `_fade.modulate.a`、两次 `change_scene_to_file` 后到者覆盖，可能出现"黑屏不恢复/切错场景"；
  2. `await` 之后默认世界没变：`_on_boss_defeated` 等 1.8 秒，期间玩家可能已死亡并 `_respawn_full`，或场景已切换（协程随 `level_1` 释放而静默终止——不报错，但"传送门生成"这个事件被悄悄丢掉）；
  3. `hitstop`（`177-182`）用全局 `Engine.time_scale`，靠 `change_scene` 里 `Engine.time_scale = 1.0`（`158`）兜底；若在 hitstop 期间退出/切场景失败，时间缩放会残留（编辑器内下次运行会重置，进程内可能卡在 0.05 倍速）；
  4. `flash_meshes` 的"存 `base_mod` → await → 恢复"在并发受击时互相覆盖：第二击在闪白期间触发，第一击的 await 结束时把颜色恢复 → 第二击闪白被提前取消；Boss 的 `_set_glow`（`scripts/boss_maw.gd:314`）每次写 `spr.set_meta("base_mod", spr.modulate)`，会把"发光色"存成基础色，之后 `flash_meshes` 恢复成发光色 → 视觉错乱；
  5. 共享 Label 的 tween 不 kill：快速连续 `show_message`（例如"拾得龙魂残片"紧接"封印已解"）时，两条 tween 同时写 `modulate:a`，出现闪烁/文字提前消失；`_on_combo_hit` 同理；
  6. `queue_free` 与 tween：本项目 Tween 都绑在节点上（`node.create_tween()`），节点 free 时会被自动清理，这一点**没有问题**；但"先 tween 后 `queue_free`"的写法（`scripts/level_1.gd:834-837`、`scripts/player.gd:661-663/684-689`）如果节点被外部提前 free，链式回调会静默取消——属于可接受行为，无需改。
- **后果**：转场/死亡/Boss 结算这三条"演出链"是最容易出偶发 bug 的地方（黑屏、按钮点两次、结算界面不出现、Boss 死了门没开）。这些在单机 demo 里偶发一次很难复现，却是发布前最耗时的 bug 类型。
- **重构方案**：
  1. 转场加锁（`SceneRouter` 内）：

```gdscript
var _transitioning := false

func change_scene(path: String) -> void:
    if _transitioning:
        return
    _transitioning = true
    await _fade_to(1.0, 0.45)
    Engine.time_scale = 1.0
    get_tree().paused = false
    get_tree().change_scene_to_file(path)
    await get_tree().process_frame          # 等新场景进入树
    await _fade_to(0.0, 0.6)
    _transitioning = false

func _fade_to(alpha: float, dur: float) -> void:
    var tw := create_tween()
    tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tw.tween_property(_fade, "modulate:a", alpha, dur)
    await tw.finished
```

  2. 所有 async 序列加存活保护与取消令牌：

```gdscript
var _seq := 0

func _on_boss_defeated() -> void:
    var token := ++_seq
    await get_tree().create_timer(1.8, false).timeout
    if not is_inside_tree() or token != _seq:
        return
    _spawn_portal()
```

  或者更简单：把"Boss 死亡 → 传送门"改成 `boss.boss_defeated` 信号 + `Timer` 节点（场景化后直接放在 `.tscn` 里），时间到发 `timeout`，由 level 连接——这样时序是场景数据，可取消、可暂停。
  3. 同属性只允许一个写入者：`gfx.scale` 由 `ActorVisual._process` 统一合成（落地挤压作为 `_squash` 偏置量，不再直接 tween `gfx.scale`）；`spr.modulate` 由 `ActorVisual` 统一合成 `base * flash * glow`（配合 A-09），`flash_meshes` 从 Game 移走。
  4. 共享 UI 元素保存 tween 引用并 `kill()`：

```gdscript
var _msg_tween: Tween
func show_message(text: String, dur := 2.2, size := 54) -> void:
    if _msg_tween: _msg_tween.kill()
    _msg_tween = create_tween()
    ...
```

  5. `hitstop` 保持现有防重入（`if Engine.time_scale < 1.0: return`）即可；建议把 `time_scale` 的恢复绑定到 `get_tree().process_frame` 而不是 timer，避免暂停时 timer 不走。
- **优先级**：P1　**工作量**：中（1 天）

---

### A-14 无存档：检查点、`souls`、`death_count` 全在内存

- **位置**：`autoload/game.gd:10-19`（`souls/death_count/run_time/run_active/intro_target` 全是普通变量）；`scripts/level_1.gd:10`（`checkpoint_pos`）、`scripts/level_1.gd:18`（`_checkpoints`）、`scripts/level_1.gd:757-773`（激活检查点只改内存）；`scripts/hud.gd:533-539`（结算读取全局内存值）；全库 0 处 `user://`、0 处 `ConfigFile`、0 处 JSON
- **问题**：关掉游戏即丢失一切：进度、龙魂残片收集、死亡次数、通关时间、最高连击。检查点也只是"本局内的重生点"。
- **后果**：
  1. 无法验证"从检查点继续"这一真实玩家行为（存档/读档本身是最容易出 bug 的系统）；
  2. 加第二章时"已通关第一章/已收集 N 残片"无法驱动（解锁、继承、统计）；
  3. 死亡次数/最高连击这类数据无法沉淀为玩家档案；
  4. 发布后玩家投诉"进度没了"是致命的。
- **重构方案**：`GameState` autoload + `SaveData` Resource + `ConfigFile`（或 JSON）。检查点存 **id + 关卡路径** 而不是坐标（配合 A-04 的 `checkpoint_lotus.tscn` 的 `id`）：

```gdscript
# scripts/data/save_data.gd
class_name SaveData
extends Resource
@export var version := 1
@export var level_path := "res://scenes/levels/level_1.tscn"
@export var checkpoint_id := 0
@export var souls := 0
@export var deaths := 0
@export var best_time := 0.0
@export var max_combo := 0
@export var unlocked_chapters: Array[int] = [1]
```

```gdscript
# autoload/game_state.gd
class_name GameState
extends Node
const SAVE_PATH := "user://save.cfg"

var data := SaveData.new()

func save_now() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("meta", "version", data.version)
    for prop in ["level_path", "checkpoint_id", "souls", "deaths", "best_time", "max_combo", "unlocked_chapters"]:
        cfg.set_value("save", prop, data.get(prop))
    var err := cfg.save(SAVE_PATH)
    if err != OK: push_error("存档失败: %d" % err)

func load_save() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return                                    # 无存档 = 新游戏
    var v: int = cfg.get_value("meta", "version", 0)
    if v < 1: _migrate_from_v0(cfg)
    for prop in [...]:
        data.set(prop, cfg.get_value("save", prop, data.get(prop)))

func reset_run() -> void: ...
```

  `level_1._activate_checkpoint` 里 `GameState.data.checkpoint_id = cp_id; GameState.save_now()`；HUD 结算读 `GameState.data`；`main_menu` 增加"继续游戏"按钮（有存档时才显示）。注意读档后要校验 `level_path` 存在，版本号加迁移函数。
- **优先级**：P1　**工作量**：小（1 天；数据量很小）

---

### A-15 无设置项（音量/分辨率/画质/按键）

- **位置**：`project.godot:22-28`（1920×1080、`mode=2`（最大化）、`canvas_items`/`expand` 全部写死）；`project.godot:38-42`（D3D12、MSAA、清屏色写死）；`project.godot` 无 `[audio]` 段（无 bus 布局、无默认音量）；`scripts/main_menu.gd:133-138` 只有"开始/世界观/操作指南/退出"四个按钮，没有设置
- **问题**：玩家无法调节音量（尤其动作游戏音效密集）、无法切全屏/窗口、无法调画质（低端机被 D3D12 + 体积雾 + MSAA 劝退）、无法改键（A-06）；强制 D3D12（`rendering_device/driver.windows="d3d12"`）在没有 D3D12 的环境无法启动，也没有回退引导。
- **后果**：发给别人试玩时会收到"卡/没声音/全屏不了/手柄用不了"四类反馈，每一条都需要作者手动改配置；Steam Deck/Linux 玩家直接无法运行。
- **重构方案**：`autoload/settings.gd` + `user://settings.cfg` + 设置面板：

```gdscript
# autoload/settings.gd
class_name Settings
extends Node

const PATH := "user://settings.cfg"
var master_db := -6.0
var music_db := -10.0
var sfx_db := 0.0
var fullscreen := true
var resolution := Vector2i(1920, 1080)
var msaa := 4
var locale := "zh_CN"

func apply() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
    DisplayServer.window_set_mode(
        DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
    if not fullscreen:
        DisplayServer.window_set_size(resolution)
    get_viewport().msaa_3d = msaa
    TranslationServer.set_locale(locale)

func save() -> void: ...
func load_and_apply() -> void: ...
```

  UI：`main_menu` 加"设 置"按钮 → `scenes/ui/settings_panel.tscn`（音量滑条/全屏复选框/分辨率下拉/画质档位/语言/按键重绑）。音频改用 bus 布局（`Master/Music/SFX`），`AudioDirector` 播放时指定 bus。渲染回退：去掉强制 D3D12（除非有明确理由），并在 README 写 `--rendering-driver vulkan` / `--rendering-method gl_compatibility` 的兜底参数。
- **优先级**：P1　**工作量**：小（1–2 天）

---

### A-16 无自动化测试、无 CI

- **位置**：项目内无 `tests/`、无 `addons/`（GUT/GdUnit 均未安装）、无 `.github/`；目前唯一的自动化是人工跑 `godot --headless --quit-after N`（lead 已确认三场景 180 帧无脚本报错）
- **问题**：5300 行代码 + 状态机 + 伤害公式 + 未来的存档/设置，零回归保障。headless 200 帧只能证明"没有解析错误/空引用崩溃"，证明不了"A-07 换 enum 后连招还走得通""A-10 资源化后伤害没变"。
- **后果**：本报告建议的每一步重构（A-03/A-05/A-07/A-11）都会动到核心逻辑，没有回归网就只能靠手感抽查；AI 辅助开发下"顺手改坏一个分支"的概率不低。
- **重构方案**（按性价比排序）：
  1. **冒烟测试脚本**（成本最低，先做）：`tools/smoke_test.gd`（`extends SceneTree`）依次实例化三个场景、各跑 120 帧、断言无错误、玩家能移动/能受击：

```gdscript
# tools/smoke_test.gd
extends SceneTree

const SCENES := [
    "res://scenes/main_menu.tscn",
    "res://scenes/intro.tscn",
    "res://scenes/levels/level_1.tscn",
]

func _initialize() -> void:
    for path in SCENES:
        var ps: PackedScene = load(path)
        var inst := ps.instantiate()
        root.add_child(inst)
        for i in 120: await process_frame
        inst.queue_free()
        await process_frame
    quit(0)
```

```powershell
godot --headless --path 001 --script res://tools/smoke_test.gd
godot --headless --path 001 --check-only --script res://scripts/player.gd   # 语法检查（可选，逐文件）
```

  2. **单元测试**（值钱）：装 GUT 4（`addons/gut`），写 `tests/unit/test_damage.gd`（Boss 击杀时间区间断言）、`test_state_machine.gd`（A-07 后：每个 enum 状态都能进入/退出、取消表合法）、`test_save.gd`（写→读→迁移）、`test_input_labels.gd`（每个 action 都有键位）。这些测试几乎不依赖场景树，跑得飞快：
  3. **CI**（GitHub Actions + `barichello/godot-ci` 镜像）：

```yaml
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    container: barichello/godot-ci:4.6.3
    steps:
      - uses: actions/checkout@v4
      - run: godot --headless --path 001 -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
      - run: godot --headless --path 001 --script res://tools/smoke_test.gd
      - run: godot --headless --path 001 --export-release "Windows Desktop" build/game.exe
```

  验收：改坏一个伤害公式/一个状态转移，CI 在 2 分钟内变红。
- **优先级**：P1　**工作量**：中（冒烟 2 小时，GUT + CI 1–2 天）

---

### A-17 UI/文字依赖 Windows 系统字体（`SystemFont`）

- **位置**：`autoload/game.gd:96-98`（`SystemFont.new()` + `["Microsoft YaHei UI","Microsoft YaHei","SimHei","NSimSun"]`）、`theme/ui_theme.tres:3-4`（同一组字体名）
- **问题**：这些字体只在 Windows 中文环境存在。导出到 Linux/Steam Deck/非中文 Windows/Web 时，`SystemFont` 会回退到不含 CJK 字形的默认字体——本项目 **100% 中文文案**（A-18），结果就是全屏方块。此外 `SystemFont` 每次启动都要做字体匹配，headless 下也仍创建字体对象（与 A-21 的泄漏排查相关）。
- **后果**：跨平台发布直接不可用；不同机器上字形/字重不一致，UI 布局（大量固定像素定位：`scripts/hud.gd:119-197`、`scripts/main_menu.gd:96-112`）可能因字体度量差异而错位。
- **重构方案**：打包 OFL 开源中文字体（如 Noto Sans SC / 思源黑体 Regular + Bold），项目内 `assets/fonts/`，`ui_theme.tres` 的 `default_font` 指向 `FontFile`；`Game.world_font`（用于 Label3D）改为 `preload("res://assets/fonts/NotoSansSC-Regular.ttf")`；`SystemFont` 仅作 fallback。顺手把散落的字号（14/16/18/22/26/30/42/54/72…）收进 `ui_theme.tres` 的 `FontSize` 变量，`default_font_size = 20` 目前基本没被使用。
- **优先级**：P1　**工作量**：小（半天，主要是选字体/确认授权）

---

### A-18 无多语言，全中文硬编码在 Label 里

- **位置**：中文字面量遍布 UI/剧情/提示：`scripts/hud.gd:109/159/185/210/293/321/329/502-524/538`、`scripts/main_menu.gd:90/97/108/133-137/187/305-332`、`scripts/intro.gd:7-23/88/104`、`scripts/level_1.gd:65/340-383/765/900/921/947/953/967/1016/1052`；全库 **0 处 `tr()`**、无 `[internationalization]` 配置
- **问题**：所有玩家可见文本直接写在代码字符串里，没有文本 key、没有翻译表、没有语言切换。剧情页（`scripts/intro.gd:7-23`）也是硬编码数组。
- **后果**：无法出英文版/多语言版（对独立游戏出海是硬门槛）；文案修改要改代码；无法请人校对文本（校对者不应读 GDScript）；配合 A-17 的字体问题，多语言还会涉及字体回退策略。
- **重构方案**：用 Godot 内置本地化：
  1. `project.godot` 加：

```ini
[internationalization]
locale/translations=PackedStringArray("res://locale/zh_CN.po", "res://locale/en.po")
locale/fallback="zh_CN"
```

  2. 所有文本改 key：`Label.text = tr("HUD_SKILL_FIRE")`，或在 `.tscn` 里 `text = "HUD_SKILL_FIRE"` 并依赖 `auto_translate`；
  3. `locale/zh_CN.po` + `en.po`（`.po` 可在 Poedit 里交给人翻）；
  4. 剧情 `PAGES` 改成 `Array[StoryPage]`（Resource：`title_key/text_key/image`），或直接把 key 写进数组；
  5. 键位提示不要写进翻译文本（A-06 的 `InputLabels.label()` 拼接）。
- **优先级**：P2（不影响单人中文玩家，但决定能否发布到海外）　**工作量**：中（1–2 天，文本量约 100 条）

---

### A-19 AI 资产管线与程序化兜底并存，缺清单与校验

- **位置**：`art/` 80.1 MB（`raw` 14.5 / `sprites` 7.7 / `models` 31.6）；`art/chroma_key.py:1-48`（raw→sprites 绿幕抠图脚本，需手动运行）；`autoload/game.gd:29-81`（GLB 顶点色/贴图判定与 AABB 归一化）；4 个未引用的 `art/sprites/*_3d.png`（`boss_3d/crawler_3d/nezha_3d/shooter_3d`，共 3.26 MB，全库 0 引用）；`art/raw/*.png` 14.5 MB 与 sprites 重复且逐个有 `.import`（会被 Godot 导入）；缺失资产 `art/sprites/nezha_jump.png`、`art/sprites/crawler_lunge.png`（见 A-12）
- **问题**：同一个角色存在 4 套资产口径：`art/raw/*.png`（生成原图）→ `art/sprites/*.png`（抠图）→ `art/models/*.glb`（TripoSR 3D）+ `models/*_0.png`（烘焙贴图）→ `art/sprites/*_3d.png`（3D 截图，未被使用）。代码里写死了"GLB > 精灵 > 程序化网格"的优先级，但没有任何地方说明"某资产当前处于哪一级、缺哪张图"。`chroma_key.py` 是管线里唯一一步，且不在任何自动化里。
- **后果**：
  1. 换美术时不知道该改哪套、改完哪套优先（要读 5 个 `_build_gfx`）；
  2. `art/raw` 若未在导出过滤里排除 → 包体 +14.5 MB、导入时间增加；`*_3d.png` 是纯浪费；
  3. 缺失资产静默降级（A-12 已证实两个 bug）；
  4. GLB 平均 8 MB，4 个进包 31.6 MB，能否压到 3–5 MB（简化网格/Draco/KTX2）没有任何记录；
  5. 没有资产清单，AI 生成新资产时无法知道"应该产出什么规格"（高度、朝向、命名、是否需要绿幕、是否要烘焙贴图）。
- **重构方案**：
  1. 目录定级（与 A-09 的 VisualProfile 对应）：

```
assets/
  visual/actors/nezha.glb / crawler.glb / shooter.glb / boss.glb
  visual/actors/sprites/{nezha,crawler,shooter,boss}_{idle,run,attack,...}.png
  visual/props/...
  source/raw/...            ← 加 .gdignore，不导入、不导出
  fonts/
tools/
  asset_pipeline.py         ← 合并 chroma_key.py + 尺寸/命名校验 + 缺失清单
  validate_assets.gd        ← headless 校验每个 VisualProfile 引用
```

  2. `art/raw/.gdignore`（空文件）→ 立刻省掉 14.5 MB 的导入与潜在包体；
  3. `tools/validate_assets.gd` 进 CI：遍历 `resources/visual/*.tres`，引用缺失即 `push_error` + 退出码 1（把 A-12 的静默降级变成构建失败）；
  4. 写一份 10 行的 `art/README.md`：每个资产需满足的高度/朝向/背景/命名/贴图规格，AI 生成提示词模板也放这里；
  5. 删除或归档 4 个 `*_3d.png`（3.26 MB）；GLB 视发布目标决定是否简化/Draco，源文件用 LFS。
- **优先级**：P2　**工作量**：中（1 天）

---

### A-20 类型标注/命名/魔法数字一致性

- **位置**（抽样）：
  - 字符串当枚举：`autoload/game.gd:16`（`intro_target := "level"`）、`scripts/level_1.gd:1086-1096`（`match f["axis"]`：`"z"/"spin_z"/"y"/"sway"`）、`scripts/player.gd:29`（`act`）、`scripts/boss_maw.gd:16`（`state`）、`scripts/enemy_crawler.gd:7`、`scripts/falling_platform.gd:6`、`scripts/level_1.gd:1104-1115`（区域 stops 用 `[0]..[3]` 索引 + `as Color` 转型）
  - 弱类型容器：`scripts/level_1.gd:28`（`var _zone_stops: Array` 内是 `Array`）、`scripts/level_1.gd:17`（`Array[Dictionary]`，键是 `"node"/"speed"/"axis"/"base"/"phase"` 字符串）、`scripts/level_1.gd:734`（`var cp := {...}` 无类型）、`scripts/boss_maw.gd:25`（`_summon_flags := [false,false]`）、`scripts/level_1.gd:902`（`var spawns := [...]`）
  - 命名不一致：`gfx`（player/enemy）vs `_gfx`（falling_platform）；`spr` vs `sprite` vs `model`；`SPR_H`（crawler/shooter）vs `SPRITE_H`（player）；`_t` 在 5 个类里语义不同（时间/相位）；变量声明位置不统一：`scripts/boss_maw.gd:305`（`_barrage_fired` 声明在文件中部）、`scripts/enemy_crawler.gd:27-32`、`scripts/enemy_shooter.gd:28-32` 把成员变量夹在 `_setup()` 与 `_build_gfx()` 之间
  - 颜色字面量 100+ 处，无调色板
- **问题**：GDScript 的类型系统是"可用但可选"的，本项目用了部分类型（`Array[Dictionary]`、`var player: Player`），但关键状态/数据仍是字符串/裸数组；命名与声明风格不统一会让 AI 或新协作者按错误约定加代码。
- **后果**：重构时没有编译器帮忙（A-07 换 enum 时最明显）；`Array` 下标/字典键写错只能运行时报错；存档序列化（A-14）需要稳定的字段名，字典 key 很容易漂移。
- **重构方案**：
  1. 状态/类型用 `enum` 或自定义 Resource：`enum Target { LEVEL, MENU }`、`enum FloaterKind { SPIN_Y, SPIN_Z, BOB, SWAY }`、`class_name ZoneStop extends Resource { @export var x: float; @export var fog: Color; @export var ambient: Color; @export var fog_albedo: Color }`、`class_name Floater extends Resource { @export var node: Node3D; @export var kind: FloaterKind; @export var speed := 0.1; @export var bob := 0.0 }`；
  2. 命名规范写成 `CONTRIBUTING.md` 的几行：私有 `_` 前缀、成员变量集中在类顶部、常量 `UPPER_SNAKE`、资源类 `*Profile/*Stats/*Config`；
  3. 调色板：`class_name Palette { const GOLD := Color(0.95,0.78,0.35); ... }`（或 `resources/palette.tres`），替换 100+ 处色值；
  4. 打开 GDScript 警告（`project.godot`）：

```ini
[debug]
gdscript/warnings/untyped_declaration=2
gdscript/warnings/unsafe_property_access=1
gdscript/warnings/unsafe_method_access=1
```

  5. CI 加 `--check-only`（A-16）卡住解析错误。
- **优先级**：P2　**工作量**：小（半天，配合 A-07/A-10 一起做）

---

### A-21 `ObjectDB instances leaked at exit` 诊断

> 本节先说明：按任务约束**没有运行 Godot**，因此无法复现确认。以下是基于代码的静态排查结论 + 一套不改动原项目的复核流程。lead 已确认"三场景 headless 180 帧无脚本报错，退出时打印该警告"。

- **位置（可疑源，按可能性排序）**：
  1. `autoload/game.gd:90-91`、`110-136`：`_init()` 里 `InputMap.action_add_event` 创建的 `InputEventKey`/`InputEventMouseButton` 由 InputMap 单例持有，退出顺序若晚于 ObjectDB 清理，会以"Leaked instance: InputEventKey"形式出现；
  2. `autoload/game.gd:96-98` + `theme/ui_theme.tres:3-4`：`SystemFont` 动态创建底层 `FontFile`，字体缓存与 TextServer 的生命周期不一致时常见此类残留；
  3. `autoload/game.gd:337-350`、`413-444`：14 个 `AudioStreamPlayer` + 21 个运行时合成的 `AudioStreamWAV`；若退出时仍在播放，AudioServer 侧可能持有引用；
  4. `autoload/game.gd:22-26`、`29-81`：`load()` 进 ResourceCache 的纹理/场景（main_menu 单张 3–5 MB PNG），属引擎侧缓存，通常不计为泄漏，但值得观察；
  5. Tween / `SceneTreeTimer`：由 SceneTree 拥有，正常不应泄漏，**基本可排除**（`scripts/hud.gd:315/323/395`、`autoload/game.gd:154/161/168/303` 等）。
- **问题**：该警告只在 debug/编辑器构建退出时由 `ObjectDB::cleanup()` 打印，含义是"退出时仍有 Object 未被释放"。它**不等于**资源泄漏/显存泄漏，但可能是真实的引用滞留（尤其是全局缓存类对象）；如果泄漏的是场景节点，则说明有 `queue_free` 未执行。
- **后果**：目前影响很小（release 不打印），但会掩盖真正的问题——一旦以后出现"切场景后内存持续上涨"，这条警告是唯一线索之一；另外它与 A-05/A-06 的重构（输入注册、音频、字体）直接相关，值得顺手解决。
- **重构方案（复核流程，不改原项目）**：
  1. 复制一份项目到临时目录，原项目零改动：
     ```powershell
     Copy-Item -Recurse E:\godot_game_by_fable\001 $env:TEMP\nz_probe
     ```
  2. 用 `--verbose` 跑，退出时会打印 `Leaked instance: <Class> (<id>)` 列表：
     ```powershell
     godot --headless --path $env:TEMP\nz_probe --verbose --quit-after 5
     ```
  3. 依次跑空场景（只保留 Game autoload）→ main_menu → intro → level_1，比较泄漏类名集合；再在副本里注释 `_register_inputs()`（`autoload/game.gd:91`）或 `world_font`（`autoload/game.gd:96-98`）做二分。
  4. 若类名是 `InputEventKey`/`InputEventMouseButton` → A-06（输入写进 project.godot）即可消除；若是 `SystemFont`/`FontFile` → A-17（打包字体）可消除；若是 `AudioStreamWAV` → 检查退出时是否停音频；若是 `Node`/`GpuParticles3D`/`Label3D` → 用 `--verbose` 的 instance id 配合编辑器 Debugger 的 `print_orphan_nodes()` 定位未释放的一次性特效节点（例如 `Game.burst` 的 `queue_free` 定时器未触发就退出）。
  5. 记录修复前后 `Performance.get_monitor(Performance.OBJECT_COUNT)` 的差值，作为验收。
- **优先级**：P2　**工作量**：小（定位 + 小改）

---

### A-22 其他一致性问题

- **位置与问题**：
  1. `scripts/main_menu.gd:289`、`scripts/intro.gd:154` 调 `set_process_input(false)`：`main_menu` 根本没有 `_input()`（只有 `scripts/hud.gd:403`、`scripts/intro.gd:118` 有），`main_menu:289` 是死代码；
  2. `scripts/hud.gd:329` 底栏操作提示、`scripts/main_menu.gd:317-332` 操作面板、`scripts/level_1.gd:340-383` 8 条 3D 提示：同一份键位文案在三处维护（A-06 会统一）；
  3. `scripts/hud.gd:167/193` 技能键帽 `Q`/`E` 硬编码；
  4. `scripts/boss_maw.gd:327-330`：先用 `player.global_position` 赋 `_sweep_dir`，下一行又用 `signf(home_pos.x - player.global_position.x)` 覆盖，第一行是死代码；
  5. `scripts/enemy_shooter.gd:121-123`：用 `signf(want) * 0.5` 预判 `next_x` 是否越界，`want` 为 0 时 `signf(0)=0` 判不出界；窄小场地里贴边可能抖动；
  6. `scripts/level_1.gd:55` `Game.souls = 0`：关卡重置全局单例状态（分层违规，A-05）；
  7. `scripts/main_menu.gd:174-181`：`btn.pivot_offset = btn.size / 2.0` 在 `mouse_entered` 里设置，此时 scale tween 已开始，首帧缩放锚点错误（视觉小瑕疵）；应在 `_ready()`/`resized` 时设置；
  8. `scripts/level_1.gd:1104-1115`：`_zone_stops` 四元数组靠下标读，新增一列要改 4 处（A-10 的 `ZoneStop` 会解决）；
  9. 未使用的资产：`art/sprites/*_3d.png` ×4（3.26 MB，A-19）；
  10. 工作区根目录 `001\_dsh_probe.gd` 是评审探针，不是项目代码，提交前删除。
- **重构方案**：随 A-06（键位提示统一）、A-10（区域数据 Resource）、A-05（全局状态归属）一起处理即可；第 1/4/7 条各自 10 分钟。
- **优先级**：P2　**工作量**：小

---

## 2. 做得好的地方（5 条）

1. **程序化音效合成，零音频资产依赖**（`autoload/game.gd:353-486`）：22 050 Hz 下手写 `_sweep`（扫频+包络）、`_noise_burst`（低通噪声）、`_mix`，合成出 21 条音效 + 8 秒环境循环 + 16 秒五声音阶主题；`play_sfx` 还带 ±6% 随机音高（`autoload/game.gd:320`）避免机械重复。这是本项目最"聪明"的一块，也直接支撑了 A-05 里"挪到离线烘焙"的低成本改造。
2. **三级渲染兜底（GLB → 立绘精灵 → 程序化网格）**：`scripts/player.gd:90-103`、`scripts/boss_maw.gd:52-63`、`scripts/enemy_crawler.gd:35-52`、`scripts/enemy_shooter.gd:35-56`。任意一级资产缺失都还能跑，这让"AI 生成 3D 模型"这种高风险资产流程没有卡死开发——值得保留，只是应该抽象（A-09）。
3. **命中反馈组合成体系**：hitstop + 震屏 + 白闪 + 伤害数字 + 粒子 + 音效这套"打击感六件套"在 `Game` 里封装成可复用的调用（`hitstop` 177-182、`shake` 185-186、`flash_meshes` 217-240、`burst` 243-286、`spawn_dmg_text` 289-308），调用点很一致（`scripts/player.gd:626-632`、`scripts/enemy_base.gd:126-129`、`scripts/boss_maw.gd:378-383`）。后续拆成 `HitFeedback.impact()` 只是搬家，不是重写。
4. **分区氛围用数据表驱动**：`scripts/level_1.gd:28-37`（4 段"雾色/环境光/体积雾反照率"）配合 `_update_zone_ambience`（`1099-1123`）做平滑插值——整关从月光青渐变到深渊红紫只需改这张表；另加 `_build_whale/_build_fish_school`（461-517）的远景动态生物。这是"程序化生成用在正确的地方"的示范。
5. **零第三方依赖、极强的可运行性**：16 个脚本 5300 行 + 5 个 shader + 1 个 Theme + 4 个 GLB，没有 addon、没有网络/数据库依赖，`godot --headless` 三场景都能跑；美术/音频/字体缺失都有兜底。缺点是"太自包含"（所有东西挂在 `Game` 与两个千行文件上），优点是任何一台机器 clone 下来就能跑——这正是后面所有重构可以安全进行的基础。

---

## 3. 重构路线图

> 排序原则：先建立"可回滚 + 可出包"的安全网（P0 基建），再改会大范围触碰代码结构的部分（场景化/拆单例），最后补产品质量项（存档/设置/本地化/测试）。**阶段 0 不完成，不要开始阶段 2 的大拆。**

### 阶段 0 · 一周内（安全网，1–2 天可全部完成）

| # | 事项 | 对应发现 | 验收标准 |
|---|---|---|---|
| 0.1 | `git init` + 首次提交 + `git tag baseline`（含 LFS 决策） | A-01 | `git log` 有提交；故意删一个文件能 `git checkout --` 恢复；`git status` 干净 |
| 0.2 | 加 `export_presets.cfg` + `config/version` | A-02 | `godot --headless --export-release "Windows Desktop"` 产出可双击运行的 exe；窗口标题/图标正确 |
| 0.3 | 写 10 行 `README.md`（怎么跑、怎么导出、目录说明、Godot 版本）+ `art/README.md` 资产规格 | A-19 | 新人/新 AI 只看 README 能跑起来并知道资产要求 |
| 0.4 | `art/raw/.gdignore`；删 4 个未引用 `*_3d.png`；补 `nezha_jump.png`/`crawler_lunge.png` 或从代码移除引用 | A-12/A-19 | 导出体积下降 ≥15 MB；`validate_assets` 清单无缺失 |
| 0.5 | 用副本 + `--verbose` 定位 ObjectDB 泄漏并修复 | A-21 | `--verbose` 退出无 `Leaked instance` |
| 0.6 | 冒烟测试脚本 `tools/smoke_test.gd` + 一条命令跑三场景 | A-16 | 本地一条命令 <60 秒通过；故意改坏脚本能变红 |

### 阶段 1 · 一个月内（架构主干，按顺序）

| # | 事项 | 对应发现 | 验收标准 |
|---|---|---|---|
| 1.1 | 输入映射写进 `project.godot` + 手柄 + 键位提示从 InputMap 生成 | A-06 | Project Settings 的 Input Map 可见全部 action；手柄可完整通关；改键后 HUD/提示自动更新 |
| 1.2 | 拆 `Game`：`Events/AudioDirector/SceneRouter/GameState` + `VfxFactory/MaterialLib/HitFeedback`；音效改离线烘焙；保留 `Game` 门面过渡 | A-05 | `Game` ≤ 50 行纯转发；`player.gd` 中 `Game.` 调用从 87 降到 <20；启动无音频合成耗时 |
| 1.3 | 玩家状态机 enum + 动作表（方案 A），对外 `state_changed` 信号 | A-07/A-08 | 新增一个动作只改 1 个表项 + 1 个分支；HUD/关卡不再读 `player._ring_out`/`act` 字符串 |
| 1.4 | 场景化第一批：`player.tscn`、`enemy_crawler.tscn`、`enemy_shooter.tscn`、`boss_maw.tscn` + `ActorVisual`/`VisualProfile` | A-03/A-04/A-09 | 编辑器打开 `level_1.tscn` 能看到角色/敌人实例；美术能在 .tscn 里换模型/贴图，不改代码；敌人参数在 Inspector 可调 |
| 1.5 | 场景化第二批：莲台/封印门/瓮/浮桥/拾取/传送门/提示 Label3D/HUD/环境 | A-04 | `level_1.gd` 的 `_add_checkpoint/_make_gate/_add_pickup` 等生成函数删除；摆位在编辑器完成 |
| 1.6 | 转场锁 + async 存活保护 + 同属性单一写入者 | A-13 | 连点"返回主菜单"10 次只发生一次转场；Boss 死亡→传送门在玩家死亡/重开后不串 |
| 1.7 | 存档 + 设置 | A-14/A-15 | 退出重进可从检查点继续；音量/全屏/画质/改键生效并持久化 |

### 阶段 2 · 长期（1–2 个月，产品质量与可维护性）

| # | 事项 | 对应发现 | 验收标准 |
|---|---|---|---|
| 2.1 | 拆 `player.gd`/`level_1.gd` 为组合子节点（visual/combat/actions/locomotion、terrain/decor/encounters/ambience） | A-11 | 所有脚本 <400 行；`player.gd` 只剩生命周期/输入意图/受击入口 |
| 2.2 | 数值资源化：`PlayerStats/EnemyProfile/BossProfile/LevelConfig/ZoneStop` + `PhysicsLayers` + 调色板 | A-10/A-20 | 调伤害/速度/坐标/颜色只改 `.tres` 或场景 Inspector，不改 `.gd`；难度档可作为 `.tres` 变体 |
| 2.3 | 本地化（`tr()` + `.po` + 打包字体 + 语言切换） | A-17/A-18 | 切到 `en` 后 UI/剧情/提示全部英文；字体在三平台一致 |
| 2.4 | 测试与 CI 完整化：GUT 单元测试（伤害/状态机/存档/数值表）+ headless 冒烟 + 自动导出 | A-16 | CI 2 分钟内跑完测试与导出；改坏一个公式/一次状态转移即红 |
| 2.5 | 资产管线自动化：`asset_pipeline.py`（raw→sprites→glb 校验）+ `validate_assets.gd` + 资产清单文档 | A-12/A-19 | 新资产按清单命名放对目录即被自动校验/引用；缺失资产使 CI 失败 |
| 2.6 | 第二章的结构准备：`LevelConfig` + `ChapterDef` + 场景继承（`level_base.tscn`）+ 存档解锁 | A-03/A-14 | 新增第二章 = 新 `.tscn` + 新 `.tres` + 新敌人 `.tscn`，不改主干代码 |

**建议的第一个提交序列**（每步都可独立回滚）：`git tag baseline` → 导出预设 + README（阶段 0）→ 冒烟测试 → 输入映射 → `Game` 拆分 → 场景化 player → 场景化敌人 → props → 状态机 → 存档/设置 → 拆文件/数值 → 本地化/测试/CI。

---

## 4. 附录：复核方式与本次评审边界

- **本次评审未做**：未运行 Godot（因此 A-21 的泄漏原因未复现确认，仅给排查流程）、未修改项目任何文件、未初始化 git、未安装任何插件。
- **可复现的只读复核命令**（均在项目根执行，不改文件）：

```powershell
# 场景"空壳"证据
Get-Content E:\godot_game_by_fable\001\scenes\level_1.tscn
# 工程事实
Test-Path E:\godot_game_by_fable\001\.git            # False
Test-Path E:\godot_game_by_fable\001\export_presets.cfg  # False
Select-String -Path E:\godot_game_by_fable\001\project.godot -Pattern '^\[input\]'   # 无结果
Select-String -Path E:\godot_game_by_fable\001\scripts\*.gd,E:\godot_game_by_fable\001\autoload\*.gd -Pattern 'PackedScene|preload\(|@export|tr\(|user://|ConfigFile'   # 0 结果
# 真实行数（与编辑器一致）
$f='E:\godot_game_by_fable\001\scripts\player.gd'; [IO.File]::ReadAllLines($f).Length   # 1083
# 缺失资产（A-12）
Test-Path E:\godot_game_by_fable\001\art\sprites\nezha_jump.png       # False
Test-Path E:\godot_game_by_fable\001\art\sprites\crawler_lunge.png    # False
```

- **复核注意事项**：`Get-Content <file> | .Count` 在这台机器对这 4 个大文件会少统计约 2%（`player.gd` 报 1056 行，实际 1083 行），引用行号时请用 `[IO.File]::ReadAllLines()` 或编辑器行号。
- **建议的下一次评审**：A-01～A-07 完成后，再评审一次"场景化后的节点数/draw call 是否恶化"与"拆分后的状态机可读性"；性能/画面层的问题见同目录 `03-performance-visual.md`，玩法/手感层见 `01-combat.md`。
