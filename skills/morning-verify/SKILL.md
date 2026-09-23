---
name: morning-verify
description: Use when the user wants to check that yesterday's (or the last workday's) merged PRs actually work in production, asks for a morning prod check, post-deploy verification, "did my deploys break anything", or invokes /morning-verify.
---

# Morning Verify

Prove from production data that each PR the user merged on the last workday works, and hand the user only the checks the data cannot settle, each as the single fastest manual step. Evidence comes from Buildkite, Datadog, PostHog, and Metabase.

## Hard rules

- MUST stay read-only. NEVER create or edit dashboards, notebooks, insights, monitors, flags, annotations, or comments. NEVER retry, unblock, or rebuild a build. SQL is SELECT only.
- NEVER use browser or computer-use tools.
- NEVER read diffs from the local checkout. Use `gh` only.
- NEVER use merge time as live time.
- A connector that fails twice: stop querying it, mark the checks that depend on it NEEDS YOU with the error, continue.

## Constants

| Thing | Value |
|---|---|
| Repo / base branch | `MutinyHQ/mutiny-frontend` / `development` |
| Buildkite org | `mutinyhq` |
| Web deploy | pipeline `mutiny-frontend-deploy`, step `s3-publish-production` |
| Recorder release | pipeline `mutiny-frontend-recorder-release` |
| PostHog | project `381053`, host `app.mutinyhq.com`, timezone UTC |
| Datadog | `env:production`; recorder `service:desktop-recorder` |
| Metabase | read-only prod access |

MCP tools are deferred: load each server's tools with ToolSearch before use. If Datadog offers skills, load `datadog/logs` first.

## Step 1: Collect

1. Window = the user's last workday in their local timezone (`date +%Z`). Monday means Friday through Sunday.
2. `gh search prs --author=@me --base=development --merged-at=<YYYY-MM-DD or A..B> -R MutinyHQ/mutiny-frontend --json number,title --limit 100`
3. Zero results: print `Nothing merged on <date>.` and stop.
4. Per PR: `gh pr view N -R MutinyHQ/mutiny-frontend --json mergedAt,mergeCommit,files,body` and `gh pr diff N -R MutinyHQ/mutiny-frontend`.

Read diffs and files ONLY through `gh`. The local checkout can be weeks stale. For a file at a commit: `gh api 'repos/MutinyHQ/mutiny-frontend/contents/<path>?ref=<sha>'`.

## Step 2: Live time

Merge time is NOT live time. Deploy builds often block (e.g. waiting on ":warning: Bypass momentic failure?") or skip, so a PR ships in a later build, minutes to hours after merge.

- **Web/backend:** the finish time of `s3-publish-production` in the first passed `mutiny-frontend-deploy` build whose commit contains the merge commit. Containment: `gh api repos/MutinyHQ/mutiny-frontend/compare/<mergeCommit>...<buildCommit> --jq .status` returns `ahead` or `identical`.
- **Desktop recorder** (any file under `apps/desktop-recorder/`): the publish time of the first passed `mutiny-frontend-recorder-release` build containing the merge commit. Note the version it shipped.
- No qualifying build: verdict NOT LIVE. Name the PR's own deploy build number, its state, and what it waits on.

## Step 3: Dispatch

- Docs-only PR (every file is `*.md` or docs): SKIP, no subagent.
- Every other PR, including CI and test changes: one subagent each, all dispatched in ONE message so they run in parallel. MUST wait for every subagent's result before Step 5; never end the turn while any is still running. Fill in this prompt:

```
READ-ONLY prod verification of MutinyHQ/mutiny-frontend#<N> "<title>".
Live since <live time UTC> (<build or recorder version>). Diff: run `gh pr diff <N> -R MutinyHQ/mutiny-frontend`. PR body: <body>.
Never create, edit, retry, or unblock anything in any tool. No browser. SQL is SELECT only. Load MCP tools via ToolSearch.

Pick the rows that match the diff:
- Web UI: PostHog `$exception` whose stack frames name a changed file, and `$pageview` distinct users on routes the diff touches (derive the route from the diff, confirm by grouping $pathname / $current_url). Filter $host = 'app.mutinyhq.com'.
- Backend/API: Datadog spans for the touched endpoints, by status code and p50/p95 latency; error logs for the touched modules.
- Recorder: Datadog service:desktop-recorder env:production. Group by `version` and compare the new version to the previous one; never compare raw before/after windows (old versions keep running and pollute them). New log codes from the diff: count by version. Also group update/start logs by installation id and flag any installation with an abnormal count (loops, crash-relaunch).
- DB writes: Metabase SELECT on the written tables, rows since live and null/invalid rates in new columns.
- CI/deploy config: Buildkite results of the affected pipeline before vs after the change.
- Test changes: did the affected suite pass in the first deploy build after live?
Before window: same length as after, ending at live time, weekdays only.
Also: list any follow-up the PR body promises that is not yet done.
Budget: at most 15 queries. Out of budget or a connector fails twice: return NEEDS YOU with what you have.
Report only what a query returned. No inferred numbers.

Constants: <paste the Constants table>

Verdict rules, apply in order, first match wins:
1. ALARM: after live, errors or failures rose (error logs, exceptions, 5xx, failed builds/jobs), an expected signal is missing, a business metric the PR targets dropped, or one entity is an outlier (e.g. one installation looping).
2. NEEDS YOU: the change is visible UI (layout, styling, new or moved elements), OR fewer than 20 distinct users hit the changed UI after live, OR (backend-only changes) fewer than 20 requests to the changed endpoints, OR any row you needed could not be queried.
3. VERIFIED: none of the above, and EVIDENCE shows the numbers.
Zero errors from 7 users proves nothing: that is NEEDS YOU, not VERIFIED. Count only users/requests that hit the CHANGED code, never a broad match.

Return exactly:
SUMMARY: <what this PR changed, as the user would notice it, max 10 words, no ticket IDs or jargon; e.g. "Recorder waits for meetings to end before updating">
VERDICT: ALARM | NEEDS YOU | VERIFIED
RULE: <which numbered rule matched, and the number that triggered it>
AFTER_VOLUME: <distinct users or requests on the changed code since live>
EVIDENCE: <query> -> <numbers>, one line each (a query that returned nothing says "0 rows")
CHECK: <for NEEDS YOU and ALARM: one manual step, exact URL, action, or ready-to-run SELECT, and the expected result>
FOLLOW-UPS: <promised but not done, or "none">
```

## Step 4: Check every verdict

Subagents drift from the rules. Before reporting, re-apply the verdict rules above to each result yourself, using its RULE, AFTER_VOLUME, and EVIDENCE:
- VERIFIED with AFTER_VOLUME under 20, or on a visible UI change: downgrade to NEEDS YOU.
- VERIFIED whose EVIDENCE shows any rise in errors or failures: upgrade to ALARM.
- Same anomaly reported by several PRs (e.g. one recorder version misbehaving): keep ALARM only on the PR whose diff touches the failing code; the others say `see <SUMMARY of that PR>` and keep their own verdict.
- A subagent that errored out: NEEDS YOU with `verification failed: <error>`.
- SKIP (docs-only) and NOT LIVE come from Steps 2-3, not from subagents.

## Step 5: Report

Count check first: every PR from Step 1 appears exactly once. Every PR line leads with its SUMMARY (write one from the title and diff for NOT LIVE and SKIP PRs), then the ticket ID and a clickable link. NEVER identify a PR by number or title alone: titles repeat across PRs for the same ticket. Then print, in this order, omitting empty groups:

```
MORNING VERIFY - <date>  (<n> PRs: <x> not live, <y> alarm, <z> need you, <v> verified, <s> skip)

NOT LIVE
  <SUMMARY> (<ticket>, [#N](https://github.com/MutinyHQ/mutiny-frontend/pull/N)) - build <b> <state>: <waiting on>
ALARM
  <SUMMARY> (<ticket>, [#N](https://github.com/MutinyHQ/mutiny-frontend/pull/N)) - <what is wrong>
    evidence: <query -> numbers>
    check: <fastest step to confirm or clear it>
NEEDS YOU  (fastest first)
  <SUMMARY> (<ticket>, [#N](https://github.com/MutinyHQ/mutiny-frontend/pull/N)) - <why data can't settle it>
    check: <exact action> -> expect <result>
VERIFIED
  <SUMMARY> (<ticket>, [#N](https://github.com/MutinyHQ/mutiny-frontend/pull/N)) - <one-line evidence>
SKIP
  <SUMMARY> (<ticket>, [#N](https://github.com/MutinyHQ/mutiny-frontend/pull/N))
FOLLOW-UPS
  <SUMMARY>: <promised item not done>

Next action: <one thing, the top ALARM or NOT LIVE item, else the first NEEDS YOU check>
```

