#!/usr/bin/env bash
#
# build_app_bundle.sh — assemble a distributable DaiJishow.app from the SwiftPM
# build, so the app carries its own icon, a self-contained corpus, and a real
# Info.plist (and shows a Dock icon in Finder).
#
# Layout produced under build/DaiJishow.app:
#   Contents/MacOS/DaiJishowMac       compiled executable
#   Contents/Resources/AppIcon.icns   the app icon (generated on demand)
#   Contents/Resources/daijishow.db   the bundled corpus (self-contained)
#   Contents/Info.plist              bundle metadata + icon reference
#
# Usage:
#   ./tools/build_app_bundle.sh            # debug build, DB copied in, + DMG
#   ./tools/build_app_bundle.sh --release  # release build (slower)
#   ./tools/build_app_bundle.sh --no-db    # skip bundling the ~221 MB corpus
#   ./tools/build_app_bundle.sh --symlink-db  # link the DB instead of copying
#   ./tools/build_app_bundle.sh --no-dmg   # skip the drag-to-Applications .dmg
#
# The DMG (build/DaiJishow-<version>.dmg) is the standard "drag the app into the
# Applications folder" installer: it contains the .app plus a symlink to
# /Applications, so you drag-and-drop to install.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="DaiJishow"
BINARY="DaiJishowMac"
BUNDLE_ID="org.daijishow.mac"
MIN_OS="14.0"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

# --- version (single source of truth: the git release tag) -------------
# Capture the version from the latest git tag so the About page, Info.plist,
# and the DMG filename all agree — there is no hand-maintained version string
# to drift. The About panel shows "short (build …)": e.g. 0.9ß (build rc3)
# for a release candidate, or just 0.9ß for the final v0.9ß tag.
capture_version() {
  local tag
  tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
  if [[ -z "$tag" ]]; then
    tag="0.9ß"                       # no git tags at all — sane default
  fi
  tag="${tag#v}"                    # drop the conventional leading "v"
  if [[ "$tag" == *-* ]]; then
    SHORT_VERSION="${tag%%-*}"      # marketing part,  e.g. 0.9ß
    BUILD_VERSION="${tag#*-}"       # RC/build suffix, e.g. rc3
  else
    SHORT_VERSION="$tag"
    BUILD_VERSION="$tag"            # no suffix → About shows just the short
  fi
  FULL_VERSION="$SHORT_VERSION"
  if [[ "$BUILD_VERSION" != "$SHORT_VERSION" ]]; then
    FULL_VERSION="${SHORT_VERSION}-${BUILD_VERSION}"
  fi
}
capture_version
echo "==> version: $FULL_VERSION  (About page shows \"$SHORT_VERSION (build $BUILD_VERSION)\")"

CONFIG="debug"
BUNDLE_DB=1
LINK_DB=0
MAKE_DMG=1
for arg in "$@"; do
  case "$arg" in
    --release)      CONFIG="release" ;;
    --no-db)        BUNDLE_DB=0 ;;
    --symlink-db)   BUNDLE_DB=1; LINK_DB=1 ;;
    --no-dmg)       MAKE_DMG=0 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
EXEC="$BIN_PATH/$BINARY"
[[ -f "$EXEC" ]] || { echo "executable not found: $EXEC" >&2; exit 1; }

# --- icon ---------------------------------------------------------------
ensure_icon() {
  local icns="$BUILD_DIR/AppIcon.icns"
  if [[ -f "$icns" ]]; then return 0; fi
  echo "==> generating AppIcon.icns (missing)"
  swift tools/make_icon.swift "$BUILD_DIR/AppIcon.iconset" "$icns" \
    && iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$icns"
  [[ -f "$icns" ]]
}

# --- assemble -----------------------------------------------------------
echo "==> assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$EXEC" "$APP_DIR/Contents/MacOS/$BINARY"

if ensure_icon; then
  cp "$BUILD_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
  echo "    + AppIcon.icns"
else
  echo "    ! AppIcon.icns unavailable (icon will be the generic executable)"
fi

if [[ "$BUNDLE_DB" -eq 1 ]]; then
  if [[ -f "$BUILD_DIR/daijishow.db" ]]; then
    if [[ "$LINK_DB" -eq 1 ]]; then
      ln -sf "$(pwd)/$BUILD_DIR/daijishow.db" "$APP_DIR/Contents/Resources/daijishow.db"
      echo "    + daijishow.db (symlink)"
    else
      cp "$BUILD_DIR/daijishow.db" "$APP_DIR/Contents/Resources/daijishow.db"
      echo "    + daijishow.db ($(du -h "$APP_DIR/Contents/Resources/daijishow.db" | cut -f1))"
    fi
  else
    echo "    ! build/daijishow.db missing (app will show the 'db not found' banner)"
  fi
fi

# --- Info.plist ---------------------------------------------------------
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${APP_NAME//-/_}</string>
    <key>CFBundleDisplayName</key>     <string>Dai-Jishow</string>
    <key>CFBundleExecutable</key>      <string>$BINARY</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key>         <string>$BUILD_VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>  <string>$MIN_OS</string>
    <key>LSApplicationCategoryType</key> <string>public.app-category.education</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key> <false/>
    <key>NSSupportsSuddenTermination</key> <false/>
</dict>
</plist>
PLIST
echo "    + Info.plist"

# --- code sign (ad-hoc) -------------------------------------------------
echo "==> codesign (ad-hoc)"
if codesign --force --deep --sign - "$APP_DIR" 2>/dev/null; then
  echo "    signed"
else
  echo "    (codesign unavailable or failed — app still runs locally)"
fi

# --- DMG (drag-to-Applications installer) --------------------------------
# The standard "drag the app into Applications" package: the .app plus a
# symlink to /Applications. Open the .dmg, drag Dai-Jishow onto the
# Applications icon, done.
if [[ "$MAKE_DMG" -eq 1 ]]; then
  echo "==> creating DMG (drag-to-Applications)"
  STAGE_PARENT="$(mktemp -d -t daijishow-dmg-XXXXXX)"
  DMG_DIR="$STAGE_PARENT/stage"
  mkdir -p "$DMG_DIR"
  cp -R "$APP_DIR" "$DMG_DIR/"
  ln -s /Applications "$DMG_DIR/Applications"

  # Deterministic layout: drop any stray Finder state.
  find "$DMG_DIR" -name .DS_Store -delete 2>/dev/null || true

  DMG_NAME="DaiJishow-${FULL_VERSION}.dmg"
  DMG_OUT="$BUILD_DIR/$DMG_NAME"
  rm -f "$DMG_OUT"

  if hdiutil create \
      -volname "DaiJishow" \
      -srcfolder "$DMG_DIR" \
      -ov -format UDZO \
      -imagekey zlib-level=9 \
      "$DMG_OUT" >/dev/null; then
    echo "    + $DMG_NAME ($(du -h "$DMG_OUT" | cut -f1))"
    echo "    open \"$DMG_OUT\"   # then drag Dai-Jishow onto the Applications icon"
  else
    echo "    ! DMG creation failed (hdiutil unavailable or disk full)"
  fi

  rm -rf "$STAGE_PARENT"
fi

echo "==> done: $APP_DIR"
echo "    open \"$APP_DIR\""
