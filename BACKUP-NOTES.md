# 备份说明（仓库内容边界）

本仓库是《哪吒·轮回海域》Godot 工程的版本化备份，**只收源码与源资产**，不收可再生成的产物。

## 远端与日常备份

- 远端：<https://github.com/Sunrise010203/nezha-lunhui-haiyu>（私有仓库）
- 默认分支 `main`。首次备份 613 文件 / 252 MB（2026-10）；2026-10-25 清理后补推至约 1.2 GB，单文件最大 77.6 MB（`001/art/models/nezha_arp.glb`）
- 一键备份：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1 -Message "feat: 第四关 Boss 调整"
```

脚本做三件事：`git add -A` → 提交 → `git push origin main`，失败自动重试 3 次。

> **网络注意**：本机访问 GitHub 走 Clash（`127.0.0.1:65372`）。某些节点上行会被重置 —— 下载正常、上传 >300 KB 报 `Send failure: Connection was reset`。换个节点重跑即可。自查命令：向 `https://httpbin.org/post` POST 1 MB，`up=1048576` 才说明上行可用。

## 收进来的

- `001/`：Godot 工程本体 —— `scripts/`、`scenes/`、`shaders/`、`autoload/`、`theme/`、`project.godot`、`art/`（glb + 贴图 + `.import`）、`audio/`、`tools/`
- `001/art/models/`：ARP 哪吒 / Boss / 小怪 / 第一章废墟的 glb 与贴图（2026-10-25 补推，约 856 MB）
- `tools/blender/`：40+ 个 Blender 无头脚本（减面、探伤、烘焙、接触图）
- `_artgen/`：APIMart 生成的源图（章节场景、图标）
- `_review/`：评审报告、构建日志、`*.diff` 证据（截图与二进制不入库）
- 根目录设计文档 `.md`、`nezha_*.glb` 备份

## 不收的（`.gitignore` 已排除）

| 排除项 | 体积 | 原因 / 重建方式 |
| --- | --- | --- |
| `art_source/` | 1.89 GB | Blender 真源；单文件最大 143 MB，超 GitHub 100 MB 硬限制，只留本地 / 网盘 |
| `001/.godot/` | 1.58 GB | Godot 导入缓存，`godot --import` 自动重建 |
| `builds/` | 1.07 GB | 试玩包导出产物，按 README「导出与试玩包」重导 |
| `_review/**/*.{png,pck,exe,npy,cache}` | 2.48 GB | 审阅截图与基线二进制副本，重跑审阅任务即可 |
| `game_assets/` | 366 MB | 中间件；`glb_game` 已复制进 `001/art/models/glb_game` |
| `_shots/` | 339 MB | 迭代期截图，用 `001/tools/capture.gd` 重拍 |
| `_baseline/` | 192 MB | 四章基线截图，同上 |
| `shots_ch4/` | 24 MB | 第四关专项截图，同上 |
| `art_assets/*.png` | 60 MB | 生成的概念图，清单与 ledger 保留 |
| `art_tmp/`、`_tmp_*`、`tools/appdata/` | 180 MB | 本地临时脚本与沙箱运行目录 |
| 根目录 `shot_*.png` / `game_shot*.png` | ~60 MB | 一次性调试截图 |

> 2026-10-25 的完整删除 / 保留清单见 `CLEANUP-REPORT.md`。

截图重拍（**不要加 `--headless`，否则拿不到画面**）：

```powershell
$env:APPDATA = 'E:\godot_game_by_fable\_tmp_appdata'   # 沙箱内 user:// 不可写会崩
godot --path E:\godot_game_by_fable\001 -s res://tools/capture.gd
```

性能基线：

```powershell
godot --path E:\godot_game_by_fable\001 -s res://tools/perf_probe.gd
```

## 克隆后第一次运行

```powershell
git clone <repo> 
cd 001
godot --import          # 重建 .godot 导入缓存，必须
godot --path .          # 启动
```

## 需要的工具版本

- Godot **4.6.3.stable.official**（hash `7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3`），Forward+，Jolt Physics，D3D12
- Blender **5.1.2** 便携版（`tools/blender/` 里的脚本按此版本写）
