#!/usr/bin/env bash
clear; printf '\e[3J';

set -euo pipefail

cd "$(dirname "$0")"

echo "=== Installing pods ==="
pod install --silent

echo "=== Cleaning ==="
xcodebuild -workspace penteLive.xcworkspace -scheme test1 clean

echo "=== Building ==="
xcodebuild -workspace penteLive.xcworkspace -scheme test1 -destination "generic/platform=iOS" build

APP_DIR=$(xcodebuild -workspace penteLive.xcworkspace -scheme test1 -destination "generic/platform=iOS" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ CODESIGNING_FOLDER_PATH /{print $2}')
echo "Built at: $APP_DIR"

DEVICE_UDID="00008160-001934C120434036"
while true; do
    echo "Attempting iPhone install on $DEVICE_UDID"
    if xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_DIR" 2>&1 | grep -q "App installed"; then
        echo "Installation succeeded"
        if [ -x /Volumes/keysCertificatesStuff/token/refreshToken.sh ]; then
            /Volumes/keysCertificatesStuff/token/refreshToken.sh
        fi
        break
    fi
    echo "Installation failed — retrying in 5s"
    sleep 5
done
