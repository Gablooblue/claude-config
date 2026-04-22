---
name: resolve-pr-comments
description: Fetch PR review comments, implement fixes, reply to each comment, push, and request re-review.
---

# Resolve PR Comments

Fetch review comments from a GitHub PR, plan fixes for each, implement after approval, reply to every comment, push, and request re-review from all reviewers.

## Mandatory End State

Every run MUST end with all three of these completed:
1. **Push** — all changes pushed to the remote branch
2. **Reply** — every comment has a reply explaining what was done (or why it was skipped)
3. **Re-review** — re-review requested from every unique comment author

NEVER skip any of these steps. NEVER push without replying first. NEVER finish without requesting re-review.

---

## Stop Conditions

Pause and ask the user before proceeding when:
- A comment is ambiguous and you cannot confidently propose a fix
- A proposed fix would change a public API contract or database schema
- An error cannot be resolved in 2 attempts
- A fix requires changes outside the PR's scope

---

## Step 1: Find the PR

Auto-detect from the current branch:

```bash
gh pr view --json number,title,url,headRefName,baseRefName 2>/dev/null
```

If no open PR exists on this branch, ask the user for a PR number or URL.

Extract `{owner}`, `{repo}`, and `{number}` for all subsequent API calls.

✅ Checkpoint: "Found PR #{number}: {title}"

## Step 2: Fetch all review comments

Pull inline and top-level review comments:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate
gh api repos/{owner}/{repo}/pulls/{number}/reviews --paginate
```

For each comment, extract:
- `author` (GitHub handle — collect unique handles for re-review in Step 7)
- `body` (the comment text)
- `path` + `line` (file and line for inline comments)
- `id` (needed to reply in Step 6)
- `in_reply_to_id` (to reconstruct threads)
- `state` (APPROVED, CHANGES_REQUESTED, COMMENTED)

Filter out already-resolved comments (author replied "done", "fixed", or similar). Focus on unresolved feedback.

✅ Checkpoint: "Found {N} unresolved comments from {reviewers}"

## Step 3: Present problems and proposed fixes

Show every unresolved comment to the user in a single pass — problem and fix side by side — so they can approve everything at once.

For each comment, show:
1. **Reviewer's comment** — quoted verbatim
2. **Current code** — the relevant snippet (5-10 lines of context)
3. **Problem** — your interpretation of what the reviewer is flagging
4. **Proposed fix** — the concrete code change, including any new tests

Example format:

> **Comment #1** by @reviewer on `src/utils/validate.ts:42`
> > _"This doesn't handle empty strings"_
>
> **Problem:** Truthiness check lets `null`/`undefined` skip validation.
> **Fix:** Replace with `typeof x === 'string' && x.trim().length > 0`, add test for null/undefined/empty.

If you disagree with a reviewer's suggestion, say so and propose an alternative with reasoning.

Group comments sharing the same root concern, but ALWAYS show every individual comment — NEVER silently merge or drop any.

After presenting all items, ask the user to approve, adjust, or discuss before implementing.

✅ Checkpoint: "Presented {N} comments for review — awaiting approval"

## Step 4: Implement the changes

After approval, work through each item:
- Make the code changes
- Write or update tests as needed
- Run tests to verify nothing breaks
- Commit following the project's conventions (e.g., `fix(ON-1234): Address review feedback — validate empty strings`)

NEVER batch unrelated fixes into a single commit if they address different concerns.

✅ Checkpoint: "Implemented {N} fixes in {M} commits"

## Step 5: Reply to every comment

MUST reply to every comment before pushing. Use `gh api` to post replies:

```bash
# Inline review comments (attached to specific lines)
gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies \
  -method POST -f body="<reply>"
```

Each reply MUST be concise and specific — state what changed and where:
> Moved validation into `validateInput()` and added a test for null/undefined/empty in `input.test.ts`. See commit `abc1234`.

If a comment was intentionally not addressed (with user approval), reply with the reasoning so the reviewer has context.

✅ Checkpoint: "Replied to {N} comments"

## Step 6: Push

MUST push all changes to the remote branch:

```bash
git push
```

✅ Checkpoint: "Pushed to remote"

## Step 7: Request re-review

MUST request re-review from every unique comment author collected in Step 2:

```bash
gh pr edit {number} --add-reviewer {reviewer1},{reviewer2},...
```

✅ Checkpoint: "Re-review requested from {reviewers}"

## Summary

After all steps, output a final summary:
- Comments addressed: {N}
- Comments skipped (with reasons): {N}
- Commits created: list each with hash and message
- Reviewers notified: {list}
- PR link
