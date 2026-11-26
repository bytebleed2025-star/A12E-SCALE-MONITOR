# One-command firmware release for the A12E Scale Monitor web installer.
# Usage:  powershell -ExecutionPolicy Bypass -File tools\release-installer.ps1 -Version 1.2.1
#
# Steps: bump FW_VERSION -> build -> sync installer files -> commit -> push (Pages redeploys).
param(
  [Parameter(Mandatory = $true)]
  [string]$Version,
  [switch]$SkipBuild,
  [switch]$SkipVersionBump,
  [switch]$NoPush
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$Version = $Version.TrimStart("v", "V")
if ($Version -notmatch '^\d+\.\d+(\.\d+)?$') {
  throw "Version must look like 1.2.1 or 1.2.1.4 (got '$Version')."
}

function Invoke-External {
  param([string]$Exe, [string[]]$Arguments)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $Exe @Arguments 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
      throw "$Exe $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
  } finally {
    $ErrorActionPreference = $previous
  }
}

Push-Location $root
try {
  if (-not $SkipVersionBump) {
    $mainPath = Join-Path $root "src\main.cpp"
    $main = Get-Content $mainPath -Raw
    $updated = [regex]::Replace(
      $main,
      '(#define\s+FW_VERSION\s+")[^"]*(")',
      '${1}' + $Version + '${2}'
    )
    if ($updated -ne $main) {
      Set-Content -Path $mainPath -Value $updated -NoNewline
      Write-Host "Firmware version set to $Version in src/main.cpp"
    } else {
      Write-Host "Firmware version already $Version in src/main.cpp"
    }
  }

  if (-not $SkipBuild) {
    Write-Host "`nBuilding esp32dev..."
    Invoke-External "pio" @("run", "-e", "esp32dev")
  } else {
    $bin = Join-Path $root ".pio\build\esp32dev\firmware.factory.bin"
    if (-not (Test-Path $bin)) {
      throw "Missing $bin - build first or drop -SkipBuild."
    }
    Write-Host "`nSkipping build, using existing firmware.factory.bin"
  }

  $sync = Join-Path $root "tools\sync-installer-firmware.ps1"
  Write-Host "`nUpdating installer files..."
  Invoke-External "powershell" @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $sync, "-Version", $Version
  )

  Invoke-External "git" @("add", "-A")

  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $changes = & git status --porcelain 2>$null
  $statusCode = $LASTEXITCODE
  $ErrorActionPreference = $previous
  if ($statusCode -ne 0) { throw "git status failed with exit code $statusCode" }

  if ($changes) {
    Invoke-External "git" @("commit", "-m", "Release v$Version")
    if ($NoPush) {
      Write-Host "`nCommitted locally (-NoPush). Push when ready: git push"
    } else {
      Write-Host "`nPushing to GitHub..."
      Invoke-External "git" @("push", "origin", "main")
    }
  } else {
    Write-Host "`nNo changes to commit."
  }

  $image = Join-Path $root "docs\install\firmware\A12E-Scale-Monitor-v$Version-factory.bin"
  $size = [math]::Round((Get-Item $image).Length / 1MB, 2)

  Write-Host ""
  Write-Host "Release v$Version ready ($size MB)" -ForegroundColor Green
  Write-Host "https://bytebleed2025-star.github.io/A12E-SCALE-MONITOR/install/"
} finally {
  Pop-Location
}
