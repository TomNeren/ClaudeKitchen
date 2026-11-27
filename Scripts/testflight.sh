#!/bin/zsh
# testflight.sh: builds a ClaudeKitchen revision (default origin/main) as an App Store Connect export
# and optionally uploads it to TestFlight with the asc CLI. Runs on Tom's Mac, never in CI (public repo).
#
# Usage:
#   Scripts/testflight.sh                              build and export only (dry run)
#   Scripts/testflight.sh --upload                     also upload, assign to no group
#   Scripts/testflight.sh --upload --group "Name"      assign to a manual TestFlight group after processing
#                                                      (internal groups with access to all builds get it anyway)
#
# Environment:
#   CLAUDEKITCHEN_REPO        checkout to build from (default: the repo of this script)
#   CLAUDEKITCHEN_REF         revision (default: origin/main)
#   CLAUDEKITCHEN_BUILD_ROOT  work tree and logs (default: /Volumes/Work/Developer-Daten/$USER/sitzungs-builds
#                             if /Volumes/Work exists, else ~/Library/Caches); never the repo itself
#   APPLE_TEAM_ID             signing team (default: DEVELOPMENT_TEAM from App/Config/Local.xcconfig)
#   ASC_APP_ID                App Store Connect app ID (default: looked up by bundle ID)
#   ASC_PROFILE               asc auth profile (default: asc's default profile)
#
# Signing uses the account signed in to Xcode (automatic signing, -allowProvisioningUpdates). The App Store
# Connect key is used by asc only: passing an App Manager key to xcodebuild fails with a cloud signing error.
# No key, issuer ID or team ID belongs in the repo.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO="${CLAUDEKITCHEN_REPO:-${SCRIPT_DIR:h}}"
REF="${CLAUDEKITCHEN_REF:-origin/main}"
BUNDLE_ID="com.tomren.claudekitchen"
if [[ -n "${CLAUDEKITCHEN_BUILD_ROOT:-}" ]]; then
  ROOT="$CLAUDEKITCHEN_BUILD_ROOT"
elif [[ -d /Volumes/Work ]]; then
  ROOT="/Volumes/Work/Developer-Daten/$USER/sitzungs-builds/claudekitchen-testflight"
else
  ROOT="$HOME/Library/Caches/claudekitchen-testflight"
fi
WT="$ROOT/worktree"
LOG_DIR="$ROOT/logs"
LAST_FILE="$ROOT/last-uploaded-commit"

UPLOAD=0
GROUP=""
while (( $# )); do
  case "$1" in
    --upload) UPLOAD=1 ;;
    --group) shift; GROUP="${1:?--group needs a name}" ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) print -u2 "Unknown argument: $1"; exit 2 ;;
  esac
  shift
done
[[ -n "$GROUP" && $UPLOAD == 0 ]] && { print -u2 "--group only together with --upload"; exit 2; }

say() { print -- "[testflight] $*"; }
fail() { print -u2 -- "[testflight] $*"; exit 1; }

# Team: environment first, then the ignored Local.xcconfig of the source checkout.
TEAM="${APPLE_TEAM_ID:-}"
if [[ -z "$TEAM" && -r "$REPO/App/Config/Local.xcconfig" ]]; then
  TEAM="$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*\([A-Z0-9]*\).*/\1/p' \
    "$REPO/App/Config/Local.xcconfig" | tail -1)"
fi
[[ "$TEAM" =~ '^[A-Z0-9]{10}$' && "$TEAM" != ABCDE12345 ]] \
  || fail "No team ID: set DEVELOPMENT_TEAM in App/Config/Local.xcconfig or APPLE_TEAM_ID."

command -v xcodegen >/dev/null || fail "xcodegen missing: brew install xcodegen"
xcodebuild -version | head -1 | grep -q '^Xcode 27' || fail "Xcode 27 is not the selected Xcode (xcode-select -p)."

typeset -a ASC
ASC=(asc)
[[ -n "${ASC_PROFILE:-}" ]] && ASC+=(--profile "$ASC_PROFILE")
if (( UPLOAD )); then
  command -v asc >/dev/null || fail "asc missing: brew install asc"
  "${ASC[@]}" auth status >/dev/null 2>&1 || fail "asc is not signed in: asc auth login ..."
  if [[ -z "${ASC_APP_ID:-}" ]]; then
    ASC_APP_ID="$("${ASC[@]}" apps list --bundle-id "$BUNDLE_ID" --output json 2>/dev/null \
      | /usr/bin/python3 -I -c '
import json, sys
d = json.load(sys.stdin)
for a in d.get("data", []) if isinstance(d, dict) else d:
    if a.get("attributes", {}).get("bundleId") == sys.argv[1]:
        print(a["id"]); break
' "$BUNDLE_ID")"
    [[ -n "$ASC_APP_ID" ]] || fail "App $BUNDLE_ID not found in App Store Connect (create it or set ASC_APP_ID)."
  fi
  say "App ID $ASC_APP_ID"
fi

mkdir -p "$ROOT" "$LOG_DIR"

# Fresh detached work tree, so local changes in the checkout never end up in a build.
git -C "$REPO" fetch -q origin main
git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
git -C "$REPO" worktree prune
git -C "$REPO" worktree add -f --detach "$WT" "$REF" >/dev/null
BUILD_NR="$(git -C "$WT" rev-list --count HEAD)"
COMMIT="$(git -C "$WT" rev-parse --short HEAD)"
say "Revision $COMMIT, build $BUILD_NR, team $TEAM"

say "Generating project"
xcodegen generate --spec "$WT/App/project.yml" >"$LOG_DIR/xcodegen.log" 2>&1 \
  || fail "XcodeGen failed ($LOG_DIR/xcodegen.log)"

ARCHIVE="$WT/build/ClaudeKitchen.xcarchive"
EXPORT_DIR="$WT/build/export"
say "Archive (log: $LOG_DIR/archive.log)"
xcodebuild archive -project "$WT/App/ClaudeKitchen.xcodeproj" -scheme ClaudeKitchen \
  -configuration Release -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -derivedDataPath "$WT/build/DerivedData" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic CURRENT_PROJECT_VERSION="$BUILD_NR" \
  >"$LOG_DIR/archive.log" 2>&1 || fail "Archive failed ($LOG_DIR/archive.log)"

# Export options are written at run time so the team ID never lands in the repo.
OPTIONS="$WT/build/ExportOptions.plist"
rm -f "$OPTIONS"
/usr/libexec/PlistBuddy \
  -c "Add :method string app-store-connect" \
  -c "Add :destination string export" \
  -c "Add :signingStyle string automatic" \
  -c "Add :teamID string $TEAM" \
  -c "Add :uploadSymbols bool true" \
  -c "Add :manageAppVersionAndBuildNumber bool false" \
  "$OPTIONS" >/dev/null

say "Export (log: $LOG_DIR/export.log)"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates \
  >"$LOG_DIR/export.log" 2>&1 || fail "Export failed ($LOG_DIR/export.log)"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' \
  "$ARCHIVE/Info.plist")"
IPAS=("$EXPORT_DIR"/*.ipa(N))
(( ${#IPAS} == 1 )) || fail "Expected one .ipa in $EXPORT_DIR"
IPA="${IPAS[1]}"
say "Exported ${IPA:t} (version $VERSION, build $BUILD_NR)"

if (( ! UPLOAD )); then
  say "Dry run ok: $IPA"
  exit 0
fi

# Test notes: commit subjects since the last uploaded revision (at most 15), otherwise the last 10.
LAST=""
[[ -r "$LAST_FILE" ]] && LAST="$(<"$LAST_FILE")"
if [[ -n "$LAST" ]] && git -C "$WT" merge-base --is-ancestor "$LAST" HEAD 2>/dev/null; then
  NOTES="$(git -C "$WT" log --no-merges --format='- %s' -n 15 "$LAST..HEAD")"
else
  NOTES="$(git -C "$WT" log --no-merges --format='- %s' -n 10)"
fi
[[ -n "$NOTES" ]] || NOTES="- Stand $COMMIT"
NOTES="Build $BUILD_NR ($COMMIT)"$'\n'"$NOTES"
print -r -- "$NOTES" >"$LOG_DIR/test-notes.txt"

say "Upload and processing (10 to 30 minutes)"
"${ASC[@]}" builds upload --app "$ASC_APP_ID" --ipa "$IPA" \
  --version "$VERSION" --build-number "$BUILD_NR" --test-notes "@file:$LOG_DIR/test-notes.txt" --locale de-DE \
  --wait --output json >"$LOG_DIR/upload.json" 2>"$LOG_DIR/upload.log" \
  || fail "Upload failed or test notes not set ($LOG_DIR/upload.log); check App Store Connect before retrying."
git -C "$WT" rev-parse HEAD >"$LAST_FILE"

if [[ -n "$GROUP" ]]; then
  "${ASC[@]}" builds add-groups --app "$ASC_APP_ID" --version "$VERSION" --build-number "$BUILD_NR" \
    --platform IOS --group "$GROUP" --skip-internal >>"$LOG_DIR/upload.log" 2>&1 \
    || fail "Build $BUILD_NR uploaded, but group \"$GROUP\" not assigned ($LOG_DIR/upload.log)."
  say "Build $BUILD_NR uploaded and assigned to \"$GROUP\""
else
  say "Build $BUILD_NR uploaded (no group assigned)"
fi
