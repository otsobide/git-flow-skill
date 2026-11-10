#!/usr/bin/env bash
# wait-for-ci.sh - block until every CI/CD check for a pull request or commit has finished (GitHub).
#
# Usage:
#   wait-for-ci.sh --pr [<number|url|branch>]   checks on a pull request (default: the current branch's PR)
#   wait-for-ci.sh --commit <sha|ref|tag>        GitHub Actions runs for a commit, e.g. origin/main or v1.4.0
#                                                (only push/release/workflow_run/deployment runs count)
#
# Options:
#   --timeout <seconds>    give up after this long (default: 3600)
#   --interval <seconds>   polling interval (default: 20)
#   --grace <seconds>      how long to wait for the first check to appear (default: 90)
#   --settle <seconds>     once everything has finished, how long to keep watching for
#                          late checks (e.g. deployments) before declaring success (default: 30)
#   --fail-fast            stop as soon as any check fails instead of waiting for all
#   -R, --repo <owner/repo>
#   -h, --help
#
# Exit codes:
#   0  every check finished and none failed
#   1  at least one check failed or was cancelled
#   2  no checks appeared within the grace period (no CI for this PR/commit?)
#   3  timed out while checks were still running
#   4  usage error, gh missing, or the PR/commit could not be found
#
# Safe to rerun at any time; it only reads state.

set -uo pipefail

mode="" ref="" timeout=3600 interval=20 grace=90 settle=30 fail_fast=0
repo_args=()   # expanded as ${repo_args[@]+"${repo_args[@]}"}: bash < 4.4 treats empty arrays as unbound under set -u

usage() { sed -n '2,/^$/p' "$0" | sed -e 's/^# \{0,1\}//' -e '/^$/d'; }
die() { echo "error: $*" >&2; exit 4; }
need_value() { [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || die "$1 needs a value"; }
is_number() { [[ "$1" =~ ^[0-9]+$ ]] || die "expected a number of seconds, got '$1'"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      mode=pr
      if [[ $# -ge 2 && "$2" != -* ]]; then ref="$2"; shift; fi
      ;;
    --commit)     need_value "$@"; mode=commit; ref="$2"; shift ;;
    --timeout)    need_value "$@"; is_number "$2"; timeout="$2"; shift ;;
    --interval)   need_value "$@"; is_number "$2"; interval="$2"; shift ;;
    --grace)      need_value "$@"; is_number "$2"; grace="$2"; shift ;;
    --settle)     need_value "$@"; is_number "$2"; settle="$2"; shift ;;
    --fail-fast)  fail_fast=1 ;;
    -R|--repo)    need_value "$@"; repo_args=(--repo "$2"); shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "error: unknown argument '$1'" >&2; usage >&2; exit 4 ;;
  esac
  shift
done

[[ -n "$mode" ]] || { usage >&2; exit 4; }
command -v gh >/dev/null 2>&1 || die "the GitHub CLI (gh) is not installed"
(( interval > 0 )) || interval=1

if [[ "$mode" == pr ]]; then
  pr_args=()
  [[ -n "$ref" ]] && pr_args=("$ref")
  info=$(gh pr view ${pr_args[@]+"${pr_args[@]}"} ${repo_args[@]+"${repo_args[@]}"} --json number,url,headRefName,baseRefName \
    --jq '"#\(.number) \(.headRefName) -> \(.baseRefName)  \(.url)"' 2>&1) \
    || die "could not find the pull request: $info"
  echo "Waiting for CI on PR $info"

  # Prints "<total> <pending> <failed>".
  poll() {
    gh pr checks ${pr_args[@]+"${pr_args[@]}"} ${repo_args[@]+"${repo_args[@]}"} --json name,bucket \
      --jq '"\(length) \([.[] | select(.bucket == "pending")] | length) \([.[] | select(.bucket == "fail" or .bucket == "cancel")] | length)"' \
      2>/dev/null
  }
  final_report() { gh pr checks ${pr_args[@]+"${pr_args[@]}"} ${repo_args[@]+"${repo_args[@]}"} 2>/dev/null; }
else
  # Accept branch names, remote refs and tags as well as SHAs; the API filter needs the full SHA.
  sha=$(git rev-parse --verify --quiet "${ref}^{commit}" 2>/dev/null || true)
  [[ -n "$sha" ]] || sha="$ref"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "'$ref' is not a commit known to the local repository (run 'git fetch' first, or pass a full SHA)"
  echo "Waiting for GitHub Actions runs on commit ${sha:0:12} ($ref)"

  # Only events a merge or tag push can cause; issue/comment/scheduled runs also carry the
  # default branch's head SHA but have nothing to do with the commit.
  relevant='def relevant: .event == "push" or .event == "release" or .event == "workflow_run" or .event == "deployment" or .event == "deployment_status";'

  poll() {
    gh run list --commit "$sha" ${repo_args[@]+"${repo_args[@]}"} --limit 100 --json event,status,conclusion \
      --jq "$relevant"' [.[] | select(relevant)] | "\(length) \([.[] | select(.status != "completed")] | length) \([.[] | select(.status == "completed" and .conclusion != "success" and .conclusion != "skipped" and .conclusion != "neutral")] | length)"' \
      2>/dev/null
  }
  final_report() {
    gh run list --commit "$sha" ${repo_args[@]+"${repo_args[@]}"} --limit 100 --json event,status,conclusion,workflowName,url \
      --jq "$relevant"' .[] | select(relevant) | "\(if .status == "completed" then .conclusion else .status end)\t\(.workflowName)\t\(.event)\t\(.url)"' \
      2>/dev/null
  }
fi

start=$(date +%s)
settled_at=0 last_total=-1 last_state="" last_print=0

while :; do
  now=$(date +%s)
  elapsed=$(( now - start ))

  summary=$(poll || true)
  read -r total pending failed <<<"${summary:-0 0 0}"
  [[ "$total" =~ ^[0-9]+$ ]] || total=0
  [[ "$pending" =~ ^[0-9]+$ ]] || pending=0
  [[ "$failed" =~ ^[0-9]+$ ]] || failed=0

  state="$total/$pending/$failed"
  if [[ "$state" != "$last_state" ]] || (( now - last_print >= 300 )); then
    if (( total == 0 )); then
      echo "[$(date +%H:%M:%S)] no checks reported yet (${elapsed}s)"
    else
      echo "[$(date +%H:%M:%S)] $total checks: $(( total - pending )) finished, $pending running, $failed failed (${elapsed}s)"
    fi
    last_state="$state" last_print=$now
  fi

  if (( total == 0 )); then
    if (( elapsed >= grace )); then
      echo
      echo "No checks appeared within ${grace}s. This PR/commit probably has no CI configured."
      exit 2
    fi
  elif (( failed > 0 && fail_fast )); then
    break
  elif (( pending == 0 )); then
    # Everything reported so far has finished; keep watching briefly for checks that start late.
    if (( settled_at == 0 || total != last_total )); then
      settled_at=$now last_total=$total
    fi
    (( now - settled_at >= settle )) && break
  else
    settled_at=0
  fi

  if (( elapsed >= timeout )); then
    echo
    echo "Timed out after ${timeout}s with $pending check(s) still running:"
    final_report
    exit 3
  fi

  sleep "$interval"
done

echo
final_report
echo
if (( failed > 0 )); then
  echo "RESULT: $failed of $total check(s) failed or were cancelled."
  echo "Inspect failures with the links above, or for GitHub Actions: gh run view <run-id> --log-failed"
  exit 1
fi
echo "RESULT: all $total check(s) finished successfully."
exit 0
