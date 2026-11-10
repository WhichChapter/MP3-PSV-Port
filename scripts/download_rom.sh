#!/usr/bin/env bash
set -Eeuo pipefail

# Downloads the user's own Mario Party 3 ROM dump for local development/builds.
# The ROM is intentionally not stored in this repository.

ROM_URL='https://file.garden/avMHBM8xM88l1IFr/Mario%20Party%203%20(Europe)%20(En%2CFr%2CDe%2CEs).z64'
OUTPUT_PATH="${1:-baserom.z64}"

command -v curl >/dev/null 2>&1 || {
  echo "Error: curl is required." >&2
  exit 1
}

echo "Downloading Mario Party 3 ROM to: $OUTPUT_PATH"
curl --fail --location --show-error \
  --retry 3 --retry-delay 2 --connect-timeout 20 \
  --output "$OUTPUT_PATH" "$ROM_URL"

if [[ ! -s "$OUTPUT_PATH" ]]; then
  echo "Error: download is empty." >&2
  rm -f "$OUTPUT_PATH"
  exit 1
fi

# A .z64 ROM uses the big-endian Nintendo 64 magic bytes 80 37 12 40.
MAGIC="$(od -An -N4 -tx1 "$OUTPUT_PATH" | tr -d ' \n')"
if [[ "$MAGIC" != "80371240" ]]; then
  echo "Error: downloaded file does not have a valid big-endian .z64 header." >&2
  echo "The host may have returned an error page or a different file." >&2
  rm -f "$OUTPUT_PATH"
  exit 1
fi

echo "Download verified: $OUTPUT_PATH"
