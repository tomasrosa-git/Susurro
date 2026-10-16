#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
app=build/Susurro.app
rm -rf $app
mkdir -p $app/Contents/MacOS
cp .build/release/Susurro $app/Contents/MacOS/
cp Resources/Info.plist $app/Contents/

# macOS ties Accessibility/Microphone grants to the code signature. Ad-hoc signatures change on every
# build, so grants reset; a stable self-signed identity (see README) keeps them across rebuilds.
identity=${SUSURRO_SIGN_IDENTITY:--}
codesign --force --sign "$identity" $app
echo "Built $app (signed with: $identity)"
