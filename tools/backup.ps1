# 一键备份到 GitHub
#
# 用法（在仓库根目录或任意位置）：
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\backup.ps1 -Message "feat: 第四关 Boss 调整"
#
# 依赖：git（已带 Windows 凭据管理器里的 GitHub token）、Clash 代理在 127.0.0.1:65372。
# 注意：上传走代理时若节点质量差，>300KB 的上传会被 reset（下载不受影响），
#       报错见 "Send failure: Connection was reset" —— 换个节点再跑一次即可。

param(
    [string]$Message = "",
    [string]$Proxy = "http://127.0.0.1:65372",
    [int]$Retries = 3
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
$env:GIT_TERMINAL_PROMPT = '0'
git config --local "http.https://github.com/.proxy" $Proxy

if (-not $Message) { $Message = "backup: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" }

$dirty = git status --porcelain
if ($dirty) {
    git add -A
    git commit -q -m $Message
    Write-Host "已提交: $Message"
} else {
    Write-Host '工作区无改动'
}

$ahead = [int](git rev-list --count 'origin/main..main')
if ($ahead -le 0) {
    Write-Host '本地与远端一致，无需推送'
    exit 0
}

for ($i = 1; $i -le $Retries; $i++) {
    Write-Host "推送 $ahead 个提交（第 $i/$Retries 次）..."
    git push origin main
    if ($LASTEXITCODE -eq 0) { Write-Host '推送成功'; exit 0 }
    Start-Sleep -Seconds 10
}
Write-Error "推送失败（$Retries 次）。通常是代理节点上传被重置：切换 Clash 节点后重跑本脚本。"
exit 1
