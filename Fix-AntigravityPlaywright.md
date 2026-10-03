# Antigravity IDE Playwright Driver Fix

> **Target Audience:** AI Coding Agents (Antigravity, Claude, Copilot, Cursor, etc.) pair programming with a developer.  
> **Author:** Dr. Ekpo Otu ([Website](https://ekpootu.com) | [GitHub](https://github.com/ekpootu) | [Bio](https://linktr.ee/ekpootu))  
> **Repository:** [https://github.com/ekpootu/playwright-driver-fix-for-antigravity-browser-preview](https://github.com/ekpootu/playwright-driver-fix-for-antigravity-browser-preview)

---

## 🚨 Root Cause Analysis

When launching the **Built-in Browser Preview** in Antigravity IDE, the IDE's internal Go Language Server attempts to download the Playwright driver binary (`playwright-1.57.0-win32_x64.zip` or platform equivalent) from Microsoft's legacy Azure CDN endpoint:

```
https://playwright.azureedge.net/builds/driver/playwright-1.57.0-win32_x64.zip
```

Microsoft has **deprecated and retired** the `playwright.azureedge.net` CDN. Because this URL permanently returns an **HTTP 404 Not Found** error, the automated download fails, leaving an empty cache folder and blocking the Browser Preview from launching.

---

## 💡 The Resolution Strategy

You **do not** need to download drivers from deprecated endpoints. The Playwright Go language server checks the local operating system cache first. If the driver directory is populated with `node.exe` (or `node` on Unix) and the `package/` runtime, it bypasses the network download entirely.

### Driver Cache Paths:
* **Windows:** `%LOCALAPPDATA%\ms-playwright-go\1.57.0`
* **macOS:** `~/Library/Caches/ms-playwright-go/1.57.0`
* **Linux:** `~/.cache/ms-playwright-go/1.57.0`

---

## 🤖 Instructions for AI Agents (Automated Execution)

As an AI Agent helping the user, follow these exact steps sequentially using the terminal:

### Step 1: Populate the Playwright Go Cache

#### Primary Method (Using Bundled Offline Driver Zip):
If this repository is available locally, extract the pre-bundled driver archive:

**On Windows (PowerShell):**
```powershell
$targetDir = "$env:LOCALAPPDATA\ms-playwright-go\1.57.0"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

$zipPath = (Resolve-Path ".\Playwright-1.5.7.0-Drivers\playwright-1.57.0-win32_x64.zip").Path
Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force
```

**On macOS (Bash/Zsh):**
```bash
TARGET_DIR="$HOME/Library/Caches/ms-playwright-go/1.57.0"
mkdir -p "$TARGET_DIR"
unzip -q -o "./Playwright-1.5.7.0-Drivers/playwright-1.57.0-mac-arm64.zip" -d "$TARGET_DIR"
chmod +x "$TARGET_DIR/node"
```

---

#### Fallback Method (Extracting from Antigravity IDE Local Resources):
If the zip file is not present, extract the bundled `playwright-core` directly from the user's Antigravity IDE installation:

**On Windows (PowerShell):**
```powershell
# 1. Locate IDE bundled playwright-core
$idePath = "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\node_modules\playwright-core"
if (-not (Test-Path $idePath)) {
    $idePath = "C:\Program Files\Antigravity IDE\resources\app\node_modules\playwright-core"
}

# 2. Copy core package to cache
$targetDir = "$env:LOCALAPPDATA\ms-playwright-go\1.57.0"
$packageDir = "$targetDir\package"
New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
Copy-Item -Recurse -Force "$idePath\*" "$packageDir\"

# 3. Copy system Node runtime
$nodeExe = (Get-Command node).Source
Copy-Item -Force $nodeExe "$targetDir\node.exe"
```

---

### Step 2: Install Required Chromium Browser Binaries

Execute the driver CLI to download/verify the official Chromium and Chromium-headless-shell browser builds:

**On Windows (PowerShell):**
```powershell
$targetDir = "$env:LOCALAPPDATA\ms-playwright-go\1.57.0"
& "$targetDir\node.exe" "$targetDir\package\cli.js" install chromium chromium-headless-shell
```

**On macOS (Bash/Zsh):**
```bash
TARGET_DIR="$HOME/Library/Caches/ms-playwright-go/1.57.0"
"$TARGET_DIR/node" "$TARGET_DIR/package/cli.js" install chromium chromium-headless-shell
```

---

### Step 3: Verify and Instruct User to Restart IDE

Verify that both the driver runtime and browser binaries are in place:

**On Windows (PowerShell):**
```powershell
$nodeExists = Test-Path "$env:LOCALAPPDATA\ms-playwright-go\1.57.0\node.exe"
$cliExists  = Test-Path "$env:LOCALAPPDATA\ms-playwright-go\1.57.0\package\cli.js"
if ($nodeExists -and $cliExists) {
    Write-Host "Playwright Driver setup is verified and complete!" -ForegroundColor Green
}
```

**Final Instruction to User:**  
Inform the user that the fix is complete and request that they **restart Antigravity IDE completely** (closing all active IDE windows and reopening) so the Go Language Server detects the local driver cache.
