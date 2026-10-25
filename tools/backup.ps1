# 备份到 GitHub —— 默认只预览，绝不静默全量提交
#
# 用法（仓库根目录，或任意位置）：
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1
#       → 只预览：列出将会提交的改动、未跟踪文件、大文件警告；不改动仓库。
#
#   powershell ... -File .\tools\backup.ps1 -Paths 001/scripts/hud.gd,001/scripts/player.gd -Commit -Message "fix: 死亡菜单"
#       → 只提交**明确列出**的路径（-Commit 必须与 -Paths 一起用）。
#
#   powershell ... -File .\tools\backup.ps1 -Paths 001/scripts/hud.gd -Commit -Push
#       → 提交后再推送（推送仍带代理与重试）。
#
#   powershell ... -File .\tools\backup.ps1 -AllConfirmed -Commit
#       → 显式确认"整库提交"，仍会先列出清单并拒绝大文件（除 -AllowLarge）。
#
# 依赖：git（Windows 凭据管理器里的 GitHub token）、Clash 代理 127.0.0.1:65372。
# 上传走代理时节点差会导致 >300KB 上传被 reset（下载不受影响），报错
# "Send failure: Connection was reset" —— 换节点重跑即可。
#
# 设计要点（2026-10-22 修正）：
#   * 旧版无条件 `git add -A` + 自动 push，会把未审阅的生成产物/大源文件静默上传；
#     现在默认 **DryRun**，只有 -Commit 且给出 -Paths（或 -AllConfirmed）才写提交。
#   * 单文件超过 -MaxFileMB（默认 5MB）默认拒绝，需显式 -AllowLarge，避免大 GLB/PNG 误传。
#   * 不做 reset / clean / checkout / 强推；脚本只会 add/commit/push。

param(
    [string]$Message = "",
    [string[]]$Paths = @(),
    [string]$Proxy = "http://127.0.0.1:65372",
    [int]$Retries = 3,
    [int]$MaxFileMB = 5,
    [switch]$Commit,
    [switch]$Push,
    [switch]$AllConfirmed,
    [switch]$AllowLarge
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
$env:GIT_TERMINAL_PROMPT = '0'

$limitBytes = [int64]$MaxFileMB * 1MB

# powershell.exe -File 传参不会把 "a,b" 拆成数组，这里统一按逗号拆分并去空格。
$Paths = @($Paths | ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

# ---------------------------------------------------------------- 收集改动
$status = @(git status --porcelain)
if ($status.Count -eq 0) {
    Write-Host '工作区无改动'
    exit 0
}

$staged = @()
$unstaged = @()
$untracked = @()
$deleted = @()
foreach ($line in $status) {
    $code = $line.Substring(0, 2)
    $path = $line.Substring(3).Trim('"')
    if ($code -eq '??') { $untracked += $path; continue }
    if ($code.Contains('D')) { $deleted += $path }
    if ($code[0] -ne ' ') { $staged += $path }
    if ($code[1] -ne ' ') { $unstaged += $path }
}

Write-Host ''
Write-Host '==== 备份预览（默认不提交、不推送）===='
Write-Host ("HEAD: {0}  分支: {1}" -f (git rev-parse --short HEAD), (git rev-parse --abbrev-ref HEAD))
Write-Host ("改动: {0} 条（已暂存 {1} / 未暂存 {2} / 未跟踪 {3} / 删除 {4}）" -f `
    $status.Count, $staged.Count, $unstaged.Count, $untracked.Count, $deleted.Count)

if ($Paths.Count -gt 0) {
    Write-Host ''
    Write-Host '指定提交路径：'
    $Paths | ForEach-Object { Write-Host "  $_" }
} elseif ($untracked.Count -gt 0 -or $unstaged.Count -gt 0) {
    Write-Host ''
    Write-Host '未跟踪文件（前 40 条；其余见 git status）：'
    $untracked | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" }
    if ($untracked.Count -gt 40) { Write-Host ("  ... 另有 {0} 条" -f ($untracked.Count - 40)) }
}

# ---------------------------------------------------------------- 大文件闸门
$candidates = if ($Paths.Count -gt 0) { $Paths } else { $unstaged + $untracked }
$large = @()
foreach ($p in $candidates) {
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        $len = (Get-Item -LiteralPath $p).Length
        if ($len -gt $limitBytes) { $large += [pscustomobject]@{ Path = $p; MB = [math]::Round($len / 1MB, 1) } }
    }
}
if ($large.Count -gt 0) {
    Write-Host ''
    Write-Host ("⚠ 大文件（>{0} MB，默认拒绝提交）：" -f $MaxFileMB)
    $large | ForEach-Object { Write-Host ("  {0,6} MB  {1}" -f $_.MB, $_.Path) }
    if (-not $AllowLarge) {
        if (-not $Commit) {
            Write-Host ''
            Write-Host '（预览模式：仅警告，未改动仓库。若真要用 -Commit，需要 -AllowLarge 才放行这些大文件。）'
            exit 0
        }
        Write-Host ''
        Write-Host '阻止提交：确认确实要传大文件时加 -AllowLarge；或把路径排除在 -Paths 之外。'
        exit 2
    }
}

# ---------------------------------------------------------------- 提交
if (-not $Commit) {
    Write-Host ''
    Write-Host '预览结束，未改动仓库。确认后用 -Paths <文件...> -Commit 精确提交。'
    exit 0
}

if (-not $Message) { $Message = "backup: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" }

if ($Paths.Count -gt 0) {
    foreach ($p in $Paths) {
        if (-not (Test-Path -LiteralPath $p)) { Write-Error "路径不存在：$p"; exit 1 }
    }
    git add -- @Paths
} elseif ($AllConfirmed) {
    Write-Host '整库提交（已 -AllConfirmed 确认）...'
    git add -A
} else {
    Write-Error '拒绝提交：必须用 -Paths 明确指定文件，或显式加 -AllConfirmed。'
    exit 1
}
if ($LASTEXITCODE -ne 0) { Write-Error 'git add 失败'; exit 1 }

$stagedNow = @(git diff --cached --name-only)
if ($stagedNow.Count -eq 0) {
    Write-Host '没有可提交的暂存内容（可能路径无改动）'
    exit 0
}
$stillLarge = @()
foreach ($p in $stagedNow) {
    if ((Test-Path -LiteralPath $p -PathType Leaf) -and ((Get-Item -LiteralPath $p).Length -gt $limitBytes)) { $stillLarge += $p }
}
if ($stillLarge.Count -gt 0 -and -not $AllowLarge) {
    git reset -q -- @stillLarge
    Write-Host ("⚠ 已从暂存区剔除大文件（{0}）：{1}" -f $MaxFileMB, ($stillLarge -join ', '))
}

git commit -q -m $Message
if ($LASTEXITCODE -ne 0) { Write-Error 'git commit 失败'; exit 1 }
Write-Host "已提交: $Message（$($stagedNow.Count) 个文件）"

if (-not $Push) {
    Write-Host '未推送（需要时加 -Push）。'
    exit 0
}

# ---------------------------------------------------------------- 推送
$env:GIT_TERMINAL_PROMPT = '0'
git config --local "http.https://github.com/.proxy" $Proxy
$ahead = [int](git rev-list --count 'origin/main..main')
if ($ahead -le 0) { Write-Host '本地与远端一致，无需推送'; exit 0 }

for ($i = 1; $i -le $Retries; $i++) {
    Write-Host "推送 $ahead 个提交（第 $i/$Retries 次）..."
    git push origin main
    if ($LASTEXITCODE -eq 0) { Write-Host '推送成功'; exit 0 }
    Start-Sleep -Seconds 10
}
Write-Error "推送失败（$Retries 次）。通常是代理节点上传被重置：切换 Clash 节点后重跑 -Push。"
exit 1
