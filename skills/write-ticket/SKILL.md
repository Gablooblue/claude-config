---
name: write-ticket
description: Use when writing, creating, or filing a ticket or Linear issue - "write a ticket", "file this", "ticket this up", "make a Linear issue for X", "create a follow-up ticket" - or when a rule says to create a ticket because none exists. Writes the ticket for a future agent with zero context, verifies every code reference in the repo, and creates it in Linear.
---

# Write Ticket

Write a Linear ticket that a brand-new agent can execute without asking anyone anything.

**The reader.** Assume the agent that picks this up has: no chat history, no memory files, no idea what was tried, possibly a fresh checkout of a different branch. It has the ticket and the repo. Nothing else.

**The rule that follows.** If a fact lives only in this conversation, it goes in the ticket or it is gone forever. When unsure whether to include something, include it.

**But facts, not transcript.** Complete does not mean long. Write distilled facts with evidence. Trim logs and outputs to the lines that prove the point. A reader drowning in noise misses the one constraint that matters.

**Scope lock.** This skill reads code, runs read-only commands, and creates or comments on one Linear issue. It changes no code and does not start the work the ticket describes.

**Stop and ask when:**
- The goal or "done" state is not stated anywhere in the conversation. Ask once; never invent acceptance criteria.
- The request bundles independent pieces of work. Ask whether to file one ticket per piece (recommended) or one combined ticket.
- Linear tools are missing or failing. Write the finished ticket to `.context/tickets/<slug>.md`, tell the user, and stop. Do not retry in a loop.

## Step 1 - Gather

Pull every one of these from the conversation. Write "none" if empty; never skip a heading silently.

- **Goal**: what the user wants to be true when this is done, in their words.
- **Why**: the trigger (bug report, customer, incident, follow-up from PR X).
- **Decisions made**: what was chosen, why, and which alternatives were rejected and why. A cold agent will otherwise re-propose the rejected ones.
- **Constraints**: things the user said must or must not happen (files not to touch, deadlines, backwards-compat, flags).
- **Failed attempts**: what was tried, the exact error or result, and why it failed.
- **Open questions**: anything still undecided. Mark it undecided; do not resolve it yourself.

Then collect repo state (skip if the ticket is not about a code repo):

```bash
git remote get-url origin
git rev-parse --abbrev-ref HEAD
git log --oneline -10
gh pr list --head "$(git rev-parse --abbrev-ref HEAD)" --json number,url,title 2>/dev/null
```

## Step 2 - Verify every reference

For each file, function, class, config key, endpoint, flag, or table you plan to mention:

1. Open it. Confirm it exists at that path on the base branch the ticket targets.
2. Record `path:line` plus a 1-5 line snippet showing the relevant code.
3. If you mention current behavior, show evidence: snippet, log line, query result, or repro command with its output.

Anything you cannot verify gets the prefix `UNVERIFIED:` and a note on why. NEVER silently drop it and NEVER state it as fact.

Line numbers drift. Always pair a line number with the function or symbol name, so the reader can grep if the line moved.

## Step 3 - Check for duplicates

Search Linear with `list_issues` using 2-3 keyword queries (feature name, error message, file name).

- Clear duplicate found: STOP. Show the user the existing issue and ask whether to add a comment with the new context instead. Do not create a second issue.
- Related issues found: link them in the ticket under Links.

## Step 4 - Write the ticket

Title: plain words, verb first, specific. "Stop `syncAccounts` retrying forever on 401", not "Sync bug".

Body uses this exact structure. The top is for humans skimming the board; the `+++ Agent notes` block (Linear's collapsible section) holds everything else. Use real newlines, not `\n`.

```markdown
## Problem
<1-3 plain sentences. What is wrong or missing, for whom.>

## Why it matters
<Impact: who is affected, how often, cost of not doing it.>

## Done when
- [ ] <Checkable outcome. Someone can say yes/no without asking you.>
- [ ] <Tests that must exist or pass.>

+++ Agent notes

### Where to work
- Repo: <owner/name>
- Base branch: <branch>
- Related PRs / commits: <links or "none">

### Background
<Explain the domain and how this part of the system works today, as if the reader never saw this codebase. Gloss every internal term on first use.>

### Current behavior (with evidence)
<What happens now. `path:line` in `symbolName` + snippet. Repro steps with exact command and actual output.>

### Where to change
<Entry points, call chain from trigger to the code that must change, the files most likely touched. `path:line` for each.>

### Decisions already made
- <Decision> - because <reason>. Rejected: <alternative> because <reason>.

### Constraints
<Must / must not. Files or behavior not to touch. Compat, flags, perf limits.>

### Already tried (don't repeat)
- <Attempt> -> <exact result/error> -> <why it failed>.

### How to verify
<Exact test commands, test files to add or extend, manual steps, what output proves success.>

### Open questions
<Unresolved items, each with who can answer it if known. "none" if none.>

### Links
<PRs, Slack threads, Datadog/Sentry links, Figma, related Linear issues.>

+++
```

## Step 5 - Cold-read check

Reread the ticket pretending you are the receiving agent. Fix every failure before creating:

- [ ] No conversation-relative words: "this", "the bug", "as discussed", "the approach above", "the user", "we decided" without saying what.
- [ ] Every pronoun has a clear referent inside the ticket.
- [ ] Every code claim has a `path:line` + symbol, or is marked `UNVERIFIED:`.
- [ ] Every "Done when" item is testable by someone who was not here.
- [ ] Every rejected alternative from Step 1 appears under Decisions.
- [ ] Every internal term or acronym is explained the first time it appears.
- [ ] No secrets, tokens, passwords, customer PII, or raw production data. Redact and say where to find it instead.

## Step 6 - Create in Linear

1. Team is required. Use the team the user named or the team of related issues found in Step 3. If still unknown, ask once.
2. Call `save_issue` with title, team, description. Set assignee/labels/project only if the user said so or the related issues make it obvious.
3. Set status with `list_issue_statuses` for that team if the user asked for a specific state (e.g. "In Progress"); otherwise leave the team default.
4. Report back: identifier, URL, and a one-line list of anything marked `UNVERIFIED:` or left in Open questions.
