# 可玩性样板切片 · 安全基线（2026-10-22）

本目录是"第一章可交付试玩样板"开工前的**工作区字节快照**，用于误改后精确回滚。
它**不是** git 备份，也不代表 HEAD。

## 为什么不用 HEAD

采集时 HEAD = `d26d3bc`（`main`），但工作区有 **247 条未提交改动**：

| 类别 | 数量 |
|---|---:|
| 修改（tracked） | 21 |
| 删除（tracked） | 9 |
| 未跟踪（含美术源资产、GLB、工具脚本） | 217 |

其中大量内容（`001/art/models/*.glb`、`_artgen/*.png`、`001/tools/*.gd`）只存在于工作区。
任何 `git reset --hard` / `git checkout -- .` / `git clean -fdx` 都会永久丢失它们。
因此基线按**文件字节**采集，`baseline.py check` 用 sha256 对比，不依赖 git 历史。

## 目录内容

```
baseline/
├── baseline.py                     # make / check / restore 三合一工具
├── MANIFEST.json                   # 机器可读清单（sha256 + size + mtime + HEAD blob）
├── MANIFEST.txt                    # 人读清单
├── git-state.txt                   # 采集时刻的 HEAD/分支/远端/完整 git status
├── README.md                       # 本文件
├── CHANGES-2026-10-22-task1.md     # 基线之后的本轮改动（backup.ps1 / .gitignore）及前后哈希
└── files/                          # 受保护文件的字节副本（相对仓库根保留原路径）
```

`files/` 与 `files.before-restore/` 已在 `.gitignore` 中精确忽略（字节副本不进仓库），
清单与脚本可以正常提交。

## 用法

```powershell
# 只读校验：工作区 vs 基线
python _review/playable_slice/baseline/baseline.py check

# 按基线回滚（先把当前版本存到 files.before-restore/<UTC>/，可再回滚）
python _review/playable_slice/baseline/baseline.py restore

# 重新采集（覆盖基线；确认工作区处于"想保留"的状态时才用）
python _review/playable_slice/baseline/baseline.py make
```

`check` 退出码：`0` 一致 / `1` 有差异 / `2` 清单缺失。

## 采集范围

本轮计划改动的文件：

| 文件 | 为什么在范围内 |
|---|---|
| `001/scripts/player.gd` | 灵力缓慢恢复、复活清临时状态、`is_dead()` |
| `001/scripts/level_base.gd` | 复活/整章重来回调、Boss 战重置 |
| `001/scripts/level_1.gd` | 落水处理 `body.dead` 缺陷、首章教学接线 |
| `001/scripts/hud.gd` | 死亡菜单、暂停与死亡互斥、输入教学面板 |
| `001/autoload/game.gd` | 键位表、技能解锁（只读，不改解锁条件） |
| `001/project.godot` | 场景/自动加载/输入映射基线 |
| `.gitignore`、`001/.gitignore` | 精确忽略生成产物 |
| `tools/backup.ps1` | 去掉无提示 `git add -A` |

`001/export_presets.cfg` 采集时**不存在**（导出验收阶段新建），因此未纳入副本；
`OPTIONAL_FILES` 会在后续 `make` 时自动补上。

## 已知的、本轮之前就存在的缺陷（不要当成回归）

1. `001/scripts/level_1.gd:566-577` 落水处理直接读 `body.dead`，而玩家死亡状态是
   `act == "dead"`（`player.gd:1685`），落水会打印脚本错误。前一轮计划已记录
   （`docs/plans/2026-10-21-ch1-hybrid-ruins.md:40`），本轮负责修复。
2. `001/scripts/hud.gd:567` 连击衰减用 `not get_tree().paused` 判断，与节点
   `process_mode` 语义重复；暂停/死亡期间界面状态未互斥。
3. 退出时 Godot 仍会报资源/ObjectDB 清理告警，改动前即存在。

## 约束

- 不 `git reset` / `git clean` / `git checkout` 覆盖未提交内容，不自动提交、不推送。
- 源美术资产只增不改；派生资源写入新目录。
- 恢复某个文件时优先 `baseline.py restore`，不要用 HEAD 版本覆盖。
