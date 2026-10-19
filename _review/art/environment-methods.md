# 场景/环境改进方法调研（Godot 4.6 · 2.5D 横版 · 三章）

查询日期：2026-10-18。仅用 web_fetch/web_search（本机 shell 无外网），未运行 Godot、未改 `001/`。工程事实来自 `001/scripts/level_base.gd`、`level_1/2/3.gd`、`autoload/game.gd`、`project.godot` 与截图 `shot_v4_start.png`。

## 0. 五条结论
1. 先修"隐性超采样 + 雾/阴影预算"，再谈加美术。`scale_3d≈1.78` 实为 SSAA：1080p 原生 2.07 MPix/帧，1.78× ≈ 3.2 MPix/帧；官方把 scale>1 定义为 SSAA，明确"高 VRAM、不推荐常态"。
2. 平涂低反射 + 横向卷轴 → 抗锯齿选 MSAA 2×/4×；TAA 有鬼影且横向持续运动会放大拖影；砍 SSAA 后用 2×MSAA + SMAA/FXAA 兜底。
3. 27 盏 Omni 不是数量问题（Forward+ 集群上限 512 个元素），问题是全部注入体积雾。官方：把某盏灯的 Volumetric Fog Energy 设 0 会把它排除出雾计算并略提性能。
4. LightmapGI 不能用于程序化关卡（只能编辑器烘焙）；SDFGI 是唯一"边生成边算"的 GI，但开销大、cascade 移动会跳变；VoxelGI 需加载时烘焙数秒，超出 0.9s 加载预算。
5. 画面收益最大的一步不是加效果，而是"三章色彩脚本 + 明度分层 + 材质槽模块库"，0 性能成本。

## 1. 美术方法：可操作规则
**三章色彩脚本**（主/次/点缀按 60/30/10 面积分配，点缀=高饱和或自发光，占屏 ≤10%）

| 章 | 主色 60% | 次色 30% | 点缀 10% | 雾色 | 明度结构 |
|---|---|---|---|---|---|
| 青蓝龙宫 | `#0E2A33` 深海青 | `#24404D` 石青 | `#38E0D0` 灵光 + `#E0B060` 金 | `#0D2A33`（=主色提亮） | 中低对比，顶部提亮做天光 |
| 铁灰牢狱 | `#14181C` 铁灰 | `#2E3236` 冷铁 | `#FF7A2A` 炉火 | `#191314` 暖灰 | 高对比硬光，明暗交界干脆 |
| 紫黑归墟 | `#0B0714` 玄黑 | `#1C1430` 玄紫 | `#4FE8FF` 灵青 + `#7A3CE0` 紫 | `#120A20` | 低明度 + 高自发光，虚空留黑 |

**全局规则**
- 明度四层：远景剪影 L 8–18%，中景结构 25–40%，可站立/可交互面 45–65%，危险与关键物 75–90%（或靠 emission）。一帧只允许 3 个明度簇；前景不得比背景更暗。
- 雾色 = 远景环境色同色相提亮 10–15%、降饱和 20%；`fog_light_color` 与 `zone_stops` 环境色同源（现有插值逻辑已具备，只需按上表取色）。
- 危险色唯一：伤害物只用红橙（H 10–20°）；可交互/收集=暖金（H 40–45°）；路径/抓手=冷青 rim。三章只换"环境主色与点缀色相"，语义不变。静态装饰的橙/红必须降饱和、降至 emission≤0.6，只有动态伤害特效用纯色高亮。
- 形状语言：龙宫=圆/环/柱（环、拱、柱头）；牢狱=方/斜/桁架（栅栏、锁链、闸门）；归墟=破碎三角/裂片 + 悬浮。剪影层只用大块简单形，避免细长高频（细柱林既增 draw 又闪烁）。
- 构图：平台落脚点与摆荡锚点落在三分线交点附近；Boss 战镜头内保留 1 个背景焦点（巨环/涡/巨眼），不与 Boss 叠 3 个以上高频元素。

## 2. 代码生成关卡的美术模块库
现状：`Game.add_mesh` 现搓 BoxMesh/材质，400+ 网格、79–92 draw，无资产标准。改成"GDScript 可拼装 kit"：

- **尺寸标准**：1 单位=1m，全局 SNAP=0.5m。平台宽 2/4/8m、厚 0.4/0.8m；通道净高 3.2m；可达性上限 Δy≤2.2m、Δx≤5m；Boss 场地净宽 ≥14m。所有模块 pivot 在底面中心、+Z 朝镜头、scale=1、AABB min.y=0（这样 `_platform(x0,x1,ytop)` 可直接换成模块坐标）。
- **命名**：`kit_ch1_platform_float_a_w4.glb`；目录 `art/kits/ch1/{geo,trim,atlas}/`、`art/kits/kit_lib.gd`、`art/kits/kit_module.gd`。
- **材质槽固定 4 槽**：0=StoneBase、1=Trim（自发光）、2=Accent、3=Glass/Water。代码用 `set_surface_override_material(i, mat)` 按槽换色 → **一套几何三章复用**，资产量降到 1/3。
- **GDScript 接口**：`KitModule`（Resource 或字典）字段 `id/footprint/slots/anchors/tags`；`Kit.spawn(id, parent, xform, palette)` 返回 Node3D+碰撞体；摆放前 `snappedf(x, 0.5)`；`anchors` 给出摆荡环/平台衔接/敌人出生点，关卡脚本不再手写装饰坐标。`level_base` 的 `_platform/_decor_*` 内部改写，签名不变，`level_1/2/3` 不用改。
- **程序化散布**：海草/碎石/晶簇/浮岩改 `MultiMeshInstance3D`（per-instance color 做色相变化），按区域拆多实例以利视锥剔除（官方建议：相距远的实例应拆开）。
- **顶点色 + shader 参数**：模块顶点色存 AO/色变（与 `game.gd` 的 `vertex_color_use_as_albedo` 路径一致，烘焙时把 AO 写进顶点色，省一张 AO 贴图）；`sky.gdshader`、`water.gdshader`、`rim_overlay.gdshader` 的颜色从章节 palette 注入（现在天空/水面颜色是写死的），模块/天空/水面共用一张色板，换章只换 palette。
- **Trim sheet + decal**：每章 1 张 1024–2048 trim（4–6 条横带：石缝/雕花/发光符文/金属边），UV 只取一条带；地面裂纹、水渍、符文用 Decal 投在平台朝镜头面（Forward+ 支持，注意 Extents 投影长度越短越省）。
- **远景视差**：背景大 Quad（z≈-50，unshaded）→ 中景剪影（z≈-25）→ 玩法层 z=0，后两层按 0.2/0.5 跟随相机偏移；远景用雾与低饱和压住，不参与光照。

## 3. 光照与后处理取舍（Godot 4.6）
| 项 | 4.6 官方要点 | 本项目建议 |
|---|---|---|
| 阴影 | 默认 PSSM 4 级；同时出现在 4 片里的大物体会被画 5 次；`max_distance` 越小越快越好；Caster Mask 只影响"谁投影" | 保留单级正交 + max_distance 30；加 Caster Mask 只留角色/Boss/可破坏物；角色脚下补 blob shadow Decal（比全量阴影便宜且提升落地感） |
| Omni×27 | Forward+ 数量上限 512 集群元素，不是瓶颈；每盏灯的 Volumetric Fog Energy 决定是否注入雾 | 只留 3–5 盏近景 `VFE=0.15~0.3`，其余 `VFE=0`；加 Distance Fade（Begin/Length）直接剔除远处灯 |
| 体积雾 | 有限距离；Volume Size/Depth 项目设置可降质换速；时域重投影让快速移动光产生鬼影 | `volumetric_fog_length` 90→45，密度再降；短命特效光 `VFE=0`；动态传送/闪现时临时关 |
| Glow | **4.6 默认 blend 改 Screen、intensity 0.3，比旧版明显更亮**；阈值 0 全屏泛光 | 升级后必须重调：`glow_hdr_threshold` 1.2 保持，intensity 0.3–0.4 起调，只让点缀色发光 |
| Tonemap | Filmic/ACES/AgX；AgX 保色相最好但最慢 | 现用 Filmic；对高饱和青/紫做一次 AgX A/B，1080p 开销可忽略，按观感定 |
| Adjustments/LUT | 支持 3D LUT（17³/33³，导入类型改 Texture3D）；在 tonemap 之后 | 每章一张 LUT（青蓝/铁灰/紫黑），替代逐场景手调 contrast/saturation，可回滚 |
| SSAO | 只作用于环境光；官方称开销显著 | 保持关闭（此前实测 +3.4ms、收益极低） |
| SSIL | 半分辨率默认，补自发光小尺度反弹，需配合 GI | 可 A/B：让晶簇/符文对周围有微弱反弹；不达预期就关 |
| SDFGI | 唯一支持"运行中生成"的 GI，但开销最大、cascade 切换可见、收敛需 25 帧 | 不进主流程；仅拍照/过场开关，或彻底不用 |
| VoxelGI | 需节点+烘焙（数秒），可在导出工程烘焙 | 加载 0.9s 预算内不做 |
| LightmapGI | 只能编辑器烘焙，动态物用 LightmapProbe | 程序化关卡不可用（官方明确） |
| AA | MSAA 卡通风格最佳；TAA 鬼影；SSAA=scale>1，极高开销 | `scale_3d=1.0` + MSAA 2×（4× 看余量）；不要 TAA；必要时 SMAA |
| DOF | CameraAttributes 控制 | 仅过场/菜单，游戏内关闭（2.5D 清晰度优先） |

工程无 Compositor 不影响：调色用 Environment 的 3D LUT/adjustments 已足够；只有要做全屏自定义描边/特殊 grade 才需要 CompositorEffect（Forward+/Mobile 支持）。

## 4. 可读性与关卡引导
- 色语义（唯一）：红橙=伤害（尖刺、弹幕、Boss 大招预警），暖金=可收集/可交互，冷青连续 trim=可站立边界，白闪=受击反馈。
- 平台"顶面亮、立面暗"：顶面用 trim 或浅一档 albedo，立面压暗，边缘才读得清；现有全屏连续青色 trim 线是全画面最亮元素（见 `shot_v4_start.png`），建议改分段/断续、亮度降 20–30%，别让它成为唯一视觉焦点。
- 背景不抢戏：远景饱和度 ≤ 主色 70%，单块细节尺寸不超过平台宽的 1/3；背景元素靠雾与明度退后。
- Boss 取景：Boss 高度 ≤ 画面 1/3，地面给大色块；地面色与 Boss 特效色拉开（牢狱=冷灰地面对橙焰，归墟=玄黑对青白）。
- 竖向引导：摆荡锚点=金环 + 细垂直光柱/粒子流；每 2 格高度重复一个装饰节奏暗示可攀爬。
- 特效层级：背景 additive ≤2 层，角色/技能占最亮层；同屏全屏闪光 ≤1 次；战斗粒子总量上限（约 500/屏）。

## 5. 资产来源与统一风格
- 免费优先：Poly Haven（全部 CC0，含 HDRI/贴图/模型，可商用免署名）；ambientCG（CC0 材质）；Kenney（CC0）；Quaternius（CC0 低模）；补充用 Blender 几何节点做程序化模块（尺寸按 §2 标准导出）。
- 付费：Synty 低模包（风格统一、含商用许可），只用来补模块；不建议写实高模包。
- AI 贴图：只做 trim/石材的可平铺 albedo（2048），Krita 去接缝 + 统一色板，Blender 烘 AO 到顶点色；不要用 AI 出整张场景。
- 现有 AI GLB 统一化：Decimate 到场景装饰 ≤5k、可交互 ≤2 万面；贴图 1024→512 + mipmap + VRAM 压缩；材质合并为 1 个（顶点色）；HSV 量化到本章 12 色板；超出 `visibility_range_end` 的直接删。

## 6. Top 10 改进清单（按性价比）
验收：1080p/60fps、draw<120、tri<30 万；用 `tools/perf_probe.gd` 每项前后各测一次。

| # | 动作 | 画面收益 | 性能影响 | 工时(人日) | 风险 |
|---|---|---|---|---|---|
| 1 | `scale_3d` 回 1.0，保留 2×MSAA | 中（略降锐度） | GPU 大幅下降（≥30% 估算） | 0.5 | 低 |
| 2 | 体积雾预算：length 45、降密度、27 灯 VFE 分级 + distance fade | 高（雾不糊、光干净） | −1~2ms | 0.5 | 低 |
| 3 | 阴影收口：Caster Mask + 角色 blob shadow Decal | 高（落地感/打击感） | ≈0 | 1 | 低 |
| 4 | 三章色彩脚本 + 3D LUT + 明度分层 | 最高 | 0 | 2–3 | 低 |
| 5 | 可读性色语义 + 特效层级上限 | 高 | 0 | 1.5 | 低 |
| 6 | 模块库 v1（命名/尺寸/4 材质槽/Kit.spawn） | 中高（一致性、可维护） | draw 下降 | 4 | 中（重构面大） |
| 7 | 装饰改 MultiMesh 散布 | 中 | draw −30~50 | 2 | 低 |
| 8 | 远景 3 层视差 + 剪影简化 + 去细柱林 | 中高（纵深） | draw 下降 | 2 | 中 |
| 9 | 现有 AI 资产精简（减面/贴图/材质/可见距） | 中 | tri −30% | 2 | 中 |
| 10 | SSIL half-size A/B；SDFGI 仅拍照模式 | 中低 | +1~3ms | 1 | 中 |

## 7. 来源（访问 2026-10-18）
- Godot 4.6 官方文档：[Environment/后处理](https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html)、[SDFGI](https://docs.godotengine.org/en/4.6/tutorials/3d/global_illumination/using_sdfgi.html)、[GI 对比](https://docs.godotengine.org/en/4.6/tutorials/3d/global_illumination/introduction_to_global_illumination.html)、[灯光与阴影](https://docs.godotengine.org/en/4.6/tutorials/3d/lights_and_shadows.html)、[体积雾](https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html)、[抗锯齿](https://docs.godotengine.org/en/4.6/tutorials/3d/3d_antialiasing.html)、[分辨率缩放](https://docs.godotengine.org/en/4.6/tutorials/3d/resolution_scaling.html)、[Mesh LOD](https://docs.godotengine.org/en/4.6/tutorials/3d/mesh_lod.html)、[Decal](https://docs.godotengine.org/en/4.6/tutorials/3d/using_decals.html)、[4.5→4.6 升级](https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html)。
- 美术/资产：[60-30-10 配色法则](https://wolfcrow.com/why-great-movies-use-the-60-30-10-percent-color-rule/)、[Trim Sheet 模块化环境流程](https://www.animaticsassetstore.com/2025/10/31/trim-sheets-that-sell-a-production-workflow-for-modular-environments/)、[Kitbash 模块化方法](https://blog.voxelschool.com/noticias/kitbashing)、[Poly Haven 许可（CC0）](https://polyhaven.com/license)、[ambientCG](https://ambientcg.com)、[Kenney](https://kenney.nl)、[Quaternius](https://quaternius.com)。
