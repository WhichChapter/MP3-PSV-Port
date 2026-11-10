#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM="$ROOT/work/native-recomp"
ROM_ARCHIVE="$ROOT/work/mario-party-3-us.zip"
ROM_DIR="$UPSTREAM/roms"
ROM="$ROM_DIR/marioparty3.us.z64"
OBJECTS="$ROOT/work/vita-objects"

: "${ROM_ARCHIVE_URL:?Set ROM_ARCHIVE_URL to the user's USA ROM ZIP URL}"
mkdir -p "$ROOT/work" "$ROM_DIR" "$OBJECTS"

echo "== Downloading the user's ROM archive (not adding it to Git or artifacts) =="
curl --fail --location --show-error --retry 3 --connect-timeout 20 \
  "$ROM_ARCHIVE_URL" -o "$ROM_ARCHIVE"
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
echo "USA ROM verified. It will remain only in this temporary runner workspace."

echo "== Checking out the static-recompilation source and submodules =="
git clone --depth 1 --recurse-submodules https://github.com/n64hub/mario-party-3-recomp.git "$UPSTREAM"
cd "$UPSTREAM"
git submodule update --init --recursive --depth 1

echo "== Generating the game's native C/C++ source from the ROM =="
bash tools/recompile.sh

echo "== Cross-compiling generated game code for Vita ARM =="
cd "$ROOT"
docker run --rm \
  -v "$ROOT:/workspace" \
  -w /workspace/work/native-recomp \
  gnuton/vitasdk-docker:20250520 \
  bash -lc '
    set -Eeuo pipefail
    mkdir -p /workspace/work/vita-objects
    common="-fno-strict-aliasing -Wno-unused-variable -Wno-implicit-function-declaration"
    includes="-Iinclude -Ilib/N64ModernRuntime/ultramodern/include -Ilib/N64ModernRuntime/librecomp/include -Ilib/N64ModernRuntime/N64Recomp/include -Ilib/N64ModernRuntime/libultra/include"
    count=0
    for src in RecompiledFuncs/*.c; do
      [ -f "$src" ] || continue
      arm-vita-eabi-gcc -std=gnu11 $common $includes -c "$src" -o "/workspace/work/vita-objects/$(basename "$src").o"
      count=$((count + 1))
    done
    for src in RecompiledFuncs/*.cpp; do
      [ -f "$src" ] || continue
      arm-vita-eabi-g++ -std=gnu++20 $common $includes -c "$src" -o "/workspace/work/vita-objects/$(basename "$src").o"
      count=$((count + 1))
    done
    [ "$count" -gt 0 ] || { echo "No generated source files found"; exit 1; }
    echo "VITA_GAME_CODE_COMPILE_OK: compiled $count generated source files."
  '

echo "== Native Vita recompilation milestone passed =="
echo "No ROM, generated source, object file, or VPK is uploaded as an artifact."
