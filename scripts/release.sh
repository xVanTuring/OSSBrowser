#!/usr/bin/env bash
# scripts/release.sh
#
# Bump version → build → Developer-ID-sign → notarize → staple →
# zip + DMG → publish a GitHub release.
#
# No Sparkle / auto-update: users download the notarized DMG from the
# GitHub Releases page.
#
# Usage:
#   ./scripts/release.sh <version> [--notes-file <path>] [--dry-run]
#
# Examples:
#   ./scripts/release.sh 1.0.0
#   ./scripts/release.sh 1.0.0 --notes-file NOTES.md
#   ./scripts/release.sh 1.0.0 --dry-run
#
# One-time machine setup (already done — shared with the Perch/Noticky account):
#   - "Developer ID Application" cert for TEAM_ID in the login keychain
#   - notarytool credential profile:
#       xcrun notarytool store-credentials <profile> --apple-id <id> \
#             --team-id <TEAM_ID> --password <app-specific-password>
#     (this script defaults NOTARY_PROFILE to the shared 'noticky-notary')
#   - gh CLI authenticated: gh auth login

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ── Project constants ───────────────────────────────────────────────
TEAM_ID="T8F5T6HKG8"
NOTARY_PROFILE="${NOTARY_PROFILE:-noticky-notary}"   # override via env if needed
SCHEME="OSSBrowser"
PROJECT="OSSBrowser.xcodeproj"
PRODUCT="OSSBrowser"
BUNDLE_ID="tech.xvanturing.OSSBrowser"
GH_REPO="xVanTuring/OSSBrowser"
PBX="${PROJECT}/project.pbxproj"
EXPORT_OPTIONS="scripts/ExportOptions.plist"
BUILD_DIR=".build/release"

# ── Args ────────────────────────────────────────────────────────────
usage() {
    cat <<EOF >&2
Usage: $(basename "$0") <version> [--notes-file <path>] [--dry-run]

  <version>          MARKETING_VERSION, e.g. 1.0.0
  --notes-file PATH  File whose contents become the GitHub release body
                     (default: gh --generate-notes from commit messages).
  --dry-run          Bump version + verify a Debug build + commit locally,
                     but skip push / archive / notarize / release.
EOF
    exit 1
}

VERSION=""
NOTES_FILE=""
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --notes-file)  NOTES_FILE="${2:?--notes-file needs a path}"; shift 2 ;;
        --dry-run)     DRY_RUN=true; shift ;;
        -h|--help)     usage ;;
        -*)            echo "Unknown flag: $1" >&2; usage ;;
        *)
            if [[ -z "$VERSION" ]]; then VERSION="$1"; shift
            else echo "Unexpected positional: $1" >&2; usage; fi
            ;;
    esac
done

[[ -z "$VERSION" ]] && usage
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || { echo "ERROR: version must be X.Y.Z (got '$VERSION')" >&2; exit 1; }

TAG="v${VERSION}"
TITLE="v${VERSION}"
DIST_DIR="dist/${TAG}"
ZIP_ASSET="${PRODUCT}-${VERSION}.zip"
DMG_ASSET="${PRODUCT}-${VERSION}.dmg"
ZIP="${DIST_DIR}/${ZIP_ASSET}"
DMG="${DIST_DIR}/${DMG_ASSET}"
APP="${DIST_DIR}/${PRODUCT}.app"
ARCHIVE="${BUILD_DIR}/${PRODUCT}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"

echo "==> Version $VERSION  •  Tag $TAG  •  Assets $ZIP_ASSET + $DMG_ASSET"

# ── Pre-flight ──────────────────────────────────────────────────────
echo "==> Pre-flight checks"

[[ -f "$PBX" ]]            || { echo "ERROR: run from repo root (no $PBX)" >&2; exit 1; }
[[ -f "$EXPORT_OPTIONS" ]] || { echo "ERROR: $EXPORT_OPTIONS missing" >&2; exit 1; }

command -v gh >/dev/null        || { echo "ERROR: gh CLI not on PATH (brew install gh)" >&2; exit 1; }
command -v xcodebuild >/dev/null|| { echo "ERROR: xcodebuild not on PATH (install Xcode)" >&2; exit 1; }

gh auth status >/dev/null 2>&1 \
    || { echo "ERROR: gh not authenticated. Run 'gh auth login'." >&2; exit 1; }

security find-identity -v -p codesigning \
    | grep -q "Developer ID Application.*${TEAM_ID}" \
    || { echo "ERROR: no 'Developer ID Application' cert for team ${TEAM_ID} in keychain." >&2
         echo "       Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application." >&2
         exit 1; }

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || { echo "ERROR: notarytool profile '${NOTARY_PROFILE}' is missing or invalid." >&2
         echo "       Set up once with: xcrun notarytool store-credentials ${NOTARY_PROFILE} ..." >&2
         echo "       (or override the profile name with: NOTARY_PROFILE=<name> $0 ...)" >&2
         exit 1; }

[[ -z "$(git status --porcelain)" ]] \
    || { echo "ERROR: working tree dirty. Commit or stash first." >&2
         git status --short >&2; exit 1; }

if git rev-parse --verify "refs/tags/${TAG}" >/dev/null 2>&1; then
    echo "ERROR: tag ${TAG} already exists locally." >&2; exit 1
fi
if git ls-remote --tags origin "${TAG}" 2>/dev/null | grep -q "refs/tags/${TAG}$"; then
    echo "ERROR: tag ${TAG} already exists on origin." >&2; exit 1
fi

if [[ -n "$NOTES_FILE" ]]; then
    [[ -f "$NOTES_FILE" ]] || { echo "ERROR: --notes-file not found: $NOTES_FILE" >&2; exit 1; }
fi

# ── Bump version in project.pbxproj ─────────────────────────────────
current_short=$(grep -m1 -E 'MARKETING_VERSION = ' "$PBX" | sed -E 's/.*= ([^;]+);.*/\1/')
current_build=$(grep -m1 -E 'CURRENT_PROJECT_VERSION = ' "$PBX" | sed -E 's/.*= ([0-9]+);.*/\1/')
next_build=$((current_build + 1))

echo "==> Version bump  ${current_short} (build ${current_build}) → ${VERSION} (build ${next_build})"

# BSD sed (macOS): -i needs a backup suffix; edit every config's copy.
sed -i.bak -E "s/(MARKETING_VERSION = )[^;]+;/\\1${VERSION};/g" "$PBX"
sed -i.bak -E "s/(CURRENT_PROJECT_VERSION = )[0-9]+;/\\1${next_build};/g" "$PBX"
rm -f "${PBX}.bak"

echo "==> Verifying Debug build before commit"
if ! xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -derivedDataPath "$BUILD_DIR" \
        -destination 'generic/platform=macOS' \
        build \
        2>&1 | grep -E "(error:|BUILD )" | tail -20; then
    echo "ERROR: Debug build failed. Reverting version bump." >&2
    git checkout -- "$PBX"
    exit 1
fi

echo "==> Committing version bump"
git add "$PBX"
git commit -m "release: bump to ${VERSION} (build ${next_build})"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "==> [dry-run] stopping before push/archive/release."
    echo "    To undo:  git reset --hard HEAD~1"
    exit 0
fi

# ── Push main ───────────────────────────────────────────────────────
echo "==> Pushing main"
git push origin main

# ── Clean output dirs ───────────────────────────────────────────────
echo "==> Cleaning ${DIST_DIR} and archive/export"
rm -rf "${DIST_DIR}" "${ARCHIVE}" "${EXPORT_DIR}"
mkdir -p "${DIST_DIR}"

# ── Archive ─────────────────────────────────────────────────────────
echo "==> Archiving Release config (this can take a minute)"
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    -quiet \
    archive

[[ -d "$ARCHIVE" ]] || { echo "ERROR: archive not produced at $ARCHIVE" >&2; exit 1; }

# ── Export with Developer ID re-sign ────────────────────────────────
echo "==> Exporting + re-signing as Developer ID (uses ${EXPORT_OPTIONS})"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    | tail -20

BUILT_APP="${EXPORT_DIR}/${PRODUCT}.app"
[[ -d "$BUILT_APP" ]] || { echo "ERROR: exported .app missing at $BUILT_APP" >&2; exit 1; }

echo "==> Copying built app to ${DIST_DIR}/"
ditto "$BUILT_APP" "$APP"

echo "==> Verifying codesign"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --verbose=2 "$APP" 2>&1 | grep -E "TeamIdentifier|Authority|Format" || true

# ── Zip + notarize the app ──────────────────────────────────────────
# Apple-required form for notary submission AND downloads. Without
# --sequesterRsrc, Finder's Archive Utility leaves AppleDouble `._File`
# siblings that break the signature seal on manual zip downloads.
echo "==> Zipping for notarization"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Submitting .zip to Apple notarization (--wait blocks until verdict)"
NOTARY_LOG="${DIST_DIR}/notary-app.log"
if ! xcrun notarytool submit "$ZIP" \
       --keychain-profile "$NOTARY_PROFILE" \
       --wait 2>&1 | tee "$NOTARY_LOG"; then
    echo "ERROR: notarization failed. See $NOTARY_LOG" >&2
    echo "       Detailed log: xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE" >&2
    exit 1
fi

echo "==> Stapling notarization ticket onto .app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Gatekeeper assessment after stapling:"
spctl -a -t exec -vv "$APP" 2>&1 || true

# Re-zip: the pre-notary zip does not carry the staple ticket.
echo "==> Re-zipping stapled app"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# ── DMG (primary download asset) ────────────────────────────────────
echo "==> Creating DMG"
DMG_STAGE="${DIST_DIR}/.dmg-stage"
rm -rf "$DMG_STAGE"; mkdir -p "$DMG_STAGE"
ditto "$APP" "${DMG_STAGE}/${PRODUCT}.app"
ln -s /Applications "${DMG_STAGE}/Applications"
hdiutil create \
    -volname "${PRODUCT} ${VERSION}" \
    -srcfolder "$DMG_STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null
rm -rf "$DMG_STAGE"

echo "==> Submitting .dmg to Apple notarization"
NOTARY_LOG_DMG="${DIST_DIR}/notary-dmg.log"
if ! xcrun notarytool submit "$DMG" \
       --keychain-profile "$NOTARY_PROFILE" \
       --wait 2>&1 | tee "$NOTARY_LOG_DMG"; then
    echo "ERROR: DMG notarization failed. See $NOTARY_LOG_DMG" >&2
    exit 1
fi

echo "==> Stapling DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# ── Tag + GitHub release ────────────────────────────────────────────
echo "==> Tagging ${TAG}"
git tag -a "$TAG" -m "$TAG"
git push origin "$TAG"

echo "==> Creating GitHub release"
if [[ -n "$NOTES_FILE" ]]; then
    gh release create "$TAG" --repo "$GH_REPO" \
        --title "$TITLE" \
        --notes-file "$NOTES_FILE" \
        "$DMG" "$ZIP"
else
    gh release create "$TAG" --repo "$GH_REPO" \
        --title "$TITLE" \
        --generate-notes \
        "$DMG" "$ZIP"
fi

echo
echo "================================================================"
echo "Release ${TAG} done"
echo "  .app : ${APP}"
echo "  .zip : ${ZIP} ($(du -h "$ZIP" | cut -f1))"
echo "  .dmg : ${DMG} ($(du -h "$DMG" | cut -f1))"
echo "  URL  : https://github.com/${GH_REPO}/releases/tag/${TAG}"
echo "================================================================"
echo
echo "Smoke test before announcing:"
echo "  1. open ${DMG}"
echo "  2. Drag ${PRODUCT}.app to /Applications"
echo "  3. First launch: right-click → Open (clears the quarantine prompt)"
