#!/usr/bin/env bash
# session-start.sh — remind the user of pending open-source contributions
# Runs at Claude Code session start via hooks.json
# Outputs to hookSpecificOutput.additionalContext

set -euo pipefail

LOG_FILE="${HOME}/.claude/open-source-contributor/log.json"

# Nothing to report if log does not exist
[[ -f "$LOG_FILE" ]] || exit 0

# Require jq
if ! command -v jq &>/dev/null; then
    exit 0
fi

# Count entries where pr is null
pending_count=$(jq '[.[] | select(.pr == null)] | length' "$LOG_FILE" 2>/dev/null || echo 0)

if [[ "$pending_count" -eq 0 ]]; then
    exit 0
fi

# Emit additionalContext JSON expected by Claude Code hooks
cat <<EOF
{
  "additionalContext": "You have ${pending_count} open-source fix(es) without a submitted PR. Run the 'contribute' skill to submit them, or check ~/.claude/open-source-contributor/log.json for details."
}
EOF
