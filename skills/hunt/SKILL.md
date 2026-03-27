---
name: hunt
description: Surfaces fixable open-source GitHub issues by running a four-layer structured filter (search index, automated repo and PR checks, contribution log dedup) before reading any full thread — when the user wants to find an issue to contribute to, search open-source bugs, or run hunt
---

# Hunt — Find a Valid Issue to Fix

## The Iron Law

```
DO NOT SELECT AN ISSUE WITHOUT READING THE FULL THREAD.
Structured filters reduce noise — they do not replace reading the thread.
```

**Violating the letter of this law is violating the spirit of it.**

## Overview

Surface a genuine, fixable, uncontested bug in a well-maintained repository — one that no one else is working on and that maintainers will welcome a fix for.

**Core principle:** Machine filters eliminate obvious rejects before Claude reads anything. Only issues that pass all four layers reach the full-thread evaluation step.

**Announce at start:** "I'm using the hunt skill to find a valid issue to contribute to."

## Four-Layer Filter

```
Layer 1  gh search issues        GitHub index — stars, activity, label, assignee
Layer 2  screen-issue.sh         Structured checks — repo quality, linked PRs, recency
Layer 3  log.sh check-issue      Dedup — skip anything already in the contribution log
Layer 4  gh issue view           Full thread — Claude reads and judges
```

Layers 1–3 are mechanical and do not rely on LLM judgment. Layer 4 is where Claude evaluates.

## Process

### Step 1: Verify GitHub Access

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-access.sh
```

`check-access.sh` exits non-zero if `gh` is not installed, not authenticated, or `jq` is missing. **Stop immediately if it fails** — print the error and instruct the user to fix the dependency before proceeding.

### Step 1.5: Gather Search Preferences (only when `$ARGUMENTS` is empty)

If `$ARGUMENTS` is non-empty, skip this step entirely.

If `$ARGUMENTS` is empty, ask the user:

```
What kind of repos are you interested in contributing to?
You can specify language, framework, ecosystem, repo size preference, or anything else.

Examples:
  - Node.js
  - Python CLI tools
  - Rust
  - React ecosystem
  - Small, actively maintained repos

Leave blank to skip and search broadly.
```

Wait for the user's reply. If the reply is non-empty and non-whitespace, treat it as `$ARGUMENTS` for the rest of this skill. If the reply is empty or whitespace-only, proceed with a broad search.

### Step 2: Layer 1 — Search Issues Directly

If `$ARGUMENTS` specifies a language or ecosystem (e.g. `"js(npm)"`), embed it as `language:<lang>` inside the query string — **do not use the `--language` flag**, it interacts poorly with other filters and frequently returns empty results. If `$ARGUMENTS` specifies a single repository (e.g. `"vuejs/vue"`), use `gh issue list --repo <owner/name>` instead of `gh search issues`. If `$ARGUMENTS` is empty, run the default broad search.

Search GitHub's issue index across all public repos with quality signals baked in:

```bash
gh search issues \
  "stars:>5000 fork:false" \
  --state open \
  --label bug \
  --no-assignee \
  --sort updated \
  --order desc \
  --limit 30 \
  --json url,title,repository,commentsCount,createdAt,updatedAt
```

> **Rate limit design:** `--limit 30` combined with server-side filtering (`stars:>5000 fork:false`) significantly reduces the initial candidate pool, lowering the number of subsequent `screen-issue.sh` API calls.

If the user specified a language, embed it in the query string — not as a flag:

```bash
gh search issues \
  "stars:>5000 fork:false language:javascript" \
  --state open \
  --label bug \
  --no-assignee \
  --sort updated \
  --order desc \
  --limit 30 \
  --json url,title,repository,commentsCount,createdAt,updatedAt
```

If they specified a repo, use `gh issue list` for that repo instead:

```bash
gh issue list --repo <owner/name> --state open --label bug --limit 50
```

If a repo does not use a `bug` label, fall back to all open issues without `--label`.

> **Note:** `gh issue list` does not support `--no-assignee`. To filter out assigned issues from `gh issue list` results, post-filter in the next step via `screen-issue.sh` (it checks assignees via the API).

Collect the raw list. Do not evaluate titles yet — that comes after filtering.

### Step 3: Layer 2 + 3 — Automated Screening

For each issue URL from Step 2, run both checks in sequence:

```bash
# Layer 2: structured repo and PR checks
${CLAUDE_PLUGIN_ROOT}/scripts/screen-issue.sh <issue-url>

# Layer 3: contribution log dedup
${CLAUDE_PLUGIN_ROOT}/scripts/log.sh check-issue <issue-url> && echo "already logged — skip"
```

`screen-issue.sh` structured stdout output:
- Starts with `=== SCREEN PASS ===`, next line is JSON → passed; use the JSON as this issue's screen result
- Starts with `=== SCREEN DISQUALIFIED:` → issue does not qualify, exit 2 — skip this issue, continue to next
- Starts with `=== SCREEN ERROR:` + exit 2 → per-issue API error — skip this issue, continue to next
- Starts with `=== SCREEN ERROR: fatal` + exit 1 → fatal error (missing dependency) — stop the entire hunt and report to the user

**Rate-limit-friendly execution:**
- `screen-issue.sh` already includes a 2s sleep at the end of each run
- `gh-call.sh` already includes a 1s sleep after every successful API call
- No additional sleep is needed here
- **Consecutive error detection:** if 3 consecutive issues return `=== SCREEN ERROR:` (exit 2), pause 30s before continuing and print: `Rate limit may be in effect — waiting 30s before continuing`

Collect all issues that pass both checks. You need at least 5 passing issues before proceeding to Step 4 — if fewer pass, re-run Step 2 with a wider search or different parameters.

**Do not read issue titles or bodies during this step.** The script output is sufficient.

### Step 4: Layer 4 — Read the Full Thread

For each candidate that passed Step 3, fetch the body and comments separately. Extract `<number>` and `<owner/repo>` from the issue URL:

```bash
# Always read body first (--comments alone skips the body entirely)
gh issue view <number> --repo <owner/repo>

# Then read comments only if the above output shows comments: N where N > 0
gh issue view <number> --repo <owner/repo> --comments
```

**Disqualify the issue if ANY of the following is true:**

| Signal | Action |
|---|---|
| Maintainer commented `won't fix`, `by design`, `wontfix`, `duplicate` | Skip |
| Maintainer closed the issue as invalid or by design | Skip |
| Any contributor has claimed they are actively working on it | Skip |
| A linked PR attempted this fix and was rejected | Skip |
| Comments suggest the bug is fixed in a newer unreleased version | Skip |
| Ongoing maintainer disagreement about whether this is a bug | Skip |
| Issue is a feature request, not a bug | Skip |
| Issue is documentation-only | Skip |
| No reproduction steps and no one has confirmed the bug | Skip |

A linked PR that was abandoned by the contributor but received positive maintainer feedback may still be viable — evaluate carefully.

**Proceed only if:** the full thread unambiguously supports that this is a real bug, no one is currently fixing it, and maintainers are open to a fix.

### Step 5: Present Candidates

For a filled-in example of the format below, load `examples/candidate-output.md`.

Present **3–5 ranked candidates**. For each, include the JSON fields from `screen-issue.sh` output plus the thread evaluation:

```text
N. owner/name (N,000 stars)
Issue: #number — title
URL: full issue URL
Last repo commit: YYYY-MM-DD
Last activity: YYYY-MM-DD
Maintainer engaged: yes / no
Fork exists: yes / no
Why it qualifies: one sentence
```

Rank by fixability — prefer issues with a clear, isolated reproduction path and a small expected code change. Issues where a maintainer has engaged are ranked higher than cold reports.

Ask the user to select one, or to request more candidates.

If no candidates passed all four layers, report the layer-by-layer breakdown (how many were disqualified at each layer and why) and ask the user to reply "more" to retry with wider parameters. See the failure case in `examples/candidate-output.md`.

## Red Flags — Skip This Issue

| Signal | Why |
|---|---|
| `screen-issue.sh` exits 2 | Disqualified — do not override the script |
| Last maintainer activity > 3 months ago with no engagement | Fix may not be reviewed |
| Repo has a CLA requirement the user has not signed | PR will be blocked |
| Issue links to 3+ duplicate reports | Likely complex or by design |
| Issue title says "sometimes", "randomly", "occasionally" without reproduction steps | Cannot reliably reproduce |
| Issue labeled `good first issue` but zero maintainer engagement > 30 days | Maintainers may not be watching |

## Common Rationalizations — Do Not Act On These

| Thought | Reality |
|---|---|
| "The title looks fixable, let me just start" | The thread may invalidate it. Read first. |
| "screen-issue.sh passed, so I can skip the thread" | Script checks structure — thread contains intent. |
| "Someone commented 2 years ago, they're probably done" | Check for a linked PR. Don't assume. |
| "The maintainer hasn't responded, so no one is working on it" | Silence ≠ abandoned. Check all signals. |
| "I'll evaluate the thread after cloning" | Evaluation comes before cloning. Always. |
| "gh isn't authenticated but WebSearch can substitute" | No. gh is required. Stop and fix auth first. |
| "The script disqualified this but it looks promising" | Trust the script. Re-run if you suspect an API error. |
