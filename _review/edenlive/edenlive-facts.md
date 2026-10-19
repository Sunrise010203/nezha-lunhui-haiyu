# EdenLive 事实清单（2026-10-18；仅凭公开仓库内容，逐条给出处）

## 0. 快照

- `VAST-AI-Research/EdenLive`，Apache-2.0，Python；created **2026-10-12T01:57Z**；repo size ≈122.6 MB（API `size:125553` KB）；homepage 指向 <https://vast-eden.ai/?p=edenlive>（JS 渲染，正文抓不到）。
- **90 stars / 2 forks / 90 watchers / 3 subscribers / 1 open issue / 0 PR / 0 release / 0 tag / 3 commits**（`stats/participation` 最近一周 3、其余全 0；`search?type:pr` total_count=0）——即"发布 6 天、一次性导入"。
- 唯一 issue **#1「今天会开源吗？」**（2026-10-18 创建，open，0 评论，无标签）——不是 bug/坑；**仓库内无其它 issue，已知坑列表为空**。文档英文为主 + `docs/zh/wan22-fa4.md` 一篇中文。

## 1. 定位

README TL;DR：解耦"状态演化（coding agent/引擎负责）"与"外观（EdenLive 渲染）"；把 proxy 参考视频 + 目标首帧 + 文本 prompt 渲染成写实视频，**24 fps 或更高**。项目页口径：over 24 FPS、minute-scale、480P/720P；5B 支持单卡 720P。

- **离线** `edenlive/configs/`：`wan21_14b_480p_{bidir,few_step}.yaml`、`wan22_5b_720p_{bidir,few_step}.yaml`（14B=480p、5B=720p）。`wan22_5b_720p_few_step.yaml`：`width:1280 height:704 fps:24 num_frames:117 chunk_size:3 num_inference_steps:4 guidance_scale:1.0`，KV `max_latent_frames:18/sink:6`。bidir=全帧联合去噪；few_step=chunk-AR（每 chunk 4 步）。
- **实时** `realtime/`：NVIDIA **FlashDreams** 分支 + TAEHV(LightTAE) 解码；内置 `game2v-eden-world-v2-{5b,14b}-taehv`。

## 2. 实时链路与接入协议（Q1/Q2）

**拓扑**（`realtime/README.md`）：`browser→8089 模型 app(GPU rank0)`；app→`8091 bridge(claude CLI)`、`8092 FLUX worker(首帧)`；`browser↔3478 TURN relay`。`start.sh 5b|14b` 读 `deploy.conf`，`launch.sh` 起模型服务，二者都不自动起 TURN。

**官方分层**（`realtime/ARCHITECTURE.md` + `flashdreams/api_v2/README.md`）：`IApplication/ISession/IModelLoop/IUILoop`；`IClientWindow` 同时是 `InputSource` 与 `OutputSink`；消息只经 `StepResult`（模型→UI）与输入事件（UI→模型）流动。**接入一种新"窗口/输入"= 用 Python 在 `client_window_factory.py` 新增 `ClientWindowMode`**，不是对外 HTTP/WS 接口。

**游戏接入方式：浏览器 Three.js，且必须经 Chromium。** `realtime/games/<slug>/{index.html,game.js,scene.js,adapter.js,initial-state.json,cover.png,first-frame.png}`；`deepwater-shock/index.html` 只有 `<canvas id="film" width="1280" height="704">` + `/shared/host/play-page.js`；`adapter.js` 是纯配置（键位、stat 显示、`validSnapshot`、从 game.js 导出 `dynamicPrompt`）。注册表 `realtime/games/registry.json` 字段：slug/title/prompt/cover_prompt/entry/host:"standalone"/vendor.three/controls/modules/restart_keys/`event_prompts`；当前 4 条：ember-den、iron-colossus、**jade-duel（固定侧视 2D 格斗）**、warehouse-sokoban（文档另称"七款内置"，两者不一致）。

**抓帧**（`integrations_v2/eden/apps/game2v/README.md`）：Chromium + **Playwright**，`GameCaptureWorker`/`GameRenderer` 独占 `game2v-render` 线程；**只有 rank0 有浏览器**（deploy.conf 注释 "rank 0 also runs Chromium and the proxy-DINO encode"）。同一张渲染既作 `ui_frame` 流给客户端，又取 latent 对齐子集 `0,4,8,12,…` 作 `condition_frame` 喂模型。输出 **WebRTC(aiortc)**，2 帧 FIFO、拥塞丢最旧帧；HUD 不是像素，而是每帧快照经 HTML overlay 画在视频上。键鼠/HUD 点击 → `KeyboardEvent`(key+code) 注入活页面 → 采样进下一捕获帧；游戏确定性 **24 Hz**（host 60Hz 累积步进），`initial-state.json` 负责 start/replay 还原。

**结论（Q1）：没有非浏览器/原生引擎接入方式。** 无 WebSocket/HTTP 生成 API（8089 只提供页面/静态路由 `/ext/game2v/play/<slug>`、`/ext/workbench/` token 鉴权 + WebRTC 信令）；无帧管道、无 NDI/共享内存/桌面捕获/引擎插件；`IClientWindow` 只有 mp4 / webrtc（cam2v 另列 `native-window`，那是"看窗"不是采集）。引擎必须在浏览器里（页面须提供 `window.gameBackend` 或 `window.__gameTest.read()` + `render(dt)`）。

**结论（Q2）：输入信号只有 RGB。** 模型条件 = proxy RGB 视频（1280×704/832×480，JPEG canvas 帧或 mp4）+ 首帧 + 文本；条件编码走 VAE + **proxy-DINO**（config：`image_size:[480,832]`、`control_dim:1024`、`channel_concat_zero_init:true`）。**没有深度/法线/运动矢量/相机矩阵 buffer 通道**：manifest 只有 `id,prompt,proxy_video,first_frame` 四列；相机位姿/内参只在 cam2v 应用里作为 `--pose-path/--intrinsic-path` 提供。

**延迟**：game2v README 给 "press-to-visible ≈ **2 个 chunk**"（T_sim≈T_gen≈T_play）；示例日志 `12 frames | capture 0.4 ms | generate 430.5 ms | 27.87 fps`，并明示 generate/fps **只算模型**，不含编码/网络/显示。**端到端 ms 数字官方未公布**；项目页 JS 渲染不可读；中文媒体只见"单卡 720P 超 24FPS"式宣传，未见毫秒级数据（未找到）。

## 3. 硬件与部署（Q2）

- 验证环境（README 表 + realtime/README）：**Linux x86-64/arm64**、**80 GB+ VRAM（例 H100 80GB）**、驱动 **R580+**、**CUDA 13.x**（torch 2.13+cu130，2.14 nightly 验证）、**Python 3.10**、100 GB+ 磁盘；Docker+NVIDIA Container Toolkit 可选；`apt-get install coturn`。
- 卡数/显存：`deploy.conf`：`MODEL=5b`、`NPROC=1`（"默认 5B 部署用一张卡"）、"**14B 支持 1-6 或 8 ranks**"；即 5B 实时=1 张 80GB 级卡，14B 实时=1–6/8 张。离线 5B bidir 另需 SM90 + flash-attn-4 4.0.0b31 + cutlass-dsl 4.7.1。
- 分辨率：realtime 5B=**720p(1280×704)**、14B=**480p**；抓帧默认 **832×480**（`DEFAULT_CAPTURE_WIDTH/HEIGHT`）。
- **Windows：不支持/未验证**（.sh、apt/coturn、EGL vendor JSON、flash-attn/triton 全为 Linux；客户端浏览器任意 OS）。
- **权重 ≈210 GB**（README Model weights，一个 `models/EdenLive/` 树）：`dit-14b/`、`dit-14b-bidir/`、`dit-5b/`、`dit-5b-bidir/`、`vae-14b/`、`vae-5b/`、`decoder-14b/`、`decoder-5b/`、`scheduler-14b/5b`（仅离线）、`umt5/`、`clip/`（仅 14B I2V）、`vision-encoder/`、`flux-c2f/`（仅 workbench 首帧）；单文件体积未公布。
- **5090 数字的归属**：`24.7 FPS@1280×704 on RTX 5090` 出自 README「Real-Time Inference with **LightX2V** on RTX 5090」，是第三方 LightX2V 的量化/KV cache/compile/CUDA Graphs 特化路径，**不是本仓库 realtime 在 24GB 卡上的实测**；该路径的显存占用/可行性细节官方未公布。本仓库 realtime 明确要求 80GB+。

## 4. 性能与"实时"定义

官方口径：`over 24 FPS, minute-scale generation, 480P/720P`；`24.7 FPS inference throughput at 1280×704`，定义为"meets the throughput requirement for real-time 24 FPS playback"——即"实时"=**模型吞吐够 24fps 播放**，不含编码/网络/显示。24 Hz 是游戏仿真率，game2v 模型帧率默认 **16 fps**（`--fps` 可改）。12 帧 chunk 的 Chromium 渲染 ≈**100–123 ms**，被拉伸进 ≈**430 ms** 的 generate。未公布：端到端延迟分布、1080p、60fps、14B 单卡实时；ARCHITECTURE.md "Not built yet" 还缺"游戏逻辑第三线程"与"丢帧计数"。

## 5. 授权（Q4）与能否商用

- **代码**：根 `LICENSE` Apache-2.0；`realtime/` 亦 Apache-2.0（自带 LICENSE/NOTICE/THIRD-PARTY-NOTICES/REUSE.toml/LICENSES）；vendored html-to-image、GameBlocks 派生模块保留 MIT。
- **权重**（README License 表 + 各上游许可原文）：

| 组件 | 许可 | 商用 |
| --- | --- | --- |
| `dit-*`（Wan2.2/2.1 衍生）、`vae-*`、`umt5`、`scheduler-*`、`decoder-*` | Apache-2.0 | 可商用（保留声明） |
| `clip/`（LAION CLIP ViT-H/14） | MIT | 可商用 |
| `vision-encoder/`（DINOv3 + 衍生） | DINOv3 License（Meta 自定义） | **可商用**：worldwide、非排他、**royalty-free** 授权 use/reproduce/modify；限制=分发须随附协议、禁止逆向、禁 ITAR/军事等用途、发表成果需致谢；非 OSI 标准开源 |
| `flux-c2f/`（FLUX.2 [klein] 9B + LoRA） | FLUX Non-Commercial License | **不可商用/不可生产用**，且要求对生成图像做内容过滤 |

- **"只跑已注册游戏不加载 FLUX"成立**：README 原文 "Playing registered games with `start.sh` does not load FLUX"；FLUX 仅被 `workbench_flux.sh`/workbench 首帧调用（`flux-c2f/`，deploy.conf `FLUX_GPU/FLUX_OFFLOAD`）。故该路径的商用限制只剩 DINOv3 条款 + 游戏素材授权（deepwater README.txt 明确"游戏名不构成第三方角色/图像授权，发布前需自行确认"）。**workbench（文本生成游戏 + FLUX 首帧）整体只能非商用。**

## 6. 成熟度与坑（Q5）

见 §0：6 天、90 stars、**3 commits / 0 release / 0 tag / 0 PR / 1 个未回复的开源询问 issue**。文档自身不一致：registry 4 款 vs 文档"七款"；`deploy.conf GAME=ember-den` vs realtime/README "default is `freeze`"；README 的 80GB 硬要求与 5090 宣称分属两套实现（本仓库 realtime vs LightX2V）。**issue 区没有可用的问题反馈**，真实坑只能从文档/代码自证（如上）。

## 7. 能力边界（对 2D/2.5D）

- **支持**：连续 3D 相机（第一/第三人称、俯仰/位移）、固定侧视 2.5D 格斗（registry `jade-duel`：fixed side view、两名武者、能量波/上勾拳/防御）、等距玩法（warehouse-sokoban）；最高 **1280×704**，模型 16/24 fps。
- **判定精度**：命中/碰撞/胜负必须留在 proxy 游戏里（README.txt "proxy geometry defines collisions and rules"），生成画面只负责外观，不能用于判定/读像素坐标。
- **UI/文字**：HUD 走 HTML overlay（清晰可交互）；**画面内文字/世界 UI 不可控**（prompt 反复要求 "No text or HUD"）。
- **1080p / 60fps**：无证据（上限 1280×704、24fps）。
- **角色一致性**：首帧+参考视频+prompt（"Keep the cave layout and spider identities"）+ chunk KV cache；长时漂移未量化。
- **镜头切换/快速运动**：无证据（cam2v 为连续相机控制）。**纯 2D 精灵/像素风**：无 demo 证据，2.5D 证据仅"3D 场景的固定侧视渲染"。

## 8. 未公开/未找到

端到端延迟 ms、1080p/60fps、Windows 支持（代码层面不支持）、权重各分量体积、5090/LightX2V 路径显存占用、14B 单卡实时、长时一致性指标、项目页正文（JS 渲染）、媒体毫秒级数据（未找到）。
