#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p /workspace/work/vita-objects
common=(-fno-strict-aliasing -Wno-unused-variable -Wno-implicit-function-declaration)
includes=(
  -Iinclude
  -Ilib/N64ModernRuntime/ultramodern/include
  -Ilib/N64ModernRuntime/librecomp/include
  -Ilib/N64ModernRuntime/N64Recomp/include
  -Ilib/N64ModernRuntime/libultra/include
)
count=0

for src in RecompiledFuncs/*.c; do
  [[ -f "$src" ]] || continue
  out="/workspace/work/vita-objects/$(basename "$src").o"
  arm-vita-eabi-gcc -std=gnu11 "${common[@]}" "${includes[@]}" -c "$src" -o "$out"
  count=$((count + 1))
done

for src in RecompiledFuncs/*.cpp; do
  [[ -f "$src" ]] || continue
  out="/workspace/work/vita-objects/$(basename "$src").o"
  arm-vita-eabi-g++ -std=gnu++20 "${common[@]}" "${includes[@]}" -c "$src" -o "$out"
  count=$((count + 1))
done

[[ "$count" -gt 0 ]] || { echo "No generated source files found"; exit 1; }
echo "VITA_GAME_CODE_COMPILE_OK: compiled $count generated source files."
