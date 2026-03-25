# Claude Open Source Contributor

## Plugin Commands

```text
/open-source-contributor:hunt       →  find a valid GitHub issue to fix
/open-source-contributor:fix        →  reproduce, test, and fix a bug
/open-source-contributor:contribute →  commit, push, and open a PR
/open-source-contributor:revise     →  address PR review feedback and reply
```

Run skills in sequence for the full workflow, or jump to any step directly. `fix` and `contribute` accept a GitHub issue URL or PR branch as context.

## Project Architecture

- **`.claude-plugin/`**: `plugin.json` and `marketplace.json` — plugin manifest and marketplace registration
- **`skills/hunt/`**: Search skill — finds qualifying issues across active repositories
- **`skills/fix/`**: Fix skill — reproduces bugs, writes failing tests, implements minimal fix, verifies
- **`skills/contribute/`**: Contribute skill — commits, pushes to fork, opens PR, updates log
- **`skills/revise/`**: Revise skill — reads PR review, evaluates comments, proposes changes, commits and replies after user implements
- **`skills/*/examples/`**: Reference examples loaded by skills at runtime — do not remove
- **`scripts/check-access.sh`**: Pre-flight check for `gh` auth and `jq` — called by all three skills at startup
- **`scripts/gh-call.sh`**: Rate-limit-safe wrapper for all `gh` API calls — retry with backoff, mandatory 1s inter-call sleep
- **`scripts/screen-issue.sh`**: Structured pre-screener for `hunt` — checks repo quality, linked PRs, recency; structured stdout output with `=== SCREEN ... ===` prefixes
- **`scripts/log.sh`**: jq-based log manager for `~/.claude/open-source-contributor/log.json`
- **`scripts/setup.sh`**: One-time setup — verifies deps, chmod scripts, initializes log
- **`scripts/validate.sh`**: Dry-run environment validation — confirms gh auth and API connectivity
- **`hooks/session-start.sh`**: SessionStart hook — reminds user of pending (`pr: null`) contributions

## Key Rules

### Git Operations
- Always use the author's git config — never override name or email
- No co-author trailers (no `Co-Authored-By` lines of any kind)
- Commit messages must be a single line only
- PR titles and descriptions must be professional plain English — no emoji anywhere

### Skills
- Iron Laws in each skill are non-negotiable — do not soften or add exceptions
- All three skills call `check-access.sh` first — this is the single gate for `gh` auth and `jq`
- `fix` writes a partial log entry (`pr: null`); `contribute` fills in the real PR URL
- Script paths use `${CLAUDE_PLUGIN_ROOT}/scripts/` — never relative paths

### Scripts
- `check-access.sh` exits non-zero on any missing dependency — treat non-zero as fatal
- `gh-call.sh` wraps all `gh` API calls with retry and rate-limit protection; exits 0 (success), 1 (fatal: gh not installed or usage error), 2 (retries exhausted or non-retryable error)
- `screen-issue.sh` exits 0 (pass, stdout: `=== SCREEN PASS ===` then JSON), 2 (disqualified or per-issue API error, stdout: `=== SCREEN DISQUALIFIED:` or `=== SCREEN ERROR:`), or 1 (fatal, stdout: `=== SCREEN ERROR: fatal — ...`)
- `log.sh` auto-stamps today's date on `append` — callers must not include a `date` field
- `log.sh init` initializes log.json if not present; validates format if file exists
- All JSON operations go through `log.sh` — never manipulate `log.json` directly with Claude

### Contribution Log
- Location: `~/.claude/open-source-contributor/log.json` (global, not in this repo)
- Schema: `repo`, `issue` (URL), `pr` (URL or null), `description`, `date`
- `hunt` and `fix` check the log before proceeding — prevents duplicate work

## Dev Setup

```shell
# Install (run steps in order)
claude plugin marketplace add .
claude plugin install open-source-contributor@claude-open-source-contributor
bash scripts/setup.sh      # verify deps, chmod, init log
bash scripts/validate.sh   # dry-run validation (requires network)

# Validate
claude plugin validate .

# Test (no automated suite — validate manually)
claude /open-source-contributor:hunt
claude /open-source-contributor:fix https://github.com/owner/repo/issues/123
```

## Dependencies

- `gh` CLI — authenticated via `gh auth login`
- `jq` — required for all log operations (`brew install jq`)
