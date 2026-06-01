#!/usr/bin/env bash
#
# Creates a local release tag and optionally pushes it.
#
# Usage:
#   Scripts/release.sh 1.0
#   PUSH=1 Scripts/release.sh 1.0

set -euo pipefail

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
    echo "Usage: $0 <version-without-v>" >&2
    exit 2
fi

TAG="v${VERSION}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "${REPO_ROOT}"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: working tree is not clean. Commit or stash changes before tagging." >&2
    git status --short >&2
    exit 1
fi

CURRENT_VERSION="$(
    xcodebuild -project navic.xcodeproj \
        -scheme navic \
        -configuration Release \
        -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/MARKETING_VERSION/ {print $2; exit}' \
    | tr -d '[:space:]'
)"

if [[ "${CURRENT_VERSION}" != "${VERSION}" ]]; then
    echo "ERROR: MARKETING_VERSION is '${CURRENT_VERSION}', expected '${VERSION}'." >&2
    echo "Update the Xcode project version first, then commit it." >&2
    exit 1
fi

if git rev-parse "${TAG}" >/dev/null 2>&1; then
    echo "ERROR: tag ${TAG} already exists." >&2
    echo "Delete or move the existing tag before creating a replacement release." >&2
    exit 1
fi

echo "Creating tag ${TAG}"
git tag -a "${TAG}" -m "Navic ${VERSION}"

if [[ "${PUSH:-0}" == "1" ]]; then
    git push origin main
    git push origin "${TAG}"
    echo "Pushed ${TAG}. GitHub Actions will build the DMGs and publish the release."
else
    echo "Tag created locally."
    echo "Push with: git push origin main && git push origin ${TAG}"
fi
