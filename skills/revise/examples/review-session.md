# Example: Review Session

This shows what a complete `revise` session looks like — from reading maintainer feedback to pushing the revision and replying on the PR. Use this as a reference for tone, gate checks, comment evaluation, and output format at each step.

**Rules:**
- No emoji anywhere — not in commit messages, PR replies, or output
- No mention of Claude, AI, or automation
- PR reply is one paragraph, not a bullet list

## Context

```
PR: https://github.com/markedjs/marked/pull/3924
Branch: fix/async-race-condition-hooks-block
Maintainer review: changes_requested by UziTech — "This looks like a good fix. Can you write some tests?"
```

## Step 0: Access Check

$ ${CLAUDE_PLUGIN_ROOT}/scripts/check-access.sh
ordinary9843

## Gate Verification

All four gates must pass before any changes are made.

| Gate | Check | Result |
|------|-------|--------|
| Gate 1 | pr_author=ordinary9843, current_user=ordinary9843 | pass |
| Gate 2 | state=OPEN | pass |
| Gate 3 | has_changes_requested=1 | pass |
| Gate 4 | branch fix/async-race-condition-hooks-block found locally | pass |

All gates passed. Proceeding.

## Comment Evaluation

| Comment author | Summary | Classification | Reason (if noise) |
|----------------|---------|----------------|-------------------|
| vercel[bot] | Deploy preview ready — preview at markedjs-marked-pr-3924.vercel.app | Noise | Automated bot, no actionable request |
| gemini-code-assist | Code review summary — no critical issues, suggested minor style notes | Noise | Automated bot summary, no unresolved specific request |
| UziTech | "This looks like a good fix. Can you write some tests?" | Actionable | Maintainer explicitly requests test coverage |

One actionable comment. Proceeding to proposed changes.

## Proposed Changes

1. Add concurrent parse/parseInline race condition test — `test/unit/Hooks.test.js` — directly tests the race condition the PR fixes. Edge cases: need async hook delay to expose the timing window; must verify correct block vs inline output is returned for each call.

2. Add tests verifying provideLexer and provideParser receive correct block argument — `test/unit/Hooks.test.js` — confirms the blockType parameter is forwarded correctly to each hook. Edge cases: test both true (parse) and false (parseInline) for each hook so all four combinations are covered.

3. Add backwards compatibility tests for this.block — `test/unit/Hooks.test.js` — the PR restores the hooks.block assignment; must confirm custom hooks reading this.block still receive the correct value in both parse and parseInline contexts.

User confirmed. Proceeding.

## After Implementation

Test run:

```text
177 passing
0 failing
```

All tests pass. Proceeding to commit and reply.

## Drafts

```
Proposed commit message:
  test: add concurrent parse/parseInline race condition and blockType forwarding tests

Proposed PR reply:
  Added tests covering concurrent parse and parseInline calls with async hooks,
  blockType forwarding to provideLexer and provideParser, and this.block
  backwards compatibility for both hooks in both parse modes.
```

User confirmed.

## Execution

```bash
git checkout fix/async-race-condition-hooks-block
git diff --name-only HEAD
# test/unit/Hooks.test.js
git add test/unit/Hooks.test.js
git commit -m "test: add concurrent parse/parseInline race condition and blockType forwarding tests"
git log --format="%an <%ae>" -1
# Jerry Chen <ordinary9843@gmail.com>
git push fork fix/async-race-condition-hooks-block
gh pr comment https://github.com/markedjs/marked/pull/3924 --body "Added tests covering concurrent parse and parseInline calls with async hooks, blockType forwarding to provideLexer and provideParser, and this.block backwards compatibility for both hooks in both parse modes."
```

## Report

```
Pushed: fix/async-race-condition-hooks-block to fork
Replied: https://github.com/markedjs/marked/pull/3924
```

## What to avoid

[NO] PR reply as a bullet list of "I did X, Y, Z"
[NO] Starting the reply with "Thank you for your feedback"
[NO] Mentioning Claude, AI, or automation in the reply
[NO] Force-pushing when push is rejected — investigate the rejection instead
[NO] Committing when tests fail — fix the tests first
