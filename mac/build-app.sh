#!/bin/bash
# Builds dist/VOID.app and dist/VOID-macOS.dmg. Needs a Mac (the release workflow runs it on one).
#   bash mac/build-app.sh 1.3.0
set -euo pipefail
VERSION=${1:-dev}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/dist"
STAGE="$OUT/dmg"
APP="$STAGE/VOID.app"

rm -rf "$OUT"; mkdir -p "$STAGE"

# a real applet (not a shell-script bundle), so Finder and Gatekeeper treat it like a normal app
osacompile -o "$APP" "$ROOT/mac/app/launcher.applescript"
cp "$ROOT/mac/void.sh" "$APP/Contents/Resources/void.sh"
chmod +x "$APP/Contents/Resources/void.sh"

# our icon instead of the default script icon
cp "$ROOT/mac/app/AppIcon.icns" "$APP/Contents/Resources/applet.icns"
rm -f "$APP/Contents/Resources/Assets.car"
PLIST="$APP/Contents/Info.plist"
plist_set() { /usr/libexec/PlistBuddy -c "Delete :$1" "$PLIST" 2>/dev/null || true; /usr/libexec/PlistBuddy -c "Add :$1 $2 $3" "$PLIST"; }
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST" 2>/dev/null || true
plist_set CFBundleIconFile string applet
plist_set CFBundleName string VOID
plist_set CFBundleDisplayName string VOID
plist_set CFBundleIdentifier string io.github.kelcum.void
plist_set CFBundleShortVersionString string "$VERSION"
plist_set CFBundleVersion string "$VERSION"
plist_set NSAppleEventsUsageDescription string "VOID opens Terminal to run its menu."
plist_set LSApplicationCategoryType string public.app-category.utilities

# ad-hoc signature: not notarized (that needs a paid Apple developer account), but keeps the bundle intact
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

# the classic "drag VOID into Applications" window
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "VOID" -srcfolder "$STAGE" -ov -format UDZO "$OUT/VOID-macOS.dmg"
rm -rf "$STAGE"
echo "built $OUT/VOID-macOS.dmg"
