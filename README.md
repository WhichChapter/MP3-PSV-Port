# Mario Party 3 — PS Vita

This repository is an emulator-based PS Vita homebrew project for launching a
personal Mario Party 3 (N64) ROM dump from a dedicated LiveArea bubble.

## Current approach

Mario Party 3 is an N64 program distributed here only as a user-supplied
`.z64` dump. It is not native PS Vita code. The build uses
[DaedalusX64-vitaGL](https://github.com/Rinnegatamante/DaedalusX64-vitaGL),
an open-source Nintendo 64 emulator for PS Vita, as its emulation engine.

The workflow builds a package with the app name **Mario Party 3** and title ID
`MP3V00001`. The emulator engine remains upstream; this repository does not
claim to be a native decompilation or a full source port of the original game.

## Build

Push to `main`, or open **Actions → Build Mario Party 3 for PS Vita → Run workflow**.

When the workflow succeeds, download the artifact named
`mario-party-3-vita-build`. It contains:

- `MarioParty3.vpk` — the Vita application package
- `DaedalusX64.zip` — the emulator data directory
- `BUILD-INFO.txt` — build details

## ROM setup

The ROM is deliberately not committed to GitHub and is not included in the
public build artifact. Download your own dump as `baserom.z64` and place it
in the emulator's ROM folder on the Vita:

`ux0:data/DaedalusX64/Roms/`

The existing helper script `scripts/download_rom.sh` downloads the supplied
personal ROM URL to the current working directory and checks the N64 big-endian
header. Keep the ROM private and do not redistribute it.

## Build limitations

A successful VPK build proves that the emulator-based Vita application
compiled. It does not prove Mario Party 3 is fully playable at full speed.
Game-specific compatibility, graphics, audio, multiplayer/controller mapping,
and performance must be tested on real Vita hardware and adjusted separately.

## Credits and licensing

DaedalusX64-vitaGL is a separate GPL-2.0-licensed project. See its upstream
repository for its source, license, build requirements, and contributor credits.
