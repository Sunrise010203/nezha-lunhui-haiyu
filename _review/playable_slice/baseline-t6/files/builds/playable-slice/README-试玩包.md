# 哪吒 · 轮回海域 —— 第一章试玩包（Windows x86_64）

导出时间：2026-10-22 · Godot 4.6.3.stable.official（Forward+ / D3D12 / Jolt）

## 内容

| 文件 | 说明 |
| --- | --- |
| `nezha_ch1_playable.exe` | 单文件可执行包（PCK 已内嵌，无需编辑器、无需安装导出模板） |
| `README-试玩包.md` | 本说明 |

校验：`nezha_ch1_playable.exe` 大小 555,540,456 字节
SHA-256 `cca642e89bc5e879186c0f9c4b31a9a7049d643fb7ee9716e4007cb2093cc9b7`

## 运行

1. 双击 `nezha_ch1_playable.exe`。
2. 首次启动会有 2–4 秒着色器/管线预热，主菜单出现前黑屏属正常。
3. 主菜单：`入海 · 开始游戏`（闯关）/ `选择关卡` / `世界观` / `操作指南`。

操作（与 README 一致）：A/D 移动，空格跳跃（二段跳），Shift 冲刺（瞬身无敌），
J 连击，K 重击，E 乾坤圈，Q 真火，V 风火轮，F 混天绫，G 定潮，Esc 暂停。

## 包体说明（1.4 GB → 530 MB）

只做两件事，均未删除/重压缩源资产：

1. **排除开发专用资源**（`export_presets.cfg` 的 `exclude_filter`）：
   `tools/*`、`*.py`、`scenes/env_ch1_showcase.tscn`、`scripts/env_ch1_showcase.gd`、
   `art/models/glb_game/*`、`art/ref/*`、`art/tmp/*`、`art_source/*`、`_artgen/*`。
2. **精确导入设置**：`art/**` 与 `art/textures/nezha/**` 中边长 ≥ 2048 的贴图
   `process/size_limit=2048`；用于 3D 的贴图改为 VRAM 压缩（法线贴图开 normal_map）。
   源 PNG/JPG 原样保留，1080p 下目检无可见劣化（见 `_review/playable_slice/shots/`）。

导出预设文本位于 `001/export_presets.cfg`，可复现：
`godot --headless --path 001 --export-release "Windows Desktop" builds/playable-slice/nezha_ch1_playable.exe`

## 已验证

- 从 exe 直接启动（无编辑器）：主菜单 → 选择关卡 → 进关渲染、HUD、技能特效正常。
- 第一章出生点与 Boss 战场帧数据见 `_review/playable_slice/perf_level1_{spawn,boss}.txt`。
- 截图（1920×1080，真实渲染器）见 `_review/playable_slice/shots/`：
  `ch1_start_hud.png`、`ch1_boss.png`、`ch1_death.png`、`ch1_wheel.png`、
  `ch1_bridge.png`、`ch2_start.png`、`ch3_start.png`、`ch4_start.png`、
  `export_menu.png`、`export_play.png`。

## 已知限制

- 包内含全部可用美术资源，体积 530 MB；后续可按章节拆分导出预设。
- 退出/首启日志写在 `%APPDATA%\Godot\app_userdata\哪吒·轮回海域\`；
  若目标目录不可写（受限沙箱），引擎无法建目录会启动失败——普通桌面环境无此问题。
- 关卡内进度不落盘（莲台/残片仅本局有效），与当前设计一致。
