#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail

if [[ $# -gt 1 ]]; then
  printf 'Usage: %s [plugin-target-directory]\n' "$0" >&2
  exit 2
fi

package_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
plugin_name="IsiXLeberQuant.isixplugin"
source="$package_dir/$plugin_name"
target_dir="${1:-$HOME/Library/Application Support/IsiX/Plugins}"

if [[ ! -d "$source" ]]; then
  printf 'Plugin bundle missing: %s\n' "$source" >&2
  exit 1
fi

/usr/bin/codesign --verify --strict "$source"
mkdir -p -- "$target_dir"
target_dir="$(cd -- "$target_dir" && pwd -P)"
target="$target_dir/$plugin_name"
if [[ "$source" == "$target" || -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then
  printf 'Invalid installation target: %s\n' "$target" >&2
  exit 1
fi

staging="$target_dir/.IsiXLeberQuant.install"
if ! mkdir -- "$staging"; then
  printf 'Could not create temporary installation directory: %s\n' "$staging" >&2
  exit 1
fi

cleanup() {
  if [[ -d "$staging/previous" && ! -e "$target" && ! -L "$target" ]]; then
    if ! mv -- "$staging/previous" "$target"; then
      printf 'Previous plugin is available at %s/previous\n' "$staging" >&2
      return 1
    fi
  fi
  rm -rf -- "$staging"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

/usr/bin/ditto "$source" "$staging/new"
/usr/bin/codesign --verify --strict "$staging/new"
if [[ -d "$target" ]]; then
  mv -- "$target" "$staging/previous"
fi
mv -- "$staging/new" "$target"

printf 'Installed: %s\n' "$target"
printf 'Start IsiX, open an image series and choose Liver IronLoad from Image Filters.\n'
