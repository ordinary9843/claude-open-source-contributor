---
name: contribute
description: Commits a locally verified bug fix to the contributor's GitHub fork, opens a pull request against the upstream repository with a human-readable description, and records the contribution in the log — when the fix branch is ready, tests pass, and the user wants to submit the PR or run contribute
---

# Contribute — Open the PR

## The Iron Laws

```
1. NO PR WITHOUT EXPLICIT USER CONFIRMATION
   Ask before every git operation. Wait for yes.

2. COMMIT AUTHOR = USER'S GIT CONFIG ONLY
   No Co-Authored-By. No tool names. No AI references.
   The commit must be indistinguishable from any human contributor.

3. WRITE THE LOG AFTER THE PR IS OPENED
   If the log write fails, report it — do not roll back the PR.
```

**Violating the letter of these laws is violating the spirit of them.**

## Overview

Commit cleanly, push to a fork, open a PR with a natural human-written description, and finalize the contribution log.

**Core principle:** Every action here is visible to the open-source maintainer. Commit history, PR body, and attribution must all read as a genuine human contribution.

**Announce at start:** "I'm using the contribute skill to submit this fix."

## Process

If `$ARGUMENTS` contains a GitHub issue URL, confirm a matching entry exists in the contribution log with `pr: null` before proceeding — run `log.sh check-issue <issue-url>`. If `$ARGUMENTS` contains a branch name (e.g. `fix/return-behavior-override`), check it out before Step 1. If `$ARGUMENTS` is empty, proceed from Step 0.

### Step 0: Verify GitHub Access

```bash
username=$(${CLAUDE_PLUGIN_ROOT}/scripts/check-access.sh)
```

`check-access.sh` exits non-zero if `gh` is not installed or not authenticated. **Stop immediately if it fails** — print the error and instruct the user to run `gh auth login`. All subsequent steps use `gh` exclusively. The `username` variable holds the authenticated GitHub username — use it wherever `<your-username>` appears in Steps 4–7.

### Step 1: If Invoked Directly (not preceded by `fix` in this session)

Run the full test suite before anything else:

```bash
<project full test command>
```

Show the complete output. If any tests fail — stop. Do not proceed. Ask the user to run `fix` first or resolve the failures manually.

### Step 2: Validate Git Config

```bash
git config user.name
git config user.email
```

If either is empty or missing, stop and instruct the user to set them:

```bash
git config user.name "Your Name"
git config user.email "you@example.com"
```

**Ask the user to confirm both values are correct** — not just non-empty. The configured email must match the account they intend to contribute from. If they correct either value, re-run the check before proceeding.

Do not proceed without both values explicitly confirmed by the user.

### Step 3: Confirm with User

State clearly:
- Repository: `owner/name`
- Issue: `#<number> — <title>`
- What was fixed: one sentence

Ask for explicit confirmation before any git operation.

### Step 4: Ensure Fork Exists

```bash
gh repo fork <upstream-owner>/<upstream-repo> --clone=false
```

If the fork already exists, `gh` will report it — that is fine. Continue.
The fork will be at `github.com/<your-username>/<repo>`.

### Step 5: Commit

Verify the fix branch is currently checked out:

```bash
git branch --show-current
```

If the output is not `fix/<slug>`, stop and check out the correct branch before proceeding. Never commit to the default branch.

Detect the upstream default branch and identify files changed on the fix branch:

```bash
default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
git diff --name-only ${default_branch}...fix/<slug>
```

If the above returns empty (e.g. local branch not yet tracking remote), fall back to:

```bash
git status --short
```

Stage only the files that are part of the fix:

```bash
git add <file1> <file2> ...
git commit -m "<message>"
```

**Commit message rules:**
- Subject line only by default (≤ 72 characters): `fix: <description>`
- No body unless the fix has multiple distinct logical parts that cannot be described in one line
- If a body is needed, keep it to 3 lines maximum — explain *what* changed and *why*, not *how*
- No `Co-Authored-By` trailer
- No mention of Claude, AI, or any tool

**If the fix has multiple distinct logical parts**, split into separate commits — each following the same rules.

**Verify attribution after committing:**
```bash
git log --format="%an <%ae>" -1
```

Expected: the user's configured name and email.

### Step 6: Push

```bash
git remote add fork https://github.com/<your-username>/<repo>.git
git push fork fix/<slug>
```

If the `fork` remote already exists:
```bash
git remote set-url fork https://github.com/<your-username>/<repo>.git
git push fork fix/<slug>
```

If `git push` fails (e.g. protected branch, remote rejection): do not force-push. Stop and report the error — the user must resolve remote state before retrying.

### Step 7: Open PR

```bash
gh pr create \
  --repo <upstream-owner>/<upstream-repo> \
  --head <your-username>:fix/<slug> \
  --base <default-branch> \
  --title "<title>" \
  --body "$(cat <<'EOF'
When [condition], [bad thing happens] because [root cause].

This fix [what changed] so that [correct behavior now].

Fixes #<issue-number>
EOF
)"
```

**Title rules:**
- ≤ 70 characters
- Natural language — describes the fix from a user's perspective
- Not the commit message verbatim
- Example: `"Fix silent return override when setter order conflicts"`

**Body rules:**
- Plain English, no mention of Claude, AI, automation, or tooling
- Write as a developer who found the bug, understood it, and fixed it

For reference bodies that hit the right tone, load `examples/pr-body.md`.

### Step 8: Update Log Entry

Try to update the existing partial entry (where `pr` is `null`):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/log.sh update-pr <issue-url> <pr-url>
```

If the script exits with code 3 (no pending entry found), append a complete new entry instead:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/log.sh append '{
  "repo": "owner/name",
  "issue": "<issue-url>",
  "pr": "<pr-url>",
  "description": "<one specific sentence>"
}'
```

`log.sh` stamps today's date automatically — do not add a `date` field.

**If the log write fails** (permission error, malformed JSON, `jq` not installed):
- Report the PR URL to the user
- Show the entry they should add manually
- Do not roll back the PR — it is already open

### Step 9: Report

```text
PR opened: <PR URL>
Log updated: ~/.claude/open-source-contributor/log.json
```

## Red Flags — Stop

| Signal | Action |
|---|---|
| `check-access.sh` fails | Step 0 — user must run `gh auth login` before any work |
| `git config user.name` or `user.email` is empty | Step 2 — set before proceeding |
| Tests fail when invoked directly | Step 1 — do not proceed |
| PR body mentions Claude, AI, or any tool | Rewrite body before opening PR |
| `Co-Authored-By` present in commit | `git commit --amend` to remove (safe only before push), then re-verify |
| Fix branch is not checked out | Checkout the correct branch before committing |

## Common Rationalizations — Do Not Act On These

| Thought | Reality |
|---|---|
| "The log write failed but the PR is open, good enough" | Report the failure — the user needs to update manually |
| "I'll add a Co-Authored-By to be transparent" | Iron Law 2. No co-authors. No exceptions. |
| "The commit message is good enough without the fix: prefix" | Consistent format matters. Use it. |
| "The PR body sounds a bit robotic but it covers the facts" | Rewrite it. It must read like a human wrote it. |
| "gh isn't authenticated but I can open the PR some other way" | No. gh is required. Stop and fix auth first. |
