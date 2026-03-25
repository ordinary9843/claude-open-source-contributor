#!/usr/bin/env bash
# setup.sh — pre-flight setup for open-source-contributor plugin
# Safe to run multiple times (idempotent).
# Can be run directly from terminal: bash scripts/setup.sh
#
# Steps:
#   1. Check gh is installed
#   2. Check jq is installed
#   3. Warn if python3 is missing (non-fatal)
#   4. chmod +x all plugin scripts
#   5. mkdir ~/.claude/open-source-contributor/
#   6. Initialize log.json via log.sh init

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Setting up open-source-contributor plugin..."

# Step 1: Check gh
if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI is not installed." >&2
    echo "Install: https://cli.github.com" >&2
    exit 1
fi
echo "[OK] gh found: $(gh --version | head -1)"

# Step 2: Check jq
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is not installed." >&2
    echo "Install: brew install jq  OR  apt install jq  OR  https://jqlang.github.io/jq/" >&2
    exit 1
fi
echo "[OK] jq found: $(jq --version)"

# Step 3: Check python3 (non-fatal, used as date fallback)
if ! command -v python3 &>/dev/null; then
    echo "[WARN] python3 not found — date fallback limited to BSD/GNU date only"
else
    echo "[OK] python3 found: $(python3 --version)"
fi

# Step 4: chmod +x explicit file list
chmod +x \
    "${PLUGIN_ROOT}/scripts/check-access.sh" \
    "${PLUGIN_ROOT}/scripts/gh-call.sh" \
    "${PLUGIN_ROOT}/scripts/log.sh" \
    "${PLUGIN_ROOT}/scripts/screen-issue.sh" \
    "${PLUGIN_ROOT}/scripts/setup.sh" \
    "${PLUGIN_ROOT}/scripts/validate.sh" \
    "${PLUGIN_ROOT}/hooks/session-start.sh"
echo "[OK] chmod +x applied to all plugin scripts"

# Step 5: Create log directory
mkdir -p "${HOME}/.claude/open-source-contributor/"
echo "[OK] log directory ready: ${HOME}/.claude/open-source-contributor/"

# Step 6: Initialize log.json via log.sh
"${PLUGIN_ROOT}/scripts/log.sh" init

echo ""
echo "Setup complete. Run /open-source-contributor:hunt to start."
