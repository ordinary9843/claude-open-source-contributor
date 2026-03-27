#!/usr/bin/env bash
# gh-call.sh — retry wrapper for all gh CLI API calls
# Provides rate-limit protection and mandatory inter-call sleep.
#
# Usage: gh-call.sh gh <subcommand> [args...]
#   e.g. gh-call.sh gh repo view "owner/repo" --json stargazerCount
#
# Exit codes:
#   0 — success (stdout = raw gh output)
#   1 — fatal: gh not installed or usage error
#   2 — failure: permission error, resource not found, or retries exhausted

set -euo pipefail

# Validate first argument
if [[ "${1:-}" != "gh" ]]; then
    echo "Usage: gh-call.sh gh <subcommand> [args...]" >&2
    exit 1
fi

_contains() { echo "$1" | grep -qiF "$2"; }

attempt=0
max_attempts=3
# retry_wait[i] = seconds to sleep after attempt i fails before attempt i+1
# Only 2 sleeps occur (after attempt 1 and 2); attempt 3 failure exits immediately
retry_wait=(5 15)

while (( attempt < max_attempts )); do
    attempt=$(( attempt + 1 ))

    # Capture stdout and stderr separately
    tmp_out=$(mktemp)
    tmp_err=$(mktemp)
    trap 'rm -f "$tmp_out" "$tmp_err"' EXIT
    set +e
    "$@" >"$tmp_out" 2>"$tmp_err"
    gh_exit=$?
    set -e

    stdout_content=$(cat "$tmp_out")
    stderr_content=$(cat "$tmp_err")
    rm -f "$tmp_out" "$tmp_err"
    trap - EXIT

    if [[ $gh_exit -eq 0 ]]; then
        printf '%s\n' "$stdout_content"
        # Mandatory inter-call sleep: prevents exceeding 1 call/sec density
        sleep 1
        exit 0
    fi

    # --- Check no-retry conditions (evaluated on EACH attempt, no sleep before exit) ---

    # Fatal: gh not installed
    if _contains "$stderr_content" "gh: command not found" || \
       _contains "$stderr_content" "gh: not found"; then
        echo "$stderr_content" >&2
        exit 1
    fi

    # Non-retryable: permission error (403 without rate limit signal)
    if _contains "$stderr_content" "HTTP 403"; then
        if ! _contains "$stderr_content" "rate limit" && \
           ! _contains "$stderr_content" "secondary rate limit" && \
           ! _contains "$stderr_content" "too many requests" && \
           ! _contains "$stderr_content" "API rate limit exceeded"; then
            echo "$stderr_content" >&2
            exit 2
        fi
    fi

    # Non-retryable: resource does not exist
    if _contains "$stderr_content" "Could not resolve to a" || \
       _contains "$stderr_content" "Not Found"; then
        echo "$stderr_content" >&2
        exit 2
    fi

    # --- Retryable: rate limit or generic network error ---

    # If this was the last attempt, fail now (no more retries)
    if (( attempt >= max_attempts )); then
        echo "ERROR: gh-call failed after ${max_attempts} attempts: $*" >&2
        exit 2
    fi

    # Sleep before next attempt (after confirmed failure, not before)
    wait_secs="${retry_wait[$(( attempt - 1 ))]}"
    if _contains "$stderr_content" "rate limit" || \
       _contains "$stderr_content" "secondary rate limit" || \
       _contains "$stderr_content" "too many requests" || \
       _contains "$stderr_content" "API rate limit exceeded"; then
        echo "Rate limit detected, waiting ${wait_secs}s before retry (attempt $attempt/$max_attempts)..." >&2
    else
        echo "gh call failed (attempt $attempt/$max_attempts), waiting ${wait_secs}s before retry..." >&2
    fi
    sleep "$wait_secs"
done

exit 2
