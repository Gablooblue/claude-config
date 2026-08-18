# Design: explain-pr + explain-plan skills

Date: 2026-08-18
Status: Approved (conversation, 2026-08-18)

## Problem

Gab reviews PRs written by agents in repos they barely know. Two failure moments:
1. Approving an agent's plan without understanding the code it references (rubber-stamping).
2. Reviewing an agent's finished PR without understanding what the diff actually does.

Requirements confirmed with Gab:
- Triggers: PR review and plan approval (explicit invocation, no auto-trigger).
- Output: visual HTML page (rendered artifact with diagrams), not terminal text.
- Persistence: explanations accumulate into a per-repo orientation guide.
- Depth: ELI-new-hire. Zero repo knowledge assumed. Every term glossed.

## Architecture

Two skills in `~/.claude/skills/`, sharing one persistent guide file per repo.

```
~/.claude/skills/explain-pr/SKILL.md
~/.claude/skills/explain-plan/SKILL.md
~/.claude/repo-guides/<repo-basename>.md   (created on first run)
```

Rejected alternatives:
- 3 skills (process-map, component-breakdown, combiner): process map and
  component breakdown are sections of one explanation, never wanted alone;
  the combiner is maintenance overhead with no gain.
- 1 skill with modes: two distinct workflows in one description triggers
  less reliably and bloats the SKILL.md.
- Dedicated /explain-repo skill: the guide file already serves orientation;
  a plain sentence ("walk me through the repo guide") covers rendering it.

## Component 1: The repo guide (shared foundation)

- Path: `~/.claude/repo-guides/<repo-key>.md`, where repo-key is derived
  from the repo's identity, not the checkout path (Gab works in worktrees;
  every worktree of a repo must resolve to the same guide):
  1. If an `origin` remote exists: slug of its URL (strip protocol/host
     noise, e.g. `github-com-mutinyhq-app.md`). Also unifies multiple
     clones of the same repo.
  2. Else: basename of the parent of `git rev-parse --git-common-dir`
     (points at the main repo's .git from any linked worktree).
- Lives outside every repo. Never committed, never appears in a PR diff.
- Concurrent-write caveat: agents in different worktrees may finish runs
  simultaneously. Mitigation: re-read the guide immediately before writing
  back, merge entries, then write. No lock files (personal cache,
  regenerates itself).
- Sections:
  - **Overview** - what the app does, max 5 sentences. Written on first run.
  - **Components** - one entry per file/module ever explained: path,
    plain-language purpose, key gotchas.
  - **Flows** - named mermaid diagrams (e.g. "login request path").
  - **Glossary** - repo jargon, each term defined once.
- Staleness defense: every component entry is stamped with the commit hash
  at write time. When a skill re-encounters a component whose file changed
  since that hash (`git log -1 --format=%H -- <path>` differs), it re-reads
  the file and updates the entry. The guide is a cache; the code is the truth.
- Both skills read the guide first (do not re-derive known components) and
  write back new/updated entries at the end of every run.
- The guide doubles as the orientation doc: after a few runs it answers
  "what even is this repo" on its own.

## Component 2: explain-pr skill

- Input acquisition ladder (stop at first that yields content):
  1. PR number given -> `gh pr diff <n>`
  2. Branch context -> `git diff <default-branch>...HEAD` (default branch
     from `git symbolic-ref refs/remotes/origin/HEAD`, fallback main/master)
  3. Working tree -> `git diff HEAD`
  If all empty: state "no changes found" and stop.
- Analysis rules:
  - Read every touched file in full. Never explain a hunk in isolation.
  - Grep for direct callers of changed functions to establish blast radius.
- Output: one HTML artifact containing:
  - **TL;DR** - what this PR does, 3 plain sentences.
  - **Process map** - before/after mermaid flow of the affected path,
    with the changed step visually marked.
  - **Component breakdown** - per touched file: what it is, why it exists,
    what this change does to it, what breaks if the change is wrong.
  - **Check-this-yourself** - 2-4 concrete manual verifications (URLs to
    hit, commands to run). Feeds Gab's manual-test-before-PR rule.
  - **Glossary** - terms used above, glossed.
- Guide update: add/refresh entries for every touched component, add new
  glossary terms, add/update the affected flow diagram.

## Component 3: explain-plan skill

- Input: an agent's plan - pasted text, a file path, or the plan present
  in the current conversation.
- Analysis rules:
  - For each plan step, grep/read the actual code it references.
  - Establish what that code does today, before the plan changes it.
- Output: one HTML artifact containing:
  - **Plan-to-code map** - per step: code it touches, current behavior,
    what the step changes.
  - **Risk flags** - steps touching code the plan misdescribes, unknown
    APIs, migrations, irreversible actions. Framed as "this step is an
    assumption, not a fact."
  - **Questions to ask the agent** - 2-3 concrete challenges to raise
    before approving.
- Guide update: same rules as explain-pr for any components it explained.

## HTML page design (ADHD affordances)

Each skill ships a fixed `template.html` next to its SKILL.md; Claude fills
slots, never freestyles page structure. Consistency across runs builds
spatial memory ("risks are always the red box, third section down").

- Section order is invariant: TL;DR -> diagram -> components -> risks/
  checks -> glossary.
- TL;DR pinned at top as a visually distinct card, 3 sentences max.
- Every component entry is a collapsed <details> block with a one-line
  summary; reader expands only what they care about.
- Sticky section nav with counts ("Components (4) - Risks (2)").
- Color-coded severity badges (red/amber/green) on risks and components.
- Diagrams render unchanged flow in gray, new/modified steps in one accent
  color.
- Max 2 sentences per bullet, enforced in skill instructions.
- No animation, no decorative noise.
- Check-this-yourself items are literal checkboxes with copyable commands.

## Explanation style (baked into both SKILL.md files)

Enforced in skill instructions so it survives fresh sessions:
- Mechanism, never category ("holds the result in memory for 60s" not
  "uses a caching strategy").
- Name the real thing: file, function, value, error.
- Gloss every unavoidable term on first use.
- Assume zero repo knowledge, competent general engineering knowledge.

## Error handling

- Not a git repo: say so and stop (no guide path derivable).
- `gh` missing/unauthenticated: fall back to git diff ladder; note the
  degradation in output.
- Guide file corrupt/unparseable: rename to `<name>.md.bak`, start fresh,
  tell Gab.
- Plan references code that does not exist: that is itself a top risk flag,
  not an error.

## Out of scope (YAGNI)

- Auto-triggering on every PR.
- Cross-repo guide merging, guide UI, quiz mode.
- Standalone process-map / component-breakdown / explain-repo skills.

## Testing

- Manual: run explain-pr against a real PR in a work repo; verify artifact
  renders, guide file created with stamped entries; run again on a second
  PR touching an overlapping file; verify stale entry refreshed, known
  entries reused.
- Manual: run explain-plan against a real agent plan; verify plan-to-code
  map names real files and risk flags are grounded in the diff between
  plan claims and actual code.
- Skills are prompt artifacts (no unit-testable code). Per Gab's global
  rules, both SKILL.md files get a prompt-master review pass before done.

## Implementation notes

- Follow existing skill conventions (frontmatter: name, description,
  allowed-tools) as in adversarial-code-review.
- Repo-guide conventions duplicated in both SKILL.md files (skills cannot
  share includes); two copies is acceptable at this scale.
- Use superpowers:writing-skills for structure and prompt-master for
  review during implementation.
- The template.html files MUST get an impeccable pass during
  implementation (build once, reused by every run).
- No spike needed - all components are well-understood patterns (git/gh
  commands, artifact publishing, markdown file I/O).
