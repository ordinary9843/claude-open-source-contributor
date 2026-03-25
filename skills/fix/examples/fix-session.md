# Example: Complete Fix Session

This shows what a complete `fix` session looks like — from reading the issue to handing off to `contribute`. Use this as a reference for tone, depth, and output format at each step.

## Example 1: sinonjs/sinon #2656 (success case)

### Input

The user runs `fix` with: `https://github.com/sinonjs/sinon/issues/2656`

### Step 2 — Issue Thread Summary

After fetching the full thread via `gh issue view https://github.com/sinonjs/sinon/issues/2656 --comments`:

> **Issue:** Behavior setters don't clear competing flags, causing silent override
>
> Reported behavior: `stub.returnsArg(0).returns(42)` returns the argument instead of `42`. The later `returns()` call should win, but doesn't.
>
> Maintainer comment: "Looks like a real bug. `invoke()` checks `returnArgAt` before `returnValue` so the order of checks inside `invoke()` controls the outcome, not the order the setters were called."
>
> No linked PRs. No one claiming this.

**Verdict:** Real bug. No one working on it. Maintainer acknowledged. Proceed.

### Step 3 — Confirm with User

Repository: sinonjs/sinon
Issue: #2656 — Behavior setters don't clear competing flags, causing silent override
Bug: When chaining behavior setters like .returnsArg(0).returns(42), the later setter is silently ignored because invoke() checks returnArgAt before returnValue.

Proceed with clone?

### Step 6 — Root Cause Statement

> "The bug occurs because `returnsArg()` sets `returnArgAt` and `returns()` sets `returnValue`, but neither clears the other — and `behavior.invoke()` checks `returnArgAt` before `returnValue`, so the earlier setter wins regardless of call order."

### Step 7 — Failing Test (red state)

Written in `test/stub-test.js`:

```javascript
it("returns() should supersede prior returnsArg()", function () {
    const stub = sinon.stub();
    stub.returnsArg(0).returns(42);
    assert.equals(stub("ignored"), 42);
});
```

Run: `npm test test/stub-test.js --grep "supersede"`

Output (red state):
```text
AssertionError: expected 'ignored' to equal 42
```

### Step 8 — Fix

Added `resetReturnBehavior()` helper in `lib/sinon/behavior.js` that clears all mutually exclusive return-behavior flags. Called at the start of each setter (`returnsArg`, `returns`, `returnsThis`, `throws`, etc.).

Files changed: `lib/sinon/behavior.js`, `test/stub-test.js` (new test only).

### Step 9 — Verify

```bash
npm test
```

```text
1485 passing (12s)
0 failing
```

Linter: `npm run lint` — no new errors.

### Step 11 — Hand-off Report

```text
Root cause: returnsArg() and returns() both set competing state flags but never clear each
            other's; invoke() checks flags in a fixed priority order, so the first-called
            setter always wins.
What changed: lib/sinon/behavior.js — added resetReturnBehavior() that clears returnValue,
              returnArgAt, returnThis, and related flags before each setter runs.
Test coverage: New test verifies that returnsArg(0).returns(42) resolves to 42. Existing
               test suite (1485 tests) continues to pass with no regressions.
```

Ready to open a PR? Run `contribute` to commit, push, and submit.

## What to avoid

[NO] Claiming root cause before you can complete the "The bug occurs because..." sentence
[NO] Writing the fix before observing the test in the red state
[NO] Summarizing test output ("all tests pass") instead of showing the full terminal output
[NO] Changing unrelated code while "cleaning up"

## Example 2: Disqualified Issue (failure case)

### Input

The user runs `fix` with: `https://github.com/expressjs/express/issues/4501`

### Step 2 — Issue Thread Summary

After fetching via `gh issue view https://github.com/expressjs/express/issues/4501 --comments`:

> **Issue:** `res.json()` should support bigint serialization
>
> Maintainer comment (3 months ago): "This is intentionally delegated to the user. Express will not bundle a JSON serializer — configure `app.set('json replacer', ...)` if you need bigint support. Closing as by design."
>
> Issue closed. Label: `wontfix`.

**Verdict:** Disqualified — maintainer closed as by design. Report to user and stop.

### Reported to user

Issue expressjs/express #4501 is disqualified.

The maintainer closed it as "by design" — bigint serialization is intentionally delegated to users via `app.set('json replacer', ...)`. This is not a bug the maintainers will accept a fix for.

Run `hunt` to find a different issue.

Do not clone. Do not create a branch. Stop here.

## Example 3: Directory Collision (edge case)

### Input

The user runs `fix` with: `https://github.com/hapijs/joi/issues/3089` but `~/Workspaces/joi/` already exists from a previous session.

### Step 4 — Collision Handling

The directory ~/Workspaces/joi/ already exists. How should I proceed?

1. Remove it and clone fresh (rm -rf ~/Workspaces/joi/)
2. Use the existing directory as-is (only if it is this same repo with a clean working tree)
3. Abort

User selects **2**.

Verify:

```bash
git remote get-url origin
# → https://github.com/hapijs/joi.git  [OK] correct upstream

git status
# → nothing to commit, working tree clean  [OK] clean
```

Both checks pass. Continue from Step 5 (create fix branch). Do not re-clone.
