# Example: hunt Candidate Output

This is what a well-formatted `hunt` result looks like. Use this as a reference when presenting candidates to the user.

## Success case: 4 candidates found

I found 4 candidates that passed all four layers. Which would you like me to fix?

**1. sinonjs/sinon** (9,800 stars)
Issue: #2656 — Behavior setters don't clear competing flags, causing silent override
URL: https://github.com/sinonjs/sinon/issues/2656
Last repo commit: 2026-03-10
Last activity: 2026-02-14
Maintainer engaged: yes
Fork exists: no
Why it qualifies: `returnsArg()` followed by `returns()` silently returns the argument instead of the specified value — confirmed bug, no linked PR, maintainer acknowledged it.

**2. forwardemail/supertest** (14,200 stars)
Issue: #876 — `res.header` corrupted when content-type param matches a header key
URL: https://github.com/forwardemail/supertest/issues/876
Last repo commit: 2026-03-18
Last activity: 2026-03-01
Maintainer engaged: yes
Fork exists: yes
Why it qualifies: `_setHeaderProperties` overwrites `this.header` with a string when content-type includes `header=<value>` — reproducible, no PR attempted, active maintainer.

**3. hapijs/joi** (21,000 stars)
Issue: #3089 — `object.pattern()` does not apply `convert` option to matched keys
URL: https://github.com/hapijs/joi/issues/3089
Last repo commit: 2026-03-20
Last activity: 2026-03-05
Maintainer engaged: no
Fork exists: no
Why it qualifies: Conversion silently skipped on pattern-matched keys — test case in issue confirms it, no one working on it, labeled `bug`.

**4. markedjs/marked** (34,500 stars)
Issue: #3201 — Nested blockquotes not rendered correctly when followed by a list
URL: https://github.com/markedjs/marked/issues/3201
Last repo commit: 2026-03-22
Last activity: 2026-01-10
Maintainer engaged: yes
Fork exists: no
Why it qualifies: Clear rendering regression with minimal reproduction case, no PR, maintainer confirmed it is a bug 2 months ago.

Please select 1–4, or type "more" to search for additional candidates.

## Failure case: no valid candidates found

After screening 100 issues through all four layers, no candidates passed.

No valid candidates found in this search pass.

Layer breakdown:
- 41 issues disqualified by screen-issue.sh: linked open PR (18), merged fix exists (12), repo abandoned (7), archived repo (4)
- 22 issues already in contribution log
- 30 issues passed screening — disqualified after reading full thread: wontfix/by design (12), feature request (9), actively claimed (5), no reproduction steps (4)

To try again, reply "more". To narrow to a specific language or repo, specify it: e.g., "search Python repos" or "try vuejs/vue".

## Layer 2 screen example: script disqualification

Running `screen-issue.sh https://github.com/expressjs/express/issues/4501`:

```text
DISQUALIFIED: there is an open PR addressing this issue
```

This issue was excluded before Claude read the thread. No further evaluation needed.

## Layer 3 dedup example: issue already in log

`log.sh check-issue https://github.com/sinonjs/sinon/issues/2656` returned 0 (found).

Output: `already logged — skip`

The contribution log shows this was fixed on 2026-03-25 with PR at `https://github.com/sinonjs/sinon/pull/2682`. Excluded from candidates.
