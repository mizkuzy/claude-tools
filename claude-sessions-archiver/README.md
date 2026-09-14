# claude-sessions-archiver

Moves old Claude Code session files from `~/.claude/projects/` to `~/claude-archive/` and compresses them.

## Why
The reason is wrong. archiving of files hasn't fixed the problem. Restarting fix.
But maybe this script worth it to have sessions in one place for future analysis. 


Claude Code reads every `.jsonl` file in the project directory at startup. Once that directory grows large enough, startup fails:

```
error: An unknown error occurred, possibly due to low max file descriptors (Unexpected)
```

The message is misleading: file descriptors are not the cause. This was observed at roughly 210 files totalling 335 MB in a single project; the exact threshold, and whether file count or total size is what matters, is not established.

The built-in `cleanupPeriodDays` setting (default 30) deletes files by age. It does not help when you create many sessions per day, and it deletes them permanently.

This script moves old files out of the way instead of deleting them. The data is kept. The age threshold is configurable and defaults to 7 days.

## What it does

- Walks every project in `~/.claude/projects/`.
- Moves `.jsonl` files past the age threshold to `~/claude-archive/<project-name>/`.
- Compresses each file separately: `session.jsonl` becomes `session.jsonl.gz`.
- Writes a log to `~/claude-archive/archiver.log`.
- Runs on a schedule via launchd, every 7 days by default.

The archive layout mirrors `~/.claude/projects/`. A directory name is the project path with `/` replaced by `-`.

## Requirements

macOS. `install.sh` and the scheduling both use launchd. `archive-sessions.sh` is plain bash and has only been tested on macOS; it relies on `find -mtime`, whose behavior differs between BSD and GNU, so treat other platforms as untested.

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
```

To run it now rather than waiting, see [Running it manually](#running-it-manually).

## Configuration

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `CLAUDE_PROJECTS_DIR` | `~/.claude/projects` | source directory |
| `CLAUDE_ARCHIVE_DIR` | `~/claude-archive` | destination directory |
| `CLAUDE_ARCHIVE_DAYS` | `7` | file age in days |

Nothing sets these anywhere. The script reads them if they happen to be set and falls back to the defaults otherwise.

`CLAUDE_ARCHIVE_DAYS` is the age threshold, not the schedule. It decides which files are old enough to move; `StartInterval` decides how often the script runs. The two are independent.

To override for a single run:

```bash
CLAUDE_ARCHIVE_DAYS=3 ./archive-sessions.sh
```

You can also export one in `~/.zshrc` to change the default for runs you start from a terminal:

```bash
export CLAUDE_ARCHIVE_DAYS=14
```

This does not affect the scheduled run. launchd starts jobs with a minimal environment and does not read your shell profile. To change the threshold for scheduled runs, add an `EnvironmentVariables` block to `com.user.claude-archiver.plist.template` and reinstall:

```xml
<key>EnvironmentVariables</key>
<dict>
    <key>CLAUDE_ARCHIVE_DAYS</key>
    <string>14</string>
</dict>
```

## Running it manually

You can run the archiver at any time, whether or not the job is installed and regardless of when it last ran. Two ways:

Run the script directly:

```bash
./archive-sessions.sh
CLAUDE_ARCHIVE_DAYS=3 ./archive-sessions.sh   # different threshold
```

Or trigger the installed launchd job:

```bash
launchctl kickstart -k gui/$(id -u)/com.user.claude-archiver
```

Neither affects the schedule. `kickstart` adds an extra run alongside the interval; the interval keeps counting from where it was. Verified by observation: with a 30s interval, a kickstart 12s into an interval produced an extra run immediately, and the following scheduled runs still landed 30s and 60s after the previous natural firing.

Both are safe to repeat. The script takes a lock against concurrent runs, and files already archived are no longer in the source directory, so a second run finds nothing to do.

## Schedule

The job uses `StartInterval` (seconds), not a fixed clock time, so it does not fire at an hour the machine is likely to be off.

A caveat from `man launchd.plist`: if the system is asleep when an interval would fire, that firing is missed rather than deferred. It is not run on wake. The next firing is one full interval later. A firing is also skipped if the previous run is somehow still going. In practice this means the archiver runs somewhat less often than the nominal interval, which is harmless here since it archives by file age.

To change the schedule, edit `StartInterval` in `com.user.claude-archiver.plist.template` and run `./install.sh` again. 604800 is 7 days, 86400 is 1 day.

Edits to `archive-sessions.sh` take effect immediately. No reinstall needed.

## Reading the archive

```bash
gunzip -c ~/claude-archive/<project>/<session-id>.jsonl.gz
zgrep 'text' ~/claude-archive/*/*.jsonl.gz
```

Use `gunzip -c`, not `zcat`. On macOS `zcat` appends `.Z` and fails on a `.gz` file.

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
