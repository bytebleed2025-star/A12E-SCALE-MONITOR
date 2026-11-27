# Generate the Secure Boot v2 signing key for the pilot.
#
# The private key is written to secure/keys/ and is gitignored.
# BACK IT UP OFFLINE. Losing it means the product can never be updated.
#
# Usage (from anywhere):
#   powershell -ExecutionPolicy Bypass -File secure/scripts/generate_keys.ps1

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$keyDir = Join-Path $root "secure\keys"
$keyPath = Join-Path $keyDir "secure_boot_signing_key.pem"

$python = "C:\Espressif\python_env\idf5.3_py3.11_env\Scripts\python.exe"
$espsecure = "C:\Espressif\frameworks\esp-idf-v5.3.1\components\esptool_py\esptool\espsecure.py"

if (-not (Test-Path $python)) {
    throw "ESP-IDF python not found at $python. Fix the path in this script."
}
if (-not (Test-Path $espsecure)) {
    throw "espsecure.py not found at $espsecure. Fix the path in this script."
}

New-Item -ItemType Directory -Force -Path $keyDir | Out-Null

if (Test-Path $keyPath) {
    Write-Host "Signing key already exists: $keyPath"
    Write-Host "Delete it deliberately if you really want to rotate the key."
    exit 0
}

& $python $espsecure generate_signing_key --version 2 $keyPath
if ($LASTEXITCODE -ne 0) {
    throw "espsecure.py failed with exit code $LASTEXITCODE"
}

Write-Host "Created $keyPath"
Write-Host "Generate at least two offline backups before provisioning boards."
