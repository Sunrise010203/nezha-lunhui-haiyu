Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class DpiAware { [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v); }
"@
[DpiAware]::SetProcessDpiAwareness(2) | Out-Null
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$AE = [System.Windows.Automation.AutomationElement]
$out = $null
foreach ($w in (Get-Process explorer -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })) {
  try {
    $root = $AE::FromHandle($w.MainWindowHandle)
    if ($null -eq $root) { continue }
    $rr = $root.Current.BoundingRectangle
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)
    $els = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
    for ($i = 0; $i -lt $els.Count; $i++) {
      $e = $els.Item($i)
      $sel = $false
      try { $p = $e.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern); $sel = $p.Current.IsSelected } catch { }
      if ($sel) {
        $r = $e.Current.BoundingRectangle
        $out = [pscustomobject]@{
          pid = $w.Id; hwnd = [int64]$w.MainWindowHandle; title = $w.MainWindowTitle
          root_rect = @([int]$rr.X, [int]$rr.Y, [int]$rr.Width, [int]$rr.Height)
          name = $e.Current.Name
          x = [int]$r.X; y = [int]$r.Y; w = [int]$r.Width; h = [int]$r.Height
        }
        break
      }
    }
  } catch { }
  if ($null -ne $out) { break }
}
if ($null -eq $out) { Write-Output '{"error":"no-selected-item"}' } else { $out | ConvertTo-Json -Compress }
