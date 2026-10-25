# 清理报告 · 2026-10-25

本次清理目标：把《哪吒 · 轮回海域》工程里**可再生成的缓存/构建/审阅/临时产物**清掉，只保留源码、源资产与可追溯的证据，然后分批推送到 GitHub。

## 概览

| 指标 | 清理前 | 清理后 |
| --- | --- | --- |
| 工程总大小（含 `.git`） | 约 **9.35 GB** | 约 **3.20 GB** |
| 回收 | — | 约 **6.30 GB** |
| 文件数 | 约 9 900 | 3 574 |

## 删除清单

| 类别 | 位置 | 文件数 | 体积 | 重建方式 |
| --- | --- | ---: | ---: | --- |
| Godot 导入缓存 | `001/.godot/` | 1 241 | 1 582.1 MB | `godot --import`（首次打开工程自动重建） |
| 试玩包导出 | `builds/` | 112 | 1 067.1 MB | `godot --export-release "Windows Desktop" ...`（见 README「导出与试玩包」） |
| 审阅大二进制/截图 | `_review/**/*.{pck,exe,npy,cache,png,jpg}` | 1 771 | 2 481.1 MB | 审阅任务重跑；文字报告、日志、diff 证据全部保留 |
| 重复中间件 | `game_assets/`（`glb_game` 与 `001/art/models/glb_game` 重复） | 174 | 366.2 MB | 源头在 `art_source/`，`tools/blender/` 可重新导出 |
| 迭代截图 | `_shots/` | 185 | 338.7 MB | `001/tools/capture.gd` 重拍（**不要加 `--headless`**） |
| 基线截图 | `_baseline/` | 144 | 191.7 MB | 同上 |
| 临时素材/脚本 | `art_tmp/` | 91 | 87.1 MB | 一次性裁图/校验脚本，无保留价值 |
| 生成的概念图 | `art_assets/*.png` | 26 | 60.3 MB | 生成脚本在 `art_refs/`，清单与 ledger 已保留 |
| 临时目录 | `_tmp_a10/`、`_tmp_appdata/`、`_tmp_dl/`、`_tmp_lo/`、`_tmp_t7/`、`_tmp_token_appdata/` | 371 | 52.9 MB | 运行时沙箱目录 |
| 工具运行数据 | `tools/appdata/` | 276 | 40.0 MB | 沙箱 `APPDATA`，运行自动生成 |
| 第四章截图 | `shots_ch4/` | 9 | 23.5 MB | 同 `capture.gd` |
| 诊断/垃圾文件 | `_acl_reports/`、根目录 0 字节 `hud.gd`/`level_1.gd`/`level_3.gd`、旧备份 `nezha_triposr_backup.glb` | 7 | 4.9 MB | 无 |
| Python 缓存 | `tools/**/__pycache__/`、`art_refs/__pycache__/` | 12 | 0.2 MB | 自动生成 |

> 根目录三个 0 字节 `.gd` 与 `001/scripts/` 下同名脚本重复，属于早期误放的占位文件。
> `nezha_triposr_backup.glb` 是旧 TripoSR 流程的备份，当前模型链已换成 `nezha_arp.glb`。

## 保留清单（以及为什么）

| 保留项 | 体积 | 说明 |
| --- | ---: | --- |
| `art_source/` | 1 892.3 MB | **真源**：Blender `.blend`（Boss/小怪/哪吒/武器）与四向图 zip。**不进 GitHub**（单文件最大 143 MB，超出 GitHub 100 MB 硬限制），需本地/网盘另行备份 |
| `001/`（工程本体 + 美术资源） | 1 005.4 MB | `.gd`/`.tscn`/`.shader`/`project.godot` + `art/models`（glb + 贴图 + `.import`），克隆即可运行 |
| `_review/` 文字证据 | 8.8 MB | 评审 md、构建日志、`*.diff`、基线 MANIFEST —— README 里「性能基线」的原始日志 `perf_t6_*.txt` 保留在此 |
| `art_refs/` | 30.9 MB | 素材生成脚本 + 章节参考图 |
| `_artgen/` | 20.6 MB | APIMart 生成的章节源图（已入库历史） |
| `tools/` | 17.3 MB | 工程工具脚本 + `tools/blender/` 无头脚本（`gltfpack/`、`appdata/` 二进制不入库） |
| `asset_split/` | 13.5 MB | Tripo 拆分历史素材（已入库） |
| `art_assets/` 清单 | <0.1 MB | `README-资产清单.md` + `_ledger_{a,b,c}.json`（记录生成提示词，便于复现） |
| `docs/` | <0.1 MB | 计划文档 |

## 仓库侧变更

`.gitignore` 新增/收敛的规则：

- `/builds/`、`*.pck`、`*.exe` —— 导出产物不再入库
- `_review/**/*.{png,jpg,pck,exe,npy,cache}` —— 审阅二进制不入库，文字证据仍入库
- `/art_source/` —— Blender 真源只留本地
- `/game_assets/`、`/art_assets/*.png`、`/art_tmp/` —— 中间产物与重复副本
- `/tools/gltfpack/`、`/tools/appdata/` —— 第三方二进制与本地运行数据
- `__pycache__/`、`*.pyc`、`*.tmp`

同时 `git rm` 了此前误入库的 `art_tmp/`、`_review` 大二进制、旧的过时说明文档（`P0改动说明.md`、`P1改动说明.md`、`本轮改动说明*.md`、`EdenLive-评估…md` 等，工作区已被删除）。

## 清理后第一次打开

```powershell
$G='E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe'
& $G --path 'E:\godot_game_by_fable\001' --import    # 重建 .godot（约 1~3 分钟）
& $G --path 'E:\godot_game_by_fable\001' -e          # 打开编辑器
```

## GitHub 上传说明

- 本次新增入库约 **856 MB**（`001/art/models` 下的 ARP 角色/Boss/小怪/第一章废墟资源）。
- 单文件最大 `001/art/models/nezha_arp.glb` 77.6 MB，低于 GitHub 100 MB 硬限制。
- 仓库总量预计约 1.2 GB，超过 GitHub 建议的 1 GB，属于可用但偏重；后续如需减重可考虑 Git LFS 或拆分子仓库。
- `art_source/`（1.89 GB）**不在** GitHub 备份范围内，请另行备份。
