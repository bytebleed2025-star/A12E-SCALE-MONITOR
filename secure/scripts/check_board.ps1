# Read-only check of a spare A12E board before Secure Boot v2 provisioning.
#
# This script does not burn anything. It prints the chip revision and eFuse
# summary so we can confirm the board is ESP32 ECO V3 or newer.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File secure/scripts/check_board.ps1 -Port COM5

param(
    [string]$Port = ""
)

$ErrorActionPreference = "Stop"

$env:IDF_PATH = "C:\Espressif\frameworks\esp-idf-v5.3.1"
$python = "C:\Espressif\python_env\idf5.3_py3.11_env\Scripts\python.exe"
$espefuse = Join-Path $env:IDF_PATH "components\esptool_py\esptool\espefuse.py"

if (-not (Test-Path $python)) {
    throw "ESP-IDF python not found at $python."
}
if (-not (Test-Path $espefuse)) {
    throw "espefuse.py not found at $espefuse."
}

$portArg = @()
if ($Port -ne "") {
    $portArg = @("--port", $Port)
}

Write-Host "Reading eFuse summary (read-only)..." -ForegroundColor Cyan
& $python $espefuse @portArg summary
if ($LASTEXITCODE -ne 0) {
    throw "espefuse.py summary failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Check the 'Chip revision' / 'CHIP_VER_REV' value above." -ForegroundColor Yellow
Write-Host "Secure Boot v2 needs ESP32 ECO V3 or newer (rev >= 3.0)." -ForegroundColor Yellow
Write-Host "If secure boot / flash encryption eFuses are already burned, STOP." -ForegroundColor Yellow
