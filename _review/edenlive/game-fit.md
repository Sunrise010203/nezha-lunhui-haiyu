# 哪吒 Godot 工程 × EdenLive：本地侧评估

**结论**：可接，但只能"贴画面"。proxy 可稳定导出（离线 Movie Maker 最省事，SubViewport 次之），判定/输入仍在本地 60Hz、生成帧滞后 → 实时可玩性风险高，离线 trailer 最稳。硬前置：无导出预设、无 git、中文靠系统字体。

缩写（001/ 下）：pg=project.godot，lb=level_base.gd，hud=hud.gd，cam=player_camera.gd，game=autoload/game.gd，l2/l3=level_2/3.gd，bw=boss_warden.gd，be=boss_sea_eye.gd，eb=enemy_base.gd，pl=player.gd，cap=tools/capture.gd。

## 1 管线
- 2.5D＝3D 世界＋2D HUD：关卡根 Node3D、内容代码构建（level_1.tscn:5）；HUD＝CanvasLayer layer10、内 Control/Label（hud:1,51）；黑屏层 120（game:234）；菜单纯 2D。
- 透视 fov50 侧视跟随、距离 8.8（cam:11-14,60）；Boss 双目标取中＋拉远（cam:32-49,76）。
- 无 Compositor，后期全在 Environment（lb:159-216：sky:163、filmic:170、glow:171、fog:177、体积雾:181、SSAO 关:189）＋2D 晕影（hud:77）。shader：sky→Sky、water→PlaneMesh（lb:223）、rim→material_overlay（eb:61）、fx_sprite_fade→QuadMesh（lb:1148）、vignette/menu→ColorRect。
- 1920×1080 canvas_items+expand（pg:25-28）、MSAA2×（:41）、Forward+（:16）、D3D12（:40）；无 vsync/限帧设置（仅探针关，perf_probe:36-37）→默认垂直同步；3D 目标随窗口放大（本轮改动:26-28）。

## 2 预算
- 一章 88 draw/21 万 tri/610MB/0.89s、二章 92/14 万/546MB/0.94s（README:93-102、本轮改动:129）、三章 79/28.4 万/450MB/0.78s（本轮改动:238）；目标 draw<120、tri<30 万、VRAM<700MB（第三关设计方案:178）。
- 改前全开 9.22ms/108fps、关阴影 6.60ms/152fps，且为 3414×1993 超采样（改进建议:30,39,43）；现 2.1MP＋draw−73%（本轮改动:12-14）→60fps 余量≥2×[估算]。
- GPU 文档仅 RTX 5070 Laptop（README:93），按 8GB 论述（假设）；游戏占 0.45-0.61GB，5B 能否进 8GB 待外部确认，14B 必云端。

## 3 接入点
a **SubViewport**：现 0 处使用。关卡入 SubViewport（480/720p、UPDATE_ALWAYS），HUD 留主视口、生成帧贴回 TextureRect；输入须转发（10 action 运行时注册 game:202-229、F11 game:188）。输出 tonemap 后 8bit sRGB 可直送模型；回读 480p 0.9MB/帧、1080p 8.3MB/帧（60fps＝500MB/s，GDScript 不可行）→24-30fps、480-720p。
b **`--write-movie`**：零改代码录整窗（3D+HUD+晕影+加载层），AVI+WAV；无 [editor] 段 → fps 默认 60；须真实渲染器（cap:8）。`--resolution` 可 480p 但 HUD 同糊（19px→8px，hud:344）；玩法驱动照 cap:37-77 写 SceneTree 工具。离线 proxy 首选。
c **截屏/回读**：无 DisplayServer 截屏 API，等价 viewport.get_image()（cap:68）＋save_png(:69），1080p 编码数十 ms→仅离线。
d **全覆盖＋原输入**：逻辑 60Hz 不停、生成帧滞后 100-200ms→看到过去画面；预警靠颜色（红环 bw:666-670、0.5-0.9s bw:28-32；be:19-20），重绘改色糊边→判定不可读；HUD 须 layer<10 才清晰（hud:51）。
e **Web**：须 Forward+→GL Compatibility（pg:16）；Compatibility 无体积雾→二/三章氛围掉（lb:181-188、l2:280-282、l3:108-115），glow 部分支持、SSAO 已关；7 gdshader 需实测 sky/water；Jolt（pg:36）Web 单线程需实测；art 80MB＋导入缓存 65MB＋GLB 28MB、高面（crawler 15.9 万/shooter 26 万 tri，game:76）、贴图无损无 mipmap（stone.png.import:18,26）→首包 90MB+；SystemFont（theme:3-5、game:175）非 Windows 浏览器缺中文字形→须内置 CJK；1080p 建议降 720p、关 MSAA。

## 4 视觉
- 青蓝龙宫（sky/water＋石材三向 lb:146-154）、铁灰暗红牢狱（狱火体积雾 l2:275-287）、紫黑归墟（l3:90-142）；低多边形＋平涂＋自发光＋AI TripoSR 模型（game:63-66,106-125），角色占屏高约 20%（cam:5）。
- 写实重绘会编造细节、漂移身份；480p 角色仅 100-200px，脸部与代码后挂装备（pl:246-298）一致性风险高。
- HUD 中文硬编码（hud:219,305,341,549,570）＋世界内 Label3D（lb:464-478）；生成帧含 HUD 时文字必崩（480p 8/11/24px）→须本地合成。
- 判定靠颜色语义＋rim 轮廓（eb:61-63）＋hitstop/震屏（game:323-333）；写实化削弱信号，Boss 战与摆荡最受伤。

## 5 方案
**A 离线 trailer**：①movie_recorder.gd（仿 cap:37-77）；②HUD 显隐（hud:51、game:236）录纯 3D proxy＋带 HUD 两版；③`--resolution 854x480`/720p＋`--write-movie`、30/60fps 留 WAV；④ffmpeg 转 480p；⑤云端 24-48GB 跑 14B 双向离线；⑥本地 1080p HUD＋原声合成。收益：画质上限高、无延迟、音画同源；风险：14B 成本、快速动作/震屏/粒子闪烁、须剥 HUD、挑帧。2-4 人日；本机 5070 录 proxy 足够。
**B 实时 demo**：①Web 导出（Compatibility+720p+关雾+CJK，1-2 人日）；②canvas.captureStream(24/30)→WebRTC→云端 5B；③回传 `<video>` 盖 canvas；④HUD 用 DOM/Canvas2D 经 JavaScriptBridge 重画。延迟[估算]：采集 33-42＋网络 20-40＋推理＋显示 10-20≈100-160ms；24fps＋150ms 下跑图勉强、Boss/摆荡不可玩。5-8 人日；本机 8GB 跑 5B 临界。

## 6 先改
已知：无 export_presets.cfg（README:109）、未 git init（:110）、无设置页/手柄（:107）、关卡内存档（:106）。补：①导出预设（Web/Linux/Windows）＋模板；②渲染后端切换＋分辨率/全屏/VSync/限帧（现仅 F11，game:188）；③内置 CJK 字体；④HUD/黑屏层录制排除；⑤SubViewport 捕获＋输入转发；⑥movie_recorder＋writer 设置；⑦低配代理预设（关雾/MSAA off/降 tri）；⑧Web 瘦身（VRAM 压缩/mipmap/GLB 减面）；⑨音频总线/设置页；⑩git＋perf_probe 基线。

> 数字来自 README/实测（RTX 5070 Laptop/1920×1080/D3D12，8GB 为文档假设）；帧率余量估算。
