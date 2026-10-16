#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
swift scripts/make-icon.swift "$work/AppIcon.iconset"
iconutil -c icns "$work/AppIcon.iconset" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
