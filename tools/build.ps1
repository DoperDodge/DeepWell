# tools/build.ps1 — headless export to a standalone Windows .exe (PLAN.md §17.3)
# Usage:  .\tools\build.ps1  [-Godot "C:\Path\To\Godot_v4.5-stable_win64.exe"]
param(
    [string]$Godot = "C:\Program Files\Godot\Godot_v4.5-stable_win64.exe",
    [string]$Version = "0.3.0"
)

$ErrorActionPreference = "Stop"
$Out = "build\windows\DEEPWELL.exe"

if (-not (Test-Path $Godot)) {
    throw "Godot not found at '$Godot'. Pass -Godot with the path to your Godot 4.5+ executable."
}

New-Item -ItemType Directory -Force -Path "build\windows" | Out-Null

Write-Host "Importing assets..."
& $Godot --headless --path . --import

Write-Host "Exporting release build..."
& $Godot --headless --path . --export-release "Windows Desktop" $Out

if (-not (Test-Path $Out)) { throw "EXPORT FAILED - no output produced. Did you install export templates? (Editor -> Manage Export Templates)" }

$sizeMB = [math]::Round((Get-Item $Out).Length / 1MB, 1)
Write-Host "OK: $Out ($sizeMB MB)"

# Ship the license alongside — legally required (see PLAN.md §2)
Copy-Item "LICENSE.md"             "build\windows\LICENSE.md"        -Force
Copy-Item "docs\ATTRIBUTION.md"    "build\windows\ATTRIBUTION.md"    -Force
Copy-Item "docs\ASSET_LICENSES.md" "build\windows\ASSET_LICENSES.md" -Force

Write-Host "Build complete."
