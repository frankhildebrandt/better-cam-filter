#!/bin/bash
set -euo pipefail

: "${RELEASE_TAG:?}" "${RELEASE_VERSION:?}" "${RELEASE_BUILD:?}"
: "${NOTARY_KEY_ID:?}" "${NOTARY_ISSUER_ID:?}" "${RUNNER_TEMP:?}"
signing_root="$RUNNER_TEMP/bettercam-signing"
archive_path="$PWD/build/release/BetterCam.xcarchive"
app="$archive_path/Products/Applications/BetterCam.app"
extension="$app/Contents/Library/SystemExtensions/de.bettercam.camera.systemextension"
assets="$PWD/build/release-assets"
mkdir -p "$assets"

xcodegen generate
xcodebuild -project BetterCam.xcodeproj -scheme BetterCam -configuration Release \
  -archivePath "$archive_path" -derivedDataPath build/release-derived \
  MARKETING_VERSION="$RELEASE_VERSION" CURRENT_PROJECT_VERSION="$RELEASE_BUILD" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO archive

codesign --verify --all-architectures --deep --strict "$app"
codesign --verify --all-architectures --strict "$extension"
lipo -verify_arch arm64 x86_64 "$app/Contents/MacOS/BetterCam"
lipo -verify_arch arm64 x86_64 "$extension/Contents/MacOS/de.bettercam.camera"

submission="$PWD/build/release/submission.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$submission"
notary_exit=0
xcrun notarytool submit "$submission" --key "$signing_root/notary.p8" \
  --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" \
  --wait --timeout 45m --output-format json > build/release/notarization.json || notary_exit=$?
python3 - <<'PY'
import json
from pathlib import Path
result = json.loads(Path('build/release/notarization.json').read_text())
print('Notarization:', result.get('id'), result.get('status'))
if result.get('status') != 'Accepted':
    raise SystemExit('Apple has not accepted this build; no release assets will be published')
PY
if ((notary_exit != 0)); then
  exit "$notary_exit"
fi

xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --all-architectures --deep --strict "$app"
codesign --verify --all-architectures --strict -R=notarized "$extension"
spctl --assess --type execute --verbose=4 "$app"

# Package after stapling so the downloadable app also works with its offline ticket.
ditto -c -k --sequesterRsrc --keepParent "$app" "$assets/BetterCam-$RELEASE_TAG-macos-universal.zip"
cd "$assets"
shasum -a 256 ./*.zip > SHA256SUMS.txt
