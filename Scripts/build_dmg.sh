#!/usr/bin/env bash
#
# Builds Navic.app for a single architecture (arm64 or x86_64) and packages
# it into a DMG. Designed to run from CI on a macOS runner or from a
# developer's terminal.
#
# Usage:
#     Scripts/build_dmg.sh arm64    # → build/Navic-<version>-arm64.dmg
#     Scripts/build_dmg.sh x86_64   # → build/Navic-<version>-x86_64.dmg
#
# Environment overrides:
#   CONFIGURATION   Release|Debug         (default: Release)
#   CODE_SIGN       1 to use the project's signing settings,
#                   0 to disable codesign entirely (default: 0 for CI)
#   PROJECT_NAME    Xcode project name     (default: navic)
#   SCHEME          Xcode scheme to build  (default: navic)
#   APP_NAME        Bundle display name    (default: Navic)

set -euo pipefail

ARCH="${1:-}"
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
    echo "Usage: $0 {arm64|x86_64}" >&2
    exit 2
fi

CONFIGURATION="${CONFIGURATION:-Release}"
CODE_SIGN="${CODE_SIGN:-0}"
PROJECT_NAME="${PROJECT_NAME:-navic}"
SCHEME="${SCHEME:-navic}"
APP_NAME="${APP_NAME:-Navic}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
DERIVED_DATA="${BUILD_DIR}/DerivedData-${ARCH}"
STAGE_DIR="${BUILD_DIR}/dmg-stage-${ARCH}"

mkdir -p "${BUILD_DIR}"
rm -rf "${DERIVED_DATA}" "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"

# ──────────────────────────────────────────────────────────────────────────
# Resolve version (CFBundleShortVersionString from build settings).
# ──────────────────────────────────────────────────────────────────────────
VERSION="$(
    xcodebuild -project "${REPO_ROOT}/${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/MARKETING_VERSION/ {print $2; exit}' \
    | tr -d '[:space:]'
)"
VERSION="${VERSION:-0.0.0}"
echo "──── Building ${APP_NAME} ${VERSION} for ${ARCH} (${CONFIGURATION}) ────"

# ──────────────────────────────────────────────────────────────────────────
# Build. We deliberately disable code signing for CI by default — signed,
# notarised builds require Apple Developer credentials kept outside CI.
# ──────────────────────────────────────────────────────────────────────────
SIGN_ARGS=()
if [[ "${CODE_SIGN}" != "1" ]]; then
    SIGN_ARGS+=(
        CODE_SIGN_IDENTITY=""
        CODE_SIGNING_REQUIRED=NO
        CODE_SIGNING_ALLOWED=NO
    )
fi

xcodebuild \
    -project "${REPO_ROOT}/${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA}" \
    -destination "platform=macOS,arch=${ARCH}" \
    ARCHS="${ARCH}" \
    ONLY_ACTIVE_ARCH=NO \
    "${SIGN_ARGS[@]}" \
    clean build

APP_PATH="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/${PROJECT_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
    echo "ERROR: built app not found at ${APP_PATH}" >&2
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────
# Stage the .app into the DMG layout. We rename navic.app → Navic.app for
# the user-facing display, and include a friendly /Applications shortcut.
# ──────────────────────────────────────────────────────────────────────────
cp -R "${APP_PATH}" "${STAGE_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGE_DIR}/Applications"

DMG_NAME="${APP_NAME}-${VERSION}-${ARCH}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
rm -f "${DMG_PATH}"

echo "──── Packaging ${DMG_NAME} ────"
hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "${STAGE_DIR}" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    -imagekey zlib-level=9 \
    "${DMG_PATH}" >/dev/null

echo "Done: ${DMG_PATH}"
