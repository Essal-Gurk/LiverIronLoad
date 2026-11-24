#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")"
sdk="${1:-${LIVER_IRONLOAD_SDK:-$HOME/Downloads/IsiXPluginKit-SDK-6.0.8.zip}}"
sdk_extract=""
mkdir -p .build/ModuleCache
if [[ -d "$sdk/IsiXPluginKit.framework" ]]; then
    sdk_dir="$(cd "$sdk" && pwd)"
elif [[ -f "$sdk" ]]; then
    sdk_extract="$(mktemp -d "$PWD/.build/sdk.XXXXXX")"
    trap 'rm -rf -- "$sdk_extract"' EXIT
    ditto -x -k "$sdk" "$sdk_extract"
    framework="$(find -L "$sdk_extract" -name IsiXPluginKit.framework -type d -print -quit)"
    if [[ -z "$framework" ]]; then
        echo "IsiXPluginKit.framework is missing from the SDK archive." >&2
        exit 1
    fi
    sdk_dir="$(dirname "$framework")"
else
    echo "Provide an IsiXPluginKit SDK 6.0.8 directory or ZIP (Dev Kit 1.0.0 / API 1)." >&2
    exit 1
fi
/usr/bin/ruby verify-sdk.rb "$sdk_dir"
bundle="$PWD/.build/IsiXLeberQuant.isixplugin"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$sdk_dir/SDK.json" "$bundle/Contents/Resources/SDK.json"
cp Resources/Translations.tsv "$bundle/Contents/Resources/"
cp LICENSE THIRD_PARTY_NOTICES.md ACKNOWLEDGEMENTS.md REFERENCES.md "$bundle/Contents/Resources/"
/usr/bin/ditto LICENSES "$bundle/Contents/Resources/LICENSES"
/usr/bin/ditto Docs "$bundle/Contents/Resources/Docs"
cp Docs/EU_MEDICAL_USE.md "$bundle/Contents/Resources/"
cp Info.plist "$bundle/Contents/"
compiler_options=()
if [[ "${ISIX_LEBERQUANT_NESTED_SANDBOX_UNAVAILABLE:-0}" == "1" ]]; then
    # The compiler's macro subprocess is already confined by the outer workspace sandbox.
    compiler_options+=(-Xfrontend -disable-sandbox)
fi
xcrun swiftc "${compiler_options[@]}" -module-name IsiXLeberQuant -parse-as-library -O \
    -target arm64-apple-macos15.0 -F "$sdk_dir" \
    -module-cache-path "$PWD/.build/ModuleCache" \
    -framework IsiXPluginKit -framework AppKit -framework SwiftUI \
    -Xlinker -bundle -o "$bundle/Contents/MacOS/IsiXLeberQuant" Sources/*.swift
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
echo "$bundle"
