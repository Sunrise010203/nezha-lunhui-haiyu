# 把「Unity 版 AI 3D 工作流」搬到 Godot：建议与注意点

> 对象：`E:\godot_game_by_fable`（Godot 4.6.3 / Forward+ / Jolt / 2.5D 横版《哪吒·轮回海域》）
> 原文流程（X @Saccc_c，2026-10）：Fable 5.1 出 PRD → Image 2.5 出场景/人物参考图 → Tripo 生成 3D 资产 → Blender + Auto-Rig Pro 绑骨蒙皮 → Mixamo 接动作 → Opus 5.5 搭代码 → Unity MCP/CLI 在编辑器里操作 + 多机位截图迭代。
> 本文只讨论「Unity → Godot」这一段替换，以及落到本项目上的顺序与风险。

---

## 0. 结论先说

1. **整条流程只有两处真的绑在 Unity 上**：
   ①「Unity App + Unity CLI + Pipeline 包 + 官方 Unity MCP」= 让 agent 在**编辑器里动手**；
   ②「Unity Humanoid Avatar」= 动作**重定向**。
   其余环节（PRD、生图、Tripo、Blender、Auto-Rig Pro、Mixamo、写代码）与引擎无关，原样保留。

2. **那一格不需要"找个 Godot MCP"来顶。** Godot 的工程是纯文本（`.tscn` / `.tres` / `.gd` / `.gdshader`），agent 直接读写文件就等于改工程；真正要搭的是一条**「CLI 冷启动 + 结构化打印 + 真实渲染截图」**的验证闭环。这个项目里其实已经齐了：`001/tools/capture.gd`（截图）、`001/tools/perf_probe.gd`（性能）、`001/tools/probe_*.gd`（逻辑走查）。需要的只是把它们收敛成一条命令。

3. **但别照搬"从零做游戏"的姿势。** 你现在这套是「程序化场景 + 程序化骨骼动画 + 顶点色 toon 材质」，这条工作流产出的资产是「独立 GLB 网格 + PBR 贴图 + 导入动画」。两者是不同的"美术真相"，硬塞进来会复现你上一轮已经遇到过的那个问题：**角色是异类、场景没跟上**（`哪吒角色重做路线对比.md` 已论证：场景精度决定角色上限）。
   → 这条流程对你的正确用途是「**补资产 + 补动作**」，不是「重做游戏」。

---

## 1. 环节对照表：哪些照搬、哪些必须换

| # | 环节 | 原文（Unity 版） | Godot 版 | 处置 | 风险 |
|---|---|---|---|---|---|
| 1 | PRD / 玩法梳理 | Fable 5.1 | 不变 | 留 | 低 |
| 2 | 概念图 | GPT Image 2.5 | 不变（你已在用 apimart / lovart） | 留 | 低（多视图一致性） |
| 3 | 3D 资产生成 | Tripo（H3.1 高精 / P2 游戏向） | 不变，**导出 GLB** | 留 | 中（面数、UV 重叠） |
| 4 | 修形 / 减面 / 展 UV / 烘焙 | Blender | 不变（`tools/blender/` 已有 30+ 无头脚本） | 留 | 中 |
| 5 | 绑骨蒙皮 | Auto-Rig Pro（Blender 插件） | 不变 | 留 | **高**：新骨架命名 vs 现有 22 根骨骼契约 |
| 6 | 动作 | Mixamo → Unity Humanoid 直接重定向后播放 | Mixamo → **Blender 烘到目标骨架** → 导出"单 GLB 含全部动画" → Godot `AnimationPlayer` / `AnimationTree` | **换** | **高**：与现有程序化动画体系冲突 |
| 7 | 场景搭建 | Unity MCP 在编辑器里按参考图摆放 | 沿用 `level_base.gd` / `level_4.gd` **程序化摆放**，GLB 只作为单体道具 | **换** | 中（draw call、风格割裂） |
| 8 | 材质 / 光照 | URP Lit + Progressive Lightmapper | `StandardMaterial3D` / 自写 `.gdshader`（现有 `char_body.gdshader`）+ `WorldEnvironment` / `LightmapGI` / `ReflectionProbe` | **换** | 中（材质名契约、PBR↔toon 转换） |
| 9 | 写代码 | Opus 5.5 | 不变（GDScript） | 留 | 低 |
| 10 | 迭代与 bug 修复 | Unity MCP 截图 + 看画面 | `--headless` 逻辑校验 + `capture.gd` 真实渲染截图 + `perf_probe.gd` 数值 | **换（但已有）** | 低 |
| 11 | 打包发布 | Unity Build | `export_presets.cfg` + `--export-release`（**当前还没有这个文件**） | **换** | 低 |

一句话：**第 6、7、8、10 行是真正的工作量，第 5 行是真正的门槛，其余都是"换个软件继续做"。**

---

## 2. 核心替换：Unity MCP →「一条命令」

### 2.1 为什么 Godot 不需要等价的编辑器 MCP

- Godot **没有**"从外部驱动运行中编辑器"的公共 API；社区 Godot MCP（Coding-Solo / Fulviuus / jasonsuhari 等）基本是三条路的封装：CLI 启停与导出、`--headless --script` 跑 GDScript 改 `.tscn`、注入临时 autoload 开 TCP 抓帧。**它们不能可靠操作编辑器里正在编辑的节点**，截图能力依赖自建 bridge。
- 而 Unity 之所以必须 MCP，是因为 `.unity` / `.prefab` 的序列化与 GUID 引用太脆，手改文本容易炸；Godot 的 `.tscn` 虽然也有 `uid://`，但结构简单、路径是 fallback，直接写是可行的。
- 结论：**别把"模拟 Unity 工作流"当目标**。这个项目的关卡本来就是脚本生成的（`level_base.gd`），回到编辑器拖节点是**退步**。

### 2.2 实际要建的三件东西（半天到一天）

```
① 逻辑真值： --headless --path <项目> [--check-only --script res://x.gd]
             → 退出码 / stderr / 打印的结构化结果
② 画面真值： 真实渲染器 + capture.gd（不能用 --headless，拿不到画面）
③ 成本真值： perf_probe.gd（draw call / tris / 显存 / 帧时间）
```

可选优化：把 `capture.gd` / `perf_probe.gd` / `probe_*` 的参数收敛到一个入口脚本（`tools/agent_run.gd`），agent 只记一条命令，减少"跑错工具"的概率。

### 2.3 本机实测到的 CLI 事实（Godot 4.6.3）

| 开关 | 状态 | 用途 |
|---|---|---|
| `--headless` | ✅ | 等价 `--display-driver headless --audio-driver Dummy`，**关闭全部渲染** |
| `--script <res://…>` | ✅（需 editor build） | 脚本须 `extends SceneTree` 或 `MainLoop` |
| `--check-only` | ✅（配 `--script`） | 只解析语法错误，最快的"编译门禁" |
| `--import` | ✅（editor build，隐含 `--editor --quit`） | 新增/改动资源后必须跑，否则运行期资源为空 |
| `--quit-after <N>` | ✅ | 只跑 N 帧，适合"能不能实例化"的冒烟 |
| `--write-movie <file>` | ⚠️ | 帮助里支持 `.avi` / `.png` 序列；本机试跑一次 `signal 11` 崩溃（疑似 D3D12 + 沙箱下 `user://` 写入失败），**暂不作为关键路径** |
| `--resolution` / `--position` | ✅ | 固定截图分辨率 / 把窗口挪开 |

### 2.4 沙箱环境的坑（本机实测）

Godot 启动会写 `user://`（Windows 上是 `%APPDATA%\Godot\app_userdata\…`）。在当前 workspace-write 文件沙箱下，如果 APPDATA 不可写，会先报：

```
ERROR: Failed to open 'user://logs/godot2026-10-20T00.43.03.log'.
CrashHandlerException: Program crashed with signal 11
```

跑命令前把 `APPDATA` 指到工作区内目录即可（实测可行）：

```powershell
$env:APPDATA = 'E:\godot_game_by_fable\_tmp_appdata'
```

同时注意：截图 / 日志 / 探针输出**一律用绝对路径**，不要依赖 `user://`。

---

## 3. 七个坑（按翻车代价排序）

### 3.1 【代价最高】骨骼命名契约：换模型 = 换掉整套动画

- 现状：`nezha_lit.glb` 是 22 根骨骼、**0 个动画**，动画全程序化。`player.gd` 通过 `_bones` 字典**按骨骼名**取 index：`player.gd:1584` 取 `hand.R` 让火尖枪跟手；`player.gd:1538-1575` 驱动 `rib.L/R.1~3` 六节做混天绫摆动；风火轮跟脚骨。
- Tripo / Auto-Rig Pro / Mixamo 出来的骨架命名与层级完全不同（常见 `mixamorig:Hips`）。
- **对策**：在 Blender 里写 `rename_bones.py`（正则映射 + `apply rest`），把新骨架改成那 22 个原名，并把「**新 GLB 的骨骼名集合 == 旧 GLB**」作为资产进厂的**硬验收**（可以加进 `tools/blender/inspect_glb.py` 的输出里）。
- **不要指望 `BoneMap` 救场**：`BoneMap` / `SkeletonProfileHumanoid` 是**导入期给动作重定向**用的，它不会改变运行时 `Skeleton3D` 的骨骼名，`_bones.get("hand.R")` 照样返回 `-1`，整套 pose 静默失效。

### 3.2 【代价最高】动画体系冲突：程序化 pose vs 导入动画

- 现状：`player.gd` 每帧算姿态（待机/奔跑/腾空三态、攻击 Tween、倾斜、呼吸、飘带、武器跟随）。Mixamo 动画是完整片段，两者直接叠会"打架"（谁覆盖谁取决于 `set_bone_pose` 的调用顺序，出现"动画抽搐/武器脱手"这类难查的 bug）。
- **对策（架构）**：
  - `AnimationTree`（StateMachine + BlendSpace1D）只管**基础片段**；
  - `SkeletonModifier3D` / 代码叠加层管**增量**（受击抖动、冲刺残影、飘带、武器跟随）。
  - 本机已确认 `AnimationTree` / `AnimationNodeBlendSpace2D` / `SkeletonModifier3D` / `SpringBoneSimulator3D` / `RetargetModifier3D` **全部存在**（Godot 4.6.3 实测）。
- 项目内已有两处方案论述可直接照做：`美学改进建议与实施方案.md`（路线 A，3–5 天）、`场景与角色改进方法.md`（Mixamo → AnimationTree → 叠加层）。
- **止损条件**：只接 idle + run 两段试做 2–3 天；若在游戏机位下"没有明显更好"，问题就不在动画（在模型/镜头/材质），立刻回退。

### 3.3 【代价高】面数 / draw call 预算

- 基线：第四章 33 万三角形 / 82 draw call（已略超 30 万红线）；TripoSR 遗留的敌人单只 15.9 万–26 万面。
- Tripo H3.1 可出 150 万面、4K 贴图；直接进 Godot 的结果是：导入慢、显存涨、**每个材质一个 draw call**。
- **对策（进厂门禁）**：
  - 单体道具 ≤ 3k tris、角色 ≤ 15k tris、贴图 ≤ 1K；
  - 导出前 Blender 里 Decimate + **合并同材质** + 贴图降采样 + 一张图集；
  - 每次进厂跑 `perf_probe.gd`，超基线不允许进下一阶段。
- 依据：2.5D 侧视、角色在游戏机位只有 300–350px 高，超过这个面数在画面上看不出来，只是烧性能。

### 3.4 【代价中】材质名契约：新资产会被压成"塑料"

- `game.gd:245 _stylize_character_mat()` 按**材质名**分支：名字含 `gold` / `metal` / `brass`（`game.gd:249`）→ 走 PBR 金属；其余强制 toon + `metallic ≤ 0.15`（`game.gd:262`）。这是上一轮"金饰变塑料"的修复成果。
- Tripo 导出的材质名通常是 `material_0` / `Mat` / `材质` → 全部落进 toon 分支，金饰又变塑料。
- **对策**：资产进厂时把材质名改到契约内，或把黄金/金属白名单扩成正则；并在 `本轮改动说明-*.md` 里记一笔"这次新增/改名的材质"。

### 3.5 【代价中】风格割裂：写实 PBR 资产 vs 平涂 toon 场景

- 现在的场景是低多边形 + 平涂 + 自发光（`level_base.gd` 程序化拼装），角色走 6×2048 贴图 + 自定义 shader。Tripo 出的是写实/半写实 PBR。
- **对策**：新资产**必须过一道"风格化"处理**（色板化 / 顶点色 / 反向外扩描边），或者至少保证"一个关卡里只有一种美术语言"。你自己的 `哪吒角色重做路线对比.md` 已经算过：孤立提精度只会更割裂。
- 相关低成本前置项：主关卡加 1 个 `ReflectionProbe`（现在是"无 SSR、SSAO 关、无探针"，金饰只能"亮黄"）。**先补这个，再谈换模型。**

### 3.6 【代价中】导入缓存与 UID 纪律

- `.import`（128 个）、`.uid`（59 个）、`.godot/` 缓存是**生成物**：`.import` / `.uid` 不手写，`.godot/` 要 ignore。
- 改了 GLB / 贴图 / 新增资源后，**必须先 `--headless --import`**，否则运行期报"资源为空 / No loader found"。
- 以后 `git init` 时 `.uid` **必须提交**（4.4+ 的 UID 机制；缺了会报 `invalid UID … using text path instead`）。
- 现在 `.gitignore` 只有 `.godot/` 和 `/android/` 两行——够用，但**至今没有 git 仓库**（`git rev-parse` 失败），这是当前最大的单点风险。

### 3.7 【代价低但致命】截图不是真值：语法错也会"看起来像美术坏了"

- 项目踩坑记录第 5 条：改 `player.gd` 时误删一行函数头 → `Parse Error` → 整个关卡脚本编译失败 → **截图全黑**。
- **对策（真值优先级）**：
  `退出码 / SCRIPT ERROR` > `probe 打印的数值` > `截图` > `肉眼感觉`
- 顺序固定为：`--check-only` → `--headless` 实例化 → `--import` → 截图 → `perf_probe`。

---

## 4. 落到这个游戏的顺序（P0–P5，每步可停）

| 阶段 | 内容 | 工时 | 验收（硬指标） | 止损 |
|---|---|---|---|---|
| **P0 备份** | `git init` + 首次提交（含 `.uid`，忽略 `.godot/`）；四章各跑一次 capture + perf_probe 存 `_baseline/r0/` | 0.5 天 | 能 `git checkout` 回退；四章基线图与数字齐 | 无（必须先做） |
| **P1 资产进厂管线** | 一条命令：Blender 无头（减面→合并材质→贴图降采样→改名（骨骼/材质）→导出 GLB）→ `--import` → 自动出 5 视角 contact sheet | 1 天 | 单件 ≤3k tris、≤1 张 1K 贴图、骨骼名/材质名都在白名单 | 若改名脚本写不动 → 先只换"无骨骼道具" |
| **P2 道具试点** | 只做第四关 3 件标志性道具（潮纹碑 / 鲸骨拱 / 椎骨天顶），仍由 `level_4.gd` 程序化摆放 | 1–2 天 | draw call ≤ 90、tris ≤ 33 万、同机位截图与 r0 对比 | 风格不搭 → 回退到程序化几何 |
| **P3 动作试点（风险最高）** | 只接 idle / run：`AnimationTree` 播片段 + 程序化降级为叠加层 | 2–3 天 | 游戏机位下动作更自然、无滑步、武器不脱手 | 不更好 → 立即回退，不做全量 |
| **P4 主角网格（选做）** | `哪吒角色重做路线对比.md` 的 A 路线；先做 1 天前置实验（3 版图生 3D 同机位对比） | 5–9 天 | 350px 下摆脱"玩具感"、帧率不低于当前 | 3 版都糊 → 改走"采购资产 + A 级材质" |
| **P5 敌人（可选）** | 先减面 + 补 normal/ORM（现有 `post_nezha_maps.py` 那套管线），不重新生成 | 2–3 天 | 单只 ≤ 20k tris、材质统一 | 收益低 → 直接砍 |

**顺序的理由**：先有回退能力（P0）→ 先有管线（P1）→ 先做低风险高可见的道具（P2）→ 再做高风险的动画（P3）→ 最后才动角色网格（P4）。原文是"从零做新游戏"，可以先搭场景再上角色；你是"改已有项目"，必须先保住可回退性。

---

## 5. 过程中的操作纪律（这条流程最容易被忽略的部分）

1. **一次只改一个变量。** agent 批量改 10 个文件 → 出问题无法定位；本项目已有"改完先 `--headless --import | grep SCRIPT ERROR` 再截图"的教训。
2. **每次迭代留证**：截图进 `_baseline/<轮次>/`，说明写进 `本轮改动说明-*.md`（项目已有这个习惯，保持）。
3. **资产进厂 = 一次可回退的提交**，附：GLB 路径、tris、贴图数、骨骼名 diff、材质名 diff、截图。
4. **不要把"手感变化"当成美术问题**：换模型时必须保持碰撞体、脚底偏移（`MODEL_LIFT = 0.34`）、攻击判定框不变；最好固定一段输入序列跑 probe，比较 HP / 位置 / 命中数轨迹。
5. **Blender 侧优先无头脚本**（`E:\blender.exe --background --factory-startup --python …`）：可复现、可进版本库。`blender-mcp`（TCP 9876）留给交互式调试——它不在无头模式下工作，且要求 GUI 常开，不适合当流水线关键路径。
6. **`.blend` 不要直接拖进 Godot**：虽然能读，但它会调本机 Blender（headless 下同样要调），CI 里会挂死。统一"Blender 导出 GLB"。

---

## 6. 不要做的事

1. **不要用 Godot MCP 去模拟 Unity 工作流**：关卡本来就是代码生成的，回到编辑器拖节点是退步；社区 MCP 也不能可靠操作运行中的编辑器。
2. **不要整场景导入**：每个道具一个 mesh + material，draw call 会从 82 飙到几百，且失去"改一个数就改关卡"。
3. **不要用 `BoneMap` 修命名**（见 3.1）：它不改变运行时骨骼名。
4. **不要给敌人做全套骨骼**：TripoSR 遗留的高模敌人先减面，收益/成本比最高（`_review/art/ai-3d-pipeline.md` 已论证）。
5. **不要在没有 git 的情况下让 agent 批量改文件**；也不要在沙箱里让 Godot 写 `user://`（见 2.4）。
6. **不要相信"一次生成就能用"**：这条流程 60% 的时间在重拓扑 / 减面 / 展 UV / 烘焙 / 改名 / 绑骨——正是 AI 帮不上、也是原文强调"要在 Blender 里反复微调"的部分。按项目估算：AI 出形路线 3–4.5 人日/角色，哪吒（带挂件与精修）6–8 人日。

---

## 7. 可选增强：让流程更接近原文

1. **概念图阶段锁"四视图一致性"**：固定参考图 + 明确"同一角色 / 四视图 / 无遮挡 / 同服装细节"。最贵的一次返工是"3D 生成完发现四视图不自洽 → 重生成 + 重烘贴图"。
2. **把"哪些走 Tripo、哪些走程序化"的判断固化成规则**（原文是让 AI 在图上标注）：
   - 程序化几何：地形 / 建筑 / 可交互机关 / 需要反复改参数的；
   - Tripo：有辨识度的单体道具 / 角色 / 只摆 1–3 次的装饰件。
   写进 `README.md` 或 `AGENTS.md`，省掉每轮对话的判断成本。
3. **`contact_sheet.py` 已有**：把"资产进厂自动出 5 视角对比图"做成验收件，比让 agent 逐张描述可靠。
4. **补齐 `export_presets.cfg`**：原文流程的终点是"能玩"，你现在只能从编辑器运行。可先做 Windows 桌面预设，跑一次 `--export-release` 验证。

---

## 8. 可以直接复用的原文提示词（改口径）

原文的场景资产拆解提示词，把技术栈换掉即可：

> 我现在要做 Godot 4.6 的 2.5D 横版游戏，技术栈是 Tripo（出 GLB）+ Blender（无头脚本修形/减面/改名）+ Godot（程序化摆放）。根据这张场景参考图，分析哪些资产适合用 Tripo 生成、哪些适合用程序化几何（箱体/圆柱/材质）拼——判断依据是"是否需要被反复调参数、是否会大量重复出现"。把需要 Tripo 生成的资产在图上标注出来。

原文的场景复刻提示词同样可用，但要追加 Godot 侧约束：

> …要求实现和参考图一样的质感和细节还原。约束：单件道具 ≤3k 三角面、≤1 张 1K 贴图、材质名与骨骼名必须沿用我给出的白名单；导出 GLB（Y-up），不要 .blend；完成后给我 tris / 贴图数 / 材质名清单。

---

*本文的事实核对：Godot CLI 开关取自本机 `--help`；类可用性用 `tools/_probe_caps.gd` 在 4.6.3 上实测；沙箱 `user://` 崩溃为 2026-10-20 本机实测。*
