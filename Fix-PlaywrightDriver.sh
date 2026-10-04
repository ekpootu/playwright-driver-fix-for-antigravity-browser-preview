#!/usr/bin/env bash
# ==========================================================
#    Antigravity IDE - Playwright Browser Preview Fix (macOS & Linux)
#    Author: Dr. Ekpo Otu (https://github.com/ekpootu)
#    Website: https://ekpootu.com | Bio: https://linktr.ee/ekpootu
#    Repository: https://github.com/ekpootu/playwright-driver-fix-for-antigravity-browser-preview
# ==========================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}==========================================================${NC}"
echo -e "${YELLOW}   Antigravity IDE - Playwright Browser Preview Fix       ${NC}"
echo -e "   Author: Dr. Ekpo Otu (https://github.com/ekpootu)       "
echo -e "${CYAN}==========================================================${NC}"
echo ""

PW_VERSION="1.57.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pinned SHA-256 Checksums
PINNED_MAC_ARM64_SHA256="7fee6872b7225a83fd1195f1542d884b128c284e90aedcedfa71a8e960b8447b"

# Parse CLI arguments
FORCE=false
PREFLIGHT=false

for arg in "$@"; do
    case "$arg" in
        --force|-f)
            FORCE=true
            ;;
        --preflight|-p)
            PREFLIGHT=true
            ;;
    esac
done

# Detect Operating System & Architecture
OS_TYPE="$(uname -s)"
ARCH_TYPE="$(uname -m)"

if [[ "$OS_TYPE" == "Darwin" ]]; then
    TARGET_DIR="$HOME/Library/Caches/ms-playwright-go/$PW_VERSION"
elif [[ "$OS_TYPE" == "Linux" ]]; then
    TARGET_DIR="$HOME/.cache/ms-playwright-go/$PW_VERSION"
else
    echo -e "${RED}[ERROR] Unsupported operating system: $OS_TYPE${NC}"
    echo "For Windows, please execute: .\Fix-PlaywrightDriver.ps1"
    exit 1
fi

TARGET_NODE="$TARGET_DIR/node"
TARGET_CLI="$TARGET_DIR/package/cli.js"

mkdir -p "$TARGET_DIR"

# Preflight Check
if [[ -f "$TARGET_NODE" && -f "$TARGET_CLI" && "$FORCE" == false ]]; then
    echo -e "${GREEN}[PREFLIGHT PASSED] Playwright Go driver cache (v$PW_VERSION) is already populated.${NC}"
    echo -e "                   Path: $TARGET_DIR"
    if [[ "$PREFLIGHT" == true ]]; then
        echo -e "${GREEN}[PREFLIGHT] Preflight check succeeded. Driver is ready.${NC}"
        exit 0
    fi
    echo -e "                   Use --force to reinstall if needed."
fi

echo -e "${CYAN}[1/3] Preparing Playwright Go driver cache (v$PW_VERSION)...${NC}"
echo -e "      Target path: $TARGET_DIR"

INSTALLED_VIA_ZIP=false

# Strategy 1: Check for offline driver zip
if [[ "$OS_TYPE" == "Darwin" && ("$ARCH_TYPE" == "arm64" || "$ARCH_TYPE" == "aarch64") ]]; then
    CANDIDATE_ZIPS=(
        "$SCRIPT_DIR/Playwright-1.5.7.0-Drivers/playwright-1.57.0-mac-arm64.zip"
        "$SCRIPT_DIR/playwright-1.57.0-drivers/playwright-1.57.0-mac-arm64.zip"
        "$SCRIPT_DIR/playwright-1.57.0-mac-arm64.zip"
    )
else
    CANDIDATE_ZIPS=(
        "$SCRIPT_DIR/Playwright-1.5.7.0-Drivers/playwright-1.57.0-linux.zip"
        "$SCRIPT_DIR/playwright-1.57.0-drivers/playwright-1.57.0-linux.zip"
    )
fi

FOUND_ZIP=""
for z in "${CANDIDATE_ZIPS[@]}"; do
    if [[ -f "$z" ]]; then
        FOUND_ZIP="$z"
        break
    fi
done

if [[ -n "$FOUND_ZIP" ]]; then
    ZIP_NAME="$(basename "$FOUND_ZIP")"
    echo -e "${CYAN}      Verifying and extracting pre-packaged offline driver zip: $ZIP_NAME...${NC}"

    # SHA-256 Checksum Verification
    if [[ "$ZIP_NAME" == "playwright-1.57.0-mac-arm64.zip" ]]; then
        echo -e "      Checking SHA-256 integrity hash..."
        ACTUAL_HASH=""
        if command -v shasum >/dev/null 2>&1; then
            ACTUAL_HASH="$(shasum -a 256 "$FOUND_ZIP" | awk '{print $1}')"
        elif command -v sha256sum >/dev/null 2>&1; then
            ACTUAL_HASH="$(sha256sum "$FOUND_ZIP" | awk '{print $1}')"
        fi

        if [[ -n "$ACTUAL_HASH" ]]; then
            if [[ "${ACTUAL_HASH,,}" == "${PINNED_MAC_ARM64_SHA256,,}" ]]; then
                echo -e "${GREEN}      [VERIFIED] SHA-256 checksum matched: $ACTUAL_HASH${NC}"
            else
                echo -e "${RED}[ERROR] SHA-256 checksum mismatch for $ZIP_NAME!${NC}"
                echo -e "${YELLOW}        Expected: $PINNED_MAC_ARM64_SHA256${NC}"
                echo -e "${RED}        Actual:   $ACTUAL_HASH${NC}"
                exit 1
            fi
        fi
    fi

    unzip -q -o "$FOUND_ZIP" -d "$TARGET_DIR"
    INSTALLED_VIA_ZIP=true
    echo -e "${GREEN}      Extracted successfully into: $TARGET_DIR${NC}"
fi

# Strategy 2: Extract from Antigravity IDE bundled resources
if [[ "$INSTALLED_VIA_ZIP" == false ]]; then
    echo -e "${CYAN}      Checking local Antigravity IDE installation resources...${NC}"
    
    CANDIDATE_IDE_PATHS=(
        "/Applications/Antigravity IDE.app/Contents/Resources/app/node_modules/playwright-core"
        "$HOME/Applications/Antigravity IDE.app/Contents/Resources/app/node_modules/playwright-core"
        "/opt/Antigravity IDE/resources/app/node_modules/playwright-core"
        "/usr/share/antigravity-ide/resources/app/node_modules/playwright-core"
    )
    
    FOUND_IDE_CORE=""
    for p in "${CANDIDATE_IDE_PATHS[@]}"; do
        if [[ -d "$p" ]]; then
            FOUND_IDE_CORE="$p"
            break
        fi
    done

    if [[ -z "$FOUND_IDE_CORE" ]]; then
        echo -e "${RED}[ERROR] Neither offline driver zip nor local Antigravity IDE playwright-core found.${NC}"
        echo -e "${YELLOW}Please ensure 'playwright-1.57.0-mac-arm64.zip' is inside 'Playwright-1.5.7.0-Drivers'.${NC}"
        exit 1
    fi

    echo -e "${GREEN}      Found bundled playwright-core at: $FOUND_IDE_CORE${NC}"
    mkdir -p "$TARGET_DIR/package"
    cp -R "$FOUND_IDE_CORE/"* "$TARGET_DIR/package/"

    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}[ERROR] Node.js is required when extracting from IDE resources.${NC}"
        echo "Please install Node.js via Homebrew (brew install node) or https://nodejs.org"
        exit 1
    fi

    cp "$(command -v node)" "$TARGET_NODE"
    echo -e "${GREEN}      Copied system Node.js runtime into cache.${NC}"
fi

# Ensure executable permissions on node binary
if [[ -f "$TARGET_NODE" ]]; then
    chmod +x "$TARGET_NODE"
fi

# Step 2: Install Playwright Chromium binaries
echo -e "${CYAN}[2/3] Installing Playwright Chromium browser binaries...${NC}"
if [[ ! -f "$TARGET_CLI" ]]; then
    echo -e "${RED}[ERROR] Driver CLI entrypoint not found at: $TARGET_CLI${NC}"
    exit 1
fi

"$TARGET_NODE" "$TARGET_CLI" install chromium chromium-headless-shell
echo -e "${GREEN}      Chromium browser binaries installed successfully.${NC}"

# Step 3: Verification & Port Availability
echo -e "${CYAN}[3/3] Verifying configuration & port availability...${NC}"

# Check for potential CDP port 9222 collisions
if command -v lsof >/dev/null 2>&1; then
    PORT_PID="$(lsof -ti :9222 2>/dev/null | head -n 1 || true)"
    if [[ -n "$PORT_PID" ]]; then
        echo -e "${YELLOW}[WARNING] Port 9222 (CDP Remote Debugging) is currently held by PID $PORT_PID.${NC}"
        echo -e "${YELLOW}          This may trigger 'could not resolve IP for 127.0.0.1 / timed out' errors.${NC}"
        echo -e "${YELLOW}          If this is a stale zombie process, terminate it using: kill -9 $PORT_PID${NC}"
    fi
fi

if [[ -x "$TARGET_NODE" && -f "$TARGET_CLI" ]]; then
    echo ""
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN} [SUCCESS] Playwright Driver v$PW_VERSION is fully configured! ${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    echo -e "${CYAN}Next Step: Restart Antigravity IDE completely for the changes${NC}"
    echo -e "${CYAN}           to take effect, then open your Browser Preview.${NC}"
    echo ""
else
    echo -e "${RED}[ERROR] Verification failed. Required driver components are missing in $TARGET_DIR${NC}"
    exit 1
fi
