#!/usr/bin/env bash
# screen-issue.sh — structured pre-screening for a GitHub issue before Claude reads the thread
#
# Usage: screen-issue.sh <issue-url>
#   e.g. screen-issue.sh https://github.com/sinonjs/sinon/issues/2656
#
# Exit codes:
#   0  — passed all checks
#   1  — fatal: dependency missing or usage error
#   2  — disqualified or per-issue API error (skip and continue)
#
# stdout is structured with prefix separators for Claude to parse:
#   === SCREEN PASS ===        (exit 0) followed by JSON on next line
#   === SCREEN DISQUALIFIED: <reason> ===  (exit 2)
#   === SCREEN ERROR: <reason> ===         (exit 2, API error for this issue)
#   === SCREEN ERROR: fatal — <reason> === (exit 1, dependency missing)
#
# stderr is plain text for human reading.
# Rate limit protection: sleep 2s before exit 0 (inter-issue gap).

set -euo pipefail

ISSUE_URL="${1:-}"
if [[ -z "$ISSUE_URL" ]]; then
    echo "=== SCREEN ERROR: fatal — Usage: screen-issue.sh <issue-url> ==="
    exit 1
fi

# --- Parse owner/repo/number from URL ---
if [[ ! "$ISSUE_URL" =~ ^https://github\.com/([^/]+)/([^/]+)/issues/([0-9]+)$ ]]; then
    echo "=== SCREEN ERROR: fatal — not a valid GitHub issue URL: $ISSUE_URL ==="
    exit 1
fi
OWNER="${BASH_REMATCH[1]}"
REPO="${BASH_REMATCH[2]}"
NUMBER="${BASH_REMATCH[3]}"
REPO_FULL="$OWNER/$REPO"

# --- Cross-platform date helper (GNU date → BSD date → python3) ---
_date_minus_months() {
    local months=$1
    local days=$(( months * 30 ))
    { date -d "${days} days ago" +%Y-%m-%d 2>/dev/null; } && return
    { date -v-${months}m +%Y-%m-%d 2>/dev/null; } && return
    { python3 -c "from datetime import date,timedelta; \
print((date.today()-timedelta(days=${days})).isoformat())" 2>/dev/null; } && return
    echo "=== SCREEN ERROR: fatal — cannot compute date offset — install GNU date or python3 ==="
    exit 1
}

cutoff=$(_date_minus_months 6)
three_months_ago=$(_date_minus_months 3)

# --- Layer 1: Repo quality ---
repo_json=$(${CLAUDE_PLUGIN_ROOT}/scripts/gh-call.sh \
    gh repo view "$REPO_FULL" \
    --json stargazerCount,pushedAt,isArchived,isFork,hasIssuesEnabled) || {
    gh_exit=$?
    if [[ $gh_exit -eq 1 ]]; then
        echo "=== SCREEN ERROR: fatal — gh not available ===" ; exit 1
    fi
    echo "=== SCREEN ERROR: could not fetch repo data for $REPO_FULL ===" ; exit 2
}

stars=$(echo "$repo_json" | jq '.stargazerCount')
pushed_at=$(echo "$repo_json" | jq -r '.pushedAt | split("T")[0]')
is_archived=$(echo "$repo_json" | jq -r '.isArchived')
is_fork=$(echo "$repo_json" | jq -r '.isFork')

if [[ "$is_archived" == "true" ]]; then
    echo "=== SCREEN DISQUALIFIED: repo is archived ===" ; exit 2
fi
if [[ "$is_fork" == "true" ]]; then
    echo "=== SCREEN DISQUALIFIED: repo is a fork ===" ; exit 2
fi
if (( stars < 5000 )); then
    echo "=== SCREEN DISQUALIFIED: repo has fewer than 5,000 stars ($stars) ===" ; exit 2
fi
if [[ "$pushed_at" < "$cutoff" ]]; then
    echo "=== SCREEN DISQUALIFIED: last commit $pushed_at is older than 6 months ===" ; exit 2
fi

# --- Layer 2: Issue state ---
issue_json=$(${CLAUDE_PLUGIN_ROOT}/scripts/gh-call.sh \
    gh issue view "$NUMBER" --repo "$REPO_FULL" \
    --json state,stateReason,assignees,comments,milestone,closedAt) || {
    gh_exit=$?
    if [[ $gh_exit -eq 1 ]]; then
        echo "=== SCREEN ERROR: fatal — gh not available ===" ; exit 1
    fi
    echo "=== SCREEN ERROR: could not fetch issue $NUMBER from $REPO_FULL ===" ; exit 2
}

state=$(echo "$issue_json" | jq -r '.state')
state_reason=$(echo "$issue_json" | jq -r '.stateReason // ""')
assignee_count=$(echo "$issue_json" | jq '.assignees | length')

if [[ "$state" != "OPEN" ]]; then
    echo "=== SCREEN DISQUALIFIED: issue is $state (reason: $state_reason) ===" ; exit 2
fi
if (( assignee_count > 0 )); then
    echo "=== SCREEN DISQUALIFIED: issue has an assignee ===" ; exit 2
fi

# --- Layer 3: Linked PR check (open) ---
open_pr_out=$(${CLAUDE_PLUGIN_ROOT}/scripts/gh-call.sh \
    gh pr list --repo "$REPO_FULL" --state open \
    --search "fixes #$NUMBER OR closes #$NUMBER OR resolves #$NUMBER" \
    --json number) || {
    gh_exit=$?
    if [[ $gh_exit -eq 1 ]]; then
        echo "=== SCREEN ERROR: fatal — gh not available ===" ; exit 1
    fi
    echo "=== SCREEN ERROR: could not check open PRs for issue $NUMBER ===" ; exit 2
}
open_pr=$(echo "$open_pr_out" | jq 'length')
if (( open_pr > 0 )); then
    echo "=== SCREEN DISQUALIFIED: there is an open PR addressing this issue ===" ; exit 2
fi

# --- Layer 3b: Broader open PR check — catches "Fix #N" titles without closing keywords ---
title_pr_out=$(${CLAUDE_PLUGIN_ROOT}/scripts/gh-call.sh \
    gh pr list --repo "$REPO_FULL" --state open \
    --search "#$NUMBER in:title" \
    --json number) || {
    gh_exit=$?
    if [[ $gh_exit -eq 1 ]]; then
        echo "=== SCREEN ERROR: fatal — gh not available ===" ; exit 1
    fi
    echo "=== SCREEN ERROR: could not check title-referenced PRs for issue $NUMBER ===" ; exit 2
}
title_open_pr=$(echo "$title_pr_out" | jq 'length')
if (( title_open_pr > 0 )); then
    echo "=== SCREEN DISQUALIFIED: there is an open PR referencing this issue in its title ===" ; exit 2
fi

# --- Layer 4: Linked PR check (merged) ---
merged_pr_out=$(${CLAUDE_PLUGIN_ROOT}/scripts/gh-call.sh \
    gh pr list --repo "$REPO_FULL" --state merged \
    --search "fixes #$NUMBER OR closes #$NUMBER OR resolves #$NUMBER" \
    --json number) || {
    gh_exit=$?
    if [[ $gh_exit -eq 1 ]]; then
        echo "=== SCREEN ERROR: fatal — gh not available ===" ; exit 1
    fi
    echo "=== SCREEN ERROR: could not check merged PRs for issue $NUMBER ===" ; exit 2
}
merged_pr=$(echo "$merged_pr_out" | jq 'length')
if (( merged_pr > 0 )); then
    echo "=== SCREEN DISQUALIFIED: a merged PR already fixed this issue ===" ; exit 2
fi

# --- Layer 5: Last comment recency + maintainer signal ---
comment_count=$(echo "$issue_json" | jq '.comments | length')
last_comment_at="none"
maintainer_commented="false"

if (( comment_count > 0 )); then
    last_comment_at=$(echo "$issue_json" | jq -r '.comments[-1].createdAt | split("T")[0]')

    maintainer_raw=$(echo "$issue_json" | jq -r '
        .comments[]
        | select(.authorAssociation == "MEMBER" or .authorAssociation == "OWNER" or .authorAssociation == "COLLABORATOR")
        | "true"
    ' 2>/dev/null | head -1)
    maintainer_commented="${maintainer_raw:-false}"

    if [[ "$last_comment_at" < "$three_months_ago" && "$maintainer_commented" != "true" ]]; then
        echo "=== SCREEN DISQUALIFIED: last comment $last_comment_at > 3 months ago with no maintainer engagement ===" ; exit 2
    fi
fi

# --- Layer 6: Fork check ---
username=$(${CLAUDE_PLUGIN_ROOT}/scripts/gh-call.sh gh api user --jq '.login') || {
    gh_exit=$?
    if [[ $gh_exit -eq 1 ]]; then
        echo "=== SCREEN ERROR: fatal — gh not available ===" ; exit 1
    fi
    username=""
}

fork_exists="false"
if [[ -n "$username" ]]; then
    gh_out=$(${CLAUDE_PLUGIN_ROOT}/scripts/gh-call.sh \
        gh repo list "$username" --json name) || {
        gh_exit=$?
        if [[ $gh_exit -eq 1 ]]; then
            echo "=== SCREEN ERROR: fatal — gh not available ===" ; exit 1
        fi
        # Deliberate safe fallback on API error: assume no fork, continue.
        # Consequence: may re-screen a repo we already forked — acceptable because
        # contribute skill re-checks fork status before submitting a PR.
        fork_exists="false"
        gh_out=""
    }
    if [[ -n "$gh_out" ]]; then
        fork_exists=$(echo "$gh_out" \
            | jq --arg r "$REPO" '[.[].name] | map(select(. == $r)) | length > 0')
    fi
fi

# --- Output: structured stdout for Claude, rate-limit gap before exit ---
sleep 2
echo "=== SCREEN PASS ==="
jq -n \
    --arg url "$ISSUE_URL" \
    --arg repo "$REPO_FULL" \
    --argjson number "$NUMBER" \
    --argjson stars "$stars" \
    --arg pushed_at "$pushed_at" \
    --argjson fork_exists "$fork_exists" \
    --arg last_comment_at "$last_comment_at" \
    --arg maintainer_commented "$maintainer_commented" \
    '{url:$url,repo:$repo,number:$number,stars:$stars,pushed_at:$pushed_at,
      fork_exists:$fork_exists,last_comment_at:$last_comment_at,
      maintainer_commented:($maintainer_commented == "true")}'
exit 0
