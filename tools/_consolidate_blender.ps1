# Consolidate everything Blender-related at E:\ root into E:\blender\
# Layout: E:\blender\app\ (portable install) + E:\blender\downloads\
$ErrorActionPreference = 'Stop'
$root = 'E:\'
$dest = 'E:\blender'
$app  = Join-Path $dest 'app'
$dl   = Join-Path $dest 'downloads'

if (Test-Path $dest) { throw "ABORT: $dest already exists - refusing to merge into an existing folder." }

$dirs = @('5.1', 'blender.crt', 'blender.shared', 'license')
$files = @(
    'blender.exe', 'blender.exe.manifest',
    'blender-launcher.exe', 'blender-launcher.exe.manifest',
    'blender.pdb',
    'blender_cpu_check.dll', 'blender_cpu_check.lib',
    'blender_debug_cycles.cmd', 'blender_debug_gpu.cmd',
    'blender_debug_gpu_glitchworkaround.cmd', 'blender_debug_log.cmd',
    'blender_factory_startup.cmd', 'blender_factory_startup_vulkan.cmd',
    'blender_oculus.cmd', 'blender_startup_opengl.cmd',
    'blender_startup_vulkan.cmd', 'blender_system_info.cmd',
    'BlendThumb.dll', 'BlendThumb.lib',
    'cycles_kernel_oneapi_aot.dll',
    'python3.dll', 'python313.dll',
    'ucrtbase.dll',
    'oculus.json', 'copyright.txt', 'readme.html', 'Uninstall.exe'
)

$srcs = @()
foreach ($d in $dirs) { $srcs += (Join-Path $root $d) }
foreach ($f in $files) { $srcs += (Join-Path $root $f) }

$missing = $srcs | Where-Object { -not (Test-Path -LiteralPath $_) }
if ($missing) { throw ("ABORT: expected Blender payload missing: " + ($missing -join ', ')) }

# Verify these really are Blender's own files, so a same-named unrelated item never gets swept in.
if (-not (Test-Path -LiteralPath (Join-Path $root '5.1\datafiles'))) { throw 'ABORT: E:\5.1 does not look like a Blender version folder.' }
if ((Get-Item -LiteralPath (Join-Path $root 'blender.exe')).Length -lt 50MB) { throw 'ABORT: E:\blender.exe is not the expected ~108MB binary.' }

New-Item -ItemType Directory -Path $app -Force | Out-Null
New-Item -ItemType Directory -Path $dl -Force | Out-Null

$moved = @()
try {
    foreach ($s in $srcs) {
        $t = Join-Path $app (Split-Path -Leaf $s)
        if (Test-Path -LiteralPath $t) { throw "ABORT: destination already has $t" }
        Move-Item -LiteralPath $s -Destination $t -ErrorAction Stop
        $moved += [pscustomobject]@{ from = $s; to = $t }
        Write-Output ("moved  {0}  ->  {1}" -f $s, $t)
    }
} catch {
    Write-Output "FAILED: $($_.Exception.Message)"
    Write-Output 'Rolling back everything moved so far...'
    for ($i = $moved.Count - 1; $i -ge 0; $i--) {
        $m = $moved[$i]
        try { Move-Item -LiteralPath $m.to -Destination $m.from -ErrorAction Stop; Write-Output ("  reverted {0}" -f $m.to) }
        catch { Write-Output ("  ROLLBACK FAILED for {0}: {1}" -f $m.to, $_.Exception.Message) }
    }
    throw 'Move aborted and rolled back. Nothing was left split.'
}

# Installer MSI that belongs to this install
$msi = 'E:\User_Sunrise_Downloads\blender-5.1.2-windows-x64.msi'
if (Test-Path -LiteralPath $msi) {
    Move-Item -LiteralPath $msi -Destination (Join-Path $dl 'blender-5.1.2-windows-x64.msi') -ErrorAction Stop
    Write-Output "moved  $msi  ->  $dl"
}

Write-Output '=== E:\ root leftovers matching blender ==='
Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^blender|^5\.1$|^BlendThumb|^license$|^oculus\.json$' } |
    Select-Object -ExpandProperty Name

Write-Output '=== result ==='
Get-ChildItem -LiteralPath $dest -Force | Select-Object Mode, Name
Get-ChildItem -LiteralPath $app | Measure-Object -Property Length -Sum | ForEach-Object { "app root files={0}" -f $_.Count }
