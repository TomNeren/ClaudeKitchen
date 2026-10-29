#!/bin/sh
# Writes the git commit into the built app's Info.plist, so Settings shows which state is installed.
# Runs as a post-build phase of the app target (see project.yml); Xcode signs the bundle afterwards.
set -eu

plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
cd "${SRCROOT}"

commit=$(git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)
date=$(git log -1 --format=%cs 2>/dev/null || true)
if [ "$commit" != unknown ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    commit="${commit}+"
fi

set_key() {
    /usr/libexec/PlistBuddy -c "Delete :$1" "$plist" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$plist"
}

set_key GitCommit "$commit"
set_key GitCommitDate "$date"
echo "Stamped GitCommit=$commit GitCommitDate=$date"
