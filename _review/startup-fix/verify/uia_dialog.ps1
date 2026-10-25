Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class DpiAware { [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v); }
"@
[DpiAware]::SetProcessDpiAwareness(2) | Out-Null
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$AE = [System.Windows.Automation.AutomationElement]
$hwnd = [IntPtr]10752224
$root = $AE::FromHandle($hwnd)
if ($null -eq $root) { Write-Output "NO_ROOT"; exit }
$rr = $root.Current.BoundingRectangle
Write-Output ("ROOT class=" + $root.Current.ClassName + " name='" + $root.Current.Name + "' pid=" + $root.Current.ProcessId + " rect=" + [int]$rr.X + "," + [int]$rr.Y + "," + [int]$rr.Width + "x" + [int]$rr.Height)
$cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
$els = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
Write-Output ("texts=" + $els.Count)
for ($i = 0; $i -lt $els.Count; $i++) {
  $e = $els.Item($i)
  $r = $e.Current.BoundingRectangle
  Write-Output ("  text[" + $i + "] '" + $e.Current.Name + "' rect=" + [int]$r.X + "," + [int]$r.Y + "," + [int]$r.Width + "x" + [int]$r.Height)
}
$bcond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$bs = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $bcond)
Write-Output ("buttons=" + $bs.Count)
for ($i = 0; $i -lt $bs.Count; $i++) {
  $e = $bs.Item($i)
  $r = $e.Current.BoundingRectangle
  Write-Output ("  button[" + $i + "] '" + $e.Current.Name + "' rect=" + [int]$r.X + "," + [int]$r.Y + "," + [int]$r.Width + "x" + [int]$r.Height)
}
