#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
scripts/build-app.sh

staging=build/dmg
rm -rf $staging
mkdir -p $staging
ditto build/Susurro.app $staging/Susurro.app
ln -s /Applications $staging/Applications

dmg=build/Susurro-$version.dmg
rm -f $dmg
hdiutil create -quiet -volname "Susurro $version" -srcfolder $staging -format UDZO $dmg
rm -rf $staging
echo "Created $dmg"
