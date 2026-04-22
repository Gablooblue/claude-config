# Resolve Merge Conflicts — Skill Design

## Overview

A Claude Code skill that autonomously resolves merge, rebase, and cherry-pick conflicts. It detects the conflict state, classifies conflicted files by type, applies resolution strategies ranging from silent auto-resolve to full semantic analysis, and escalates genuinely ambiguous conflicts to the user in a single batch.

## Trigger

User invokes the skill directly (e.g., "resolve conflicts", "fix merge conflicts") or it detects the repo is in a conflicted state.

## Step 0 — Detect Conflict State

Check the repo for an in-progress operation:

- `git status` for conflict markers and operation state
- `.git/MERGE_HEAD` — merge in progress
- `.git/rebase-merge/` or `.git/rebase-apply/` — rebase in progress
- `.git/CHERRY_PICK_HEAD` — cherry-pick in progress

**If no conflicts exist:** report clean state and stop.
**If uncommitted changes exist outside the conflict:** hard stop — risk of losing work.

## Step 1 — Inventory Conflicted Files

Run `git diff --name-only --diff-filter=U` to list all conflicted files.

Classify each file into one of three tiers:

### Tier 1 — Auto-resolvable (silent)

Files where the correct resolution is mechanical:

- **Lockfiles** (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Gemfile.lock`, `poetry.lock`, `Cargo.lock`): Delete and regenerate via the appropriate package manager command.
- **Auto-generated code** (GraphQL codegen output, Prisma client, OpenAPI stubs): Accept base version and regenerate.
- **Formatting-only conflicts**: Both sides changed only whitespace or formatting in the same region.

### Tier 2 — Domain-heuristic resolvable

Files where type-specific rules produce a confident resolution:

- **`package.json`**: Merge both dependency additions. If the same dependency has different versions, take the higher semver (unless it's a major bump — escalate to human queue).
- **`tsconfig.json` / config files**: Merge additive changes (new entries in arrays/objects). Flag removals or value changes for review.
- **Migration files**: Keep both migrations. Reorder by timestamp if naming convention supports it. If both modify the same table/column, escalate.
- **`.gitignore`, `.eslintrc`, linter configs**: Merge additive entries. Flag removals.

### Tier 3 — Full analysis required

All other files: application code, tests, utilities, documentation. These require reading both sides and understanding intent.

**Checkpoint:** "Found {N} conflicted files: {X} auto-resolvable, {Y} domain-heuristic, {Z} need full analysis."

## Step 2 — Resolve Tier 1 Files

Process silently. For each:

1. For lockfiles: stage the conflicted file as-is, then run the regeneration command (e.g., `npm install`, `yarn install`).
2. For auto-generated code: accept the base version, run the generation command.
3. For formatting-only: accept either side (prefer ours), run formatter if available.
4. `git add` the resolved file.

## Step 3 — Resolve Tier 2 Files

Apply domain heuristics. For each:

1. Read the conflict markers in the file.
2. Apply the type-specific merge strategy.
3. Write the resolved file.
4. `git add`.

If a heuristic produces a result with low confidence (e.g., major version bump on a dependency, both sides modified the same config key), add to the human queue instead.

## Step 4 — Resolve Tier 3 Files

For each application code or test file:

1. Read base (`:1:path`), ours (`:2:path`), theirs (`:3:path`) using `git show`.
2. Read commit messages from both sides for intent context.
3. Determine if changes are independent or overlapping:
   - **Independent changes** (different functions, different regions): merge both, `git add`.
   - **One side subsumes the other** (e.g., theirs refactored a function that ours only tweaked): take the more complete version, `git add`.
   - **Genuinely ambiguous** (both sides rewrote the same logic incompatibly): add to human queue.

## Step 5 — Human Queue

Present all unresolved conflicts at once. For each conflict, show:

- **File path**
- **Ours** — what our branch did, with the relevant commit message and code snippet
- **Theirs** — what the other branch did, with commit message and code snippet
- **Why auto-resolution failed** — specific reason (e.g., "both sides replaced the function body")
- **Recommendation** — the skill's best guess at the right resolution, with rationale

Wait for user decisions. Apply each decision, `git add`.

## Step 6 — Continue the Operation

Based on the detected operation type:

- **Merge:** `git commit` (using the auto-generated merge commit message)
- **Rebase:** `git rebase --continue` — if the next commit also has conflicts, loop back to Step 1
- **Cherry-pick:** `git cherry-pick --continue`

## Step 7 — Verify

- Run `git status` to confirm clean working tree.
- If the project has a fast test command, run it as a sanity check and report results.

## Stop Conditions — Pause and Ask

- The human queue (Step 5) — always present ambiguous conflicts for user decision.
- A resolution would delete more than 50 lines of non-generated code.
- A rebase has more than 10 sequential commits with conflicts — suggest squash-and-rebase or merge instead.
- A lockfile regeneration command fails.

## Hard Stops — Abort and Explain

- Uncommitted changes exist outside the merge/rebase conflict.
- A conflict involves binary files — ask user which version to keep.
- `git status` shows unexpected state after resolution (still conflicted after `git add`).

## Forbidden Actions

- Never run `git rebase --abort` or `git merge --abort` without explicit user confirmation.
- Never force-push after resolution.
- Never modify files outside the conflicted set.
- Never skip a conflicted file without resolving or escalating it.

## Output Format

**Per-file (inline as it works):**
```
[ok] package-lock.json — Tier 1: regenerated lockfile
[ok] src/api/users.ts — Tier 3: independent changes merged (ours added validation, theirs added logging)
[..] src/core/engine.ts — ambiguous: both sides rewrote processQueue()
```

**Human queue presentation:**
```
### Conflict: src/core/engine.ts

**Ours** (branch: feature/async-queue):
  Rewrote processQueue() to use async iterators (commit abc123: "refactor: async queue processing")

**Theirs** (main):
  Rewrote processQueue() to use worker threads (commit def456: "perf: parallelize queue with workers")

**Why auto-resolution failed:** Both sides replaced the same function body with incompatible implementations.

**Recommendation:** Keep the worker threads version (theirs) since it addresses a performance goal, then layer async iteration on top.
```

**Final summary:**
```
## Merge Conflict Resolution Complete

Operation: rebase onto main
Conflicts resolved: 8/8
  - Auto-resolved (Tier 1): 2
  - Heuristic-resolved (Tier 2): 3
  - Analyzed & resolved (Tier 3): 2
  - User-decided: 1

Status: clean working tree, rebase complete
Tests: 142 passed, 0 failed
```

## Allowed Tools

`Read`, `Grep`, `Glob`, `Bash`, `Edit`, `Write`
