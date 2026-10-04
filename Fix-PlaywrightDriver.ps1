<#
.SYNOPSIS
    Automated Playwright Driver & Chromium Browser Fix for Antigravity IDE.

.DESCRIPTION
    Fixes the Antigravity IDE built-in browser preview failure caused by Microsoft's
    deprecated Azure CDN (playwright.azureedge.net returning 404 for playwright-1.57.0-win32_x64.zip).
    
    Resolution Strategies:
    1. Pre-Packaged Offline Zip: Automatically extracts the official driver zip if present in
       the repository ('Playwright-1.5.7.0-Drivers\playwright-1.57.0-win32_x64.zip').
       (Includes bundled node.exe and complete package files - zero internet required!)
    2. Local IDE Extraction: If the zip is not found, automatically extracts playwright-core
       from the local Antigravity IDE installation resources and links the system node.exe.
    3. Browser Provisioning: Executes the driver CLI to install and verify Chromium binaries.

.PARAMETER Force
    Forces re-extraction and re-installation even if the driver directory already exists.

.PARAMETER Preflight
    Runs as a non-destructive preflight check. Exits immediately if the driver and browser are already installed.

.PARAMETER ClearPortCollision
    Automatically terminates any orphaned background processes holding port 9222 (preventing CDP resolution errors).

.EXAMPLE
    .\Fix-PlaywrightDriver.ps1
    .\Fix-PlaywrightDriver.ps1 -Preflight
    .\Fix-PlaywrightDriver.ps1 -Force -ClearPortCollision

.NOTES
    Author: Dr. Ekpo Otu (https://ekpootu.com | https://github.com/ekpootu)
    Repository: https://github.com/ekpootu/playwright-driver-fix-for-antigravity-browser-preview
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Preflight,
    [switch]$ClearPortCollision
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Antigravity IDE - Playwright Browser Preview Fix       " -ForegroundColor Yellow
Write-Host "   Author: Dr. Ekpo Otu (https://github.com/ekpootu)       " -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$pwVersion = "1.57.0"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetDir = "$env:LOCALAPPDATA\ms-playwright-go\$pwVersion"
$targetPackageDir = "$targetDir\package"
$targetNodeExe = "$targetDir\node.exe"

# Official Pinned SHA-256 Checksums for Driver Integrity Verification
$PINNED_SHA256 = @{
    "playwright-1.57.0-win32_x64.zip" = "9F447E15A3688397222588938E9D848B680C1A0582118B37970B383622D8DABD"
    "playwright-1.57.0-mac-arm64.zip"   = "7FEE6872B7225A83FD1195F1542D884B128C284E90AEDCEDFA71A8E960B8447B"
}

# --- STEP 1: Check existing installation (Preflight Check) ---
$driverPopulated = (Test-Path "$targetDir\package\cli.js") -and (Test-Path $targetNodeExe)
if ($driverPopulated -and (-not $Force)) {
    Write-Host "[PREFLIGHT PASSED] Playwright Go driver cache (v$pwVersion) is already populated." -ForegroundColor Green
    Write-Host "                   Path: $targetDir" -ForegroundColor DarkGray
    if ($Preflight) {
        Write-Host "[PREFLIGHT] Preflight check succeeded. Driver is ready." -ForegroundColor Green
        exit 0
    }
    Write-Host "                   Use -Force to reinstall if needed." -ForegroundColor DarkGray
} else {
    # If forcing reinstall, terminate any lingering playwright node.exe instances locking the files
    if ($Force) {
        Write-Host "[INFO] Releasing any active Playwright driver processes..." -ForegroundColor DarkGray
        Get-Process -ErrorAction SilentlyContinue | Where-Object { 
            try { $_.Path -and ($_.Path -ieq $targetNodeExe) } catch { $false } 
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }

    # Ensure target directory structure exists
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }

    $installedViaZip = $false

    # --- STRATEGY 1: Check for Pre-packaged Offline Driver Zip ---
    $candidateZips = @(
        "$scriptDir\Playwright-1.5.7.0-Drivers\playwright-1.57.0-win32_x64.zip",
        "$scriptDir\playwright-1.57.0-drivers\playwright-1.57.0-win32_x64.zip",
        "$scriptDir\playwright-1.57.0-win32_x64.zip"
    )

    $foundZip = $candidateZips | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($foundZip) {
        $zipFileName = Split-Path -Leaf $foundZip
        Write-Host "[1/3] Verifying and extracting pre-packaged driver zip: $zipFileName..." -ForegroundColor Cyan

        # SHA-256 Integrity Verification
        if ($PINNED_SHA256.ContainsKey($zipFileName)) {
            $expectedHash = $PINNED_SHA256[$zipFileName]
            Write-Host "      Checking SHA-256 integrity hash..." -ForegroundColor DarkGray
            $actualHash = (Get-FileHash -Path $foundZip -Algorithm SHA256).Hash
            if ($actualHash -ieq $expectedHash) {
                Write-Host "      [VERIFIED] SHA-256 checksum matched: $actualHash" -ForegroundColor Green
            } else {
                Write-Host "[ERROR] SHA-256 checksum mismatch for $zipFileName!" -ForegroundColor Red
                Write-Host "        Expected: $expectedHash" -ForegroundColor Yellow
                Write-Host "        Actual:   $actualHash" -ForegroundColor Red
                exit 1
            }
        }

        Expand-Archive -Path $foundZip -DestinationPath $targetDir -Force
        $installedViaZip = $true
        Write-Host "      Extracted successfully into: $targetDir" -ForegroundColor Green
    }

    # --- STRATEGY 2: Fallback to Antigravity IDE bundled resources ---
    if (-not $installedViaZip) {
        Write-Host "[1/3] Driver zip not found. Searching Antigravity IDE local resources..." -ForegroundColor Cyan

        # Detect IDE install directory
        $candidateIdePaths = @(
            "$env:LOCALAPPDATA\Programs\Antigravity IDE",
            "C:\Program Files\Antigravity IDE",
            "C:\Program Files (x86)\Antigravity IDE"
        )

        # Also check running processes if installed in custom path
        $proc = Get-Process "Antigravity IDE" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc -and $proc.Path) {
            $procDir = Split-Path -Parent $proc.Path
            $candidateIdePaths = @($procDir) + $candidateIdePaths
        }

        $idePath = $candidateIdePaths | Where-Object { Test-Path "$_\resources\app\node_modules\playwright-core" } | Select-Object -First 1

        if (-not $idePath) {
            Write-Host "[ERROR] Could not find Antigravity IDE bundled playwright-core." -ForegroundColor Red
            Write-Host "        Please place 'playwright-1.57.0-win32_x64.zip' inside the 'Playwright-1.5.7.0-Drivers' folder." -ForegroundColor Yellow
            exit 1
        }

        $playwrightCorePath = "$idePath\resources\app\node_modules\playwright-core"
        Write-Host "      Found bundled playwright-core at: $playwrightCorePath" -ForegroundColor Green

        # Check version from package.json
        $pkgJsonPath = "$playwrightCorePath\package.json"
        if (Test-Path $pkgJsonPath) {
            try {
                $pkg = Get-Content $pkgJsonPath -Raw | ConvertFrom-Json
                $pwVersion = $pkg.version
                $targetDir = "$env:LOCALAPPDATA\ms-playwright-go\$pwVersion"
                $targetPackageDir = "$targetDir\package"
                $targetNodeExe = "$targetDir\node.exe"
            } catch {
                # Fallback to default
            }
        }

        if (-not (Test-Path $targetPackageDir)) {
            New-Item -ItemType Directory -Force -Path $targetPackageDir | Out-Null
        }

        Write-Host "      Copying playwright-core files to cache..." -ForegroundColor Cyan
        Copy-Item -Recurse -Force "$playwrightCorePath\*" "$targetPackageDir\"

        # Check and copy Node.js
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if (-not $nodeCmd) {
            Write-Host "[ERROR] Node.js is required when installing from local IDE resources." -ForegroundColor Red
            Write-Host "        Please install Node.js from https://nodejs.org or use the pre-packaged zip." -ForegroundColor Yellow
            exit 1
        }
        Copy-Item -Force $nodeCmd.Source $targetNodeExe
        Write-Host "      Copied Node.js runtime from: $($nodeCmd.Source)" -ForegroundColor Green
    }
}

# --- STEP 2: Install Chromium Browser Binaries ---
Write-Host "[2/3] Installing Playwright Chromium browser binaries..." -ForegroundColor Cyan
$cliJsPath = "$targetDir\package\cli.js"

if (-not (Test-Path $cliJsPath)) {
    Write-Host "[ERROR] cli.js not found at: $cliJsPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $targetNodeExe)) {
    Write-Host "[ERROR] node.exe not found at: $targetNodeExe" -ForegroundColor Red
    exit 1
}

# Execute driver cli to install chromium and headless shell
try {
    & $targetNodeExe $cliJsPath install chromium chromium-headless-shell
    Write-Host "      Chromium browser binaries installed successfully." -ForegroundColor Green
} catch {
    Write-Host "[WARNING] Browser installation reported a warning: $_" -ForegroundColor Yellow
}

# --- STEP 3: Complete and verify ---
Write-Host "[3/3] Verifying configuration & port availability..." -ForegroundColor Cyan

# Check for potential CDP port 9222 collisions
try {
    $portConn = Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($portConn) {
        $blockingPid = $portConn.OwningProcess
        $blockingProc = Get-Process -Id $blockingPid -ErrorAction SilentlyContinue
        Write-Host "[WARNING] Port 9222 (CDP Remote Debugging) is currently held by PID $blockingPid ($($blockingProc.ProcessName))." -ForegroundColor Yellow
        Write-Host "          This may trigger 'could not resolve IP for 127.0.0.1 / timed out' errors." -ForegroundColor Yellow
        if ($ClearPortCollision -or ($Force -and (-not $blockingProc.MainWindowTitle))) {
            Write-Host "          Attempting to free port 9222 by stopping background PID $blockingPid..." -ForegroundColor Cyan
            Stop-Process -Id $blockingPid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            if (-not (Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue)) {
                Write-Host "          [RESOLVED] Port 9222 has been freed successfully!" -ForegroundColor Green
            }
        } else {
            Write-Host "          If this is a stale zombie process, terminate it using: Stop-Process -Id $blockingPid -Force" -ForegroundColor Yellow
            Write-Host "          Or re-run with: .\Fix-PlaywrightDriver.ps1 -ClearPortCollision" -ForegroundColor DarkGray
        }
    }
} catch {
    # Non-critical warning check
}

$driverReady = (Test-Path $targetNodeExe) -and (Test-Path $cliJsPath)
if ($driverReady) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " [SUCCESS] Playwright Driver v$pwVersion is fully configured! " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Step: Restart Antigravity IDE completely for the changes" -ForegroundColor Cyan
    Write-Host "           to take effect, then open your Browser Preview." -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "[ERROR] Setup failed to verify required files in $targetDir" -ForegroundColor Red
    exit 1
}
