# 备份说明（仓库内容边界）

本仓库是《哪吒·轮回海域》Godot 工程的版本化备份，**只收源码与源资产**，不收可再生成的产物。

## 收进来的

- `001/`：Godot 工程本体 —— `scripts/`、`scenes/`、`shaders/`、`autoload/`、`theme/`、`project.godot`、`art/`（glb + 贴图）、`audio/`、`tools/`
- `tools/blender/`：30+ 个 Blender 无头脚本（减面、探伤、烘焙、接触图）
- `art_tmp/`：临时生成脚本与素材
- `_artgen/`：APIMart 生成的源图（章节场景、图标）
- 根目录设计文档 `.md`、参考图 `ref_*.png`、`nezha_*.glb` 备份

## 不收的（`.gitignore` 已排除）

| 排除项 | 体积 | 原因 / 重建方式 |
| --- | --- | --- |
| `001/.godot/` | ~195 MB | Godot 导入缓存，`godot --import` 自动重建 |
| `_shots/` | ~339 MB | 迭代期截图，用 `001/tools/capture.gd` 重拍 |
| `_baseline/` | ~192 MB | 四章基线截图，同上 |
| `shots_ch4/` | ~24 MB | 第四关专项截图，同上 |
| 根目录 `shot_*.png` / `game_shot*.png` | ~60 MB | 一次性调试截图 |

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
