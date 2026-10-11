#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_ID="${SIMULATOR_UDID:-7EF41CFD-CA52-44E3-AF68-228EA39F3A76}"
OUTPUT_DIR="${1:-$ROOT_DIR/app-store-screenshots/public/screenshots/apple/ipad/zh-Hans}"
BUNDLE_ID="com.wenlei.PlayTimer"
DERIVED_DATA="${PLAYTIMER_CAPTURE_DERIVED_DATA:-/tmp/PlayTimerMarketingCaptureDerivedData}"
TEMP_DIR="$(mktemp -d /tmp/playtimer-marketing-capture.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$OUTPUT_DIR"

if ! xcrun simctl list devices available | grep -q "$DEVICE_ID"; then
  echo "Simulator $DEVICE_ID is unavailable. Set SIMULATOR_UDID to an available iPad simulator." >&2
  exit 1
fi

if ! xcrun simctl list devices available | grep "$DEVICE_ID" | grep -q '(Booted)'; then
  xcrun simctl boot "$DEVICE_ID" || true
  xcrun simctl bootstatus "$DEVICE_ID" -b
fi

xcrun simctl ui "$DEVICE_ID" appearance light
xcrun simctl status_bar "$DEVICE_ID" override \
  --time '9:41' \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100

xcodebuild \
  -project "$ROOT_DIR/PlayTimer.xcodeproj" \
  -scheme PlayTimer \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/PlayTimer.app"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

capture() {
  local file_name="$1"
  shift
  xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" "$@" \
    -AppleLanguages '(zh-Hans)' -AppleLocale zh-Hans >/dev/null
  sleep 3
  xcrun simctl io "$DEVICE_ID" screenshot "$TEMP_DIR/$file_name.png" >/dev/null
  dimensions="$(sips -g pixelWidth -g pixelHeight "$TEMP_DIR/$file_name.png" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')"
  width="${dimensions%x*}"
  height="${dimensions#*x}"
  if [[ "$width" -lt "$height" ]]; then
    # CoreSimulator writes the rotated landscape framebuffer as portrait pixels.
    sips -r 270 "$TEMP_DIR/$file_name.png" --out "$TEMP_DIR/$file_name-landscape.png" >/dev/null
    mv "$TEMP_DIR/$file_name-landscape.png" "$TEMP_DIR/$file_name.png"
  fi
  cp "$TEMP_DIR/$file_name.png" "$OUTPUT_DIR/$file_name.png"
  echo "Captured $OUTPUT_DIR/$file_name.png"
}

capture '01-parent-setup' -PlayTimerPreviewReady
capture '02-app-collections' -PlayTimerPreviewReady -MarketingCaptureCollection
capture '03-playtime' -PlayTimerPreviewPlaying
capture '04-rest' -PlayTimerPreviewBreak
capture '05-parent-verification' -MarketingCaptureParentGate

for image in "$OUTPUT_DIR"/*.png; do
  dimensions="$(sips -g pixelWidth -g pixelHeight "$image" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')"
  width="${dimensions%x*}"
  height="${dimensions#*x}"
  if [[ -z "$width" || -z "$height" || "$width" -le "$height" ]]; then
    echo "Expected landscape screenshots, but $image is $dimensions. Rotate the Simulator to landscape and rerun this script." >&2
    exit 1
  fi
done
