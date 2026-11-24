#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
sdk_root="$repo_root/.build/sdk"
sdk_zip="$sdk_root/IsiXPluginKit-SDK-6.0.8.zip"
sdk_checksum="fa22e5cf21890e9e1dc75e7de676e563794b117b5f6d852e24f4bd494c1c6d32"
mkdir -p "$sdk_root"
if [[ ! -f "$sdk_zip" ]]; then
  temporary="$(mktemp "$sdk_root/download.XXXXXX")"
  trap 'rm -f -- "$temporary"' EXIT
  /usr/bin/curl --fail --location --silent --show-error --retry 2 \
    'https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS/releases/download/v6.0.8/IsiXPluginKit-SDK-6.0.8.zip' \
    -o "$temporary"
  printf '%s  %s\n' "$sdk_checksum" "$temporary" | /usr/bin/shasum -a 256 -c - >/dev/null
  mv -- "$temporary" "$sdk_zip"
fi
printf '%s  %s\n' "$sdk_checksum" "$sdk_zip" | /usr/bin/shasum -a 256 -c - >/dev/null
printf '%s\n' "$sdk_zip"
