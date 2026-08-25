---
name: resolve-build-checks
description: Use when a GitHub PR has failing, red, or stuck CI checks backed by Buildkite - failing builds, failed jobs, failing tests in CI - or the user says "fix the build", "CI is red", "make the checks pass", or "resolve build checks".
---

# Resolve Build Checks

Find the failing Buildkite checks on a GitHub PR, diagnose them with the Buildkite MCP tools, fix the root causes locally, push, and verify the checks go green.

## Mandatory End State

Every run MUST end in one of these two states for EACH failing check:
1. **Green** - the check passes on a build of the pushed fix, OR
2. **Escalated** - a specific diagnosis of why it cannot be fixed here, reported to the user

NEVER weaken, skip, or delete a test to make CI pass. NEVER retry a job as a substitute for diagnosing it. NEVER claim done while any check is still red or pending.

---

## Stop Conditions

Pause and report findings instead of proceeding when:
- The same failure reproduces on the latest base-branch build (main is broken, not this PR) - do not fix unrelated code
- A check is still failing after 2 fix attempts
- The fix would require changing a public API contract, DB schema, or code outside the PR's scope
- The build is blocked on a manual unblock step or the token lacks access (401/403)

---

## Step 1: Find the PR and its failing checks

```bash
gh pr view --json number,title,url,headRefName,baseRefName,headRefOid
gh pr checks {number} --json name,state,bucket,link
```

If no open PR exists on this branch, ask the user for a PR number or URL.

Collect every check with bucket `fail`, plus any `pending` check whose Buildkite build is not actually running (verify with `get_build` - state `blocked`, `canceled`, or no started_at after 30+ minutes means stuck). A build with a started_at that is still running is NOT stuck - leave it and poll it in Step 6. Ignore `skipping` checks.

If `gh pr checks --json` is unsupported (older gh), fall back to `gh api repos/{owner}/{repo}/commits/{headRefOid}/status` and parse `statuses[].target_url`.

✅ Checkpoint: "PR #{number}: {N} failing checks: {names}"

## Step 2: Map each failing check to a Buildkite build

Buildkite check links have the form `https://buildkite.com/{org_slug}/{pipeline_slug}/builds/{build_number}`. Parse all three from each failing check's `link`.

- `build_number` is the integer from the URL - Buildkite MCP tools want this, never the build UUID
- Confirm the org matches `user_token_organization`; if it differs, the token cannot see that build - mark that check Escalated with that diagnosis and continue with the remaining checks
- A failing check with a non-Buildkite link (e.g. GitHub Actions) is out of scope - do not attempt to fix it under this skill; mark it Escalated in the summary (this satisfies the Mandatory End State for it)

## Step 3: Diagnose each failing build

Start with `get_build_failure_summary` - one call returns build state, failed jobs, log tails, error annotations, and failed tests. Only go deeper when the summary points somewhere:

- More log context: `load_skill` the Buildkite MCP `debug-logs-guide`, then `tail_logs` / `search_logs` / `read_logs`
- Full annotation bodies: `list_annotations`
- Test failure detail and stack traces: `get_failed_executions`

Job state `broken` means the job never ran (a condition was false or an upstream dependency failed) - its command did not fail. Chase the upstream cause: `list_jobs` with `state=failed,broken` to see which dependency failed, `get_job` for the job's condition.

✅ Checkpoint: "Build {pipeline}#{number}: {failed jobs} failed because {cause}"

## Step 4: Classify each failure before touching code

| Class | Evidence | Action |
|---|---|---|
| Bug introduced by this PR | Failure involves files in the diff; reproduces locally | Fix the root cause (Step 5) |
| Flaky test | Passes locally on this branch; failure unrelated to the diff; prior retries visible in `list_jobs` (include_retried_jobs) | `retry_job` ONCE, keep watching |
| Infra failure | Agent lost/disconnected, timeout, OOM in the log tail | `retry_job` ONCE; escalate if it recurs |
| Base branch already broken | Same failure on the latest base-branch build (`list_builds` with `branch={baseRefName}`) | Stop condition - report |

Ask "why did this happen?" at least 3 times. The fix MUST target the deepest cause, not the first error line in the log.

## Step 5: Fix, reproduce, push

- Reproduce locally using the same command the failed job ran (the `command` field in the failure summary's job info, or `get_job`) whenever possible
- Fix the code, not the test. Only change a test when the PR/ticket explicitly intends the new behavior - quote that intent in the commit message. "It seems intended" does not meet this bar; ask the user
- Run the failing test/lint/build locally until it passes, review your own diff, then commit (conventional format with ticket number) and push

✅ Checkpoint: "Fixed {cause} in {files}, pushed {sha}"

## Step 6: Verify green

The push triggers new builds. Watch until every check settles:

```bash
gh pr checks {number} --watch
```

Alternatively find the new build (`list_builds` with `branch={headRefName}`, newest first) and poll `wait_for_build`. If a new failure appears, return to Step 3 - the 2-attempt stop condition counts per check.

✅ Checkpoint: "All checks green" or a stop-condition report

## Summary

End with:
- Checks fixed: {name → root cause → fix, commit sha}
- Retries used: {job → reason}
- Escalated: {check → diagnosis}
- PR link
