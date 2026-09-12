#!/bin/bash
# Moves old Claude Code session files from ~/.claude/projects to an archive and compresses them.
set -euo pipefail

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
ARCHIVE_DIR="${CLAUDE_ARCHIVE_DIR:-$HOME/claude-archive}"
DAYS="${CLAUDE_ARCHIVE_DAYS:-7}"

mkdir -p "$ARCHIVE_DIR"
LOG="$ARCHIVE_DIR/archiver.log"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

if [ ! -d "$PROJECTS_DIR" ]; then
    log "directory $PROJECTS_DIR not found, exiting"
    exit 0
fi

# Lock: a second run exits immediately.
LOCK="$ARCHIVE_DIR/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    log "already running, exiting"
    exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

moved=0
failed=0

for project in "$PROJECTS_DIR"/*/; do
    [ -d "$project" ] || continue
    name="$(basename "$project")"
    dest="$ARCHIVE_DIR/$name"

    while IFS= read -r -d '' file; do
        mkdir -p "$dest"
        base="$(basename "$file")"
        target="$dest/$base"

        # Name taken - append a timestamp.
        if [ -e "$target" ] || [ -e "$target.gz" ]; then
            target="$dest/${base%.jsonl}-$(date +%s).jsonl"
        fi

        if mv "$file" "$target" && gzip -q -f "$target"; then
            moved=$((moved + 1))
        else
            failed=$((failed + 1))
            log "error: $file"
        fi
    done < <(find "$project" -maxdepth 1 -type f -name '*.jsonl' -mtime +"$DAYS" -print0)
done

log "moved $moved, failed $failed, threshold $DAYS days"
