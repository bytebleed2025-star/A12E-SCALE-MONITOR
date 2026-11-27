# Clone the Arduino core used as an ESP-IDF component.
#
# The clone is intentionally gitignored: it is large and pinned by branch.
# Run this once after cloning the repository on the secure-boot branch.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dest = Join-Path $root "components\arduino"

if (Test-Path (Join-Path $dest "CMakeLists.txt")) {
    Write-Host "Arduino component already present: $dest"
    exit 0
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null

git clone --depth 1 -b release/v3.1.x `
    https://github.com/espressif/arduino-esp32.git $dest

Write-Host "Arduino component ready: $dest"
Write-Host "Next: secure/scripts/generate_keys.ps1"
