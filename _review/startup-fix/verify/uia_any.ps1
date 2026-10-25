param([string]$HwndHex)
Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class DpiAware2 { [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v); }
"@
[DpiAware2]::SetProcessDpiAwareness(2) | Out-Null
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$AE = [System.Windows.Automation.AutomationElement]
$hwnd = [IntPtr][Convert]::ToInt64($HwndHex, 16)
$root = $AE::FromHandle($hwnd)
if ($null -eq $root) { Write-Output "NO_ROOT"; exit 1 }
$rr = $root.Current.BoundingRectangle
Write-Output ("ROOT class=" + $root.Current.ClassName + " pid=" + $root.Current.ProcessId + " rect=" + [int]$rr.X + "," + [int]$rr.Y + "," + [int]$rr.Width + "x" + [int]$rr.Height)
$walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
function Walk($e, $depth) {
  $ct = $e.Current.ControlType.ProgrammaticName
  $nm = $e.Current.Name
  $r = $e.Current.BoundingRectangle
  if ($nm -ne "" -or $ct -match "Button|Hyperlink") {
    Write-Output ("  " + ("  " * $depth) + $ct + " name='" + $nm + "' rect=" + [int]$r.X + "," + [int]$r.Y + "," + [int]$r.Width + "x" + [int]$r.Height)
  }
  $c = $walker.GetFirstChild($e)
  while ($null -ne $c) {
    Walk $c ($depth + 1)
    $c = $walker.GetNextSibling($c)
  }
}
Walk $root 0
