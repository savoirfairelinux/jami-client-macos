#!/bin/bash

echo ""
cd build-local
echo "cloning certificates"
git clone $CERTIFICATES_REPOSITORY
echo "prepare keychain"
security create-keychain -p $KEYCHAIN_PASSWORD $KEYCHAIN_NAME  > /dev/null 2>&1
security unlock-keychain -p $KEYCHAIN_PASSWORD $KEYCHAIN_NAME  > /dev/null 2>&1
security list-keychains -s $KEYCHAIN_NAME  > /dev/null 2>&1
security set-key-partition-list -S apple-tool:,apple:,productbuild: -s -k $KEYCHAIN_PASSWORD $KEYCHAIN_NAME  > /dev/null 2>&1
echo "import certificates"
security import certificates/certificates/distribution/Certificates.p12 -k $KEYCHAIN_PATH -P $CERTIFICATES_PASSWORD -T /usr/bin/codesign -T /usr/bin/productbuild
DELIVER_PASSWORD=$APPLE_PASSWORD fastlane sigh --app_identifier $BUNDLE_ID --username $APPLE_ACCOUNT --readonly true --platform macos --team_id $TEAM_ID
security set-key-partition-list -S apple-tool:,apple:,productbuild: -s -k $KEYCHAIN_PASSWORD $KEYCHAIN_NAME > /dev/null 2>&1
echo "start signing"
macdeployqt ./Jami.app -codesign="${APP_CERTIFICATE}"
codesign --force --sign "${APP_CERTIFICATE}" --entitlements ../data/Jami.entitlements Jami.app
codesign --verify Jami.app
echo "create .pkg"
productbuild --component Jami.app/ /Applications --sign "${INSTALLER_CERTIFICATE}" --product Jami.app/Contents/Info.plist Jami.pkg
/Applications/Xcode.app/Contents/Applications/Application\ Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Support/altool  --validate-app  --type osx -f Jami.pkg -u $APPLE_ACCOUNT --password $APPLE_PASSWORD
echo "start deploying"
/Applications/Xcode.app/Contents/Applications/Application\ Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Support/altool  --upload-app  --type osx -f Jami.pkg -u $APPLE_ACCOUNT --password $APPLE_PASSWORD
