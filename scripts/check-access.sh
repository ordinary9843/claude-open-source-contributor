#!/usr/bin/env bash
# check-access.sh — verify all required dependencies are present and gh is authenticated
# Exits 0 and prints the authenticated GitHub username on success
# Exits 1 with an error message on any failure

set -euo pipefail

# Check gh CLI
if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI is not installed. Install it from https://cli.github.com" >&2
    exit 1
fi

# Check jq
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is not installed. Install it with: brew install jq" >&2
    exit 1
fi

# Check gh authentication
if ! gh auth status &>/dev/null; then
    echo "ERROR: gh CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi

# Print authenticated username
gh api user --jq '.login'
