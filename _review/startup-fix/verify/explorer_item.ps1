Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$out = @()
foreach ($w in (Get-Process explorer -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })) {
  try {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($w.MainWindowHandle)
    if ($null -eq $root) { continue }
    $cond = New-Object System.Windows.Automation.AndCondition(
      (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)),
      (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::IsSelectedProperty, $true))
    )
    $el = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
    $item = $null
    if ($null -ne $el) {
      $r = $el.Current.BoundingRectangle
      $item = [pscustomobject]@{
        name = $el.Current.Name
        x = [int]$r.X; y = [int]$r.Y; w = [int]$r.Width; h = [int]$r.Height
        selected = $true
      }
    }
    $out += [pscustomobject]@{
      pid = $w.Id
      hwnd = [int64]$w.MainWindowHandle
      title = $w.MainWindowTitle
      item = $item
    }
  } catch { }
}
$out | ConvertTo-Json -Depth 5 -Compress
