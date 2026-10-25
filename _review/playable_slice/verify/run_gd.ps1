param(
  [Parameter(Mandatory=$true)][string]$Script,
  [Parameter(Mandatory=$true)][string]$Log,
  [int]$TimeoutSec = 180
)
$godot = "E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$args = @("--headless", "--path", "E:\godot_game_by_fable\001", "--script", $Script)
$p = Start-Process -FilePath $godot -ArgumentList $args -WorkingDirectory "E:\godot_game_by_fable" `
  -RedirectStandardOutput $Log -RedirectStandardError "$Log.err" -PassThru -NoNewWindow
if (-not $p.WaitForExit($TimeoutSec * 1000)) {
  Write-Output "TIMEOUT after $TimeoutSec s, killing $($p.Id)"
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  exit 124
}
Write-Output "EXIT $($p.ExitCode)"
exit $p.ExitCode
