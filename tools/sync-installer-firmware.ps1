# Copies the merged factory image into the web installer and bumps its manifest.
# Usage:  powershell -ExecutionPolicy Bypass -File tools\sync-installer-firmware.ps1 [-Version 1.2.0]
param(
  [string]$Version = "1.2.0"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root ".pio\build\esp32dev\firmware.factory.bin"

if (-not (Test-Path $source)) {
  throw "Missing $source - run 'pio run -e esp32dev' first."
}

$destDir = Join-Path $root "docs\install\firmware"
$destName = "A12E-Scale-Monitor-v$Version-factory.bin"
$dest = Join-Path $destDir $destName

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Copy-Item $source $dest -Force

Get-ChildItem $destDir -Filter "A12E-Scale-Monitor-*-factory.bin" |
  Where-Object { $_.FullName -ne $dest } |
  Remove-Item -Force

$manifestPath = Join-Path $root "docs\install\manifest.json"
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$manifest.version = $Version
$manifest.builds[0].parts[0].path = "firmware/$destName"
$manifest | ConvertTo-Json -Depth 8 | Set-Content $manifestPath -Encoding utf8

$size = [math]::Round((Get-Item $dest).Length / 1MB, 2)
Write-Host "Installer updated: v$Version -> docs/install/firmware/$destName ($size MB)"
