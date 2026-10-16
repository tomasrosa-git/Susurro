#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh
target="$HOME/Applications/Susurro.app"
pkill -x Susurro || true
mkdir -p "$HOME/Applications"
rm -rf "$target"
ditto build/Susurro.app "$target"
open "$target"
echo "Installed $target"
