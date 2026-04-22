# finish-pr Design Spec

Iterative PR hardening skill that runs adversarial tests and multi-agent code review in a Ralph Wiggum loop until the branch is clean. Replaces the `pr-finisher` skill.

## Context

The old `pr-finisher` skill ran three parallel code reviewers (adversarial-code-reviewer, superpowers:code-reviewer, pr-review-toolkit:review-pr) and managed a `.pr-finisher-triage.json` file to track skipped findings across iterations. It also handled worktree creation.

Problems:
- Three overlapping reviewers produced duplicate findings and wasted tokens
- The triage JSON required staleness-checking via file hashes
- Worktree management is unnecessary — the user always runs this skill from inside a worktree

## Design

### Assumptions

- The user is already in a git worktree with a meaningful diff
- The Ralph Wiggum loop plugin is installed
- The `op:review-branch` skill and its dependencies are installed

### Per-iteration flow

```
1. Adversarial tests (sequential — must finish before review)
   - Invoke /adversarial-tests to write paranoid tests against the diff
   - Run the project's full test suite
   - If tests fail: fix the code, not the tests. Re-run to confirm.

2. Code review (sequential — uses op:review-branch)
   - Invoke /op:review-branch
   - Receives structured findings with severity and confidence scores

3. Triage findings
   - For each finding:
     - Genuine issue → fix it
     - Nitpick or false positive → add a natural code comment explaining
       the deliberate choice at the relevant line, then skip
   - Re-run test suite to confirm fixes didn't break anything

4. Docs accuracy review (sequential — after code fixes are done)
   - Invoke /docs-accuracy-review
   - Checks that docstrings, markdown docs, READMEs, API specs, and
     inline comments still accurately describe the code after all fixes
   - Fixes any Critical and Stale findings, writes Missing docs

5. Exit decision
   - No fixes made in any phase → PR is clean, output completion promise
   - Fixes were made → Ralph loop re-checks on next iteration
```

### Skipped findings: natural code comments

When a finding is triaged as a nitpick or false positive, the skill adds a brief code comment at the relevant line explaining the deliberate choice. The comment reads like a developer wrote it — no triage markers, no machine-generated tags.

Example: an agent flags `processItems` as an unclear function name.
Instead of fixing it, add: `// Processes batch items from the ingest queue — name matches the pipeline terminology`

This serves two purposes:
1. Documents the deliberate choice for future developers
2. Prevents re-flagging on subsequent iterations or by other people running the skill — the explanation is visible in the diff

For general findings with no specific line, add the comment at the most relevant location (e.g., top of the function or file).

Staleness is handled naturally: if the code around a comment is substantially rewritten, the comment either gets removed with the old code or becomes obviously stale.

No `.pr-finisher-triage.json` file. No hash-based staleness checks. The code is the triage log.

### Ralph loop integration

The skill bootstraps by starting a Ralph loop:

```
/ralph-loop:ralph-loop "/finish-pr" --completion-promise "PR CLEAN" --max-iterations 10
```

Each iteration follows the per-iteration flow above. The completion promise `PR CLEAN` is only output when no fixes were made across all phases.

### Exit summary

Each pass reports:

```
--- finish-pr Pass N ---
Adversarial tests: [wrote X tests, Y failures found and fixed / all passed]
Review (op:review-branch): [X findings total, Y after filtering]
Triage: [X fixed / Y skipped with comments]
Docs accuracy: [X critical, Y stale, Z missing found and fixed / all clean]
Test suite: [passing / N failures remaining]
Fixes made: [yes — Ralph loop will re-check / no — PR is clean]
```

When the PR is clean, report a final summary:

```
=== finish-pr Complete ===
Total passes: N
Files modified: [git diff --stat output]
All tests passing. PR is clean.
```

Then output `<promise>PR CLEAN</promise>`.

### What's removed from pr-finisher

- `.pr-finisher-triage.json` and all staleness/hash logic
- Triage context block construction
- Three parallel code reviewers (adversarial-code-reviewer, superpowers:code-reviewer, pr-review-toolkit:review-pr)
- Background agent dispatch and collection phases
- Worktree management

### Principles (carried forward)

- Tests are sacred. Fix the code to satisfy the test.
- Scope discipline. Only fix code in the PR diff.
- Root cause over symptoms. Flag recurring bug categories as design issues.
- Don't over-fix review findings. Use judgment — focus on correctness, security, and error handling.
- Triage consistency. If you added a comment explaining a choice, don't reverse that decision on a later pass just because an agent flags it more aggressively.
