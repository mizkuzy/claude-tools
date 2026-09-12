# claude-sessions-archiver

Moves old Claude Code session files from `~/.claude/projects/` to `~/claude-archive/` and compresses them.

## Why

Claude Code reads every `.jsonl` file in the project directory at startup. With 200+ files the startup fails:

```
error: An unknown error occurred, possibly due to low max file descriptors (Unexpected)
```

The message is misleading: file descriptors are not the cause.

The built-in `cleanupPeriodDays` setting (default 30) deletes files by age. It does not help when you create many sessions per day, and it deletes them permanently.

This script moves files older than 7 days. The data is kept.

## What it does

- Walks every project in `~/.claude/projects/`.
- Moves `.jsonl` files older than 7 days to `~/claude-archive/<project-name>/`.
- Compresses each file separately: `session.jsonl` becomes `session.jsonl.gz`.
- Writes a log to `~/claude-archive/archiver.log`.
- Runs every 7 days via launchd.

The archive layout mirrors `~/.claude/projects/`. A directory name is the project path with `/` replaced by `-`.

## Requirements

macOS. The scheduler uses launchd. The script itself is plain bash and works anywhere, but `install.sh` is macOS-only.

## Install

```bash
git clone https://github.com/mizkuzy/claude-tools.git
cd claude-tools/claude-sessions-archiver
./install.sh
```

## Verify

```bash
launchctl list | grep claude-archiver     # job is registered
cat ~/claude-archive/archiver.log         # what was moved
launchctl kickstart -k gui/$(id -u)/com.user.claude-archiver   # run now
```

## Configuration

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `CLAUDE_PROJECTS_DIR` | `~/.claude/projects` | source directory |
| `CLAUDE_ARCHIVE_DIR` | `~/claude-archive` | destination directory |
| `CLAUDE_ARCHIVE_DAYS` | `7` | file age in days |

Run manually with a different threshold:

```bash
CLAUDE_ARCHIVE_DAYS=3 ./archive-sessions.sh
```

The job uses `StartInterval` (seconds), not a fixed clock time, so it does not depend on the machine being awake at a particular moment. If the interval elapses while the Mac is asleep or off, launchd runs the job once after it wakes.

To change the schedule, edit `StartInterval` in `com.user.claude-archiver.plist.template` and run `./install.sh` again. 604800 is 7 days, 86400 is 1 day.

Edits to `archive-sessions.sh` take effect immediately. No reinstall needed.

## Reading the archive

```bash
zcat ~/claude-archive/*/session-id.jsonl.gz
zgrep 'text' ~/claude-archive/*/*.jsonl.gz
```

Python:

```python
import gzip, json, pathlib

for path in pathlib.Path("~/claude-archive").expanduser().rglob("*.jsonl.gz"):
    with gzip.open(path, "rt") as f:
        for line in f:
            record = json.loads(line)
```

## Restoring a session to `/resume`

```bash
gunzip -c ~/claude-archive/<project>/<file>.jsonl.gz > ~/.claude/projects/<project>/<file>.jsonl
```

The restored file falls under `cleanupPeriodDays` and is deleted after 30 days unless you open it.

## Uninstall

```bash
launchctl bootout gui/$(id -u)/com.user.claude-archiver
rm ~/Library/LaunchAgents/com.user.claude-archiver.plist
```

The archive in `~/claude-archive` is not touched.

## First run

If Claude Code already fails to start, move everything except the most recent files once:

```bash
CLAUDE_ARCHIVE_DAYS=1 ./archive-sessions.sh
```
