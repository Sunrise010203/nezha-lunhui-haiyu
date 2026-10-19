# EdenLive 能不能用在《哪吒·轮回海域》上？

**评估对象**：GitHub 项目 [`VAST-AI-Research/EdenLive`](https://github.com/VAST-AI-Research/EdenLive)
（VAST / 三启万物「Project Eden」里负责**实时生成式渲染**的模块，2026-10-12 开源，Apache-2.0）
**本地项目**：`E:\godot_game_by_fable\001`，Godot 4.6.3，2.5D 横版动作，三章
**日期**：2026-10-18　**依据**：仓库代码/README/ARCHITECTURE/deploy.conf、项目页、技术报道、本仓库代码审计（见文末来源）

---

## 0. 一句话结论

**不能当成这款游戏的“运行时渲染器”接进来；能用的只有“离线生成”——把录好的游戏画面喂给 EdenLive，生成写实/风格化的宣传片、过场或背景视频，这是唯一现实、且不需要改引擎的用法。**

实时玩法演示（把画面实时重绘）技术上勉强能搭出来，但 **1280×704 / 24fps / 百毫秒级延迟** 与“60fps 高频战斗 + 精确判定”正面冲突，投入产出比很差，不建议做。

---

## 1. EdenLive 是什么（事实，不夹带宣传）

| 维度 | 事实 |
|---|---|
| 定位 | **生成式视频渲染器**，不是引擎插件、不是超分/后处理。输入 = *proxy 参考视频*（粗糙/简化画面）+ *目标首帧* + *文本 prompt*；输出 = 沿参考布局与运动重新生成的精细视频 |
| 核心思想 | “世界状态/规则”由上游程序（引擎、游戏、Agent）维护；“画面长什么样”交给 EdenLive。状态不被视频模型隐式推断，因此不负责判定、碰撞、胜负 |
| 模型 | 5B / 14B；双向（bidirectional）与少步 chunk-AR（few-step）两种推理；离线配置 14B=480p、5B=720p |
| 输出规格 | 480p / 720p；离线 24fps；实时服务默认模型帧率 16fps（可调），游戏仿真 24Hz；抓帧上限 **1280×704** |
| 实时系统 | NVIDIA FlashDreams 的 Eden 分支，WebRTC（aiortc）+ TAEHV/LightTAE 解码；**系统要求 Linux x86-64/arm64 + 80GB 以上显存（H100 级）+ 驱动 R580+ + CUDA 13 + Python 3.10** |
| 消费级显卡？ | README 确实给了「RTX 5090 上 5B 720p ≈24.7fps」，但要看清：那是**第三方推理库 LightX2V 的低比特量化部署**，**不是本仓库 `realtime/` 服务在 5090 上的实测**；本仓库实时服务自己写的是 80GB+ |
| 权重 | 约 **210GB**（dit/vae/decoder/scheduler/umt5/clip/vision-encoder/flux-c2f），Hugging Face 单独分发，需离线加载（`HF_HUB_OFFLINE=1`） |
| 接入方式 | **只有浏览器网页游戏一条路**：游戏是 `realtime/games/<slug>/` 下的 Three.js 页面，rank0 用 **Chromium + Playwright** 抓帧（`GameCaptureWorker`），HUD 以 **HTML overlay** 叠在生成视频上；没有原生引擎 SDK、没有 NDI/共享内存/桌面捕获入口、没有文档化的 REST/WS 生成 API |
| 授权 | 代码 Apache-2.0；权重混合：dit/vae/umt5/scheduler/decoder 为 **Apache-2.0（可商用）**，CLIP 为 **MIT（可商用）**，**vision-encoder（proxy-DINO / DINOv3）为 DINOv3 License（可商用，但有随附协议、禁逆向、禁军事等限制）**，**flux-c2f 为 FLUX 非商用**（只用于 workbench 生成首帧；跑已注册游戏不加载 FLUX） |
| 成熟度 | 2026-10-12 开源，90 stars / 2 forks，**0 release / 0 tag**，仍在高频更新；文档自身有前后不一致处（注册表 4 款 vs 文档“七款”等）；已知 1 个未回复 issue |

### 三个容易被营销数字带偏的点

1. **“实时 24fps”只是模型吞吐**：官方示例日志是“12 帧 / 生成 430.5ms / 27.87fps”，并注明只算模型；端到端毫秒数**没有公布**。媒体（量子位/机器之心）转述 VAST 口径是“输入到画面**百毫秒级**”，且官方明说“稳定延迟 ≈ **2 个 chunk**”。
2. **它不是“低分辨率渲染 + 神经精修”**：条件信号只有 RGB proxy（proxy-DINO 特征 + VAE latent），**不吃深度、法线、运动矢量、G-Buffer**，所以无法像 DLSS/神经渲染那样“精确引导”。它是“照着参考画面重新想象”，画面细节和角色身份由首帧 + prompt 决定，会漂移。
3. **它不负责判定**：官方示例反复强调“proxy 几何定义碰撞与规则”。对动作游戏，这意味着生成画面必须服从本地逻辑，不能反过来用生成画面做命中判定。

### 它明确擅长/不擅长的
- 擅长：连续 3D 相机（第一/第三人称）、固定侧视 2.5D（示例 `jade-duel` 就是两名武者的侧视格斗）、等距玩法（`warehouse-sokoban`）；慢节奏、画面元素少的场景。
- 不擅长（官方自认）：**高频激烈交互**、多角色身份保持、小物体精细控制、长时间视觉一致性；官方建议现阶段更适合“场景漫游、推箱子等交互相对低频的玩法”。

### 值得借鉴的设计（即使这次不用）
- **状态/外观解耦**：引擎只管规则与状态，生成模型只管“长什么样”，判定永远不交给视频模型——这个边界对任何“AI 渲染”方案都成立。
- **HUD 外挂合成**：生成帧不含 HUD，UI 由上层单独绘制；既保文字清晰，也避免模型乱画 UI。
- **确定性 24Hz 仿真 + chunk 对齐**：让参考帧节奏和模型 chunk 严格对齐，是把“视频生成”变成“可交互”的关键工程手段。
- **proxy + 首帧 + prompt 三输入**：同一段运动可以换不同首帧/prompt 出不同画风，适合做风格比较。

---

## 2. 你的项目现状（代码审计结论）

| 维度 | 现状 | 对 EdenLive 的意义 |
|---|---|---|
| 引擎/渲染 | Godot 4.6.3，**Forward+**，Windows **D3D12**，Jolt 物理，1920×1080 `canvas_items` + expand，MSAA 2× | EdenLive 服务只支持 Linux；Godot 侧没有官方插件 |
| 画面结构 | **3D 世界 + 2D HUD 分离**：关卡根 `Node3D`，HUD 是 `CanvasLayer(layer=10)` 的 Control/Label；后期全在 `Environment`（glow、体积雾、fog、filmic），**无 Compositor**；7 个自定义 shader | HUD 可单独保留、不送模型 → 中文文字不会被生成帧糊掉（这点反而对齐 EdenLive 的 HTML overlay 设计） |
| 相机 | 透视侧视跟随（fov 50、距离 8.8），Boss 战双目标取景 | 固定侧视 2.5D 有官方 demo 先例（jade-duel），但**没有连续、快速位移的 2.5D 动作 demo** |
| 性能 | 88 / 92 / 79 draw call，21 / 14 / 28.4 万三角形，450–610MB 显存，0.78–0.96s 加载；60fps 余量 ≥2×（估算）；此前全开 3414×1993 超采样时 14ms/帧 | 本地渲染**有余量**，但这份余量对“跑 5B 模型”毫无帮助 |
| GPU | RTX 5070 Laptop（**8GB 显存**，按文档假设） | 见下方“硬件差距” |
| 美术 | 青蓝龙宫 / 铁灰牢狱 / 紫黑归墟；低多边形 + 平涂 + 自发光 + TripoSR 生成的 GLB/贴图；角色约占屏高 20%；HUD 中文硬编码 | 已经是**风格化**路线；EdenLive 是“重绘成写实/二次元”，等于换美术方向，不是“提升现有画质” |
| 可录 proxy | `--write-movie` 零改代码录整窗（AVI+WAV，默认 60fps，可 `--resolution 854x480`）；也可新增 SubViewport 捕获 | 离线路线**不需要改引擎**，这是最有利的一点 |
| 缺失工程项 | 无 `export_presets.cfg`、未 `git init`、无设置页/手柄、关卡内进度不存档 | 做 Web 导出/实时演示前必须先补 |

---

## 3. 逐项对照：能不能用

| 维度 | EdenLive 现状 | 本项目需求 | 判定 |
|---|---|---|---|
| **平台** | 服务端 Linux only（.sh/apt/coturn/EGL/flash-attn/triton） | Windows + D3D12 | ❌ 只能云 GPU 或 WSL2 折腾 |
| **显存** | 官方 realtime：80GB+（H100 级）；5B 单卡；14B 1–6/8 卡 | 8GB 笔记本 | ❌ 5B BF16 权重 ~10GB，加文本编码器/VAE/解码器远超 8GB；量化版也要 32GB 级（5090） |
| **分辨率** | 抓帧上限 1280×704，输出 480p/720p | 1920×1080 | ❌ 720p 上采样到 1080p，动作游戏会明显发软 |
| **帧率** | 24fps（实时服务模型默认 16fps），24Hz 确定性仿真 | 60fps | ❌ 3D 画面只有 24fps，和 60fps 的 HUD/判定并置会“画面抖、判定跟手”割裂 |
| **延迟** | 约 2 个 chunk；模型单档 430ms/12 帧；端到端未公布（媒体口径百毫秒级） | 输入到画面 <50ms（60fps 动作游戏常识） | ❌ 差一个数量级；冲刺/弹反/摆荡会明显“拖” |
| **接入** | 浏览器 Three.js + Chromium/Playwright 抓帧 + WebRTC；契约是 `window.gameBackend` / `window.__gameTest.read()+render(dt)` | Godot 原生工程 | ❌ 没有 Godot/原生入口；要么 Web 导出重做，要么自写帧管道+改服务端 |
| **画面控制** | RGB proxy 条件；首帧+prompt 定外观；官方承认小物体/多角色/长时一致性弱 | 精确的角色动作、特效节拍、命中可读性 | ⚠️ 会“重画”，细节不可控；快速连击/粒子/震屏容易糊或漂移 |
| **玩法节奏** | 官方建议低频交互（漫游/推箱子） | 高频战斗（连击、冲刺、Boss 三核、摆荡） | ❌ 官方自己划的适用边界正好把本作排除在外 |
| **文字/UI** | HUD 走 HTML overlay，不进模型；画面内文字不可控 | HUD/中文提示/世界内 Label3D | ✅ HUD 可本地合成；但世界内 Label3D 和特效文字有风险 |
| **美术方向** | 写实/二次元/油画等“重绘” | 已有明确风格化美术 | ⚠️ 等于换皮；风格一致性靠首帧+prompt，不适合当生产管线 |
| 授权 | 代码 Apache-2.0；核心权重（dit/vae/umt5/scheduler/decoder）Apache-2.0、CLIP MIT、DINOv3 许可允许商用（有条款限制）；FLUX 非商用仅用于 workbench 首帧 | 个人项目发布/商用 | ✅ 离线路线用自有首帧即可不碰 FLUX；仍需核对 DINOv3 条款与游戏素材授权 |
| **成本/成熟度** | 210GB 权重、H100 租用、环境搭建；开源 6 天、0 release | 个人项目 | ❌ 学习/试错成本高，不是生产级依赖 |

**结论**：作为**运行时**——不行，且不是“再优化一下”就能行，而是硬件、平台、分辨率、帧率、延迟、接入方式、玩法节奏七个层面同时不匹配。作为**离线工具**——可行。

---

## 4. 如果要用：三条路线

### 路线 A（推荐）：离线生成宣传片 / 过场 / 背景视频

**这是唯一“拿来就能用”的方式，不需要 Godot 插件，也不需要实时服务。**

步骤：
1. **录 proxy**：Godot `--write-movie` 直接录 854×480 或 1280×704 的 AVI/WAV（配 `--fixed-fps 30` 定帧率）；录时隐藏 HUD（`CanvasLayer(layer=10)` 和黑屏层），只留 3D 画面。可写一个 autopilot 脚本按固定镜头走位，避免手操抖动。
2. **准备首帧**：用自己渲染的一张同机位静帧（不要用 FLUX 生成，规避非商用许可），或选一张写实/国风概念图。首帧决定整段片子的画风。
3. **写 manifest**：`id, proxy_video, first_frame` 三列 CSV + 每段 `prompts.json`（`staticPrompt` + 时间戳 `dynamicPrompts`），这是仓库 `examples/samples/` 的官方格式。
4. **租卡跑离线推理**：Linux + 80GB 显存（H100/A100 80G），装 CUDA 13 + PyTorch + 依赖，下载 210GB 权重（HF 或国内镜像），跑 `wan22_5b_720p_few_step`（720p）或 `wan21_14b_480p_bidir`（画质优先、480p）。单段 117 帧≈5 秒。
5. **回本地合成**：生成片段 → 剪辑 → 叠回本地渲染的 1080p HUD/字幕/音效。

预期：
- 产出：30–60 秒 PV、章节片头、菜单动态背景（`VideoStreamPlayer` 播 Ogg Theora 循环）。
- 耗时：环境 0.5–2 天 + 生成/挑片 1–2 天；成本粗估 H100 租用 ¥15–30/小时 × 几小时 + 权重下载流量，**总预算几百到一千元级**。
- 风险：快速动作、粒子、震屏、镜头切换容易崩；角色（哪吒/混天绫/乾坤圈）身份会漂移；需要多跑几版挑片。**慢镜头、固定机位、少元素**的镜头成功率最高。

### 路线 B（谨慎）：实时“生成式渲染”演示

技术上可搭，但只适合“慢节奏展示”，不能用于正式玩法。
- 路线 B1：**Godot Web 导出**。必须把 Forward+ 换成 GL Compatibility（体积雾没了，二三章氛围掉一档）、7 个自定义 shader 重测、Jolt/中文字体/首包 90MB+ 都要处理；然后实现它的 `window.gameBackend` 契约、注册进 `games/registry.json`、补 `initial-state.json` 和 `adapter.js`。工作量 5–8 人日起步，且画面仍是 720p/24fps。
- 路线 B2：**原生捕获 + 自建客户端**：Godot 用 SubViewport 渲染 720p → 编码 → 送服务；但服务端的抓帧路径绑定 Chromium（rank0 同时跑 Chromium 和 proxy-DINO 编码），要改服务端代码，等于给研究代码做二次开发。
- 延迟预算：采集/编码 30–40ms + 网络 20–40ms + 推理（2 chunk）+ 显示 10–20ms，**实际 100–300ms 量级**；24fps 下跑图勉强，Boss 战/混天绫摆荡不可玩。

### 路线 C（可选）：风格探索 / 概念图
用同一段 proxy 跑不同首帧+prompt（写实、国风、水墨、动画），给美术定调；或只生成 5 秒“如果这游戏是写实电影”的样片。成本同样需要 GPU 环境，收益是“决策参考”，不是资产。

### 不建议
- 把 EdenLive 放进运行时渲染管线；
- 期待它做“1080p 60fps 画质升级”；
- 用它替代现有美术资产生产（它是重绘，不是生成资产/贴图）。

---

## 5. 具体不足与差距（清单）

1. **硬件**：官方实时服务要 80GB 显存（H100 80G）；最快的消费级路径是 32GB 的 5090（且是第三方 LightX2V 量化）；本机 8GB，连 5B 权重都放不下。
2. **平台**：Linux only（驱动 R580+、CUDA 13、coturn、EGL 等），Windows 未支持未验证；只能云 GPU 或 WSL2 自行折腾。
3. **分辨率**：抓帧上限 1280×704、输出 480p/720p；项目是 1920×1080，上采样后动作画面发软。
4. **帧率**：24fps（服务默认模型 16fps），项目 60fps；生成画面与 60fps HUD/判定并置会割裂。
5. **延迟**：约 2 个 chunk、模型单档 430ms/12 帧、端到端未公布（媒体口径百毫秒级）；动作游戏预算是 <50ms，差一个数量级，云上还要加网络。
6. **接入**：无 Godot/原生 SDK；唯一入口是浏览器 Three.js + Chromium/Playwright + WebRTC；要么 Web 导出重做，要么自写管道并改服务端。
7. **画面可控性**：只吃 RGB proxy，不吃深度/法线/运动矢量；角色身份、小物件、快速动作、粒子/震屏、长时一致性都是官方承认的弱项。
8. **判定与可读性**：判定必须留在本地逻辑；但本项目靠颜色语义（红环预警）、rim 轮廓光、hitstop/震屏传达节奏，写实重绘会削弱这些信号，Boss 战和摆荡最受伤。
9. **玩法节奏**：官方明确“现阶段更适合场景漫游、推箱子等低频交互”，本作是高频动作——正好在边界外。
10. **美术方向**：写实化重绘 ≠ 现有青蓝龙宫/铁灰牢狱/归墟虚空的风格化；等于换美术方向，一致性不可控，不适合当生产管线。
11. **授权**：代码 Apache-2.0、核心权重 Apache-2.0/MIT，DINOv3 许可允许商用（有附加条款），FLUX 非商用但只用于 workbench 首帧（跑已注册游戏/离线用自有首帧都不碰它）——授权不是主要障碍；商用仍需核对 DINOv3 条款与游戏素材授权。
12. **成本与成熟度**：210GB 权重、H100 租用、环境搭建；开源 6 天、0 release/tag、文档前后不一致、仅 1 个 issue——研究代码，不是稳定依赖。
13. **工程前置**：项目本身无 `export_presets.cfg`、未 git init、无设置页；做 Web 导出/实时演示前要先补这些。

---

## 6. 更划算的替代方案（如果目标是“更好看/更有卖点”）

| 目标 | 建议 | 成本 |
|---|---|---|
| 提升实机画面 | 先做已有评审的 P0：阴影 pass、AI 模型减面/LOD、去 1.78× 超采样；再统一光照/材质/后处理；FSR 类超分 | 低 |
| 宣传片质感 | 录 1080p60 实机 → 离线 AI 超分/补帧（Topaz、RIFE、Real-ESRGAN）→ 调色剪辑 | 低 |
| “AI 感”美术 | 继续用 Tripo/TripoSR/图像模型做资产、贴图、立绘（已在用） | 低 |
| 想验证生成式渲染 | 租 5090/ H100 跑官方 demo（自带样例视频），先感受 24fps/百毫秒延迟的真实体感 | 几十到几百元 |
| 想“把 EdenLive 放进游戏” | 只做**离线过场/背景视频**贴进 `VideoStreamPlayer` | 中（见路线 A） |

---

## 7. 建议的下一步（决策树）

- **目标是“让游戏更好玩/更好看”** → 不采用 EdenLive，回到第 6 节的本地优化。
- **目标是“做一支 AI 宣传片”** → 走路线 A，先做一个 **10 秒 spike**：录 5 秒固定机位慢镜头 proxy → 租 1 张 80GB 卡跑一个 clip → 看质量再决定是否扩大；预算控制在几百元内。
- **目标是“研究/展示生成式渲染”** → 走路线 B，但明确只做 demo，不绑定正式玩法；优先用官方自带游戏验证链路，再考虑移植。
- **无论哪条**：先补 `git init`、`export_presets.cfg`、设置页；录 proxy 前加“隐藏 HUD / 纯 3D 捕获”开关。

**什么条件下可以重新评估**（满足其中 3 条以上再考虑接入运行时）：
- 输出支持 1920×1080、≥60fps；
- 端到端延迟压到 50ms 以内（官方当前口径是百毫秒级）；
- 单卡 16GB 显存可跑，或提供 Windows 支持 / 引擎插件（Godot GDExtension）；
- 提供帧级同步输入（引擎 buffer、时间戳、状态）而不是只吃 RGB proxy；
- 商用许可链条清晰（当前代码/核心权重已可商用，需核对 DINOv3 条款）；
- 出现正式的 release/版本化 API，而不是“6 天大的研究仓库”。

**一句话决策**：现在**不值得**把它纳入这个游戏的渲染管线；如果对“AI 生成画面”有兴趣，**只值得花几百元做一次离线宣传片 spike**，用结果说话。

---

## 8. 附：来源

- 仓库主页：<https://github.com/VAST-AI-Research/EdenLive>
- 主 README（定位/模型/权重/许可/5090 数字）：<https://github.com/VAST-AI-Research/EdenLive/blob/main/README.md>
- 实时服务 README（80GB H100、WebRTC、四服务拓扑）：<https://github.com/VAST-AI-Research/EdenLive/blob/main/realtime/README.md>
- 部署配置（5B/14B、NPROC、Chromium/FLUX 注释）：<https://github.com/VAST-AI-Research/EdenLive/blob/main/realtime/deploy.conf>
- 架构文档：<https://github.com/VAST-AI-Research/EdenLive/blob/main/realtime/ARCHITECTURE.md>
- 游戏注册表（含侧视 2.5D 的 jade-duel）：<https://github.com/VAST-AI-Research/EdenLive/blob/main/realtime/games/registry.json>
- 权重：<https://huggingface.co/VAST-AI/EdenLive>　技术报告：<https://assets.vast-eden.ai/assets/edenlive/EdenLive-tech-report.pdf>
- 项目页：<https://vast-eden.ai/?p=edenlive>
- 中文报道（“单卡 720P 超 24FPS / 端到端百毫秒级 / 现阶段更适合低频交互”）：[量子位（新浪转载）](https://finance.sina.com.cn/wm/2026-10-18/doc-inivrzvi7712925.shtml)、[机器之心（搜狐）](https://www.sohu.com/a/1089378426_129720)
- 本地审计：`_review/edenlive/game-fit.md`（渲染管线/接入点/性能预算，含 `文件:行号`）、`_review/edenlive/edenlive-facts.md`（仓库事实清单）
