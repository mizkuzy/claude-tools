#!/bin/bash
# Registers the job with launchd.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$REPO/archive-sessions.sh"
ARCHIVE_DIR="${CLAUDE_ARCHIVE_DIR:-$HOME/claude-archive}"
LABEL="com.user.claude-archiver"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

chmod +x "$SCRIPT"
mkdir -p "$ARCHIVE_DIR" "$HOME/Library/LaunchAgents"

sed -e "s|__SCRIPT__|$SCRIPT|g" -e "s|__ARCHIVE__|$ARCHIVE_DIR|g" \
    "$REPO/$LABEL.plist.template" >"$PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "installed: $PLIST"
echo "script:  $SCRIPT"
echo "archive: $ARCHIVE_DIR"
echo
echo "check:  launchctl list | grep claude-archiver"
echo "run now: launchctl kickstart -k gui/$(id -u)/$LABEL"
