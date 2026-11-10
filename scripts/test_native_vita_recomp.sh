#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM="$ROOT/work/native-recomp"
ROM_ARCHIVE="$ROOT/work/mario-party-3-us.zip"
ROM_DIR="$UPSTREAM/roms"
ROM="$ROM_DIR/marioparty3.us.z64"

: "${ROM_ARCHIVE_URL:?ROM_ARCHIVE_URL is required}"
mkdir -p "$ROOT/work" "$ROM_DIR"

echo "== Downloading the supplied ROM archive (temporary runner storage only) =="
curl --fail --location --show-error --retry 3 --connect-timeout 20 \
  "$ROM_ARCHIVE_URL" -o "$ROM_ARCHIVE"
mkdir -p "$ROOT/work/rom-extract"
unzip -oq "$ROM_ARCHIVE" -d "$ROOT/work/rom-extract"
ROM_CANDIDATE="$(find "$ROOT/work/rom-extract" -type f -iname '*.z64' -print -quit)"
if [[ -z "$ROM_CANDIDATE" ]]; then
  echo "ERROR: the supplied ZIP did not contain a .z64 ROM." >&2
  exit 1
fi
cp "$ROM_CANDIDATE" "$ROM"
rm -rf "$ROM_ARCHIVE" "$ROOT/work/rom-extract"
ACTUAL_SHA="$(sha1sum "$ROM" | awk '{print $1}')"
EXPECTED_SHA="6beb80ff822b96bcf85dcdb512e8b2b7969d8259"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "ERROR: ROM SHA-1 mismatch. Expected USA Mario Party 3; got $ACTUAL_SHA" >&2
  exit 1
fi
echo "USA ROM verified. It remains only in this temporary runner workspace."

echo "== Checking out static-recompilation source and submodules =="
git clone --depth 1 --recurse-submodules https://github.com/n64hub/mario-party-3-recomp.git "$UPSTREAM"
cd "$UPSTREAM"
git submodule update --init --recursive --depth 1

echo "== Generating the game's native C/C++ source from the ROM =="
bash tools/recompile.sh

echo "== Cross-compiling generated game code for Vita ARM =="
docker run --rm \
  -v "$ROOT:/workspace" \
  -w /workspace/work/native-recomp \
  gnuton/vitasdk-docker:20250520 \
  bash /workspace/scripts/vita_compile_generated.sh

echo "== Generated game-code cross-compile milestone passed =="
echo "This test does not yet build a complete Vita runtime or VPK."
echo "No ROM, generated source, object file, or VPK is uploaded as an artifact."
