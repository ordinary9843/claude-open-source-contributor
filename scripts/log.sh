#!/usr/bin/env bash
# log.sh — manage ~/.claude/open-source-contributor/log.json
# Requires: jq
#
# Usage:
#   log.sh check-issue <issue-url>   → exits 0 if issue already in log, 1 if not
#   log.sh append <json-entry>       → append new entry to log
#   log.sh update-pr <issue-url> <pr-url>  → set pr field for matching entry
#   log.sh list                      → print all entries as JSON array
#   log.sh pending                   → print entries where pr is null

set -euo pipefail

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is not installed. Install it with: brew install jq" >&2
    exit 1
fi

# Override in tests via: LOG_FILE=/tmp/test-log.json log.sh ...
LOG_FILE="${LOG_FILE:-${HOME}/.claude/open-source-contributor/log.json}"

_ensure_log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        echo '[]' > "$LOG_FILE"
    fi
}

_validate_json() {
    # jq empty has a jq-1.6 bug (exits 0 on parse errors); jq -e . is reliable
    if ! jq -e . "$LOG_FILE" > /dev/null 2>&1; then
        echo "ERROR: $LOG_FILE contains invalid JSON" >&2
        exit 3
    fi
}

cmd="${1:-}"

case "$cmd" in

init)
    if [[ -f "$LOG_FILE" ]]; then
        if ! jq -e . "$LOG_FILE" > /dev/null 2>&1; then
            echo "ERROR: $LOG_FILE exists but contains invalid JSON." >&2
            echo "Fix: mv $LOG_FILE ${LOG_FILE}.bak && run setup.sh again to reinitialize." >&2
            exit 3
        fi
        echo "OK: log.json already exists and is valid at $LOG_FILE, skipping"
    else
        mkdir -p "$(dirname "$LOG_FILE")"
        echo '[]' > "$LOG_FILE"
        echo "OK: log.json initialized at $LOG_FILE"
    fi
    ;;

check-issue)
    issue_url="${2:?Usage: log.sh check-issue <issue-url>}"
    _ensure_log
    _validate_json
    count=$(jq --arg url "$issue_url" '[.[] | select(.issue == $url)] | length' "$LOG_FILE")
    if [[ "$count" -gt 0 ]]; then
        exit 0   # found
    else
        exit 1   # not found
    fi
    ;;

append)
    entry="${2:?Usage: log.sh append <json-entry>}"
    _ensure_log
    _validate_json
    if ! echo "$entry" | jq -e . > /dev/null 2>&1; then
        echo "ERROR: append entry is not valid JSON" >&2
        exit 3
    fi
    # --- format validation ---
    for field in repo issue description; do
        val=$(echo "$entry" | jq -r --arg f "$field" '.[$f] // empty')
        if [[ -z "$val" ]]; then
            echo "ERROR: append entry missing required field: $field" >&2
            exit 3
        fi
    done
    pr_type=$(echo "$entry" | jq -r '.pr | type')
    case "$pr_type" in
        "null") : ;;
        "string")
            pr_val=$(echo "$entry" | jq -r '.pr')
            if [[ -z "$pr_val" ]]; then
                echo "ERROR: .pr is empty string — must be a URL or null" >&2; exit 3
            fi
            ;;
        *)
            echo "ERROR: .pr must be string or null, got: $pr_type" >&2; exit 3
            ;;
    esac
    # --- format validation end ---
    today=$(date +%F)
    tmp=$(mktemp)
    # Always stamp today's date — callers do not need to supply it
    jq --argjson entry "$entry" --arg date "$today" \
        '. + [$entry | .date = $date]' "$LOG_FILE" > "$tmp"
    mv "$tmp" "$LOG_FILE"
    echo "OK: entry appended (date: $today)"
    ;;

update-pr)
    issue_url="${2:?Usage: log.sh update-pr <issue-url> <pr-url>}"
    pr_url="${3:?Usage: log.sh update-pr <issue-url> <pr-url>}"
    _ensure_log
    _validate_json
    count=$(jq --arg url "$issue_url" '[.[] | select(.issue == $url and .pr == null)] | length' "$LOG_FILE")
    if [[ "$count" -eq 0 ]]; then
        echo "ERROR: no pending entry found for issue $issue_url" >&2
        exit 3
    fi
    tmp=$(mktemp)
    jq --arg url "$issue_url" --arg pr "$pr_url" \
        'map(if .issue == $url and .pr == null then .pr = $pr else . end)' \
        "$LOG_FILE" > "$tmp"
    mv "$tmp" "$LOG_FILE"
    echo "OK: pr updated to $pr_url"
    ;;

list)
    _ensure_log
    _validate_json
    jq '.' "$LOG_FILE"
    ;;

pending)
    _ensure_log
    _validate_json
    jq '[.[] | select(.pr == null)]' "$LOG_FILE"
    ;;

*)
    echo "Usage: log.sh <init|check-issue|append|update-pr|list|pending> [args...]" >&2
    exit 1
    ;;

esac
