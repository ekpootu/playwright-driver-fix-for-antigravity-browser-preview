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

> **Agent Note on Workspace:** If this fix repository is not yet cloned in your user's current project workspace, clone it first to access the verified driver archives:
> ```bash
> git clone https://github.com/ekpootu/playwright-driver-fix-for-antigravity-browser-preview.git
> cd playwright-driver-fix-for-antigravity-browser-preview
> ```
> *(Or execute `.\Fix-PlaywrightDriver.ps1 -Preflight` directly if already downloaded).*

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

---

## 🛡️ Antigravity Harness Bootstrap & Preflight Integration

### 💡 One Thing to Add to Your Harness (Architecture & Best Practice)

When using Antigravity IDE or the Antigravity CLI as an **automated AI-agent harness**, autonomous coding pipeline, or developer provisioning system, make the driver-cache check an official part of your **harness bootstrap preflight**:

```
if Playwright 1.57.0 driver exists:
    continue
else:
    verify driver archive integrity (SHA-256)
    install bundled/offline driver
    install Chromium
    verify browser launch & CDP readiness
```

### Complete Execution Flow

```
Antigravity IDE / CLI / Agent Harness
                 │
                 ▼
        Go Language Server
                 │
                 ▼
           playwright-go
                 │
                 ├── checks %LOCALAPPDATA%\ms-playwright-go\1.57.0
                 │
                 ▼
            Driver Exists
                 │
                 ├── node.exe (verified)
                 ├── package/
                 │     └── cli.js
                 │
                 ▼
          Install Chromium
                 │
                 ▼
   Browser Preview / open_browser_url
                 │
                 ▼
             ✅ WORKS
```

Instead of the failing CDN route:

```
playwright-go ──► Azure CDN (playwright.azureedge.net) ──► 404 Not Found ──► 💥 Browser Preview Failure
```

### Key Operational Benefits

1. **Zero 404 Exceptions**: Fresh developer machines and runner instances never attempt to contact the decommissioned Microsoft Azure CDN.
2. **Pinned Cryptographic Integrity**: By pinning driver archives with **SHA-256** checksums, you prevent supply-chain tampering and ensure reproducible environments.
3. **CDP Port Collision Remediation**: Detects and resolves TCP port `9222` conflicts (e.g. from background zombie browser processes) that trigger `open_browser_url failed with failed to create browser context: failed to resolve CDP URLs: get CDP version info: could not resolve IP for 127.0.0.1 / timed out`.

### 🔒 Official Pinned SHA-256 Checksums

| Driver Archive | Target Platform | Architecture | SHA-256 Checksum |
| :--- | :--- | :--- | :--- |
| `playwright-1.57.0-win32_x64.zip` | Windows | x64 (64-bit) | `9F447E15A3688397222588938E9D848B680C1A0582118B37970B383622D8DABD` |
| `playwright-1.57.0-mac-arm64.zip` | macOS | Apple Silicon (arm64) | `7FEE6872B7225A83FD1195F1542D884B128C284E90AEDCEDFA71A8E960B8447B` |

### 🚀 Automated Preflight Commands for AI Harnesses & CI/CD

**On Windows (PowerShell):**
```powershell
# Non-destructive preflight check (exits 0 if ready, provisions if missing)
.\Fix-PlaywrightDriver.ps1 -Preflight

# Force clean reinstallation and clear port 9222 collisions
.\Fix-PlaywrightDriver.ps1 -Force -ClearPortCollision
```

**On macOS & Linux (Bash):**
```bash
# Non-destructive preflight check
./Fix-PlaywrightDriver.sh --preflight

# Force reinstall
./Fix-PlaywrightDriver.sh --force
```
