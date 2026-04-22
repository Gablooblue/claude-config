---
name: finish-pr
description: Iterative PR hardening via Ralph Wiggum loop — runs adversarial tests, code review, and docs accuracy review in a loop until clean. Use this skill whenever the user says "finish the PR", "harden the PR", "finish-pr", "polish the PR", "make the PR bulletproof", or wants a final quality pass before merging.
---

# finish-pr

You are a quality gate. Iteratively harden a PR until clean.

## Bootstrap

1. Verify these skills are available: `adversarial-tests`, `op:review-branch`, `docs-accuracy-review`, `ralph-loop:ralph-loop`. If any are missing, tell the user which plugin to install and stop.
2. Verify you are in a git repository with a meaningful diff (`git diff HEAD` or `git diff main...HEAD`). No diff → nothing to harden, stop.
3. Start the Ralph loop:

```
/ralph-loop:ralph-loop "/finish-pr" --completion-promise "PR CLEAN" --max-iterations 10
```

Everything below describes one iteration of the loop.

## Step 1: Adversarial Tests

MUST finish before review — it changes code, and the review needs the final diff.

1. Invoke `/adversarial-tests` via the Skill tool
2. Run the project's full test suite (auto-detect: `npm test`, `pytest`, `cargo test`, `go test ./...`, `mix test`, etc.)
3. If any tests fail:
   - Fix the **code under test**, not the tests (unless a test is genuinely incorrect, e.g. testing impossible behavior)
   - Re-run to confirm fixes

## Step 2: Code Review

Invoke `/op:review-branch` via the Skill tool. Returns structured findings with severity and confidence scores.

## Step 3: Triage Findings

For each finding from Step 2:

**Genuine issue** — fix it. Focus on correctness, security, and error handling.

**Nitpick or false positive** — add a brief, natural code comment at the relevant line explaining the deliberate choice, then skip. The comment MUST read like a developer wrote it — no triage markers, no machine-generated tags.

Good comments:
- `// Using camelCase to match the rest of the config module`
- `# Intentionally catching broad Exception here — upstream library throws untyped errors`
- `// O(n^2) is acceptable here — list is bounded to 10 items by validation above`

General findings with no specific line: add the comment at the most relevant location (top of function, near the import, etc.).

After all fixes, re-run the test suite to confirm nothing broke.

## Step 4: Docs Accuracy Review

Invoke `/docs-accuracy-review` via the Skill tool. Checks that docstrings, markdown docs, READMEs, API specs, and inline comments still accurately describe the code after Steps 1-3. Fixes Critical and Stale findings, writes Missing docs.

## Exit

Report per-pass summary:

```
--- finish-pr Pass N ---
Adversarial tests: [wrote X tests, Y failures found and fixed / all passed]
Review (op:review-branch): [X findings total, Y after filtering]
Triage: [X fixed / Y skipped with comments]
Docs accuracy: [X critical, Y stale, Z missing found and fixed / all clean]
Test suite: [passing / N failures remaining]
Fixes made: [yes — Ralph loop will re-check / no — PR is clean]
```

If no fixes were made in any step, the PR is clean:

```
=== finish-pr Complete ===
Total passes: N
Files modified: [git diff --stat output]
All tests passing. PR is clean.
```

Then output the completion promise:

```
<promise>PR CLEAN</promise>
```

If fixes were made, do NOT output the promise — the Ralph loop will re-check.

## Principles

- **Tests are sacred.** Fix the code to satisfy the test. NEVER weaken a test to match broken code.
- **Scope discipline.** Only fix code in the PR diff. No refactoring adventures.
- **Root cause over symptoms.** Same bug category appearing across iterations → flag to user as a design issue.
- **Don't over-fix review findings.** Use judgment — correctness, security, error handling. Ignore style wars.
- **Triage consistency.** If you added a comment explaining a choice, don't reverse that decision on a later pass. The comment is the source of truth.
