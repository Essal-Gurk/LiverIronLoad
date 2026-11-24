#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
/usr/bin/codesign --verify --strict .build/IsiXLeberQuant.isixplugin
python3 scripts/package.py
