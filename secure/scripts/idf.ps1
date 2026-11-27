# Run idf.py with the local ESP-IDF 5.3.1 installation.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File secure/scripts/idf.ps1 set-target esp32
#   powershell -ExecutionPolicy Bypass -File secure/scripts/idf.ps1 build
#   powershell -ExecutionPolicy Bypass -File secure/scripts/idf.ps1 -p COM5 flash monitor
#
# idf_cmd_init.bat sets up the toolchain, Python env and PATH for this shell.

$ErrorActionPreference = "Stop"

$env:IDF_PATH = "C:\Espressif\frameworks\esp-idf-v5.3.1"

$init = "C:\Espressif\idf_cmd_init.bat"
if (-not (Test-Path $init)) {
    throw "ESP-IDF init script not found at $init."
}

$argLine = ($args | ForEach-Object {
    if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
}) -join ' '

cmd /c "set IDF_PATH=$($env:IDF_PATH)&& call `"$init`" && idf.py $argLine"
exit $LASTEXITCODE
