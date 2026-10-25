param([string]$Exe, [string]$OutDir, [int]$WaitSec = 15)
$ErrorActionPreference = 'Stop'
$env:APPDATA = 'E:\godot_game_by_fable\_review\playable_slice\verify\export_run\appdata'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class W {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$p = Start-Process -FilePath $Exe -ArgumentList '--resolution','1920x1080','--position','0,0' -PassThru
Write-Output "PID=$($p.Id)"
$h = [IntPtr]::Zero
for ($i=0; $i -lt ($WaitSec*4); $i++) {
  Start-Sleep -Milliseconds 250
  $wins = New-Object System.Collections.ArrayList
  $cb = [W+EnumWindowsProc]{ param($w,$l) 
    $pid2 = 0; [W]::GetWindowThreadProcessId($w, [ref]$pid2) | Out-Null
    if ($pid2 -eq $p.Id -and [W]::IsWindowVisible($w)) { [void]$wins.Add($w) }
    return $true }
  [W]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
  if ($wins.Count -gt 0) { $h = $wins[0]; break }
}
if ($h -eq [IntPtr]::Zero) { Write-Output 'NO_WINDOW'; Stop-Process -Id $p.Id -Force; exit 2 }
$sb = New-Object System.Text.StringBuilder 512
[W]::GetWindowText($h, $sb, 512) | Out-Null
Write-Output "HWND=$h TITLE=$($sb.ToString())"
[W]::ShowWindow($h, 5) | Out-Null
[W]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Seconds 6
$r = New-Object W+RECT
[W]::GetWindowRect($h, [ref]$r) | Out-Null
Write-Output "RECT=$($r.Left),$($r.Top),$($r.Right),$($r.Bottom)"
$w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
if ($w -le 0 -or $ht -le 0) { $w=1920; $ht=1080 }
$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[W]::PrintWindow($h, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc); $g.Dispose()
$path = Join-Path $OutDir 'exe_window.png'
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Output "SAVED=$path"
Stop-Process -Id $p.Id -Force
