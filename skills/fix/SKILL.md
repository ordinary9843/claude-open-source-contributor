---
name: fix
description: Reproduces and resolves a GitHub bug report by reading the full issue thread, establishing root cause, writing a failing test, implementing the minimal fix, and verifying the full test suite — when the user provides a GitHub issue URL or asks to fix an open-source bug, patch a library issue, or contribute a bugfix
---

# Fix — Reproduce, Debug, and Fix

## The Three Iron Laws

```
1. NO FIX WITHOUT CONFIRMED ROOT CAUSE
   If you cannot explain in one sentence exactly why the bug occurs
   and point to the specific code responsible — you do not have root cause.

2. NO FIX CODE WITHOUT A FAILING TEST FIRST
   Write the test. Run it. Watch it fail. Only then write the fix.
   If you write fix code before observing the red state, delete it and start over.

3. NO COMPLETION CLAIM WITHOUT FRESH VERIFICATION EVIDENCE
   Run the full test suite and linter in this step.
   Show the complete output. Summaries do not count as evidence.
```

**Violating the letter of these laws is violating the spirit of them.**

## Overview

**Core principle:** Understand before touching. Test before fixing. Verify before claiming.

**Announce at start:** "I'm using the fix skill to reproduce and fix this issue."

For a complete worked example, load `examples/fix-session.md`.

## Process

If `$ARGUMENTS` contains a GitHub issue URL, use it directly in Step 2 — skip asking the user what issue to fix.

### Step 1: Verify GitHub Access

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-access.sh
```

`check-access.sh` exits non-zero if `gh` is not installed or not authenticated. **Stop immediately if it fails** — print the error and instruct the user to run `gh auth login`. All subsequent steps use `gh` exclusively.

### Step 2: Read the Full Issue Thread

Fetch body and comments separately. Extract `<number>` and `<owner/repo>` from the issue URL — `--comments` alone skips the body entirely and returns empty when there are 0 comments:

```bash
# Always read body first
gh issue view <number> --repo <owner/repo>

# Then read comments only if the above shows comments: N where N > 0
gh issue view <number> --repo <owner/repo> --comments
```

**Disqualify the issue if ANY of the following is true:**

| Signal | Action |
|---|---|
| Maintainer commented `won't fix`, `by design`, `wontfix`, `duplicate` | Stop — report to user |
| Maintainer closed the issue as invalid or by design | Stop — report to user |
| Any contributor has claimed they are actively working on it | Stop — report to user |
| A linked PR attempted this fix and was rejected by maintainers | Stop — report to user |
| A linked PR was abandoned by contributor — but maintainer showed interest | Evaluate carefully before proceeding |
| Comments suggest the bug is fixed in a newer unreleased version | Stop — report to user |
| Ongoing maintainer disagreement about whether this is a bug | Stop — report to user |
| Issue is a feature request, not a bug | Stop — report to user |
| Issue is documentation-only | Stop — report to user |

If the issue is disqualified, report the specific reason to the user and stop. Do not proceed to clone.

### Step 3: Confirm with User

Summarize clearly:
- Repository name
- Issue title and number
- Your understanding of the bug in one sentence

Ask for confirmation before cloning. Wait for explicit approval.

### Step 4: Clone

```bash
git clone <upstream-url> ~/Workspaces/<repo-name>/
```

**Collision handling — if `~/Workspaces/<repo-name>/` already exists:**

Stop and present three options:

```text
The directory ~/Workspaces/<repo-name>/ already exists. How should I proceed?

1. Remove it and clone fresh (rm -rf ~/Workspaces/<repo-name>/)
2. Use the existing directory as-is (only if it is this same repo with a clean working tree)
3. Abort
```

Do not proceed without an explicit choice. Do not overwrite silently.

If option 2 is chosen, verify with `git remote get-url origin` (must point to the expected upstream) and `git status` (must show clean tree) before continuing.

### Step 5: Create Fix Branch

```bash
cd ~/Workspaces/<repo-name>/
git checkout -b fix/<short-slug>
```

Where `<short-slug>` is 2–4 words from the issue title, hyphenated, lowercase.
Example: `fix/return-behavior-override`, `fix/header-property-corruption`

**All work from this point happens on this branch. Never commit to the default branch.**

### Step 6: Reproduce — Find Root Cause

*(Applies `superpowers:systematic-debugging` behavior)*

1. Read all error messages completely — stack traces, file paths, line numbers
2. Reproduce the bug consistently — find the minimal input that triggers it
3. Trace the execution path from the symptom back to the cause
4. Identify the specific function, line, or logic that is wrong

**Root cause is established when** you can complete this sentence:
> "The bug occurs because [specific code/logic] [does wrong thing] when [condition]."

Do not proceed to Step 7 until you can state this clearly.

### Step 7: Write Failing Test

*(Applies `superpowers:test-driven-development` behavior)*

**Before writing anything, read the existing test files for the affected module.** Understand:
- The test framework and assertion library in use (`assert.strictEqual`, `expect().toBe()`, `t.is()`, etc.)
- The describe/it structure and naming conventions (`should ...`, `throws when ...`, etc.)
- How existing tests are organized — by method, by scenario, or by input type
- Any test helpers or fixtures already defined

Your new test must be indistinguishable in style from the tests already in that file.

**Writing the test:**
1. Write the test that demonstrates the bug
2. Run it: `<project test command> <specific test>`
3. **Observe the red state** — confirm it fails with the expected failure reason
4. If the test passes before the fix, it does not test the right thing — rewrite it

**Test quality rules:**
- **One behavior per test** — each test asserts one specific thing; a test that checks five behaviors in sequence is five tests waiting to be written
- **Targets the exact failure** — the test must fail for the reason described in the issue, not for an unrelated reason
- **Covers the bug's edge cases** — think: what input variations trigger this bug? boundary values, empty collections, null/undefined inputs, concurrent calls, error paths
- **Would have caught this bug** — if the test would have passed before the fix, it does not test the right thing; rewrite it
- **Does not duplicate existing passing tests** — read existing tests first; do not re-test behavior that is already covered
- **Meaningful assertion** — `assert.strictEqual(result, expectedValue)` over `assert.ok(result)` wherever possible; vague truthy checks hide bugs
- **No over-mocking** — mock only what you must (network, filesystem, time); mocking the thing under test defeats the purpose

**Anti-patterns — if you are doing any of these, stop and reconsider:**
- Testing that a function was called rather than what it returned
- A test that always passes regardless of the implementation
- Asserting on implementation details that could change without the behavior changing
- A test name that says "should work" with no description of what "work" means

### Step 8: Implement Fix

Write the minimal code change that makes the failing test pass.

- Do not refactor unrelated code
- Do not add features beyond the bug fix
- Do not change test files other than the new test written in Step 7

### Step 9: Verify

*(Applies `superpowers:verification-before-completion` behavior)*

Run the **full test suite** — not just the new test:

```bash
<project full test command>
```

Then run the linter if the project has one:

```bash
<project lint command>
```

**Show the complete output.** Do not summarize. If the output exceeds ~200 lines, show the full summary block (total pass/fail counts, all failure messages in full) and the last 20 lines — never abbreviate individual test failure messages. All tests must pass. Linter must produce no new errors.

If anything fails — fix it before proceeding.

### Step 10: Write Partial Log Entry

Append a partial entry to the contribution log (`pr: null` will be filled by `contribute`):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/log.sh append '{
  "repo": "owner/name",
  "issue": "https://github.com/owner/repo/issues/<number>",
  "pr": null,
  "description": "<one specific sentence — not fixed a bug but what exactly was fixed>"
}'
```

`log.sh` stamps today's date automatically — do not add a `date` field.

**If the log write fails** (permission error, missing directory, malformed existing JSON, `jq` not installed):
- Report the failure to the user
- Show the entry they should add manually to `~/.claude/open-source-contributor/log.json` (include `"date": "YYYY-MM-DD"` with today's date, since `log.sh` would have stamped it automatically)
- Do not stop the workflow — proceed to Step 11

### Step 11: Report and Hand Off

Output the following format exactly:

```text
Root cause: <one sentence — "The bug occurs because [code] [does wrong] when [condition].">
What changed: <file(s) and what logic was modified>
Test coverage: <what the new test verifies and which edge cases it covers>
```

Then ask: "Ready to open a PR? Run `contribute` to commit, push, and submit."

## Red Flags — Stop and Return to Earlier Step

| Signal | Action |
|---|---|
| `check-access.sh` fails | Stop — user must run `gh auth login` before any work |
| Cannot explain exactly why the bug occurs | Return to Step 6 |
| Failing test passes before the fix is written | Test is wrong — return to Step 7 |
| Fix requires changing more than the minimal necessary code | Scope down or reconsider the approach |
| Full test suite has failures unrelated to the fix | Investigate — do not ignore pre-existing failures |
| Linter reports new errors introduced by the fix | Fix them before proceeding |

## Common Rationalizations — Do Not Act On These

| Thought | Reality |
|---|---|
| "I understand the bug, I'll write the test after the fix" | Iron Law 2. Write test first. No exceptions. |
| "The new test passes, I don't need to run the full suite" | Iron Law 3. Full suite, full output. |
| "I can see the root cause just by reading the code" | Reproduce it. Assumptions are not root cause. |
| "The fix is small, linting can wait" | New lint errors from the fix are your responsibility. |
| "gh isn't available but I can use WebSearch to read the issue" | gh is required. Stop and fix auth first. |
