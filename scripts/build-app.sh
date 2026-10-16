#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
app=build/Susurro.app
rm -rf $app
mkdir -p $app/Contents/MacOS $app/Contents/Resources
cp .build/release/Susurro $app/Contents/MacOS/
cp Resources/Info.plist $app/Contents/
cp Resources/AppIcon.icns $app/Contents/Resources/

# macOS ties Accessibility/Microphone grants to the code signature. Ad-hoc signatures change on every
# build, so grants reset; a stable self-signed identity (see README) keeps them across rebuilds.
# Self-signed certificates show up as untrusted, hence no -v when looking for it.
default=-
if security find-identity -p codesigning | grep -q '"Susurro Dev"'; then default="Susurro Dev"; fi
identity=${SUSURRO_SIGN_IDENTITY:-$default}
codesign --force --sign "$identity" $app
echo "Built $app (signed with: $identity)"
