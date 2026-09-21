#!/bin/zsh
# Proves the Swift engine against the ORIGINAL web engine, frame by frame.
#
# Fetches Jakub Antalik's thinking-orbs at a pinned commit, runs its
# TypeScript engine under Node (built-in type stripping, no npm install) and
# streams ~725k frames through a FIFO into SweepTests, which recomputes each
# one in Swift on an iPhone simulator and compares every dot and line.
#
# usage: Scripts/differential-sweep.sh [simulator name or UDID]   (default: iPhone 17 Pro)
# needs: Xcode, git, python3, Node 23.6+ (runs TypeScript directly)
set -euo pipefail
cd "$(dirname "$0")/.."

command -v node >/dev/null || { echo "needs Node 23.6+"; exit 1; }
node -e 'const [a, b] = process.versions.node.split(".").map(Number); process.exit(a > 23 || (a === 23 && b >= 6) ? 0 : 1)' \
  || { echo "needs Node 23.6+ to run TypeScript directly (found $(node --version))"; exit 1; }

UPSTREAM="https://github.com/Jakubantalik/thinking-orbs"
PIN="de85557ca220332586d070d8788c0e1d6e877a0d"
WORK="$PWD/Scripts/.work/sweep"
SIM="${1:-iPhone 17 Pro}"

if [[ "$SIM" =~ ^[0-9A-F-]{36}$ ]]; then
  UDID="$SIM"
else
  UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d['name'] == sys.argv[1] and 'iOS' in runtime:
            print(d['udid']); sys.exit()
sys.exit('no available iOS simulator named ' + sys.argv[1])" "$SIM")
fi

rm -rf "$WORK" && mkdir -p "$WORK/ts/engine"
git clone --quiet "$UPSTREAM" "$WORK/upstream"
git -C "$WORK/upstream" checkout --quiet "$PIN"

# the engine as shipped, with relative imports made explicit for Node
cp "$WORK/upstream/src/presets.ts" "$WORK/upstream/src/types.ts" "$WORK/ts/"
cp "$WORK/upstream/src/engine/"*.ts "$WORK/ts/engine/"
for f in "$WORK"/ts/*.ts "$WORK"/ts/engine/*.ts; do
  sed -E -i '' "s#(from ')(\.{1,2}/[^']+)(')#\1\2.ts\3#g" "$f"
done
cp Scripts/sweep/gen.ts "$WORK/gen.ts"
echo '{ "type": "module" }' > "$WORK/package.json"   # plain ESM, whatever sits above

mkfifo "$WORK/frames.fifo"
(cd "$WORK" && node gen.ts spec.json frames.fifo 2> gen.log) &
GEN=$!
trap 'kill $GEN 2>/dev/null || true' EXIT INT TERM
until [[ -s "$WORK/spec.json" ]]; do
  kill -0 $GEN 2>/dev/null || { echo "the web engine failed to start:"; cat "$WORK/gen.log"; exit 1; }
  sleep 0.5
done

xcrun simctl boot "$UDID" 2>/dev/null || true
echo "Streaming the web engine into the Swift engine on simulator $UDID…"
TEST_RUNNER_ORB_SWEEP_SPEC="$WORK/spec.json" \
TEST_RUNNER_ORB_SWEEP_STREAM="$WORK/frames.fifo" \
TEST_RUNNER_ORB_SWEEP_REPORT="$WORK/report.txt" \
xcodebuild test \
  -scheme ThinkingOrbs \
  -destination "id=$UDID" \
  -derivedDataPath "$PWD/Scripts/.work/DerivedData" \
  -only-testing:ThinkingOrbsTests/SweepTests \
  -parallel-testing-enabled NO \
  SWIFT_OPTIMIZATION_LEVEL=-O \
  -quiet || { kill $GEN 2>/dev/null; tail -20 "$WORK/report.txt" 2>/dev/null; exit 1; }

wait $GEN
tail -1 "$WORK/report.txt"
echo
