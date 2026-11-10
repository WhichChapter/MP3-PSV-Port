#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM="$ROOT/work/native-recomp"
ROM_ARCHIVE="$ROOT/work/mario-party-3-us.zip"
ROM_STAGING="$ROOT/work/marioparty3.us.z64"
ROM_DIR="$UPSTREAM/roms"
ROM="$ROM_DIR/marioparty3.us.z64"

: "${ROM_ARCHIVE_URL:?ROM_ARCHIVE_URL is required}"
mkdir -p "$ROOT/work"

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
cp "$ROM_CANDIDATE" "$ROM_STAGING"
rm -rf "$ROM_ARCHIVE" "$ROOT/work/rom-extract"
ACTUAL_SHA="$(sha1sum "$ROM_STAGING" | awk '{print $1}')"
EXPECTED_SHA="6beb80ff822b96bcf85dcdb512e8b2b7969d8259"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "ERROR: ROM SHA-1 mismatch. Expected USA Mario Party 3; got $ACTUAL_SHA" >&2
  exit 1
fi
echo "USA ROM verified. It remains only in this temporary runner workspace."

echo "== Cloning static-recompilation source and submodules =="
if [[ -e "$UPSTREAM" ]]; then
  echo "ERROR: upstream checkout path already exists; refusing to overwrite it." >&2
  exit 1
fi
git clone --depth 1 --recurse-submodules https://github.com/n64hub/mario-party-3-recomp.git "$UPSTREAM"
cd "$UPSTREAM"
git submodule update --init --recursive --depth 1

mkdir -p "$ROM_DIR"
mv "$ROM_STAGING" "$ROM"

echo "== Adding a 32-bit ARM implementation of MIPS 64x64 multiply =="
python3 - "$UPSTREAM/lib/N64ModernRuntime/N64Recomp/include/recomp.h" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
needle = '''#elif defined(_MSC_VER)

#include <intrin.h>'''
replacement = '''#elif defined(__arm__) || defined(__aarch64__)

// ARM32 VitaSDK does not provide a native __int128 type. Implement the
// MIPS HI/LO 64x64 multiply using four 32-bit partial products instead.
static inline void DMULTU(uint64_t a, uint64_t b, uint64_t* lo64, uint64_t* hi64) {
    uint64_t t = (uint64_t)(uint32_t)a * (uint32_t)b;
    uint64_t w0 = (uint32_t)t;
    uint64_t carry = t >> 32;

    t = (a >> 32) * (uint32_t)b + carry;
    uint64_t w1 = (uint32_t)t;
    uint64_t w2 = t >> 32;

    t = (uint64_t)(uint32_t)a * (b >> 32) + w1;
    *hi64 = (a >> 32) * (b >> 32) + w2 + (t >> 32);
    *lo64 = (t << 32) | w0;
}

static inline void DMULT(int64_t a, int64_t b, int64_t* lo64, int64_t* hi64) {
    uint64_t lo, hi;
    DMULTU((uint64_t)a, (uint64_t)b, &lo, &hi);
    hi -= (a < 0) ? (uint64_t)b : 0;
    hi -= (b < 0) ? (uint64_t)a : 0;
    *lo64 = (int64_t)lo;
    *hi64 = (int64_t)hi;
}

#elif defined(_MSC_VER)

#include <intrin.h>'''
if needle not in source:
    raise SystemExit("ERROR: expected 128-bit multiply section was not found; refusing to patch an unknown upstream header.")
path.write_text(source.replace(needle, replacement, 1))
print("ARM32 DMULT/DMULTU fallback installed.")
PY

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
