Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class DpiAware { [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v); }
"@
[DpiAware]::SetProcessDpiAwareness(2) | Out-Null
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$AE = [System.Windows.Automation.AutomationElement]
$wins = Get-Process explorer -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
foreach ($w in $wins) {
  Write-Output ("WINDOW pid=" + $w.Id + " hwnd=" + $w.MainWindowHandle)
  try {
    $root = $AE::FromHandle($w.MainWindowHandle)
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)
    $els = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
    Write-Output ("listitems=" + $els.Count)
    for ($i = 0; $i -lt [Math]::Min($els.Count, 30); $i++) {
      $e = $els.Item($i)
      $r = $e.Current.BoundingRectangle
      $sel = "?"
      try { $p = $e.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern); $sel = $p.Current.IsSelected } catch { $sel = "err" }
      Write-Output ("  item[" + $i + "] name='" + $e.Current.Name + "' sel=" + $sel + " rect=" + [int]$r.X + "," + [int]$r.Y + "," + [int]$r.Width + "x" + [int]$r.Height)
    }
  } catch { Write-Output ("ERR " + $_.Exception.Message) }
}
