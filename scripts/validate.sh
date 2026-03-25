#!/usr/bin/env bash
# validate.sh — dry-run environment validation for open-source-contributor plugin
#
# REQUIRES NETWORK: Step 2 makes a real GitHub API call (one issue screening).
# Purpose: confirm that gh auth, API connectivity, and script logic all work.
#
# Prints [PASS] or [FAIL] for each step.
# Exit 0 if all pass, exit 1 if any fail.
#
# Can be run directly from terminal: bash scripts/validate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${HOME}/.claude/open-source-contributor/log.json"

# Known stable public issue used for API connectivity test
# (from hunt SKILL.md examples — a real issue that has existed for years)
TEST_ISSUE_URL="https://github.com/sinonjs/sinon/issues/2656"

all_passed=true

echo "Validating open-source-contributor environment..."
echo ""

# --- Step 1: gh authentication ---
echo "Step 1: Checking gh authentication..."
if auth_out=$("${PLUGIN_ROOT}/scripts/check-access.sh" 2>&1); then
    echo "[PASS] gh authenticated as ${auth_out}"
else
    echo "[FAIL] check-access: ${auth_out}"
    all_passed=false
fi

# --- Step 2: screen-issue.sh API connectivity ---
echo ""
echo "Step 2: Testing screen-issue.sh with known issue URL..."
echo "  (This makes real GitHub API calls — requires network)"
echo "  URL: ${TEST_ISSUE_URL}"

set +e
screen_out=$(CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}" \
    "${PLUGIN_ROOT}/scripts/screen-issue.sh" "${TEST_ISSUE_URL}" 2>/dev/null)
screen_exit=$?
set -e

# exit 0 + SCREEN PASS = validated and qualified
# exit 2 + SCREEN DISQUALIFIED or SCREEN ERROR = script ran correctly
# exit 1 = fatal dependency error
if [[ $screen_exit -eq 0 ]] && echo "$screen_out" | grep -q "=== SCREEN PASS ==="; then
    echo "[PASS] screen-issue.sh: issue passed screening"
elif [[ $screen_exit -eq 2 ]] && echo "$screen_out" | grep -qE "=== SCREEN (DISQUALIFIED|ERROR):"; then
    prefix=$(echo "$screen_out" | head -1)
    echo "[PASS] screen-issue.sh: script ran correctly (${prefix})"
else
    echo "[FAIL] screen-issue.sh: fatal error (exit ${screen_exit})"
    echo "  Output: $(echo "$screen_out" | head -1)"
    all_passed=false
fi

# --- Step 3: log.json validation ---
echo ""
echo "Step 3: Checking log.json..."
if [[ ! -f "$LOG_FILE" ]]; then
    echo "[FAIL] log.json not found at ${LOG_FILE} — run 'bash scripts/setup.sh' first"
    all_passed=false
elif jq -e . "$LOG_FILE" > /dev/null 2>&1 && \
     [[ "$(jq 'if type == "array" then "yes" else "no" end' "$LOG_FILE")" == '"yes"' ]]; then
    entry_count=$(jq 'length' "$LOG_FILE")
    echo "[PASS] log.json is valid (${entry_count} entries)"
else
    echo "[FAIL] log.json: invalid JSON or not an array at ${LOG_FILE}"
    all_passed=false
fi

# --- Summary ---
echo ""
if [[ "$all_passed" == "true" ]]; then
    echo "All checks passed. Environment is ready."
    exit 0
else
    echo "Validation failed. Fix the issues above before running hunt/fix/contribute."
    exit 1
fi
