#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

# Command Line Tools ship swift-testing's macro plugin but don't put it on the default search path.
plugins=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if [[ -d $plugins ]]; then
  swift test -Xswiftc -plugin-path -Xswiftc $plugins "$@"
else
  swift test "$@"
fi
