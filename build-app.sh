#!/bin/bash
# build-app.sh — Build NotchHub and assemble a .app bundle
# Usage: ./build-app.sh [debug|release]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG="${1:-debug}"
APP_NAME="NotchHub"
APP_BUNDLE="build/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "==> Building ${APP_NAME} (${CONFIG})..."
swift build -c "$CONFIG" 2>&1

# Get the actual bin path from SPM
BUILD_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> Assembling .app bundle..."
# Kill any running instance first
pkill -x NotchHub 2>/dev/null || true
sleep 0.5

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy the executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Copy Info.plist
cp "${APP_NAME}/Resources/Info.plist" "${CONTENTS}/Info.plist"

# Copy helper scripts into Resources
if [ -d "${APP_NAME}/Resources/Scripts" ]; then
    mkdir -p "${RESOURCES}/Scripts"
    cp "${APP_NAME}/Resources/Scripts/"* "${RESOURCES}/Scripts/"
fi

# Re-sign the .app bundle (required for MediaRemote and other framework access)
echo "==> Signing .app bundle (ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Built ${APP_BUNDLE}"
echo "==> Run with: open build/${APP_NAME}.app"
echo ""
echo "==> Launching..."
open "${APP_BUNDLE}"
