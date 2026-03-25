# Example: PR Body

This is what a well-written PR body looks like. Use this as a reference when composing the PR description.

**Rules:**
- Plain English — reads like a developer who found and fixed the bug
- No mention of Claude, AI, automation, or any tool
- Describes: the problem, the root cause, and the fix
- References the issue number
- Concise — not exhaustive

## Example 1: Logic bug (sinon)

When chaining behavior setters like `stub.returnsArg(0).returns(42)`, the later call to `returns()` should win — but it doesn't. The stub still returns the argument instead of `42`.

The root cause is that `returnsArg()` sets `returnArgAt`, and `returns()` sets `returnValue` — but neither clears the other. Since `behavior.invoke()` checks `returnArgAt` before `returnValue`, the earlier setter silently persists regardless of call order.

This fix adds a `resetReturnBehavior()` helper that clears all mutually exclusive return-behavior flags before each setter runs, ensuring the most recently called setter always takes effect.

Fixes #2656

## Example 2: Property corruption (supertest)

When a server sets a `content-type` header with a parameter whose name matches an existing property (e.g., `text/csv; header=present`), the `_assertHeader` check fails for unrelated headers.

The issue is in superagent's `_setHeaderProperties`, which expands content-type parameters directly onto `this`. When the parameter is named `header`, it overwrites `this.header` — the headers object — with a string. Subsequent calls to `res.header['foo']` then return `undefined`.

This fix changes `_assertHeader` to use `res.headers` (the raw Node.js headers object) instead of `res.header`, which is never overwritten by `_setHeaderProperties`.

Fixes #876

## Example 3: Type coercion edge case (joi)

When using `object.pattern()` with `convert: true`, matched keys are validated but the coercion step is silently skipped — so a numeric string like `"42"` is returned unchanged instead of being converted to `42`.

The issue is in `_validator.js` where the pattern-matched value is validated without passing the current `options` object into the inner schema's `_validate()` call. Since `convert` lives in options, it never reaches the inner type check.

This fix threads the parent options through to the inner schema validation for pattern-matched keys, matching the behaviour already present for non-pattern keys.

Fixes #3089

## What to avoid

[NO] "This PR was generated with the help of AI tools."
[NO] "Claude identified the root cause as..."
[NO] "I used automated analysis to find this bug."
[NO] Walls of text explaining every file touched
[NO] Repeating the commit message verbatim as the PR title

## Failure case: log write failed after PR was opened

The PR is already open. The log write failed (jq not installed). Report to the user — do not roll back the PR.

PR opened: https://github.com/hapijs/joi/pull/3102

Log write failed: jq is not installed. Add this entry manually to `~/.claude/open-source-contributor/log.json`:

```json
{
  "repo": "hapijs/joi",
  "issue": "https://github.com/hapijs/joi/issues/3089",
  "pr": "https://github.com/hapijs/joi/pull/3102",
  "description": "object.pattern() now threads options through to inner schema validation so convert:true applies to matched keys",
  "date": "2026-03-25"
}
```

The PR is real. Do not reopen it. Fix the log manually.
