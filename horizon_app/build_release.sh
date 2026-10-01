#!/usr/bin/env bash
# Builds the release APKs members download from GitHub Releases.
#   bash build_release.sh                 -> production server
#   PB_URL=https://other bash build_release.sh
# Output: dist/Horizon.apk (all phones) and dist/Horizon-arm64.apk (smaller, most phones).
# Bump `version:` in pubspec.yaml first; the in-app update check compares against it.
set -euo pipefail
cd "$(dirname "$0")"

PB_URL="${PB_URL:-https://horizon.streamharbor.me}"
VERSION="$(sed -n 's/^version: *\([0-9.]*\)+.*/\1/p' pubspec.yaml)"
[ -f android/key.properties ] || { echo "android/key.properties missing: restore the signing key first (see Documents/Horizon-signing-key)"; exit 1; }

DEFINES=(--dart-define=PB_URL="$PB_URL" --dart-define=APP_VERSION="$VERSION")
flutter build apk --release "${DEFINES[@]}"
flutter build apk --release --split-per-abi --target-platform android-arm64 "${DEFINES[@]}"

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk dist/Horizon.apk
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk dist/Horizon-arm64.apk
echo "Built v$VERSION for $PB_URL -> dist/"
ls -la dist
