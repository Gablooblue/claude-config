---
name: manual-test
description: Use when a PR is about to be created, the user says ready to ship/merge/review, or a feature, bug fix, or UI change needs manual verification before review.
---

# Manual Test Gate

Tests passing proves the code is correct; manual testing proves the feature works. Your job: enumerate every path this diff puts at risk, verify every machine-verifiable one YOURSELF with throwaway scripts, and hand the human only what genuinely needs human judgment. Then stop — the PR waits for their reply.

## Step 0 — Acquire the Diff

Try in order, stop at the first that returns content:

1. `git diff HEAD` — unstaged + staged changes against HEAD
2. `git diff --staged` — staged changes only
3. `git diff main...HEAD` — full branch diff against main

All empty → output "No changes to manually test" and STOP.

## Step 1 — N/A Check

If the change is a pure internal refactor with full test coverage, type-only, or doc-only: output `MANUAL TEST N/A: [reason]` and proceed to the PR. This escape hatch is NOT allowed for UI, API, CLI, or any behavior change.

## Step 2 — Enumerate Test Paths

For every function, component, endpoint, or command the diff touches:

1. **Grep for all callers.** Each caller's user-facing entry point (route, screen, command) is a test path — especially callers the diff did NOT update.
2. **Walk every new or changed branch**, early return, throw, and error path. Each is a test path.
3. **Apply the change-type checklist:**
   - UI: empty / loading / error / long-content states; both themes if themed
   - API: each status code the change can now produce; auth'd vs not; malformed body
   - CLI: no args, bad args, piped input
   - Shared util: every other consumer is a regression path
   - Migration / schema: irreversible — flag it, Stop Conditions apply
4. **Behavior deltas:** anywhere the same input now produces a different status, shape, or side effect than before the diff, that delta is a test path.

Checkpoint — output the list before proceeding:

```
[path] — [why it's at risk] — verify: script | human | both
```

`human` is only valid for checks that need judgment or access you lack: visual layout and UX feel, real credentials or third-party accounts, hardware. "Tedious to script" is not a reason. If browser or simulator tooling is available this session, a screenshot of the changed screen counts as script evidence.

## Step 3 — Script and Run the Scriptable Paths

For each `script` or `both` path, write a throwaway script in `<repo root>/.manual-test/` (create the directory) named `NN-what-it-checks.sh` or `.js`, then RUN it.

- Scripts must be self-contained: start what they need (pick a free port, never assume one), seed their own data, print the evidence, clean up after themselves.
- Result per script is binary: `PASS` or `FAIL`, plus one line of evidence (status code + body, exit code, output diff, screenshot path). NEVER "looks like it works".
- A FAIL that reveals a real defect: output `BUG FOUND: [file:line] — [what the script proved]` and STOP. No handoff, no PR — broken features don't go to manual testing.
- Leave the scripts in place so the human can re-run them.

## Step 4 — Handoff Block

Output this block, then STOP. Every section is required; write "none" rather than omitting one.

```
🛑 MANUAL TEST REQUIRED before PR

▶ Already verified by script:
   - [path] → PASS — [one-line evidence]

▶ Scripts you can re-run:
   - .manual-test/NN-name.sh — [what it checks]

▶ Lowest-effort run command:
   [exact command + URL/route/input — the single shortest path to exercise THIS change; never "run the full test suite"]

▶ Golden path (must pass):
   1. [concrete user action]
   2. [expected observable result]

▶ Needs human eyes — I could not script these:
   - [path] — [why scripting was impossible, not just inconvenient]

▶ Reply with one of:
   "tested ✅"  → I create the PR
   "broken: [what]" → I debug
   "skip test" → I create the PR with a `## Skipped Manual Test` section listing the untested risks
```

Every risk and path must name a specific file, route, or command from THIS diff — no generic checklists. If every path was script-verified, say so under "Needs human eyes: none — all paths verified above"; the reply protocol still applies.

## Forbidden Actions

- NEVER modify production code — scripts only
- NEVER `git add` anything under `.manual-test/`, and NEVER add it to .gitignore
- NEVER claim PASS for a script you did not run this session
- NEVER create the PR before the human replies "tested ✅" or "skip test"
