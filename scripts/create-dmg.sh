#!/bin/bash
set -euo pipefail

APP_NAME="LSLS"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"
VERSION="${1:-dev}"
DMG_FINAL="${PROJECT_DIR}/${APP_NAME}-${VERSION}-macOS.dmg"
STAGING_DIR="$(mktemp -d)"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "Error: ${APP_BUNDLE} not found. Run build-app.sh first."
    exit 1
fi

echo "Creating DMG..."

# Set up DMG staging area
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# Create DMG with hdiutil
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_FINAL}"

# Clean up
rm -rf "${STAGING_DIR}"

echo "Done: ${DMG_FINAL}"
