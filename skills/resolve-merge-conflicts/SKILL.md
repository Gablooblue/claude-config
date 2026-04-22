---
name: resolve-merge-conflicts
description: Detect and resolve merge, rebase, and cherry-pick conflicts autonomously. Classifies files by type, applies tiered resolution strategies, and escalates genuinely ambiguous conflicts to the user.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# Resolve Merge Conflicts

Resolve merge, rebase, and cherry-pick conflicts. Classify conflicted files by tier, resolve what is safe autonomously, escalate what is ambiguous to the user in a single batch.

**Starting state:** Repository mid-operation with conflicts, OR a PR branch that GitHub reports as conflicting with its base branch.
**Target state:** All conflicts resolved, operation completed, clean working tree, PR mergeable.

## Hard Rules — NEVER Violate

- NEVER run `git rebase --abort`, `git merge --abort`, or `git cherry-pick --abort` without explicit user confirmation.
- NEVER force-push after resolution.
- NEVER modify files outside the conflicted set.
- NEVER skip a conflicted file — every file MUST be resolved or escalated.
- NEVER leave conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) in any file.

## Stop Conditions — Pause and Ask

- Human queue (Step 5) — ALWAYS present ambiguous conflicts for user decision.
- A resolution would delete more than 50 lines of non-generated code.
- A rebase hits more than 10 sequential commits with conflicts — suggest squash-and-rebase or merge instead.
- A lockfile regeneration command fails.
- A conflict involves binary files — ask user which version to keep.
- Uncommitted changes exist outside the merge/rebase conflict — HARD STOP, tell user to stash or commit first.
- `git status` shows unexpected state after resolution (still conflicted after `git add`) — HARD STOP, report the state.

---

## Step 0 — Detect Conflict State

First, check if a merge/rebase/cherry-pick is already in progress:

```bash
git status
test -f .git/MERGE_HEAD && echo "MERGE"
test -d .git/rebase-merge -o -d .git/rebase-apply && echo "REBASE"
test -f .git/CHERRY_PICK_HEAD && echo "CHERRY_PICK"
```

If an operation is already in progress with conflicts, proceed to Step 1.

**If no operation is in progress** (clean working tree), check for a PR with upstream conflicts:

```bash
gh pr view --json baseRefName,headRefName,mergeable 2>/dev/null
```

If `mergeable` is `CONFLICTING`:
1. Fetch the latest base branch: `git fetch origin <baseRefName>`
2. Attempt the merge: `git merge origin/<baseRefName>`
3. This will surface the conflicts locally. Proceed to Step 1.

**No conflicts detected and no conflicting PR:** Report clean state and STOP.

✅ "Detected {OPERATION} in progress with conflicts."

## Step 1 — Inventory Conflicted Files

```bash
git diff --name-only --diff-filter=U
```

Classify each file into one tier:

### Tier 1 — Auto-resolvable (silent)

Mechanical resolution, no user input needed:

| File type | Examples | Strategy |
|-----------|----------|----------|
| Lockfiles | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Gemfile.lock`, `poetry.lock`, `Cargo.lock` | Delete and regenerate via package manager |
| Auto-generated code | GraphQL codegen, Prisma client, OpenAPI stubs | Accept base version, regenerate |
| Formatting-only | Both sides changed only whitespace in the same region | Accept ours, run formatter |

### Tier 2 — Domain-heuristic resolvable

Type-specific rules produce a confident resolution:

| File type | Strategy | Escalate when |
|-----------|----------|---------------|
| `package.json` | Merge both dependency additions; same dep with different versions takes higher semver | Major version bump |
| `tsconfig.json` / config files | Merge additive changes (new array/object entries) | Removals or value changes |
| Migration files | Keep both, reorder by timestamp | Both modify same table/column |
| `.gitignore`, `.eslintrc`, linter configs | Merge additive entries | Removals |

### Tier 3 — Full analysis required

All other files: application code, tests, utilities, documentation.

✅ "Found {N} conflicted files: {X} Tier 1, {Y} Tier 2, {Z} Tier 3."

## Step 2 — Resolve Tier 1 Files

Process silently. For each file:

1. **Lockfiles:** `git checkout --theirs <lockfile>`, run the regeneration command (`npm install` / `yarn install` / `pnpm install` / `bundle install` / `poetry lock` / `cargo generate-lockfile`). `git add` the result.
2. **Auto-generated code:** Accept base version, run the generation command. `git add`.
3. **Formatting-only:** Accept ours, run the project formatter. `git add`.

Report each: `[ok] package-lock.json — Tier 1: regenerated lockfile`

## Step 3 — Resolve Tier 2 Files

For each file:

1. Read the file including conflict markers.
2. Apply the type-specific merge strategy from the Tier 2 table.
3. Write the resolved file. `git add`.

If the heuristic produces low-confidence output (matches an "Escalate when" condition), add to the **human queue** instead.

Report each: `[ok] package.json — Tier 2: merged dependency additions`

## Step 4 — Resolve Tier 3 Files

For each file:

1. Read all three versions:
   ```bash
   git show :1:<path>   # base (common ancestor)
   git show :2:<path>   # ours
   git show :3:<path>   # theirs
   ```
2. Read commit messages from both sides to understand intent.
3. Classify and resolve:
   - **Independent changes** (different functions, different regions): Merge both. `git add`.
   - **One side subsumes the other** (e.g., theirs refactored a function that ours only tweaked): Take the more complete version. `git add`.
   - **Genuinely ambiguous** (both sides rewrote the same logic incompatibly): Add to human queue.

Report resolved: `[ok] src/api/users.ts — Tier 3: independent changes merged (ours added validation, theirs added logging)`

Report queued: `[..] src/core/engine.ts — ambiguous: both sides rewrote processQueue()`

## Step 5 — Human Queue

If the human queue is empty, skip to Step 6.

Present ALL unresolved conflicts at once. For each conflict:

```
### Conflict: <file path>

**Ours** (<branch name>):
  <What our branch changed — cite commit hash and message>

**Theirs** (<target branch>):
  <What the other branch changed — cite commit hash and message>

**Why auto-resolution failed:** <specific reason>

**Recommendation:** <best-guess resolution with rationale>
```

Wait for user decisions on every item. Apply each decision, write the resolved file, `git add`.

## Step 6 — Continue the Operation

Based on the operation detected in Step 0:

- **Merge:** `git commit` (use the auto-generated merge commit message)
- **Rebase:** `git rebase --continue` — if the next commit also has conflicts, **loop back to Step 1**
- **Cherry-pick:** `git cherry-pick --continue`

## Step 7 — Verify

1. Run `git status` — confirm clean working tree.
2. Check for leftover conflict markers across all previously-conflicted files:
   ```bash
   grep -rn '<<<<<<<\|=======\|>>>>>>>' <resolved files>
   ```
   If any found: STOP and fix them before continuing.
3. Run the project's test command if one exists. Report results.
4. Output the final summary:

```
## Merge Conflict Resolution Complete

Operation: <merge | rebase | cherry-pick>
Conflicts resolved: {total}
  - Auto-resolved (Tier 1): {N}
  - Heuristic-resolved (Tier 2): {N}
  - Analyzed & resolved (Tier 3): {N}
  - User-decided: {N}

Status: clean working tree, <operation> complete
Tests: <pass/fail count or "not run">
```
