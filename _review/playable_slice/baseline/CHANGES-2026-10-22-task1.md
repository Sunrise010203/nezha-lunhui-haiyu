# 基线变更记录 · Task 1（2026-10-22）

本文件记录**基线采集之后**、由 Task 1 主动做出的改动。`files/` 里仍是**改动前**的原始字节，
所以 `baseline.py check` 会固定报这 2 个文件 `CHANGED` —— 这是预期的，不是漂移。

| 文件 | 基线 sha256（原始） | 当前 sha256（Task 1 后） |
|---|---|---|
| `.gitignore` | `b9cdcd8240ca6db7ef400d01c8f87fe18d5e7054f37c4757672ecc5274ffd1a2` | `9e7b1b3055c76920b48b92e36f49ced318943d784d690fd7d9cb3290cbdb358f` |
| `tools/backup.ps1` | `672e710d24feb07257ec7547efbd4ce9add4952cdcfe5e8136f8564f0e1f8796` | `d2a747ecb09a420bbd7f8773e12203eb03ddc3448e05666b98a53b852a84a069` |

（原始哈希同时保存在 `MANIFEST.txt` 里；大小 `874 → 1671` 字节、`1647 → 7178` 字节。）

## 改了什么

### `tools/backup.ps1`

风险：旧版无条件 `git add -A` + 自动 `git push`，会把 217 个未跟踪文件（含
`001/art/models/*.glb`、59MB 的 PNG、`_artgen/*`）静默上传，且无法只提交某个修复。

修正：

1. 默认 **DryRun**：只打印 HEAD/分支/改动统计/未跟踪清单/大文件警告，不 add、不 commit、不 push；
2. 提交必须 `-Paths <文件…> -Commit`；整库提交必须显式 `-AllConfirmed`；
3. 单文件 > `-MaxFileMB`（默认 5MB）默认拒绝，需 `-AllowLarge`；预览模式只警告不阻断（退出码 0）；
4. `-Push` 才推送，保留代理与重试；
5. `powershell.exe -File` 的 `-Paths a,b` 不会自动拆数组，脚本内按逗号拆分；
6. 文件改为 UTF-8 with BOM —— Windows PowerShell 5.1 无 BOM 时按 ANSI 解析，
   中文注释会让脚本直接语法错误（已实测）。

验证（不改动仓库）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1
# → 预览、退出码 0、git diff --cached 为空
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1 -Paths 001/art/models/shooter.glb
# → 输出 "⚠ 大文件（>5 MB，默认拒绝提交）10.5 MB"，退出码 0（预览）
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1 -Commit
# → 因未给 -Paths 且存在大文件，拒绝，退出码 2，仓库无提交
```

### `.gitignore`

只在"生成产物"段精确新增，不使用 `*.png` 之类会误伤源资产的宽通配：

```gitignore
_review/playable_slice/baseline/files/              # 基线字节副本
_review/playable_slice/baseline/files.before-restore/
/001/export/                                        # 导出产物（export_presets.cfg 仍入库）
/.agent-teams/                                      # 本机协作态
```

验证：`git check-ignore -v` 命中上述路径；`git status --porcelain -uall` 中只出现
`baseline.py/MANIFEST*/README/git-state` 这些应当入库的文本文件。

## 下游 Task 怎么读 `check`

- 看到这 2 个文件 `CHANGED` → 正常（本文件已记录）；
- 看到 `player.gd`/`hud.gd`/`level_1.gd`/`level_base.gd`/`game.gd`/`project.godot` 里
  **任何** `CHANGED` → 是本轮计划内改动，请在该 Task 的验收里点名；若不属于该 Task → 立即 `restore` 并查因；
- 看到 `BASE-BAD`/`MISSING` → 基线副本被破坏，停止改动并上报队长。

Task 1 结束时 `check` 的期望输出：`9 files checked, 2 changed`。

## 2026-10-22 追加（队长反馈后修订）

- 导出目录统一为仓库根 `builds/playable-slice/`（任务合同），`.gitignore` 由 `/001/export/` 改为 `/builds/playable-slice/`；
  计划 `docs/plans/2026-10-22-playable-slice.md` 同步（Task 4 与验收清单）。`.gitignore` 现为 `9e7b1b3055c76920b48b92e36f49ced318943d784d690fd7d9cb3290cbdb358f`。
- `check` 中 `.gitignore` / `tools/backup.ps1` 的 CHANGED 是预期改动；判定标准 = 备份完整 + 无计划外差异。
- 实测本机 shell 直连 github 失败（curl exit 7），Task 4 已写明改用编辑器/GUI 或 Web 通道获取同版本官方模板，不预判不可交付。
