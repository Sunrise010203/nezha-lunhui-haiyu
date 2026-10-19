# AI 3D 角色管线调研（2026-10-18）

对象：Godot 4.6 / 2.5D 横版动作《哪吒·轮回海域》；Win + RTX 5070 Laptop 8GB；个人开发者 + AI 辅助。
现状（实测）：本地角色全是 TripoSR 类静态网格 —— 哪吒 24,252 tris、crawler 159,116、shooter 260,764、boss 196,136，**无骨骼**、1024² 贴图（`_review/03-performance-visual.md` A-02）。
→ 真正的问题不是"怎么生成模型"，而是"怎么把无骨骼三角面汤变成能绑骨、能进 Godot 的角色"。
来源：2026-10-18 用 web_fetch 抓取；抓不到的页面标"未核实"。本机 shell 无外网。

## 0. 六条结论

1. 主角路线应是 **AI 出形 → Blender 重拓扑 → Mixamo 绑骨 → Godot 内置 Retarget**，不是"生成一次直接进游戏"。
2. Tripo **H 系列 = 高精度**（H3.1 标准最高 150 万面 / ultra 200 万面），**P 系列 = 游戏向低面数**（P1.0 最高 2 万面、更快）。"P 系列原生四边面"仅第三方资料间接支持，官方页不可达 → **未核实**。
3. Hunyuan3D 云端 API 性价比最高：Normal 生成 25 credits、**自动绑骨 10 credits（可导出 FBX）**、四边面 Smart Topology 50 credits；credit 单价 $0.0135–0.015 → **一个带骨骼的 quad 角色 ≈ $1.2**。
4. 8GB 笔记本本地跑 Hunyuan3D/TRELLIS 不现实（权重 + 贴图流水线显存远超 8GB），一律走网页/API。
5. Mixamo 仍免费（Adobe 账号，2000+ mocap、自动绑骨、FBX、可商用），但**只支持人形**、库近年几乎不更新。
6. 敌人不必绑骨：159k–260k tris 先减面，或直接切回项目已预留的 Sprite3D 立绘路径，收益远大于做全套骨骼。

## 1. 工具横评

| 工具/模型 | 2026 版本 | 拓扑/面数 | 自动绑骨 | 导出 | 价格/许可 | 国内 |
|---|---|---|---|---|---|---|
| Tripo H3.1 | v3.1-20260211 | 三角为主，150 万/200 万面 | 需另购 Rig | GLB | 官方价未核实 | 网页、阿里云百炼 |
| Tripo P1.0 | P1-20260311 | ≤2 万面，快 | 同上 | GLB | 同上 | 阿里云百炼可调 |
| Tripo P2 | 2026 | 未核实 | 未核实 | GLB | Comfy 211–274cr/次 | 第三方 |
| Hunyuan3D 3.0/3.1 | 3.1 无 LowPoly | ≤1.5M 面 + 8K PBR | 增值 API 10cr | GLB/FBX | 社区许可，商用需读条款 | 腾讯云，直连 |
| Meshy 7.1 | 2026-09 | 可选 quad/tri、面数、对称 | 同次生成一步绑骨 | 未核实 | 官方价未核实（第三方 172cr/模型） | 网页 |
| Rodin 2.5 | Hyper3D | 干净拓扑，≤5 张参考图 | 未核实 | 未核实 | Comfy Gen-2.5 158–316cr | 网页 |
| TRELLIS / SAM3D | 开源 | 高面三角、无绑骨 | 无 | GLB | 开源免费 | 需自建 GPU |

（定价对比基准：ComfyUI 合作节点报价，2026-10-18；Hunyuan 单价取自腾讯云官方文章）

## 2. AI 静态网格 → 游戏可用角色（单人估算）

| 步骤 | 工具 | 做什么 | 工时 |
|---|---|---|---|
| 减面/重拓扑 | Quad Remesher（Blender 插件，付费含 1 月试用）、Blender Decimate、Instant Meshes（免费开源） | 三角面汤 → 5–10k 四边面，保剪影 | 0.5–1 人日 |
| UV + 烘焙 | Blender Smart UV + Bake | 把 AI 1024 贴图烘到新 UV，保住原观感 | 0.5 人日 |
| 材质简化 | Blender + Godot toon | 压成 4–8 色色板/顶点色，平涂 + 描边 | 0.5 人日 |
| 绑骨 | Mixamo / Tripo Rig / Rigify | T-pose 上传，分钟级出骨骼 + 权重 | 0.5 人日（含修手） |
| 动作 | Mixamo 库 | idle/走/跑/跳/攻击，下载勾 In-Place | 0.5 人日 / 5 动作 |
| Godot 接入 | Skeleton3D + bone_map + AnimationTree | 见 §4 | 0.5–1 人日 |

合计 **3–4.5 人日/角色**；哪吒因挂件与精修，按 6–8 人日估。

## 3. 绑定与动作

- **Mixamo**：免费、自动绑骨 1 分钟内、FBX 导出、允许商用（不可转卖原始动画数据）；对人形好，对四足/异形/夸张比例会翻车；没有中国武术类动作。
- **Tripo Rig**：Comfy 暴露 `Rig model`(52.75cr)、`Rig Check`(免费)、`Retarget rigged model`(21.1cr)；是否自带动作库**未核实**。
- 备选：AccuRig（Reallusion，免费）、Blender Rigify；动作库 ActorCore 付费；视频转动作 Rokoko Video / Plask / Cascadeur（价格未核实）。
- 2.5D 横版只需 **idle / run / attack1-3 / hit / death / jump / dash 共 8–10 个**，Mixamo 覆盖大半；重击与大招建议手 K 或 Cascadeur。

## 4. Godot 4.6 接入要点（官方文档）

- Godot 骨骼动画是"骨骼 Nodepath 的 Transform 轨道"，**同名骨骼不能直接共享动画**，必须 Retarget：Skeleton3D 高级导入 → `bone_map` + `SkeletonProfileHumanoid`（按命名模式自动映射，故保留通用英文骨骼名）。
- Rest Fixer 三个开关最关键：`Apply Node Transform`（修导出残留变换 / 0.01 缩放）、`Overwrite Axis`（统一 rest，共享动画最重要）、`Fix Silhouette`（A-pose 必开）；`Normalize Position Tracks` 用 `motion_scale` 归一化位移。
- 导入共享动画库时开 `Remove Tracks`（Except Bone Transform / Unimportant Positions / Unmapped Bones）；要保留原 rest 用 `realtime_retarget` 模块。
- Godot 4 的 Bone Pose **包含** Bone Rest（与 Godot 3 不同）。
- 坑：FBX 不能直接导入（先 Blender 转 glTF）；导出前 Apply Transform；带挂件（混天绫/乾坤圈）的角色**别开** Remove Tracks，否则挂件不动；Mixamo 动画用 In-Place + 代码驱动 CharacterBody3D 根运动，避免滑步；动画压缩会削位置轨道。
- 面数：现有 AI 模型直接进场景使初始敌人达 1.42M tris/帧（实测），必须先减到 <20k。

## 5. 三条路线（成本/工时/质量/风险）

| | A 全 AI 生成 + 自动绑骨 | B AI 出形 + Blender 精修（推荐） | C 资产包 / 外包 / 转 2D |
|---|---|---|---|
| 工具链 | Hunyuan API / Meshy 7.1 / Tripo P1 + 内置 rig | Tripo P1 或 Hunyuan 出形 → Blender 重拓扑 → Mixamo 绑骨动作 | Synty / Quaternius / Kenney、国内外包；或 Sprite3D + Spine |
| 工时 | 0.5–1 人日/角色 | 3–5 人日/角色 | 0–1 人日（买）/ 外包 5–10 天 |
| 预算 | ≈$1–5/角色 | $0–150（AI credits，Quad Remesher 可选） | 资产包 $50–200；外包 $300–1500/角色（未核实） |
| 质量 | 中：手部、权重、拓扑不稳 | 高：可控低模 + 平涂，贴风格 | 中上，但风格不符中国神话 |
| 风险 | 结果不可预测、返工、许可 | Blender 学习曲线 | 风格不统一、沟通成本 |

**推荐 B，并做混合**：哪吒走 B；杂兵/Boss 走 A（Hunyuan Smart Topology + Auto Rig 一键，或减面后保留程序化骨骼）；预算极低时敌人切 Sprite3D。
理由：2.5D 侧视、角色屏高约 17%（实测），5–10k tris + 平涂足够；观感由**骨骼与动作质量**决定，不是 AI 面数。

## 6. 哪吒的一致性与挂件

- 一致性：先锁一张正/侧/背/45° 概念图，再用多视图输入（阿里云 Tripo 支持前/左/后/右 2–4 张）一次生成；脸、发髻、红绫在 Blender 手改，贴图重绘成色板 → 跨动作、跨镜头一致。
- 混天绫：3–4 段骨骼链 + 自写 spring（每帧向父骨方向弹回）或 `PhysicalBoneSimulator3D`；不要每帧重建碰撞。
- 乾坤圈：`BoneAttachment3D` 挂右手骨，投掷时 detach 成独立投射物（项目 `ring_throw.gd` 已有逻辑）；风火轮挂脚部 Socket + GPUParticles3D。
- 材质：AI 贴图压成色板 + toon/unshaded + 反向外扩描边，比保留 PBR 更贴"平涂 + 自发光"目标。

## 来源（均 2026-10-18 抓取）

- Hunyuan3D 开源 vs API、增值能力与价格：https://www.tencentcloud.com/techpedia/148276?lang=en
- Hunyuan 社区许可与 credit 单价（$0.0135–0.015）：https://www.tencentcloud.com/techpedia/148273?lang=en
- Tripo H3.1 / P1.0 定位与面数（阿里云百炼）：https://help.aliyun.com/zh/model-studio/tripo-3d-generation-api-reference
- Tripo/P1/P2/Rig/Retopology/quad 加购、Hunyuan 3.x、Rodin 报价：https://docs.comfy.org/tutorials/partner-nodes/pricing
- Meshy 7.1（2026-09，quad+一步绑骨）、Hunyuan 3.1 Pro、Rodin 2.5：https://www.summerengine.com/pt/models/meshy-7-1
- Mixamo 免费/可商用/仅人形：https://schoolofmotion.com/blog/why-mixamo-is-still-one-of-the-best-animation-resources
- Godot Retarget（bone_map / Rest Fixer / Remove Tracks）：https://docs.godotengine.org/zh-cn/4.x/_sources/tutorials/assets_pipeline/retargeting_3d_skeletons.rst.txt
- Quad Remesher（付费、1 月试用）：https://exoside.com/quadremesher/
- Hunyuan3D 开源仓库（社区许可，2.x 权重）：https://github.com/Tencent-Hunyuan/Hunyuan3D-2
