---
name: revise
description: Reads maintainer review comments on an open PR, evaluates each comment, proposes changes with reasoning, and — after the user implements them — commits, pushes, and replies to the PR — when a maintainer has reviewed a PR opened via contribute and the user wants to address the feedback
---

# Revise — Address PR Review Feedback

## The Four Iron Laws

```
1. NO ACTION WITHOUT VERIFYING YOU OWN THIS PR
   Confirm PR author matches authenticated gh user.
   Stop if it fails — do not touch a PR you did not open.

2. COMMIT AUTHOR = USER'S GIT CONFIG ONLY
   No Co-Authored-By. No tool names. No AI references.
   The commit must be indistinguishable from any human contributor.
   Verify git config before committing. Stop if name or email is empty.

3. NO COMMIT WITHOUT USER CONFIRMATION
   Show commit message and PR reply drafts.
   Wait for explicit approval. Never commit, push, or comment without yes.

4. NO AI MARKERS IN OUTPUT
   Commit messages, PR replies, and all user-facing text must read as a human
   developer wrote them. No emoji. No bullet lists of "I addressed X, Y, Z".
   No AI-sounding phrasing.
```

**Violating the letter of these laws is violating the spirit of them.**

## Overview

**Core principle:** The maintainer is a human. Every reply should read like one human developer responding to another — not a changelog, not a bullet list, not a summary of actions taken.

**Announce at start:** "I'm using the revise skill to address the PR review feedback."

For a worked example, load `examples/review-session.md`.

## Process

`$ARGUMENTS` must contain a GitHub PR URL. If empty, ask the user to provide one before proceeding.

### Step 0: Verify GitHub Access

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-access.sh
```

`check-access.sh` exits non-zero if `gh` is not installed or not authenticated. **Stop immediately if it fails** — print the error and instruct the user to run `gh auth login`. All subsequent steps use `gh` exclusively.

### Step 0.5: Validate Git Config

```bash
git config user.name
git config user.email
```

If either is empty or missing, stop and instruct the user to set them:

```bash
git config user.name "Your Name"
git config user.email "you@example.com"
```

Do not proceed without both values confirmed.

### Step 1: Four-Gate Verification

All four gates must pass. If any fails, stop and explain which gate failed and why.

**Gate 1 — PR author is you:**

```bash
pr_author=$(gh pr view "$PR_URL" --json author --jq '.author.login')
current_user=$(gh api user --jq '.login')
[ "$pr_author" = "$current_user" ] || echo "FAIL: PR author is $pr_author, authenticated as $current_user"
```

**Gate 2 — PR is open:**

```bash
pr_state=$(gh pr view "$PR_URL" --json state --jq '.state')
[ "$pr_state" = "OPEN" ] || echo "FAIL: PR state is $pr_state"
```

**Gate 3 — PR has pending review or unresolved comment:**

```bash
has_changes_requested=$(gh pr view "$PR_URL" --json reviews --jq '[.reviews[] | select(.state == "CHANGES_REQUESTED")] | length')
has_comments=$(gh pr view "$PR_URL" --json comments --jq '.comments | length')
[ "$has_changes_requested" -gt 0 ] || [ "$has_comments" -gt 0 ] || echo "FAIL: no pending review or comments found"
```

**Gate 4 — Local branch exists:**

```bash
pr_branch=$(gh pr view "$PR_URL" --json headRefName --jq '.headRefName')
git branch --list "$pr_branch" | grep -q "$pr_branch" || echo "FAIL: branch $pr_branch not found locally"
```

### Step 2: Read All Review Comments

```bash
gh pr view "$PR_URL" --comments
gh pr view "$PR_URL" --json reviews --jq '.reviews[] | {author: .author.login, state: .state, body: .body}'
```

Read them in full — do not summarise before evaluation.

### Step 3: Evaluate Each Comment

Classify each as **actionable** or **noise**.

**Actionable:** concrete requests to change code, add tests, rename something, fix a bug, update docs, clarify behaviour.

**Noise — skip if:** automated bot output (Vercel deploy previews, CI status, Gemini/Copilot auto-summaries with no specific asks), vague praise with no request, off-topic discussion, requests contradicting a stated decision by a senior maintainer in the same thread.

Present as a table:

```
Comment author | Summary | Classification | Reason (if noise)
```

Ask user to confirm before proceeding. User can override any noise classification.

### Step 4: Propose Changes

For each actionable comment, state:

1. What to change — file, function, or section
2. Why — how this directly addresses the comment
3. Edge cases — backwards compatibility, test coverage needed, or anything that could break

Present as a numbered list. Wait for user confirmation before they start implementing.

### Step 5: User Implements

The user makes the changes. Do not auto-apply any edits.

**If the review requests new or additional tests**, provide specific guidance before the user starts:

- Read the existing test files for the affected module first — identify the test framework, assertion library, describe/it structure, and naming conventions
- Each new test must match the style of existing tests in that file exactly
- Each test asserts one specific behavior — not five things at once
- Cover the edge cases implied by the fix: boundary values, concurrent calls, backwards compatibility, error paths
- A test is meaningful if removing the fix would cause it to fail — if the test passes regardless of the implementation, it tests nothing
- Use precise assertions (`assert.strictEqual(result, expected)`) over vague truthy checks (`assert.ok(result)`)
- Do not mock the thing under test — mock only external dependencies (network, filesystem, time)

When the user signals they are done (e.g. "done", "ready", "implemented"), proceed to Step 6.

### Step 6: Verify

Run the full test suite:

```bash
<project full test command>
```

If the test command is unknown, check `package.json` scripts, `Makefile`, or `README` — or ask the user before proceeding.

Show complete output. If tests fail, stop and wait. Do not proceed to commit until all tests pass.

### Step 7: Draft Commit Message and PR Reply

**Commit message rules:**
- Single line only
- Follows the repo's existing commit format (check `git log --oneline -5`)
- No `Co-Authored-By` trailer
- No mention of Claude, AI, or any tool
- Describes what changed, not who reviewed it

**PR reply rules:**
- Plain English — one short paragraph
- No emoji
- No bullet lists of "I did X, Y, Z"
- Reads like a developer who understood the feedback and made the change
- Does not thank the reviewer excessively or use filler phrases

Show both drafts to the user:

```
Proposed commit message:
  <single line>

Proposed PR reply:
  <one paragraph>
```

Wait for explicit user approval. User may edit either draft. Do not proceed until confirmed.

### Step 8: Execute

On user confirmation:

```bash
git checkout "$pr_branch"
# Stage only files changed since the last commit on this branch
git diff --name-only HEAD
git add <files from above output>
git commit -m "<approved message>"
git log --format="%an <%ae>" -1
git push <fork remote> "$pr_branch"
gh pr comment "$PR_URL" --body "<approved reply>"
```

Stage only the files you changed. Do not stage unrelated working tree changes.

If `git push` fails: do not force-push. Stop and report the error.

Verify attribution after commit — expected: user's configured name and email only.

### Step 9: Report

```
Pushed: <branch> to <fork remote>
Replied: <PR URL>
```

Note: the contribution log entry written by `contribute` is not modified — `revise` does not update the log.

## Red Flags — Stop

| Signal | Action |
|---|---|
| Gate 1 fails (author mismatch) | Stop — do not touch this PR |
| Gate 2 fails (PR not open) | Stop — nothing to address |
| Gate 3 fails (no review/comments) | Stop — ask user to confirm the correct PR URL |
| Gate 4 fails (branch missing) | Stop — user must check out or restore the branch |
| Tests fail after implementation | Stop — do not commit broken code |
| `git config user.name` or `user.email` is empty | Stop — set before proceeding to commit |
| Commit would include `Co-Authored-By` | Remove it before committing |
| PR reply sounds like an AI summary | Rewrite it before posting |
| `git push` rejected | Stop — do not force-push |

## Common Rationalizations — Do Not Act On These

| Thought | Reality |
|---|---|
| "The gate failed but I can tell this is their PR" | Gate 1 exists for a reason. Stop. |
| "The bot comment has a useful suggestion buried in it" | Extract the suggestion, classify as actionable, attribute to the human reviewer |
| "The reply is a bit listy but it covers everything" | Rewrite as a paragraph. Lists read as AI output. |
| "I'll add Co-Authored-By to be transparent" | Iron Law 2. No co-authors. No exceptions. |
| "The tests have one unrelated failure, the fix is fine" | All tests must pass. Investigate the failure. |
| "I'll force-push to fix the push rejection" | Never. Stop and report the error. |
