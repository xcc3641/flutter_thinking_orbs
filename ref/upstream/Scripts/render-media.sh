#!/bin/zsh
# Renders the README animations on an iPhone simulator and encodes them as
# looping GIFs into assets/. Every frame is drawn by the package's real views
# with the orb clock pinned, so the output is exact and repeatable.
#
# usage: Scripts/render-media.sh [simulator name or UDID]   (default: iPhone 17 Pro)
# needs: Xcode, python3 with Pillow + numpy, ffmpeg (gifsicle optional)
set -euo pipefail
cd "$(dirname "$0")/.."

command -v ffmpeg >/dev/null || { echo "needs ffmpeg (brew install ffmpeg)"; exit 1; }
python3 -c 'import PIL, numpy' 2>/dev/null || { echo "needs Pillow and numpy (pip3 install pillow numpy)"; exit 1; }

WORK="$PWD/Scripts/.work"
SIM="${1:-iPhone 17 Pro}"

if [[ "$SIM" =~ ^[0-9A-F-]{36}$ ]]; then
  UDID="$SIM"
else
  UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d['name'] == name and 'iOS' in runtime:
            print(d['udid']); sys.exit()
sys.exit('no available iOS simulator named ' + name)" "$SIM")
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
rm -rf "$WORK/media" && mkdir -p "$WORK/media"

echo "Rendering frames on simulator $UDID…"
TEST_RUNNER_ORBS_MEDIA_OUT="$WORK/media" xcodebuild test \
  -scheme ThinkingOrbs \
  -destination "id=$UDID" \
  -derivedDataPath "$WORK/DerivedData" \
  -only-testing:ThinkingOrbsTests/MediaTests \
  -parallel-testing-enabled NO \
  -quiet

echo "Encoding GIFs…"
python3 Scripts/make_gifs.py "$WORK/media" assets
