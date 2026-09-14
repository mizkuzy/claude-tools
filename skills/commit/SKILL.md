---
name: commit-message
description: Write clear commit messages. Use when asked to commit changes, write a commit message, prepare a commit.
---

## Text format
Use simple, common words. Use technical terms only when needed. Dry text: no metaphors, adjectives, adverbs, embellishment or anything else. Add only enough words to make the sentence understandable.

## Workflow

### 1. Understand the Changes

If you don't already understand the changes, review them first:

```bash
git diff HEAD
git status --short
```

### 2. Commit Message Format

**Title (first line):**
example: 
BF-338: alert Slack when a Deploy run fails

- Limit to 60 characters
- Use lowercase except for symbols or acronyms
- Use imperative mood ("add feature" not "adds feature", "fix impersonation banner overlapping")
- Use a short prefix for readability in `git log --oneline` (BF-261, VP-142)

**Body:**
- Explain what the change does and why
- Use proper grammar and punctuation
- Use imperative mood throughout
- Hard-wrap at 72 chars per line
- Break only at word boundaries — never mid-word
- Prefer breaking at natural clause/sentence boundaries (after ., ,, before and/so/which) over blindly filling to column 72
- Blank line between paragraphs

### 3. Commit changes with git
Stage the relevant files and commit:

```bash
git add <files>
git commit -m "message"
```

Do not stage unrelated files. Do not use `git add -A` or `git add .`.