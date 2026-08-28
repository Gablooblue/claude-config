---
name: quiz-implementation
description: Use when the user wants to check their own understanding of code changes - "quiz me", "test my understanding", "do I actually understand this diff/PR", or after an agent wrote code the user has not internalized. Also on /quiz-implementation.
---

# Quiz Implementation

Quiz the user on a diff so they could maintain this code without the agent. You are an examiner, not a reviewer: honest grades, no praise padding, no code critique mid-quiz.

Scope lock: this skill READS the repo and WRITES only the ledger file. NEVER modify repo files, even if a quiz question exposes a real bug.

## Step 0 - Repo key and ledger

Derive the repo key (same as explain-pr, so all checkouts share one ledger):

```bash
origin=$(git remote get-url origin 2>/dev/null)
if [ -n "$origin" ]; then
  key=$(printf '%s' "$origin" | sed -E 's#^[a-z]+://##; s#^git@##; s#\.git$##; s#[^A-Za-z0-9]+#-#g' | tr 'A-Z' 'a-z')
else
  key=$(basename "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")")
fi
```

Not inside a git repo: tell the user and STOP. Read `~/.claude/quiz-ledgers/<key>.md` if it exists.

## Step 1 - Acquire the material

First that returns content: PR number/URL given -> `gh pr diff <n>`; else `default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##'); git diff ${default:-main}...HEAD`; else `git diff HEAD`. All empty: say "No changes to quiz on" and STOP.

## Step 2 - Deep read (silent)

- Read every touched file IN FULL.
- Grep the repo for callers of every changed function/class. Tracing questions MUST name real callers, and you cannot know them from the diff alone.
- Diff over 800 changed lines: quiz only the 5 files with the largest blast radius (auth, money, data, shared utilities first) and say so.

## Step 3 - Build the question bank (silent - never show it upfront)

6-8 questions. The bank MUST contain at least one of each type:

| Type | Shape |
|---|---|
| Prediction | "What happens when this input is null / this call fails / two calls race?" |
| Design rationale | "Why X here instead of Y? What breaks with Y?" |
| Tracing | "Who calls this? What do they see if it misbehaves?" - from your Step 2 grep |
| Modify-it | "Where would you add [plausible change]? Sketch it in words." |

Weight toward the riskiest code. Up to 2 slots: unmastered ledger concepts touched by or near this diff, asked FIRST as fresh questions.

## Step 4 - Quiz loop

One question per message. Free-text answer. Each reply is exactly:

1. Verdict: ✅ correct / 🟡 partial / ❌ missed. A half-right answer is 🟡, never ✅.
2. The mechanism with `file:line` - what actually happens and why their answer does or does not match.
3. If 🟡 or ❌: ONE follow-up probe on the same concept, then move on regardless of the result. Teach, don't dogpile.

Modify-it answers are graded against the actual code ("your sketch misses that the catch block resets `attempts`").

## Step 5 - Scorecard and ledger

End with: score (e.g. 5/7), weak spots in plain language with what to re-read (`file:function`), and - only if the quiz exposed a genuine bug - one line flagging it (no fix, scope lock applies).

Then update `~/.claude/quiz-ledgers/<key>.md` (create dir/file if missing):

```markdown
# Quiz ledger: <key>

| Concept | Anchor | Last asked | Streak |
|---|---|---|---|
| stale-on-error fallback | src/userCache.js:fetchUser | 2026-08-28 | 0 |
```

Streak = consecutive fully-correct answers. ✅ increments, 🟡/❌ resets to 0 (add the row if new). A row reaching streak 2 is removed - mastered. Tell the user which concepts were mastered or added.
