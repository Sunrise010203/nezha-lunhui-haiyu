Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class DpiAware3 { [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v); }
"@
[DpiAware3]::SetProcessDpiAwareness(2) | Out-Null
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$AE = [System.Windows.Automation.AutomationElement]
$root = $AE::RootElement
foreach ($ct in @([System.Windows.Automation.ControlType]::Button, [System.Windows.Automation.ControlType]::Hyperlink, [System.Windows.Automation.ControlType]::Text)) {
  $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, $ct)
  $els = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
  for ($i = 0; $i -lt $els.Count; $i++) {
    $e = $els.Item($i)
    $nm = $e.Current.Name
    if ($nm -match '更多信息|仍要运行|不运行|保护|SmartScreen') {
      $r = $e.Current.BoundingRectangle
      Write-Output ($ct.ProgrammaticName + " name='" + $nm + "' pid=" + $e.Current.ProcessId + " rect=" + [int]$r.X + "," + [int]$r.Y + "," + [int]$r.Width + "x" + [int]$r.Height)
    }
  }
}
