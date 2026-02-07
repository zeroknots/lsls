#!/bin/bash
set -euo pipefail

APP_NAME="LSLS"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/.build/release"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"

# 1. Build release binary
echo "Building ${APP_NAME}..."
swift build -c release --package-path "${PROJECT_DIR}"

# 2. Create .app bundle structure
echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

# 3. Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"

# 4. Copy Info.plist and inject version if available
cp "${PROJECT_DIR}/Sources/${APP_NAME}/Resources/Info.plist" "${CONTENTS}/Info.plist"
if [ -n "${VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${CONTENTS}/Info.plist"
fi

# 5. Copy icon if it exists
if [ -f "${PROJECT_DIR}/Sources/${APP_NAME}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Sources/${APP_NAME}/Resources/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"
fi

# 6. Ad-hoc code sign
echo "Code signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done: ${APP_BUNDLE}"
