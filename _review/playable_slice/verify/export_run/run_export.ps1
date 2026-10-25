$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = "E:\godot_game_by_fable"
$exe = Join-Path $root "builds\playable-slice\nezha_ch1_playable.exe"
$out = Join-Path $root "_review\playable_slice\verify\export_run"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$env:APPDATA = Join-Path $out "appdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null

function Shot($name) {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $path = Join-Path $out $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output "SHOT $name $($b.Width)x$($b.Height)"
}

$log = Join-Path $out "run.log"
$p = Start-Process -FilePath $exe -ArgumentList "--resolution","1600x900","--position","20,20","--verbose" -RedirectStandardOutput $log -RedirectStandardError (Join-Path $out "run.err.log") -PassThru
Write-Output "PID $($p.Id)"
Start-Sleep -Seconds 18
Shot "01_menu.png"
# focus window and accept the focused primary menu button
$wshell = New-Object -ComObject wscript.shell
$null = $wshell.AppActivate($p.Id)
Start-Sleep -Milliseconds 800
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 22
Shot "02_ch1.png"
Start-Sleep -Seconds 2
Shot "03_ch1b.png"
Start-Sleep -Seconds 2
# pause via Esc to check overlay rendering
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Seconds 2
Shot "04_pause.png"
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
Start-Sleep -Seconds 1
Write-Output "DONE exited=$($p.HasExited)"
