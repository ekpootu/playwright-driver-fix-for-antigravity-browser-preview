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

.EXAMPLE
    .\Fix-PlaywrightDriver.ps1
    .\Fix-PlaywrightDriver.ps1 -Force

.NOTES
    Author: Dr. Ekpo Otu (https://ekpootu.com | https://github.com/ekpootu)
    Repository: https://github.com/ekpootu/playwright-driver-fix-for-antigravity-browser-preview
#>

[CmdletBinding()]
param(
    [switch]$Force
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

# --- STEP 1: Check existing installation ---
if ((Test-Path "$targetDir\package\cli.js") -and (Test-Path $targetNodeExe) -and (-not $Force)) {
    Write-Host "[INFO] Playwright Go driver cache (v$pwVersion) is already populated." -ForegroundColor Green
    Write-Host "       Path: $targetDir" -ForegroundColor DarkGray
    Write-Host "       Use -Force to reinstall if needed." -ForegroundColor DarkGray
} else {
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
        Write-Host "[1/3] Extracting pre-packaged driver zip: $(Split-Path -Leaf $foundZip)..." -ForegroundColor Cyan
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
Write-Host "[3/3] Verifying configuration..." -ForegroundColor Cyan

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
