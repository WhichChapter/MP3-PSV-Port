#!/usr/bin/env python3
"""Patch DaedalusX64 so the Mario Party 3 bubble boots the user's ROM directly."""
from pathlib import Path
import sys

source = Path(sys.argv[1])
text = source.read_text(encoding="utf-8")
old = '''\t// Check if Daedalus X64 has been launched with a custom bubble
\tsceAppMgrGetAppParam(boot_params);
\tif (strstr(boot_params,"psgm:play") && strstr(boot_params, "&param=")) {
\t\tgSkipCompatListUpdate = true;
\t\tgStandaloneMode = false;
\t\trom = strstr(boot_params, "&param=") + 7;
\t} else {
\t\tloadCustomRomPath();
\t\tloadNetRomPath();
\t}'''
new = '''\t// Mario Party 3 dedicated boot: start the user's European ROM directly.
\t// Keep the normal Daedalus selector available as a fallback if the ROM is
\t// not present, so a missing file does not make the application unusable.
\tconst char *mp3_rom = "ux0:data/DaedalusX64/Roms/Mario Party 3 (Europe) (En,Fr,De,Es).z64";
\tSceIoStat mp3_rom_stat;
\tif (sceIoGetstat(mp3_rom, &mp3_rom_stat) >= 0) {
\t\tgSkipCompatListUpdate = true;
\t\tgStandaloneMode = false;
\t\trom = (char *)mp3_rom;
\t} else {
\t\tsceAppMgrGetAppParam(boot_params);
\t\tif (strstr(boot_params,"psgm:play") && strstr(boot_params, "&param=")) {
\t\t\tgSkipCompatListUpdate = true;
\t\t\tgStandaloneMode = false;
\t\t\trom = strstr(boot_params, "&param=") + 7;
\t\t} else {
\t\t\tloadCustomRomPath();
\t\t\tloadNetRomPath();
\t\t}
\t}'''
if old not in text:
    raise SystemExit("ERROR: upstream ROM boot block changed; refusing to patch the wrong source.")
source.write_text(text.replace(old, new, 1), encoding="utf-8")
print(f"Patched dedicated Mario Party 3 auto-boot in {source}")
