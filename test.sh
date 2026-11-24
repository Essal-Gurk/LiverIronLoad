#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/ModuleCache
xcrun swiftc -O -module-cache-path "$PWD/.build/ModuleCache" \
    -o .build/CoreChecks Sources/Localization.swift Sources/Quantification.swift Sources/DICOMHeader.swift Sources/EchoGrouping.swift Sources/ROIMeasurement.swift Tests/EchoGroupingChecks.swift Tests/CoreChecks.swift
.build/CoreChecks
