$ErrorActionPreference = "Stop"
$env:APPDATA = "E:\godot_game_by_fable\_review\playable_slice\verify\export_run\appdata"
$exe = "E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable.exe"
$out = "E:\godot_game_by_fable\_review\playable_slice\verify\export_run\window_probe.txt"
$p = Start-Process -FilePath $exe -ArgumentList @("--windowed", "--resolution", "1280x720", "--position", "100,100") -PassThru
Start-Sleep -Seconds 15
$lines = @()
$p2 = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
if ($null -eq $p2) {
  $lines += "PROCESS_EXITED"
} else {
  $lines += "PID=$($p2.Id) RESPONDING=$($p2.Responding) TITLE=[$($p2.MainWindowTitle)] HANDLE=$($p2.MainWindowHandle)"
}
Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | ForEach-Object {
  $lines += "WIN PID=$($_.Id) NAME=$($_.ProcessName) TITLE=[$($_.MainWindowTitle)] HANDLE=$($_.MainWindowHandle)"
}
$lines | Set-Content -Path $out -Encoding UTF8
if ($null -ne $p2 -and -not $p2.HasExited) { Stop-Process -Id $p2.Id -Force }
Write-Output "DONE"
