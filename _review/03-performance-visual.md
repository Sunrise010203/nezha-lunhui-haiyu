# 《哪吒·轮回海域》性能 / 渲染 / 画面与 UX 评审

评审对象：`E:\godot_game_by_fable\001`（Godot 4.6.3 stable，Forward+，D3D12，MSAA 2x，体积雾开启）
评审方式：**静态数数 + 引擎内插桩实测 + 截图逐像素测量**（只读，不改任何项目文件；实测在项目副本上做，见附录 A）
实测机：NVIDIA RTX 5070 Laptop / D3D12 / Windows；窗口 2560×1494（最大化，`window/size/mode=2`）
截图：`shot_v4_start.png`、`shot_v4_boss.png`、`shot_v4_menu.png`、`shot_v3_mid.png`、`shot_fx_boss.png`、`shot_level_boss.png`、`shot_m_*.png`

标记约定：**【实测】**= 引擎内 Performance 监视器 / 插桩打印的真实数字；**【静态】**= 数代码调用点与循环次数得到的估算；**【截图】**= 对 2560×1494 截图做像素级测量的结果。

---

## 0. 实测基线（先看数字）

### 0.1 场景规模【实测，起点区，Boss 未激活】

| 指标 | 数值 | 说明 |
|---|---|---|
| `MeshInstance3D` 总数 | **413** | 与静态估算 408–413 完全吻合 |
| `OmniLight3D` 总数 | **27** | 玩家 1 + 检查点 3 + 露灯 5 + 水晶 4 + 拾取物 5 + 爬行者 5 + 浮母 3 + Boss 1 |
| `GPUParticles3D` 总数 | **12–13** | 灵尘 3 + 玩家火苗 2 + 爬行者滴液 5 + Boss 光环 1 + 闸门 2 |
| `Label3D` 总数 | **8** | 全部是 `_hint()` 的世界内提示 |
| Draw call / 帧 | **375–384** | 其中 **约 304 来自平行光阴影 pass**（关闭阴影后只剩 71） |
| 三角形 / 帧 | **806k** | 关闭阴影后只剩 **103k**（阴影 pass 占 703k ≈ 87%） |
| 3D 渲染分辨率 | **3414×1993（6.8 MP）** | 窗口只有 2560×1494，存在 **1.33× 隐性超采样** |
| 显存占用 | **799 MB** | 关 MSAA 后 652 MB；开 SSAO 后 892 MB |
| 帧时间（RTX 5070 Laptop） | **avg 14.0 ms / p50 13.9 / p95 14.6** | 起点区；Boss 区 avg 10.3 ms 但 **max 94.4 ms** 单帧尖峰 |
| Boss 区三角形 / 帧 | **1.83 M** | 是起点区的 2.3 倍 |

### 0.2 构建耗时【实测，`Time.get_ticks_msec()` 插桩】

| 阶段 | 耗时 |
|---|---|
| `Game._build_audio()`（每次启动，含菜单） | **431–455 ms**（GDScript 逐采样合成 750k+ 样本） |
| `level_1._ready()` 合计 | **519–563 ms** |
| ├ `_build_decor()` | 128–154 ms |
| ├ `_build_enemies_and_logic()` | 178–282 ms（加载/实例化 4 个 GLB 模型） |
| ├ `_build_boss_arena()` | 72–130 ms |
| ├ `_build_hud()` | 67–109 ms |
| └ 其余（环境/水/玩家/地形） | 3+4+29+14 ms |

> 结论：**进关卡前有约 1 s 的确定性卡顿**（引擎启动 1.2 s + 关卡构建 0.55 s），重开关卡时还会再付一次关卡构建成本；这是玩家能直接感知的。

### 0.3 对任务简报中几处事实的修正（重要）

1. **玩家不是 2 盏 Omnilight，而是 1 盏**（`player.gd:267-273`，模型模式；程序化兜底路径 `player.gd:212-218` 同样只有 1 盏）。传送门另加 1 盏，仅 Boss 战后出现。
2. **体积雾 GI 并没有开**：只设了 `volumetric_fog_ambient_inject=0.4`（`level_1.gd:128`），`volumetric_fog_gi_inject` 保持默认 0——所谓“体积雾 GI 全开”不成立，真正的开销来自 **27 盏 OmniLight 全部以默认 `light_volumetric_fog_energy=1.0` 往雾里注入光**。
3. **实测体积雾开关几乎无差别**（fog_off 13.91 ms vs baseline 14.04 ms，在噪声内）——它**不是当前瓶颈**，不要为它牺牲画面（详见 C-01）。
4. **角色屏高不是 10%**：按 `z=10.2`、`FOV 50` 的相机数学，1.9 m 角色在 1080p 设计分辨率下应占 **≈19%**（≈205 px/1080）；截图实测主体连线约 **250 px/1494 ≈ 16.7%**（含飘带），但**站在莲台上时可见剪影只有 ~150 px ≈ 13–15%**——观感“小”的主因是**被莲台花瓣吞掉下半身 + 下半屏全是平台前脸**，不是角色真的只有 10%（详见 D-05、D-09）。
5. **退出泄漏来自音频，不是 Tween/粒子**（见 B-08，实测只泄漏 2 个对象）。

---

## A. 性能 / 渲染开销

### A-01 平行光阴影 Pass 吃掉了 80% 的 draw call 和 87% 的三角形

- 位置：`scripts/level_1.gd:138-145`（`sun.shadow_enabled = true`，PSSM 默认 4 级），`scripts/level_1.gd:147-151`（第二盏无阴影平行光）
- 问题：场景里 400+ 个装饰 MeshInstance 全部默认 `cast_shadow=ON`（`Game.add_mesh()` 从不设 `cast_shadow`，`game.gd:204-214`）。4 级 PSSM 每一级都会把落在该级范围内的投影体重画一遍；而侧视相机视野只有约 16.6 m 宽，**主 pass 只画 71 个 draw call，阴影 pass 却画了 304 个**——阴影级联的覆盖范围远大于实际可见范围，属于纯浪费。
- 量化【实测】：关阴影后 draw call **375 → 71（−81%）**、三角形 **806k → 103k（−87%）**、帧时间 14.04 → 13.38 ms（5070 上只省 0.66 ms，因为 5070 填充/几何吞吐很强；**在 GTX 1060/1650 这一档会省 3–5 ms**）。截图里阴影本身几乎不可见（只有角色脚下一团淡影），性价比极低。
- 改法：
  1. 最省事：`sun.shadow_enabled = false`，靠 `vignette` + 体积雾 + 接触阴影贴图式假 AO 补层次；
  2. 保留阴影则：`sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL`、`sun.directional_shadow_max_distance = 30`、`sun.shadow_bias` 调好，只让 **玩家/Boss/敌人** 投影，装饰统一 `mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF`（可在 `Game.add_mesh()` 里默认关闭，另开一个 `add_mesh_cast()` 给需要投影的对象）；
  3. 背景柱/巨环/海草/浮岩/瓮这些 100% 不需要投影。
- 优先级 **P0**，工作量 **小**

### A-02 初始 8 个敌人的模型合计约 123 万三角形，且不设 LOD 偏置/可见距离/阴影开关

- 位置：`scripts/enemy_crawler.gd:36`、`scripts/enemy_shooter.gd:36`、`scripts/boss_maw.gd:53`、`autoload/game.gd:29-81`
- 问题：AI（TripoSR 类）导出的 GLB 面数完全没减：**crawler 159,116 tris / shooter 260,764 tris / boss 196,136 tris**（GLB JSON 实测），玩家 24,252 tris。初始 5 只爬行者 + 3 只浮母 = **636k + 782k ≈ 1.42 M tris**，且它们在 `_ready` 里全部实例化进树，没有 `visibility_range_end`、没有 `lod_bias`、没有按距离降级。Boss 区实测 **1.83 M tris/帧**。
- 量化【实测+静态】：Boss 区帧三角形 1.83 M（起点 0.81 M）；4 个模型纹理各 1024²、导入后 1.6–1.9 MB/张；`video_mem` 799 MB。若关掉阴影投射，模型只参与主 pass，可立刻砍掉约 87% 的模型三角形。
- 改法：
  1. `Game.load_model()` 返回后统一设置：`mi.cast_shadow = SHADOW_CASTING_SETTING_OFF`（Boss/精英除外）、`mi.lod_bias = 1.5`、`mi.visibility_range_end = 28.0`（爬行者/浮母）、`mi.extra_cull_margin = 0.5`；
  2. 导入时用 Blender/gltf-transform 做 **decimate 到 15–25k tris**（这类 AI 模型在 1080p、角色只有 20% 屏高的情况下，2.5k–8k tris 已足够；159k→20k 是 8 倍差距）；
  3. 或者干脆切回已经准备好的 **立绘 Sprite3D 路径**（`player.gd:100-103`、`enemy_crawler.gd:48-52`、`enemy_shooter.gd:47-51`、`boss_maw.gd:59-62` 都写了，只是因为 GLB 存在而永远走不到）——在 2.5D 侧视里这是最划算的方案。
- 优先级 **P0**，工作量 **中**

### A-03 27 盏 OmniLight 全部注入体积雾，且没有一盏做距离淡化

- 位置：`scripts/level_1.gd:565-572`（水晶灯）、`scripts/level_1.gd:619-624`（露灯）、`scripts/level_1.gd:713-719`（检查点灯）、`scripts/pickup.gd:48-53` 与 `68-73`（拾取物灯）、`scripts/projectile.gd:33-38`（投射物灯）、`scripts/ring_throw.gd:28-33`（乾坤圈灯）、`scripts/player.gd:267-273`（玩家灯）、`scripts/boss_maw.gd:156-161`（Boss 灯）
- 问题：这些灯全部只设了 `shadow_enabled=false`，**没有设 `light_volumetric_fog_energy`（默认 1.0）**，也没有 `distance_fade_enabled`。Forward+ 下每盏灯都会进 cluster、并且**参与体积雾的逐 froxel 光注入**；投射物灯还每帧移动，在 64³ 的雾体积里会有时间性拖影/闪烁。
- 量化【实测】：常驻 **27 盏**；Boss 弹幕时实测 **29 盏**（同时 2 发投射物存活）。最坏情况：4 发扇形弹 + 2 发冲击波 + 乾坤圈 + 新星闪光 + 4 只召唤物 = **27 + 12 ≈ 39 盏同时存在**。体积雾 froxel 数默认 64³ = 262k，每盏灯都要参与局部注入。
- 改法：
  ```gdscript
  # 通用：装饰灯一律不进雾
  light.light_volumetric_fog_energy = 0.0
  light.distance_fade_enabled = true
  light.distance_fade_begin = 22.0
  light.distance_fade_length = 8.0
  ```
  只保留 Boss 灯（0.4）与玩家灯（0.25）注入雾；拾取物灯的 5 盏合并成“只保留 SOUL 的 3 盏”；水晶灯 4 盏 → 2 盏并调大 `omni_range` 替代数量。
- 优先级 **P1**，工作量 **小**

### A-04 413 个 MeshInstance 里约 130+ 个是“一次性 new 出来的材质/网格”，主 pass 无法合批

- 位置：`scripts/level_1.gd:575-591`（**每株海草 `Game.std_mat()` 新建一个材质，30 株 = 30 个材质**）、`scripts/level_1.gd:607-626`（每盏露灯 1 个材质 = 5）、`scripts/level_1.gd:700-712`（每个检查点花瓣/核心各 1 个 = 6）、`scripts/level_1.gd:686-754` 的 `beam_mat`（每个检查点 1 个 = 3）、`scripts/pickup.gd:23-73`（每个拾取物 1–2 个 = 初始 12）、`scripts/breakable.gd:19-22`（每个瓮 2 个×10 = 20）、`scripts/level_1.gd:520-536`（每根柱子 new 一个 `CylinderMesh`，26 个）、`scripts/level_1.gd:594-604`（12 块浮岩 new 一个 `SphereMesh`）
- 问题：`add_mesh()` 一律走 `material_override`（`game.gd:208`），因此**即使网格相同也无法自动实例化**；而网格本身也大多是每个对象 new 的（每根柱子、每株海草、每块浮岩、每个瓮都是独立 `Mesh` 资源）。只有符文砖（同平台共用 1 个 `BoxMesh`）、珊瑚刺（18 根共 1 个）、莲瓣（8 片共 1 个）、鲸鱼光斑（7 个共 1 个）能真正 instancing。
- 量化【实测+静态】：
  - MeshInstance3D 分布：主平台 34（6×(2)+符文砖 22）、浮台 21、碎裂浮桥 8、珊瑚刺 18、背景柱 ≈42、海草 ≈90、浮岩 12、水晶 ≈30、渊晶瓮 50、检查点 33、露灯 5、巨环 2、巨涡 5、鲸 12、鱼 7、拾取物 22、闸门 6、背景画 2、水面 1、玩家装备 4、AI 模型 4（+ 各自多 surface）→ **合计 ≈408–413，实测 413**。
  - 独立 `StandardMaterial3D` 静态 ≈ **131 个**（9 共享 + 海草 30 + 瓮 20 + 拾取物 12 + 莲台 9 + 浮桥 8 + 海草外的零碎 ≈ 43）。
  - 主 pass 在起点只有 **71 draw call**（大部分被视锥裁掉，说明视锥裁剪本身没问题），但一旦进入 Boss 区、或关了阴影后进入密集区，材质数会直接转化为 draw call。
- 改法：
  1. `_decor_kelp` 把材质提到 `_make_materials()` 里做成 1 个共享 `mat_kelp`；
  2. 瓮的 5 个网格提到 `Breakable` 的 `static var`/预加载资源里共享；
  3. 背景柱/海草改用 `MultiMeshInstance3D`（柱子 26 根 → 1 个 MultiMesh，海草 ≈90 根 → 1–2 个 MultiMesh）；
  4. 符文砖/珊瑚刺/莲瓣已经共享网格，只需把材质保持共享即可。
- 优先级 **P1**，工作量 **中**

### A-05 启动 0.43–0.45 s 用于 GDScript 逐采样合成音频（每次启动都付）

- 位置：`autoload/game.gd:337-350`（`_build_audio`）、`413-444`（`_build_sounds`）、`447-465`（8 s 环境音，176,400 样本）、`468-486`（16 s 主题，352,800 样本）
- 问题：所有音效/环境音/主题都在 `Game._ready()` 里用 GDScript 循环逐样本算 `sin/exp/randf` 再 `encode_s16` 写 `PackedByteArray`。合计约 **75 万样本**，每样本 3–5 次三角函数/指数 + 一次编码。这段代码在**主菜单出现之前**跑，直接表现为启动白屏/黑屏卡顿。
- 量化【实测】：`game_build_audio_ms = 431–455 ms`；引擎启动总耗时 1.22 s。另外 `_wav()` 每次 `bytes.resize(n*2)` + `encode_s16`（`game.gd:353-367`）也有一次大分配。
- 改法（按性价比）：
  1. 把合成结果**离线烘成 3–4 个 `.wav` 资源**（现在每次启动都重算，完全没有必要）；
  2. 至少把 `_build_audio()` 延迟到主菜单显示之后（`await get_tree().process_frame` 分帧合成），或只合成 UI/跳跃这几个即时需要的；
  3. 环境音/主题可以直接用更短的循环（8 s → 4 s）并预生成。
- 优先级 **P1**，工作量 **小**

### A-06 关卡构建 0.52–0.56 s，且每次重开关卡都重付

- 位置：`scripts/level_1.gd:51-65`（`_ready` 串行 `_build_*`）、`scripts/level_1.gd:881-896`（8 个敌人）、`scripts/level_1.gd:927-937`（Boss）
- 问题：装饰 128–154 ms、敌人 178–282 ms、Boss 72–130 ms、HUD 67–109 ms 全部同步执行；`hud.restart_callback` 与死亡后“重新挑战”都走 `Game.change_scene()`（`level_1.gd:218-219`），整关重建。
- 量化【实测】：`level_1._ready() = 519–563 ms`；其中敌人部分 178–282 ms 主要花在 `Game.load_model()`（每个敌人 `load()`+`instantiate()`+遍历 AABB）。
- 改法：装饰/海草/浮岩分帧构建（每构建 30 个对象 `await get_tree().process_frame`）；敌人模型用 `preload()` 缓存 `PackedScene` 并复用；重生逻辑改成“复用同一关”而不是 `change_scene`（把玩家移回检查点即可，已有 `_respawn_full()`）。
- 优先级 **P2**，工作量 **中**

### A-07 运行时第一次出现的材质/粒子会造成 ~94 ms 单帧卡顿（D3D12 管线编译）

- 位置：`autoload/game.gd:243-286`（`burst()` 每次 new 6 个资源）、`scripts/projectile.gd:21-38`（弹幕首次生成时 new 材质/网格）、`scripts/boss_maw.gd:374-397`（砸地冲击波）
- 问题：Boss 战实测 **max frame = 94.44 ms**（其余帧 p50 12 ms），出现时机正好在 Boss 第一次弹幕/砸地时——这是 D3D12 首次遇到新 shader 变体/粒子 draw pass 的编译停顿，而不是 GC。
- 量化【实测】：Boss 区 avg 10.25 ms、p50 12.05、p95 15.28、**max 94.44**。
- 改法：在 `level_1._ready()` 末尾做一次“特效预热”：在屏幕外（`Vector3(0,-100,0)`）为每种颜色各生成 1 个 `burst`、1 个 Projectile、1 个 RingThrow、1 个 nova 光环，等 2 帧后 `queue_free()`。这样管线在加载黑屏期间就编译完。
- 优先级 **P0**（战斗中 94 ms 卡顿非常明显），工作量 **小**

### A-08 水面网格 10,240 三角形 + 每个顶点 12 次 sin，且始终可见

- 位置：`scripts/level_1.gd:155-165`（`subdivide_width=160`、`subdivide_depth=32`）、`shaders/water.gdshader:20-31`
- 问题：700×140 米的水面一次性铺满整关，它是一整块 mesh，**任何时刻都在视锥里**，永远要画满 5,120 个四边形（10,240 tris），而起点区关阴影后的主 pass 总共只有 103k tris——**水面一个人占了 10%**。顶点着色器里 `wave()` 被调用 3 次（法线用两次差分），每次 4 个 `sin`，即 **12 sin/顶点**。
- 量化【实测+静态】：10,240 tris / 主 pass 103k tris ≈ **10%**；顶点 5,000+ 个 × 12 sin ≈ 6 万次三角函数/帧。
- 改法：`subdivide_width 160→96`、`subdivide_depth 32→16`（→ 3,072 tris，−70%）；法线改用解析导数或 2D 噪声纹理；波浪频率降低。远处水面用低模 LOD 或直接换成一张滚动法线贴图的平面。
- 优先级 **P2**，工作量 **小**

---

## B. 每帧分配 / 对象生命周期

### B-01 `Game.burst()`：每次命中/受击/落地/死亡都新建 7 个对象 + 1 套 GPU 粒子系统

- 位置：`autoload/game.gd:243-286`
- 问题与量化：一次调用 new 出 **7 个对象**：
  1. `GPUParticles3D`（Node，进树）
  2. `ParticleProcessMaterial`
  3. `Gradient`
  4. `GradientTexture1D`
  5. `SphereMesh`
  6. `StandardMaterial3D`（`vertex_color_use_as_albedo` + unshaded + alpha）
  7. `SceneTreeTimer`（`game.gd:286`，延迟 `life+0.5` 后 `queue_free`）
  外加 GPU 侧：粒子系统 RID、`amount` 大小的粒子缓冲、draw pass 网格缓冲。`count` 越大缓冲越大（新星 60+30、死亡 50+30、Boss 死亡 4×40+60）。
- 量化：**7 个对象/次**；一次 30 秒 Boss 战 80–120 次 burst ⇒ **560–840 个对象 + 80–120 个 GPUParticles3D**。
  调用点密度：普攻每次起手 1 发（8/14 粒）、重击 1 发（20）、下砸 1 发（26）+ 新星 2 发（60+30）、跳跃/冲刺/落地各 1 发、每次 Enemy 死亡 2 发、每次 per-hit 灼烧 tick 1 发（6 粒，`enemy_base.gd:106`）、弹幕命中/落地各 1 发。**一次 30 秒 Boss 战轻松 80–120 次 burst ⇒ 560–840 个对象 + 80–120 个粒子系统**。
- 改法：做 4 色（火/紫/青/金）**对象池**，每色预建 6 个 `GPUParticles3D`（共享同一个 `SphereMesh` + 材质、同一个 `ParticleProcessMaterial`），复用时只改 `position`、`amount`、`emitting=true`，用 `finished` 信号或计时器归还；`Gradient/GradientTexture1D` 每色只建一次。
- 优先级 **P1**，工作量 **中**

### B-02 每次命中 ≈ 10 个新对象（flash + 飘字 + 斩击环）

- 位置：`autoload/game.gd:217-240`（`flash_meshes`）、`289-308`（`spawn_dmg_text`）、`scripts/player.gd:666-689`（`_slash_fx`）、`scripts/enemy_base.gd:117-132`
- 问题与量化：一次 `take_damage` 的分配链：
  - `flash_meshes`：**1 个 `StandardMaterial3D`** + `find_children()` 返回的 2 个数组 + **1 个 `SceneTreeTimer`**（`await create_timer`）+ 每个 MeshInstance 一次 meta 读写；
  - `spawn_dmg_text`：**`Label3D` 节点** + Label3D 内部生成的 **TextMesh/ArrayMesh + 材质** + **1 个 `Tween`**；
  - 玩家的 `_slash_fx`（每次挥击命中都会调）：**`TorusMesh` + `StandardMaterial3D` + `MeshInstance3D` + `Tween`**。
  ⇒ **≈10 个对象/命中**，其中 2 个是 Node、8 个是 Resource/Tween。三连击 + 重击一轮 ≈ 4 次命中 ≈ 40 个对象；Boss 战 60 次命中 ≈ 600 个对象。
  额外：`find_children("*", "MeshInstance3D", true, false)` 在玩家 `gfx` 上每次遍历约 30 个节点（24 根骨骼 + 装备），敌人 2–6 个，Boss 4–6 个。
- 量化：**≈10 个对象/命中**（2 个 Node + 8 个 Resource/Tween）；三连击+重击一轮 ≈40 个；Boss 战 60 次命中 ≈600 个。
- 改法：
  1. `flash_meshes` 的白色材质提成 `Game` 里的 4 色单例，不再每次 new；
  2. 伤害数字用 12–16 个 `Label3D` 池（改 `text/position/modulate` 而不是重建），或统一用一张位图字体图集 + `Sprite3D`；
  3. `_slash_fx` 的 Torus+材质做成共享资源（材质颜色动画改为 `scale` + 共享材质的 `albedo_color` 副本，或用一个 `GPUParticles3D` 池）。
- 优先级 **P1**，工作量 **中**

### B-03 `flash_meshes()` 用 `material_override` 覆盖一切：打断合批、把多材质模型压成纯色、丢失双面渲染

- 位置：`autoload/game.gd:217-240`
- 问题：
  1. 覆盖期间所有 `MeshInstance3D` 的材质变成同一个 `flash` 材质——**本来能 instancing/合批的网格被拆成独立 draw call**；至少 3 个敌人 + 玩家同时受击时影响明显。
  2. 对 GLB 模型是**多材质网格**（nezha 3 个 surface，`material_override` 会统一应用到所有 surface）——受击瞬间整个角色变成一块纯色，丢掉纹理/顶点色细节（90–140 ms）。视觉上像“剪影闪”，可以接受但要知道自己在做什么。
  3. **nezha 的 3 个导入材质 `doubleSided=true`，而 `load_model()` 替换的材质没有设 `cull_mode`，默认背面剔除**（`game.gd:51-55`）；受击闪白时飘带等单面片状几何会直接消失/翻面。
  4. 恢复逻辑本身**是正确的**：`add_mesh()` 每次都 `set_meta("base_mat", mat)`（`game.gd:212`），`load_model()` 对两种分支都设了 meta（有贴图 `null`，无贴图 vertex-color 材质，`game.gd:48-55`）；`get_meta("base_mat", null)` 能正确还原。**唯一没有 set_meta 的是程序化临时网格**（`player.gd:677-683` 的斩击环、`boss_maw.gd:356-361` 的预警圈、`player.gd:710-715` 的新星环），但它们从不进 `flash_meshes` 的遍历范围，所以目前安全。
- 量化：每次受击 1 个材质 + 全子树遍历；受击时玩家子树 ≈30 个节点、Boss ≈6 个。
- 改法：
  1. 给 `flash` 材质显式 `cull_mode = BaseMaterial3D.CULL_DISABLED`，并把 `flash` 缓存为单例（4 个颜色变体）；
  2. 更正统：所有角色材质统一换成 `ShaderMaterial`，加 `uniform float flash;` 与 `COLOR += vec3(flash)`，用 `mi.set_instance_shader_parameter("flash", 1.0)` 闪白——不打断合批、不丢材质；
  3. 至少改成 `material_overlay`（叠加层）而不是 `material_override`，保留原材质。
- 优先级 **P1**，工作量 **中**

### B-04 伤害数字：`Label3D` + `SystemFont` 每次重建，字号 96/64 且 `no_depth_test`

- 位置：`autoload/game.gd:289-308`（`world_font` 在 `96-98` 建，`font_size = 96 if big else 64`，`outline_size = 18`，`no_depth_test = true`），调用点 `enemy_base.gd:127-129`、`player.gd:1040-1041`、`1077-1078`、`1019-1021`
- 问题：每个数字都是一整个新 `Label3D`（含内部 TextMesh + 材质 + 字形四边形），且用 `SystemFont`（运行时从系统取字体，首次字形光栅化有一次性成本；之后复用字形缓存）。`font_size=96` + `outline_size=18` 意味着每个数字的光栅化面积是普通 UI 文本的 20+ 倍；`no_depth_test=true` 让它们永远盖在角色/敌人/UI 世界层之上，配合"受击 3 连击"很容易出现 5–8 个 96 px 数字同屏，视觉噪音大。
- 量化：每次 new **1 Node + 1 TextMesh + 1 材质 + 1 Tween ≈ 4 个对象**；每次命中 1 个。Boss 战 60 次命中 = 60 个 Label3D 生命周期。
- 改法：`Label3D` 池 + 位图字体（`FontFile` 预生成 SDF 或 1 张 PNG 图集）+ 字号统一 48，只有暴击/闪身才放大；关掉 `no_depth_test`（或改成 billboard + `render_priority`）。
- 优先级 **P2**，工作量 **中**

### B-05 `HUD.show_message()` 每次都新建 Tween 且不 kill 上一条，消息会互相打架

- 位置：`scripts/hud.gd:392-398`；调用点密集区 `level_1.gd:65, 765, 900, 921, 947, 953, 967, 1016, 1052`
- 问题：`show_message` 在 `_msg_label` 上 `create_tween()`，从不保留/`kill()` 旧 tween。两条消息间隔 < 1.2 s 时（例如“封印已解”紧跟“莲台已铭刻”，或 Boss 阶段切换 + 召唤提示），旧 tween 的 `modulate:a→0` 会把新消息提前淡出；新 tween 又同时写 alpha，最终淡入淡出曲线由两个 tween 竞争决定。
- 量化：每条消息 1 个 Tween；正常一局 20–30 条消息；叠加场景实测存在（Boss 阶段 2 切换时 `_enter_phase2` 无消息，但 `_do_summon` 与 `_on_boss_summon` 会在 1.1 s 内连发两条）。
- 改法：保存 `_msg_tween`，新消息前 `if _msg_tween: _msg_tween.kill()`；或改用 `AnimationPlayer` 单条动画重启。
- 优先级 **P2**，工作量 **小**

### B-06 空闲时 `_process` 的固定开销（可接受，但有几处可以省）

- 位置：`scripts/level_1.gd:1078-1096`（`_floaters` 全遍历 + `is_instance_valid`）、`1126-1146`（鲸 + 7 条鱼 + 每帧 3 次 `fposmod/sin` 三角）、`1099-1123`（每帧写 4 个 `Environment` 属性 + `_sun.light_color`）
- 问题：`_floaters` 约 **115 项**（2 巨环 + 90 海草 + 12 浮岩 + 5 露灯 + 4 涡 + 传送门后续），每帧 `match` 字符串比较 + `is_instance_valid`；`_update_zone_ambience` 每帧给 `fog_light_color / ambient_light_color / volumetric_fog_albedo / sun.light_color` 赋值，会每帧把 `Environment` 标脏并触发 uniform 上传。
- 量化：静态估算 115 项 × ~5 次属性访问 ≈ 600 次/帧；`Environment` 属性写入 4 次/帧。**这两个都不贵（<0.2 ms），但属于纯浪费**——它们完全可以 10 Hz 更新。
- 改法：`_floaters` 只保留真正需要的（海草摆动可换成顶点着色器 wind/材质 `TIME` 位移，或合并进一个 MultiMesh + shader）；`_update_zone_ambience` 用 `if Engine.get_physics_frames() % 6 == 0` 节流；已 free 的 floaters 在遍历时移除（现在 `continue` 但不清理，数组只增不减）。
- 优先级 **P2**，工作量 **小**

### B-07 HUD 每帧 `add_theme_color_override` 不会让字体/主题缓存失效，但仍然是坏习惯

- 位置：`scripts/hud.gd:351-369`（每帧对 `_skill_label`、`_skill2_label` 调 `add_theme_color_override("font_color", ...)`，每帧写 `_skill_fill.size/_skill_fill.position.y/_skill2_fill.*`）
- 问题与说明：Godot 4 的 `Control::add_theme_color_override()` 对**同值有早退**（`theme_override_colors` 里已存在且相等就直接 return，不触发 `_notify_theme_override_changed()`），所以**当前这段代码并不会每帧让主题/字体缓存失效、也不会每帧重排字形**。真正每帧产生脏标记的是 4 个 `ColorRect` 的 `size`/`position` 写入（各自 `queue_redraw`，只有 2 个小矩形，开销可忽略）。但一旦 `energy` 在阈值附近抖动，颜色切换会触发 `NOTIFICATION_THEME_CHANGED` → Label 重算最小尺寸/重绘。
- 量化：4 次字典查找+Color 比较/帧（≈0.01 ms）；跨阈值时 1 次主题通知。
- 改法：只在状态变化时调用（用 `var _last_ready := false` 缓存），`_skill_fill` 的尺寸改为 `scale.y` 或 `clip_children`，避免每帧改 layout 属性。
- 优先级 **P2**，工作量 **小**

### B-08 对象泄漏：**实测只有 2 个对象，来源是音频，不是 Tween/粒子/未入树节点**

- 位置：`autoload/game.gd:325-350`（`_ambient_player` / `_theme_player` 在退出时仍在播放）、`447-465`（8 s 环境音）
- 问题【实测】：用 `--headless --verbose` 跑 `level_1.tscn` 后退出，Godot 打印：
  ```
  Leaked instance: AudioStreamWAV:... - Reference count: 1
  Leaked instance: AudioStreamPlaybackWAV:... - Reference count: 1
  Orphan StringName: Master (static: 0, total: 2)
  ```
  即**只有 1 个 `AudioStreamWAV` + 1 个 `AudioStreamPlaybackWAV`**，原因是退出时 `_ambient_player` 还在播，AudioServer 关闭顺序导致 playback 仍持有 stream。**不是** Tween 持有、不是 `Game.burst` 的 `SceneTreeTimer`、不是 `RingThrow/Projectile`、不是 `Game.load_model` 的未入树 `queue_free`（这些路径我都逐一静态核对过，实测没有出现在泄漏列表里）。
- 量化：2 个对象 + 1 个 StringName；`AudioStreamWAV` 约 344 KB（8 s × 22050 × 16 bit）。
- 改法：
  ```gdscript
  func _exit_tree() -> void:
      if _ambient_player: _ambient_player.stop(); _ambient_player.stream = null
      if _theme_player: _theme_player.stop(); _theme_player.stream = null
      for p in _sfx_pool: p.stop(); p.stream = null
  ```
  或者监听 `NOTIFICATION_WM_CLOSE_REQUEST` 后延时一帧再 `get_tree().quit()`。
  附带说明一个**真实存在但不是泄漏源**的隐患：`game.gd:286` 用 `create_timer(life+0.5, false)` 延迟 `queue_free` —— 暂停菜单（`get_tree().paused = true`）时计时器不走，粒子会停在半空；`boss_maw.gd:362-366` 的 `set_loops()` Tween 绑在一个 `_clear_telegraph()` 会 `queue_free` 的临时节点上，靠节点释放来终止，建议显式 `kill()`。
- 优先级 **P2**，工作量 **小**

---

## C. 渲染 / 显示设置

### C-01 体积雾：不是瓶颈，别为它牺牲画面；**真正要关的是“灯往雾里注入”**

- 位置：`scripts/level_1.gd:117-128`
- 问题与实测：
  - `fog_enabled`（距离雾）+ `volumetric_fog_enabled` + `volumetric_fog_length=90` + `density=0.022` + `anisotropy=0.55`；
  - **A/B 实测：`volumetric_fog_enabled=false` 只从 14.04 → 13.91 ms（噪声内）**。在 64³ 体积、1080p 级别像素下，这套参数对 5070 基本免费；对弱卡会是 1–2 ms 级别，仍不是最大头。
  - 但 **27 盏 OmniLight 全部以默认 `light_volumetric_fog_energy=1.0` 注入雾**（只有平行光显式设了 `light_volumetric_fog_energy=1.4`，`level_1.gd:141`），这才是雾相关的主要可变成本，且会随投射物灯数量上升。
  - **`volumetric_fog_gi_inject` 保持默认 0，所谓“体积雾 GI”并没有开**；`ambient_inject=0.4` 很便宜。
- 量化：开/关 14.04 vs 13.91 ms（噪声内）；27 盏灯 × 默认注入 1.0；froxel 体积 64³ = 262k。
- 改法：体积雾保留（它是画面里最有效的空气感来源）；按 A-03 把装饰灯的 `light_volumetric_fog_energy=0`；`density 0.022→0.016`、`length 90→70`、`anisotropy` 保留 0.55（视觉不变，弱卡省一点）。
- 优先级 **P2**，工作量 **小**

### C-02 Glow 与本画面的“过曝叠加”：实测 −2 ms，且 2% 像素被裁白

- 位置：`scripts/level_1.gd:112-116`（`glow_intensity=0.7`、`bloom=0.05`、`hdr_threshold=0.9`）+ 大量 `emission_energy_multiplier` 1.3–4.0 的材质（`level_1.gd:73-74, 78-80, 614-615, 726-732`；`player.gd:674-677, 707-708`；`game.gd:223`）
- 问题与实测：
  - **A/B：`glow_enabled=false` 14.04 → 12.04 ms（−14%）**，是本场景**第二贵的后处理**（第一是阴影，第三是 MSAA）。
  - 阈值 0.9 配 1.3–4.0 的自发光，等于“几乎所有发光物都开花”。**截图统计：shot_v4_start 有 77,366 px（2.02%）、shot_v4_boss 有 35,628 px（2.4%）任一通道 ≥250（接近纯白）**——trim 线、莲台、月光、金色描边全部过曝。
  - MSAA 2x 与 glow 叠加：两者各自实测为 −1.76 ms（MSAA）与 −2.0 ms（glow）；单独关闭互不依赖，**同时关闭预计 −3.0 ~ −3.5 ms（非线性叠加，因为 MSAA 降低后 glow 的降采样也有收益）**。glow 的多级降采样 + 2× MSAA 的解析边缘会让两者成本叠加在同一帧预算里。
- 量化：glow 关 **−2.0 ms（−14%）**；1.3–4.0 自发光材质 ≥15 处；截图裁白像素 **2.0–2.4%**。
- 改法：`glow_hdr_threshold 0.9→1.25`、`glow_intensity 0.7→0.5`；把 trim/晶体/露灯的 `emission_energy_multiplier` 从 1.3–1.8 降到 0.5–0.8；只让 Boss 眼、飘字、新星保留高发光。**这一条同时解决“激光线过曝”和 −14% 的 GPU 成本**。
- 优先级 **P0**（画面与性能双赢），工作量 **小**

### C-03 MSAA 2x：实测 −1.76 ms / −147 MB，但这画风收益很低

- 位置：`project.godot:41`（`anti_aliasing/quality/msaa_3d=2`）
- 问题与实测：`msaa_3d = Viewport.MSAA_DISABLED` 后 **14.04 → 12.28 ms（−12.5%）**，显存 **799 → 652 MB（−147 MB）**。但这游戏的画面本来就以雾、glow、半透明粒子为主，MSAA 对发光边缘几乎无效（加法混合/透明不参与 MSAA 覆盖），真正被它平滑的只有角色/平台边缘。**用 12.5% 的 GPU 换一点点边缘平滑，不划算**。
- 改法：`msaa_3d=0` + `rendering/anti_aliasing/quality/use_taa=true`（或 FXAA）。如果一定要 MSAA，就降到 0 并在 1080p 以下用 TAA；同时把 C-02 的 glow 调低，避免两者叠在一起。
- 量化：14.04 → **12.28 ms（−12.5%）**；显存 **799 → 652 MB（−147 MB）**；设置项 `msaa_3d=2`。
- 优先级 **P1**，工作量 **小**

### C-04 隐性 1.33× 超采样：窗口 2560×1494，但 3D 实际渲染 3414×1993（6.8 MP）

- 位置：`project.godot:22-28`（`viewport 1920×1080` + `window/stretch/mode="canvas_items"` + `aspect="expand"` + `mode=2` 最大化）
- 问题【实测】：`DisplayServer.window_get_size() = (2560, 1494)`，`get_viewport().get_visible_rect() = (1920, 1120)`，而 **`get_viewport().get_texture().get_size() = (3414, 1993)`**。也就是说 3D 实际在 **6.8 MP** 上渲染，是窗口像素的 **1.78 倍**、是 1080p 的 **1.63 倍**（canvas_items 的拉伸与 Windows 显示缩放/DPI 叠加所致）。它带来“看起来挺干净”的边缘，但代价是 1.78× 的像素填充——**这是这份工程最大的一笔隐性 GPU 开销**。
- 量化：6.8 MP vs 2560×1494=3.8 MP；在当前机器上 14 ms；若降到 1080p 级别，按像素线性估算可省 **4–6 ms**（weak GPU 上更明显）。
- 改法：
  1. 先在编辑器里确认 `窗口 2560 宽 → RT 3414 宽` 是否可复现；若是，设 `display/window/dpi/allow_hidpi=false`（或 `rendering/scaling_3d/scale=0.67` 抵消 1.33² 的像素）；
  2. 更简单：**固定窗口 1920×1080 / 全屏 1920×1080**，让 `canvas_items` 的 scale=1，3D 就回到 1080p；
  3. 若想保留高分辨率清晰度，把 `rendering/scaling_3d/scale` 设 0.75–0.85，配合 TAA/FSR。
- 优先级 **P0**（一行设置换 30–40% 像素），工作量 **小**

### C-05 窗口 16:10 / 4:3 / 21:9 适配风险

- 位置：`project.godot:22-28`、`scripts/hud.gd:327-334`（固定 16 px 字号、固定像素位置）、`scripts/hud.gd:200-254`（Boss 条以中心底部锚定）、`scripts/player_camera.gd:24-30`（固定 `z=10.2`、固定 FOV 50、竖直 FOV 保持）
- 问题：
  - `canvas_items + expand` 在非常规比例下会把**逻辑画布往长边扩展**：4:3 屏幕上逻辑高度变成 ≈1440（1920×1440），3D 竖直方向显示更多内容，**角色的屏幕占比会再缩小约 25%**；21:9 屏幕上逻辑宽度扩展到 ≈2560，**Boss 更容易跑到画面外**（Boss 战相机问题见 D-05）。
  - HUD 用固定像素字号：设计分辨率 1080p 下 16 px 的提示，在 720p 窗口缩放 0.667 后变成 **物理 10.7 px**，中文基本不可读；4K 下 16→32 px 反而过大。Boss 血条左下角的位置是“设计坐标下刚好不重叠”（见 E-01），比例一变就撞。
  - 竖屏/超宽没有专门处理；`aspect="expand"` 保证不黑边，但**不保证构图**。
- 量化：16 px 提示在 720p 窗口缩放后物理 ≈**10.7 px**；4:3 下逻辑画布变成 ≈1920×1440，角色占屏比再降 ≈**25%**；Boss 场 33 m vs 视野 16.6 m。
- 改法：HUD 关键字号改用 `theme` 统一 + 按视口宽度 `clamp(16, viewport_width/120, 26)`；Boss 条与左下提示改用 `MarginContainer`/`VBoxContainer` 排版；给 Camera3D 设 `keep_aspect = KEEP_WIDTH` 并让 `fov` 随宽高比补偿（或者在 `_process` 里按 `get_viewport().size` 调 `cam.fov`），保证 4:3 与 21:9 下角色占屏比一致。
- 优先级 **P2**，工作量 **小–中**

### C-06 是否需要 SDFGI / SSAO：都不建议（SSAO 实测 +3.4 ms）

- 位置：`scripts/level_1.gd:100-151`（没有 SSAO/SDFGI/SSR）
- 问题与实测：**A/B 打开 SSAO（radius 1.2 / intensity 1.6）后 14.04 → 17.44 ms（+24%）**，而画面是“平涂 + 自发光 + 雾”的二次元/半写实混合风格，AO 对暗部本来就少的场景收益有限；SDFGI 对固定侧视相机更是纯浪费（3–5 ms 起，且会破坏平涂观感）。
- 量化：SSAO **+3.4 ms/帧**（14.04→17.44，+24%）、显存 **+93 MB**（799→892）；SDFGI 预计 3–5 ms 起且会破坏平涂观感。
- 改法：保持关闭。如果一定要加接触感：用 **雾 + 材质 `AO` 贴图/顶点色压暗**，或给角色脚下贴一张 1 张 `Decal`/贴片假阴影（成本 ≈0）。
- 优先级 **P0（=不要做）**，工作量 **小**

---

## D. 画面问题（逐条对应截图区域）

### D-01 角色剪影：乾坤圈套在腰上、枪穿头、飘带像两根红棍、出生点陷进莲台

- 位置：`scripts/player.gd:233-238`（乾坤圈 `TorusMesh` r=0.30–0.335 放在 `(-0.24, 1.18, 0)`，绕 (0,0,78°)）、`241-260`（火尖枪 1.9 m 的 `CylinderMesh`，`spear.position=(0.3,0.95,0.06)`）、`263`（风火轮火苗）、`scripts/level_1.gd:339`（`_add_checkpoint(Vector3(0,0,0), true)`）+ `702-706`（8 片莲瓣半径 0.9–1.1，位于 y 0.36）+ `172`（玩家出生 `(0,0.6,0)`）
- 问题【截图 shot_v4_start 特写，角色区域 x≈950–1300 / y≈640–940】：
  1. **乾坤圈**的直径 ≈0.67 m，是角色躯干宽（≈0.6 m）的 1.1 倍，环心摆在胸口高度 → 视觉上是一个 **套在腰上的金色呼啦圈**，且环的左侧穿过身体、右侧穿过手臂，明显穿模。
  2. **火尖枪**从腰部斜向右上，枪杆**从脸/头中间穿过**，枪尖在头顶上方约 0.6 m；枪尾插进莲台/地面。原因是模型模式下 `_update_spear_follow()` 用右手骨骼变换，但模型是 T-pose/A-pose 的 AI 模型，手骨位置与枪的握点不匹配（`player.gd:903-920`）。
  3. **混天绫**在 nezha.glb 里是 3 个材质中的 `HuntianLing_Red`，几何是 1.58 m 宽的薄片；在截图里表现为**两根向左后方平伸的红色直棍**，没有曲线、没有厚度、根部悬空。此外 `load_model()` 给的顶点色材质**丢掉了 GLB 的 `doubleSided=true`**（CULL 默认背面剔除），部分角度会直接看不见。
  4. **出生点**就是检查点莲台，玩家站在 8 片大莲瓣正中间，**花瓣从腰部高度把下半身包住**，看起来像穿了一条粉色裙子；金色的莲台底座被 OmniLight 打得过曝。
- 量化：乾坤圈 1.1× 身宽；枪杆 1.9 m 穿头 0.3 m；飘带单侧伸出 ≈0.75 m；莲瓣 8 片 × 0.32 m 半径覆盖角色髋部。
- 改法：
  1. 乾坤圈改为**背后斜挂**（`(0, 1.35, -0.25)`、r=0.22、旋转 (20,0,-30)）或干脆在模型模式下不显示（跑动时再出现）；
  2. 火尖枪改用**固定握把姿态 + 与手骨只做位置跟随**（不继承手腕旋转），或给模型做一根**绑定到手骨的枪**；至少把枪原点移到枪杆后 1/3；
  3. 混天绫用 **2–3 段 `Bone`/程序化 ribbon（`ImmediateMesh` 或 `Path3D`+`CurveMesh`）** 重做，正反面双面材质；
  4. 出生点移到 `(0, 0.6, 0)` 之外，莲台挪到角色侧后方，或把莲瓣径向缩到 0.55 并降低高度。
- 优先级 **P0**，工作量 **中**

### D-02 敌人可读性：深紫/深青敌人在深蓝紫背景里“不可见”

- 位置：`scripts/enemy_crawler.gd:39-45`（模型模式只加了 1 盏紫色 0.8 能量、range 3 的点光）、`scripts/enemy_shooter.gd:40-45`（同款紫灯）、`scripts/level_1.gd:28-37`（分区雾/环境光/雾反照率，Boss 区 `Color(0.115,0.045,0.13)` 深紫 + 反照率 `(0.6,0.25,0.42)`）、`scripts/level_1.gd:64-70`（Boss 体色 `Color(0.1,0.05,0.16)`）、`enemy_crawler.gd:53-58`（程序化兜底同样是深青）
- 问题【截图】：
  - **shot_v4_boss**：画面里最醒目的“Boss”其实是背景涡核（一个纯黑 `SphereMesh`，`level_1.gd:656-660`）被柱子挡住，看起来像一团黑椭圆棒棒糖；**真正的 Boss 本体不在画面里**（在 x=150，相机在 x≈133，视野仅 16.6 m）。
  - **shot_m_crawler / shot_v3_mid**：爬行者是深青/深绿的低矮团块，与深蓝背景的明度差只有约 15–20%；浮母的紫色在半透明紫雾里也糊成一团。
  - 敌人唯一的“亮”来自角色自带的紫灯，但它照亮的**是地面而不是敌人自己**（灯在 gfx 前方 0.5 m、能量 0.8/1.0，敌人模型没有自发光/描边）。
- 量化：敌人与背景的亮度差 ≈15–20%（截图取色：背景 (18,42,58)，爬行者高光 (36,72,72)）；紫色点光对敌人本体的贡献为 0（没有照明自己）。
- 改法：
  1. 给所有敌人加 **Rim Light**（自定义材质 `rim = pow(1-dot(N,V),2)`，青/白 0.6–1.2）或一像素描边（`Next Pass` + `grow`）；
  2. 敌人本体材质自发光 +0.15–0.25，眼/核心 +2.0；
  3. 把敌人色相与背景**分离**（背景青蓝 → 敌人偏洋红/橙），或给敌人脚下加**接触阴影椭圆**（Decal/贴片），形状可读性立刻提升；
  4. Boss 区把背景压暗 10–15%，给 Boss 加一圈金色/红色背光。
- 优先级 **P0**，工作量 **小**

### D-03 平台 trim 过曝成一条贯穿全屏的青色激光线（抢走全部视觉焦点）

- 位置：`scripts/level_1.gd:73-74`（`mat_trim` 自发光 1.3）、`242-244`（`trim.size = Vector3(w, 0.08, 0.12)`，放在 `z=+3.0`）、`falling_platform.gd:35-39`（同样 0.06 高 × 宽 trim，emission 1.4）
- 问题【截图，shot_v4_boss y≈1080–1120 全宽】：
  - 平台宽 24–34 m，而相机水平视野只有 ≈16.6 m → **这条 trim 的长度是 1.4–2 倍屏宽**，永远横贯全屏；
  - 0.08 m 高的发光条在 10 m 距离上几何高度 ≈12 px，但 emission 1.3 × glow 让它**膨胀到 26 px 厚**，峰值 RGB **(86,242,245)**，中心接近过曝；
  - 它被放在 `z=+3.0`（平台前缘、朝向相机），也就是**浮在角色和台面之上**，压住了画面下三分之一的构图；
  - 结果：一条 26 px 的青色激光线成了全画面最亮、最锐的元素，玩家的视线被钉在地面边缘。
- 量化【截图】：厚度 **25–26 px**、横向覆盖 **≥97% 屏宽**、峰值 (86,242,245)、单像素最大亮度超过画面 99% 的区域；全画面 2.0–2.4% 像素接近纯白。
- 改法：
  1. 删掉独立 trim，改成**平台顶面前缘 0.02 m 的内嵌凹槽**（`size=(w, 0.02, 0.05)`，`z=+2.95`），`emission_energy 1.3→0.5`；
  2. 或者只做**分段亮边**（每 4 m 一段，宽度 0.5 m），不要连续整条；
  3. 材质上 `disable_receive_shadows=true`，并把它从 glow 阈值里排除（降低 emission 到 0.7 以下，配 `glow_hdr_threshold=1.25`）；
  4. `_float_platform` 的 trim（`level_1.gd:271-273`）同样处理。
- 优先级 **P0**，工作量 **小**

### D-04 平色晶体卡片：像临时占位符，与 AI 背景画风冲突

- 位置：`scripts/level_1.gd:549-572`（`PrismMesh` + `mat_crystal_c/p`，`Game.std_mat(..., emission 1.8, roughness 0.2)`，`shading_mode` 默认受光但发光压过一切）、`77-80`（材质定义）
- 问题【截图】：shot_v4_start 左侧 x≈100–240 / y≈470–620 是一片**纯青色三角/梯形色块**；shot_v4_boss 左侧 x≈390–520 是一片**纯青大卡片**；shot_fx_boss 里同一位置也是纯青卡片。因为 `PrismMesh` 旋转随机 + 高自发光 + 低粗糙度 + 无贴图，在画面上就是“一张没有厚度的色卡”。与背景里细节丰富的 AI 龙宫废墟直接冲突，是最强的“半成品感”来源之一。
- 量化：每处 2–4 个棱柱（10 处 ≈30 个），材质只有 2 种纯色，`emission 1.8` 让它们成为画面里最平的亮块。
- 改法：
  1. 换成**多面低模晶体**（`ArrayMesh` 手写 6–10 面、法线分面）+ **受光材质** + `rim` + 内部 `BackLight`；
  2. 或直接改用 **AI 生成的晶体 PNG → `Sprite3D`（billboard）**，与背景画风立刻统一；
  3. 缩小到现在的 0.5–0.7 倍，降低 emission 到 0.6，加轻微上下浮动。
- 优先级 **P1**，工作量 **小**

### D-05 相机取景：下半屏是大块空台面/平台前脸，缺少景深层次；Boss 战框不住 Boss

- 位置：`scripts/player_camera.gd:24-30`（`desired = target + (look_ahead, 3.1, 10.2)`、`look_at(y-2.0)`、FOV 50）、`scripts/level_1.gd:224-255`（平台 `deep=9`、`Box size (w, 9, 6)`，即平台**向镜头方向厚 6 m**）、`927-937`（Boss 场 33 m 宽）
- 问题【截图 shot_v3_mid 最典型】：
  - 画面下半 35–40% 是**平台的正面竖壁**（6 m 深 × 9 m 高的盒子前脸），纹理在暗部几乎看不见，就是一大块深色梯形；
  - 相机水平视野 ≈16.6 m，垂直 ≈9.7 m，玩家站在中间只占 19%（可见剪影因莲台遮挡 ≈13–15%），**前景（平台前脸）+ 角色 + 背景之间没有中间层**；
  - **Boss 战更严重**：Boss 场 130–164（33 m），相机视野 16.6 m，Boss 常在你的屏外。shot_v4_boss 里“归墟之喉”血条已出现，但**画面里根本没有 Boss**，只有背景涡核和柱子——这是这一版最伤的一个画面事故。
- 量化：平台前脸深 6 m；水平视野 16.6 m / 关卡 172 m ≈ 9.6%；Boss 场宽 33 m = 2 倍视野；Boss 与玩家最大距离 ≈31 m。
- 改法：
  1. 平台 `deep 9→5`、`Box size.z 6→4`，前脸立刻矮 1/3；
  2. 相机 `desired.y 3.1→4.0`、`look_at y -2.0→-2.6`，把台面顶面多露出来、前脸少露出来；
  3. 加**中景层**：在 z=-6~-10 放剪影石柱/飘带/水草，z=-20 放雾墙，形成 3 层视差；
  4. **Boss 战专用相机**：`Game.run` 里进入 Boss 战切到 `z=15.5, y offset 3.6`，并把相机 x 锁在玩家与 Boss 的加权中点（Boss 0.65 / 玩家 0.35）；或直接 `fov 50→60` + `z 10.2→13.5`。
- 优先级 **P0**（Boss 看不见是玩法级问题），工作量 **小–中**

### D-06 主菜单 vs 游戏内质感断层

- 位置：`scripts/main_menu.gd:25-58`（2048² AI 主视觉 + vignette + `menu_fx` 加法粒子 + 40 个气泡）、`scripts/level_1.gd:394-458`（程序化几何装饰）
- 问题【截图】：`shot_v4_menu.png` 是精致的暗色龙宫 AI 大图（金/青/蓝、细节丰富、有镜头光晕）；`shot_v3_mid / shot_v4_start` 游戏内则是“平涂色块 + 低模圆柱 + 纯色晶体 + 发光直线”。同一个游戏，菜单像商业产品、关卡像引擎 Demo。落差最大的是：背景（AI 画 vs 26 根圆柱）、晶体（AI 细节 vs 纯色卡片）、UI 头像（精美立绘 vs 3D 红色团块）。
- 量化：菜单使用 1 张 2048² AI 图 + 2 个全屏 shader；关卡里 413 个对象中仅 2 张 AI 图（backdrop 118×50.6 两段，`z=-52`）与 1 张 vortex 是 AI 资产。
- 改法：
  1. **把 AI 背景画往前用**：把 backdrop 拆成 3 层视差（远/中/近），中景用 `unshaded` 剪影 + 雾衰减；现在它被 26 根柱子和极低亮度埋在最后；
  2. 给程序化几何统一加 AI 生成的 **stone/coral/crystal 贴图**（已有 `stone.png`，但 crystal/urn/torus 都没有贴图）；
  3. 拿菜单的“金 + 青 + 雾 + 粒子”语言重做关卡装饰的配色，别让纯色青/紫抢戏。
- 优先级 **P1**，工作量 **中**

### D-07 天空的“月亮”被过曝成一个扁平黄圆盘

- 位置：`shaders/sky.gdshader:25-31`（`moon * 2.0`，`glow` 阈值 0.9）
- 问题【截图 shot_v4_boss 右上、shot_fx_boss 右上】：一个直径约 25–30 px（2560 宽截图下 ≈40 px）的**纯黄色实心圆**，没有环形山、没有渐变、没有边缘柔化，和整体画风完全不搭；`halo` 项只有 0.35×pow(md,60)，几乎看不到。
- 量化：`smoothstep(0.9985,0.9995)` 极硬的边缘 + 2.0 强度 + glow → 中心过曝到 (255, 200+, <130)。
- 改法：`moon *= 1.0` 并加 `smoothstep(0.997,0.999)` 的软边 + 一层 `pow(md, 800)` 的月晕；或直接换成一张 AI 月亮贴图（`Sky` 无法贴图，可改用一个远距离 `Sprite3D`/`QuadMesh` 放在 z=-200）。
- 优先级 **P2**，工作量 **小**

### D-08 背景柱、巨环、涡核的比例与遮挡：黑色棒棒糖

- 位置：`scripts/level_1.gd:411-414`（26 根柱子，高 6–14 m、半径 0.7–0.9）、`520-536`（柱头 60% 概率）、`416-417` 与 `539-546`（巨环 r=9/12 → 直径 18–24 m 的 Torus）、`629-660`（涡：26×26 加法贴图 + 3 个 Torus + **纯黑 SphereMesh r=2.2**）
- 问题【截图】：shot_v4_boss 中，黑色涡核球正好被一根**带柱头的背景柱**挡住，形成“黑色圆球 + 黑色方帽”的棒棒糖剪影，被误认成 Boss；shot_m_crawler 右上角的金色巨环像一只悬空的“金箍”；26 根柱子都是等材质等宽的深蓝圆柱，没有破损/倾斜变化，读起来像栏杆不是废墟。柱子高度 6–14 m、离镜头 9–26 m，透视尺度不统一。
- 量化：涡核 r=2.2 m、3 个环半径 3.0/5.2/7.4 m；巨环直径 18–24 m；26 根柱子。
- 改法：涡核改为**加色径向渐变 billboard**（不要实体球），或提高其 emission 并降低不透明度；背景柱改 3–4 种预制“断柱/倾柱/柱头残片”变体 + MultiMesh；巨环降低 emission 并加雾衰减；Boss 战前把挡住 Boss 的柱子移走。
- 优先级 **P1**，工作量 **中**

### D-09 出生点与检查点莲台重叠（角色“穿裙子”）

- 位置：`scripts/level_1.gd:339`（检查点 `(0,0,0)`）、`702-706`（8 片 `SphereMesh` 莲瓣，`scale (1.5,0.45,0.9)`，半径 0.32，位置半径 0.62），`level_1.gd:172`（玩家 `(0,0.6,0)`）
- 问题【截图 shot_v4_start】：玩家出生就站在莲台正中心，8 片 0.5 m 长的粉色莲瓣从髋部包住角色，金色莲台底座（metallic 0.85、有 1.5 能量点光）被过曝成一片发光圆盘。第一屏给玩家的第一印象就是“穿模”。
- 量化：莲瓣外径 ≈0.62+0.32×1.5 ≈1.1 m，与角色碰撞胶囊半径 0.35 m 完全重叠。
- 改法：出生点前移 1.5 m（`level_1.gd:172` → `Vector3(-1.5, 0.6, 0)`）或把莲台移到 `x=-1.2`；莲瓣缩小到 0.6 倍并降低高度；检查点灯 `light_energy 1.5→0.8`、底座 `metallic→0.4`。
- 优先级 **P1**，工作量 **小**

### D-10 中段背景“消失”，画面只剩蓝灰渐变

- 位置：`scripts/level_1.gd:394-409`（backdrop 2 段，`z=-52`，`unshaded`）、`411-414`（柱子 `z∈[-26,-9]`）、`117-120`（`fog_density=0.012`、`fog_sky_affect=0.15`）
- 问题【截图 shot_v3_mid】：起点和 Boss 区能看到 AI 背景画，**走廊中段（x≈60–100）背景几乎全空**，只有蓝灰渐变。原因：backdrop 是 `unshaded` 但在 z=-52，被 `fog_density` 与低亮度吃掉，同时 26 根柱子在 z=-26~-9 遮挡；中段的柱子密度不足以填满画面。
- 量化：backdrop 距镜头 62 m，fog 密度 0.012 → 透射率 ≈e^(−0.74) ≈ 48%，再被柱子切碎。
- 改法：给 backdrop 单独调材质（不受雾/提高亮度或改用 `disable_fog`，Godot 4 里可用 `material.disable_fog = true`）、z 拉近到 -38、把柱子在 x 60–110 段加密；或者在 75/112 两个分区各再放一段背景画。
- 优先级 **P2**，工作量 **小**

---

## E. UI / UX

### E-01 Boss 血条压住左下角操作提示（设计坐标下就重叠）

- 位置：`scripts/hud.gd:200-254`（`_boss_box` 锚定 `PRESET_CENTER_BOTTOM`；头像 `x = -boss_w/2 - 92 = -482`、`y = -104..-28`；血条 bg `x = -394..+394`、`y = -58..-34`）、`scripts/hud.gd:327-334`（提示 `PRESET_BOTTOM_LEFT`，`position = (36, -44)`）
- 问题【截图 shot_v4_boss / shot_level_boss / 特写 crop】：设计坐标 1920×1080 下：
  - 左下提示文字：y ≈ **1036–1058**、x ≈ **36–560**；
  - Boss 血条头像框：y ≈ **976–1052**、x ≈ **478–554**；
  - 血条底条：y ≈ **1022–1046**、x ≈ **566–1354**。
  ⇒ 头像框与提示文字在 **x 478–554、y 1036–1052** 区域重叠约 76×16 px，正好盖住提示末尾的「E 乾坤圈」；血条底条与提示在纵向也重叠（1022–1046 vs 1036–1058）。截图里确实看到「E 乾坤圈」被头像框切断。
- 量化：重叠区域约 76×16 px（设计坐标），横向覆盖提示文字的 14%。
- 改法：把 `_boss_box` 整体上移 40–60 px（`bg.position.y = -58 → -110`，头像 `-104 → -156`），或把左下提示改为两行/上移到左下角上方 80 px，或 Boss 战时把提示条淡出（`show_boss_bar(true)` 时 `hint.modulate.a = 0`）。
- 优先级 **P1**，工作量 **小**

### E-02 世界内 Label3D 提示与 HUD 中央讯息同带冲突 + 三处重复

- 位置：`scripts/level_1.gd:663-674`（8 个 `_hint`，`font_size=40`、`pixel_size=0.01`、`billboard`、永不隐藏）、`scripts/hud.gd:257-270`（中央讯息 `anchor_top=0.3`、字号 54）
- 问题：
  1. HUD 中央讯息固定在屏高 **30%** 处；世界内提示是 billboard，玩家靠近时投影到屏幕 **33–40%**，**两者落在同一水平带、同一水平中心**；`shot_fx_boss` 里「前方灵气紊乱……深渊在注视你」与「第一章 · 东海碎潮回廊」几乎同一行、在 x≈570 处水平相接（再靠近就会真正叠字）；`shot_v4_boss` 里「归墟之喉 · 渊狱兽」与它并列。
  2. 同一句操作说明出现 **3 次**：世界内 `_hint`（8 个）、左下常驻提示（`hud.gd:329`）、菜单「操作指南」面板（`main_menu.gd:317-332`）。
  3. 世界提示不会消失，也不会随距离淡出；玩家已经学会操作后它们仍然全程挡在关卡里。
- 量化：8 个世界 Label3D + 1 条左下长提示 + 1 个菜单面板 = 3 套重复文案；中央讯息 y≈324–390（设计），世界提示 y≈356–430。
- 改法：世界提示**只在玩家进入对应 trigger 时显示 3–5 s 后淡出**（绑定 `Area3D.body_entered`，用 `_hint` 返回的 Label3D 做 tween）；中央讯息下移到 0.20 或上移到 0.42，避免与世界提示同带；左下常驻提示删掉或折叠成「Esc 查看操作」。
- 优先级 **P1**，工作量 **小**

### E-03 左下操作提示 16 px / 45% 透明度，实测有效对比度仅 ≈1.6:1

- 位置：`scripts/hud.gd:327-334`
- 问题【实测】：文字颜色 `(0.6,0.7,0.7,0.45)`，叠加在深色台面上。对截图取样：文字核心最亮像素 (94,142,161)，与背景 (8,28,38) 的对比度约 **4.9:1**（看似达标），但中文笔画只有 16 px、且 45% 透明，**笔画平均像素 (25,65,88) 与背景对比只有 ≈1.6:1**——实拍效果就是“一行几乎看不见的灰字”。
- 量化：字号 16 px（1080p 设计），透明度 0.45；平均对比度 1.61:1（WCAG 正文要求 4.5:1，大字 3:1）。
- 改法：字号 16→20、颜色 alpha 0.45→0.75、加 1 px 黑色描边（`font_outline_color` + `outline_size=2`），或放到一个半透明底板（`StyleBoxFlat` α 0.35）上。
- 优先级 **P1**，工作量 **小**

### E-04 技能图标对比度低、单字图标语义不清

- 位置：`scripts/hud.gd:147-197`（技能面板 58×58、`font_size=30`、未就绪色 `(0.5,0.5,0.5)`、就绪色金/橙；按键提示 `Q`/`E` 在 `(40,38)`、14 px）
- 问题【截图 shot_v4_start 左上 y≈110–160】：`焚` 是暗灰字压在暗棕底上，`环` 是金棕字压在金棕底上（就绪时），两者都缺乏亮度分离；单字「焚」「环」也不如“火/圈”直观；`Q`/`E` 只有 14 px 且位于图标右下角，几乎看不清。
- 量化【实测】：`焚` 文字像素 (134,124,103) vs 底 (35,36,32) → 对比度 **3.78:1**（30 px 算大字，勉强过 3:1，但视觉上仍偏灰）；键位 14 px。
- 改法：未就绪用 35% 灰 + 叠一层 40% 黑遮罩；就绪时图标加 1.2 能量外发光/描边；键位字号 14→18、移到左上角；图标改用 AI 生成的技能图标（跟主菜单质感统一）。
- 优先级 **P1**，工作量 **小**

### E-05 伤害/治疗数字同区域、字号过大且永久置顶

- 位置：`autoload/game.gd:289-308`（`big ? 96 : 64`、`no_depth_test=true`）、`player.gd:1077-1078`（治疗 `+100` 用默认 64 号绿色）、`enemy_base.gd:127-129`
- 问题：`+100`（治疗）与 `-N`（受伤）都用同一位置（角色头顶 +1.8 m）、同样大字号；受击 3 连击时 5–8 个 96 px 数字同时上飘，覆盖角色与敌人；`no_depth_test` 让它们永远画在 UI 世界层之上，甚至盖住世界提示。
- 量化：每次命中 1 个 Label3D，字号 64–96 px（≈角色身高的 1/3–1/2）。
- 改法：伤害字号 96→56，`big`（暴击）才 72；治疗数字缩小到 40 并加「+」图标；`no_depth_test=false`；同一角色 0.2 s 内的数字合并（累加显示）。
- 优先级 **P2**，工作量 **小**

### E-06 暂停/死亡/胜利面板的按钮无法用键盘操作

- 位置：`scripts/hud.gd:413-431`（`btn.focus_mode = Control.FOCUS_NONE`）、`_show_overlay` `434-490`、`main_menu.gd:146-182`（同样 `FOCUS_NONE`）
- 问题：全键盘动作游戏（WASD/J/K/Shift），但暂停后只能用鼠标点按钮；`_input` 里 `esc` 只处理开/关，没有上下选择/确认。玩家在键盘流里必须抬右手找鼠标。
- 量化：暂停面板 3 个按钮、死亡 2 个、胜利 1 个，全部不可聚焦。
- 改法：`focus_mode = FOCUS_ALL`，打开面板时 `grab_focus()` 第一个按钮，加 `ui_up/ui_down/ui_accept` 处理；主菜单同理。
- 优先级 **P2**，工作量 **小**

### E-07 进度信息与 Boss 信息位置分散、缺少“当前目标”

- 位置：`scripts/hud.gd:273-297`（连击右上、龙魂残片右上）、`hud.gd:200-254`（Boss 条底部）、`hud.gd:327-334`（提示左下）
- 问题：玩家需要同时看左上（血/灵/技能）、右上（连击/龙魂）、底部（Boss）、左下（操作），四个角都有信息；没有任何“目标提示”（下一个检查点/该往哪走），而关卡是线性 172 m 长。加上世界提示与中央讯息抢注意力，整体信息层级偏乱。
- 量化：4 个屏幕角落 + 中央 2 层文字。
- 改法：把「龙魂残片」并入左上角玩家面板下方；连击只在中上；Boss 条上移；加一个“向右 →”的轻量目标指示（可放在右上或世界内）。
- 优先级 **P2**，工作量 **小**

---

## F. 画质 / 性能优化优先级 TOP 5（按投入产出比）

| 排名 | 动作 | 预期收益 | 代价 | 优先级/工作量 |
|---|---|---|---|---|
| **1** | **关掉平行光阴影（或只让玩家/Boss 投影 + 单级 2048 + 装饰 `cast_shadow=OFF`）** | Draw call **375→71（−81%）**、三角形 **806k→103k（−87%）**；弱卡 3–5 ms | 1–2 行代码 + `add_mesh()` 默认关投影 | **P0 / 小** |
| **2** | **修掉 1.33× 隐性超采样（3D RT 3414×1993 → 1080p 级）** | 像素 **6.8 MP → 2.1 MP（−69%）**，约 4–6 ms | 改 `dpi/allow_hidpi` 或固定 1920×1080 / `scaling_3d/scale` | **P0 / 小** |
| **3** | **过曝三件套一起修：trim 自发光 1.3→0.5 + 宽度 0.08→0.02、glow 阈值 0.9→1.25、MSAA 2x→0** | 消掉 26 px 全屏激光线 + 2% 裁白像素；GPU **−2.0 ms（glow）+ −1.8 ms（MSAA）** | 3 个数值 + 1 个 project 设置 | **P0 / 小** |
| **4** | **敌人可读性 + Boss 战相机**：敌人 Rim Light/自发光/接触阴影；Boss 战 `z 10.2→15.5` 或双目标构图 | Boss 从“不在画面”到“始终可见”；敌人从“黑团”到“可读” | 材质补 rim + 相机分支，约 1 天 | **P0 / 小–中** |
| **5** | **特效对象池 + 加载预热**：burst / 伤害数字 / flash 材质池化；开工前在屏幕外预热一遍 | 消掉 **94 ms** 战斗尖峰；每次命中 10 个分配 → 0；30 s Boss 战少 500–800 次分配 | 2–3 天 | **P0–P1 / 中** |

> 次优先（第 6–8）：AI 模型减面（159k/260k/196k → 15–25k，P0/中）→ 音频离线烘焙 + 关卡构建分帧（P1/小）→ 海草/柱子/瓮改 MultiMesh + 共享材质（P1/中）。再往后才是体积雾参数、水面细分、`_process` 节流。

---

## G. 做得好的地方（≤5 条）

1. **所有 AI 资产都有程序化兜底**：`Game.tex()` 返回 null、`Game.load_model()` 返回 null 时，玩家/敌人/Boss/背景/晶体/水面都有逐级 fallback（`game.gd:22-81`、`player.gd:94-103`、`enemy_crawler.gd:36-52`、`level_1.gd:398-409`）。个人项目里这种健壮性很少见，也让“美术替换期”能一直跑。
2. **打击感系统完整且有想法**：hitstop（`game.gd:177-182`）、震屏、连击计数、完美闪身时缓、受击白闪、斩击环、屏幕 fade——一套都齐了，手感方向是对的。
3. **渲染资源已有合批意识**：9 个共享材质（`level_1.gd:40-48`）、stone 三向平铺、符文砖/珊瑚刺/莲瓣复用了同一个 mesh；说明作者知道“共享”这件事，只是还没系统化（见 A-04）。
4. **相机与氛围有表现层设计**：朝向预判 `_look_ahead`、震屏、`snap_to_target`（`player_camera.gd:16-42`）；随 x 变化的雾色/环境光/雾反照率/日光四通道渐变（`level_1.gd:1099-1123`）是值得保留的差异化设计。
5. **AI 模型导入管线正确**：自动旋转（TripoSR Z-up → Y-up）、按 AABB 归一化高度、底部对齐、顶点色材质、`base_mat` meta 记录以便受击闪白还原（`game.gd:29-81`、`204-214`）——这套“导入即用”的封装思路是对的，只需补上 A-02/B-03 提到的几个细节。

---

## 附录 A：实测方法与复现

所有实测都在 **项目副本** 上做（`%TEMP%\nezha_probe`），原项目除本报告外**未写入任何文件**。

1. 泄漏定位：
   ```
   & '...Godot_v4.6.3-stable_win64_console.exe' --headless --verbose --path 'E:\godot_game_by_fable\001' res://scenes/level_1.tscn --quit-after 60
   ```
   输出末尾 `Leaked instance: AudioStreamWAV / AudioStreamPlaybackWAV`。
2. 规模统计（在副本 `_process` 里插桩）：
   ```
   find_children("*", "MeshInstance3D", true, false)  → 413
   find_children("*", "OmniLight3D",  true, false)  → 27
   find_children("*", "GPUParticles3D", true, false) → 12~13
   find_children("*", "Label3D", true, false)      → 8
   Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME     → 375~384
   Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME     → 806k（Boss 区 1.83M）
   Performance.RENDER_VIDEO_MEM_USED                → 799 MB
   ```
3. A/B 变体（同一副本，命令行 `-- <variant>` 切换，跑 400 帧取 p50/p95）：
   | 变体 | 帧时间 | 变化 |
   |---|---|---|
   | baseline | 14.04 ms | — |
   | 阴影关 | 13.38 ms（DC 375→71，tri 806k→103k） | −0.66 ms |
   | glow 关 | 12.04 ms | **−2.0 ms（−14%）** |
   | MSAA 0 | 12.28 ms（显存 −147 MB） | **−1.76 ms（−12.5%）** |
   | 体积雾关 | 13.91 ms | 噪声内 |
   | 装饰灯不进雾 | 14.41 ms | 噪声内 |
   | SSAO 开 | 17.44 ms | **+3.4 ms（不要开）** |
   | Boss 区 baseline | 10.25 ms，**max 94.44 ms** | 首帧尖峰 |
   （同一台机器上多次运行方差约 ±1.5 ms，小于 1 ms 的差异不要当真。）
4. 构建耗时：在副本 `level_1._ready()` / `Game._ready()` 里插 `Time.get_ticks_msec()` 分段打印。
5. 截图测量：Pillow 对 2560×1494 原图做红色掩膜 bbox、行亮度扫描、对比度计算；命令与脚本不入库，仅用于本报告数字。

## 附录 B：静态统计（draw call / 材质口径）

- **MeshInstance3D 413 个**：主平台 34（含符文砖 22）、浮台 21、浮桥 8、珊瑚刺 18、背景柱 ≈42、海草 ≈90、浮岩 12、水晶 ≈30、瓮 50、检查点 33、露灯 5、巨环 2、巨涡 5、鲸 12、鱼 7、拾取物 22、闸门 6、背景画 2、水面 1、玩家装备 4、AI 模型 4。
- **符文砖总数**：`maxi(int(w/5),1)`，6 个平台分别 4/2/3/3/4/6 = **22 个**。
- **独立 StandardMaterial3D**：≈**131 个**（海草 30、瓮 20、拾取物 12、莲台 9、浮桥 8、露灯 5、涡 5、其余共享/零碎）。每次 `Game.std_mat()` 都是一个新的 `StandardMaterial3D`，且 `add_mesh()` 一律走 `material_override`，所以同网格也难以自动实例化。
- **每帧 draw call 口径**：起点区主 pass 71（关阴影）/ 阴影 pass ≈304（4 级 PSSM × ≈76）；Boss 区总 draw call 348、三角形 1.83M。
- **每命中分配**：≈10 个对象（flash 材质 1 + Timer 1 + Label3D 1 + TextMesh 1 + Label 材质 1 + Tween 1 + TorusMesh 1 + 斩击材质 1 + MeshInstance 1 + 斩击 Tween 1）。每次 burst 另加 7 个。
