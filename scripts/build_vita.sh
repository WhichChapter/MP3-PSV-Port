#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== Preparing Vita SDK build dependencies =="
apt-get update
apt-get install -y --no-install-recommends pkg-config libc6-dev-i386 zip git cmake make curl
export DEBIAN_FRONTEND=noninteractive

# Build the open-source Nintendo 64 emulation engine for Vita.
# The emulator's own Vita entry point is C++ (Source/SysVita/main.cpp);
# this project customizes its package identity rather than adding a fake C main.
git clone --depth 1 https://github.com/Rinnegatamante/DaedalusX64-vitaGL.git daedalus

cd daedalus

echo "== Installing Vita headers =="
git clone --depth 1 https://github.com/vitasdk/vita-headers.git
cp -r vita-headers/include/* "$VITASDK/arm-vita-eabi/include/"

echo "== Building math-neon =="
git clone --depth 1 https://github.com/Rinnegatamante/math-neon.git
make -C math-neon -j"$(nproc)"
make -C math-neon -j"$(nproc)" install

echo "== Building vitaShaRK =="
git clone --depth 1 https://github.com/Rinnegatamante/vitaShaRK.git
make -C vitaShaRK -j"$(nproc)"
make -C vitaShaRK -j"$(nproc)" install

echo "== Building vitaGL =="
git clone --depth 1 https://github.com/Rinnegatamante/vitaGL.git
sed -i 's/float fog_dist = coords.z \/ coords.w;/float fog_dist = coords.z;/' vitaGL/source/shaders/ffp_f.h
sed -i 's/#define FFP_SHADER_CACHE_MAGIC /#define FFP_SHADER_CACHE_MAGIC 99/' vitaGL/source/shared.h
VITAGL_FLAGS="READBACKS_SPEEDHACK=1 HAVE_GLSL_TEXTURE_SIZE=1 NO_DEBUG=1 HAVE_UNFLIPPED_FBOS=1 NO_TEX_COMBINER=1 HAVE_CUSTOM_HEAP=1 SINGLE_THREADED_GC=1 HAVE_FFP_SHADER_SUPPORT=1 DEPTH_STENCIL_HACK=1 CIRCULAR_POOL_SPEEDHACK=1 ENABLE_LEGACY_PIPELINE=1 NO_SPLASHSCREEN=1"
# shellcheck disable=SC2086
make -C vitaGL -j"$(nproc)" $VITAGL_FLAGS
# shellcheck disable=SC2086
make -C vitaGL -j"$(nproc)" $VITAGL_FLAGS install

echo "== Building ImGui Vita backend =="
git clone --depth 1 https://github.com/Rinnegatamante/imgui-vita.git
make -C imgui-vita -j"$(nproc)"
make -C imgui-vita -j"$(nproc)" install

echo "== Customizing dedicated LiveArea bubble =="
# Keep the upstream emulator code intact; change only the installed app identity.
sed -i 's/set(VITA_APP_NAME .*)/set(VITA_APP_NAME "Mario Party 3")/' Source/CMakeLists.txt
sed -i 's/set(VITA_TITLEID  "DEDALOX64")/set(VITA_TITLEID  "MP3V00001")/' Source/CMakeLists.txt

echo "== Patching direct Mario Party 3 boot =="
python3 "$ROOT/scripts/patch_game.py" Source/SysVita/main.cpp

git config --global --add safe.directory "$PWD"
mkdir -p daedbuild
cd daedbuild
cmake ../Source
make -j"$(nproc)"

cd "$ROOT/daedalus/Data"
zip -9 -r "$ROOT/artifacts_DaedalusX64.zip" DaedalusX64

mkdir -p "$ROOT/artifacts"
cp "$ROOT/daedalus/daedbuild/DaedalusX64.vpk" "$ROOT/artifacts/MarioParty3.vpk"
cp "$ROOT/artifacts_DaedalusX64.zip" "$ROOT/artifacts/DaedalusX64.zip"
{
  echo "Project: MP3-PSV-Port"
  echo "Package: Mario Party 3"
  echo "Title ID: MP3V00001"
  echo "Engine: DaedalusX64-vitaGL (upstream Vita N64 emulator)"
  echo "ROM: not bundled; install your own baserom.z64 separately"
  echo "Note: this is an emulator-based dedicated bubble, not a native decompilation."
} > "$ROOT/artifacts/BUILD-INFO.txt"

echo "== Build outputs =="
ls -lh "$ROOT/artifacts"
