# claude-config

My personal [Claude Code](https://docs.claude.com/en/docs/claude-code) configuration — global instructions, custom skills, slash commands, sub-agents, and a snapshot of installed plugins.

This repo mirrors the contents of my `~/.claude/` directory so I can version, share, and restore it across machines.

## Contents

```
.
├── CLAUDE.md                       # Global Claude instructions (always active)
├── install.sh                       # Symlinks this repo into ~/.claude (idempotent)
├── settings.json                    # Global settings: env, permissions, hooks, enabled plugins, marketplaces
├── agents/                          # Custom sub-agents (invoked by name)
│   └── adversarial-code-reviewer.md
├── commands/                        # Custom slash commands
│   └── pr-review.md                 # /pr-review — adversarial PR review via pr-agent
├── docs/                            # Authored reference docs (design specs, etc.)
├── plugins/
│   ├── installed_plugins.json       # Snapshot of installed plugin versions
│   └── known_marketplaces.json      # Registered plugin marketplaces
└── skills/                          # Custom skills (each with its own SKILL.md)
    ├── adversarial-code-review/
    ├── adversarial-tests/
    ├── docs-accuracy-review/
    ├── finish-pr/
    ├── prompt-master/
    ├── resolve-merge-conflicts/
    └── resolve-pr-comments/
```

## Installation

```sh
git clone https://github.com/Gablooblue/claude-config.git ~/src/claude-config
~/src/claude-config/install.sh
```

The script symlinks `CLAUDE.md`, `settings.json`, `agents/`, `commands/`, `skills/`, and `docs/` into `~/.claude/`, so the repo is the source of truth and edits take effect immediately. Any pre-existing real files are moved to a timestamped `~/.claude-backup-*` directory first, so it is safe to re-run.

Plugins reinstall themselves: `settings.json` carries `enabledPlugins` and `extraKnownMarketplaces`, so Claude Code refetches the marketplaces and installs the plugins on first launch. The `plugins/*.json` files are informational snapshots.

Requires `readlink -f` for the auto-sync hooks (any Linux; macOS 12.3+).

## Auto-sync

Two hooks in `settings.json` keep every machine in sync automatically:

- **`SessionStart`** (startup/resume) — runs `git pull --rebase --autostash` on the repo in the background, so each session starts with the latest config.
- **`SessionEnd`** — commits any local config changes (`sync: auto from <hostname>`) and pushes them.

Both hooks locate the repo by resolving the `~/.claude/CLAUDE.md` symlink, so the clone can live anywhere. They no-op silently when `~/.claude/CLAUDE.md` is not a symlink (i.e. this repo is not installed), and never block the session.

Failure mode to know about: if two machines edit the same file offline, the next pull's rebase can stop on a conflict. The hooks stay silent about it — if config changes stop propagating, run `git status` in the repo and finish the rebase by hand.

## Machine-specific settings — `settings.local.json`

The synced `settings.json` must stay portable, so anything with absolute paths belongs in `~/.claude/settings.local.json` (created as an empty stub by `install.sh`, never committed). Claude Code merges it with `settings.json`. Example:

```json
{
  "permissions": {
    "allow": [
      "Read(//Users/gab/Work/analytics/**)"
    ],
    "additionalDirectories": [
      "/Users/gab/Work/analytics/src/analytics/core"
    ]
  }
}
```

If you previously had machine-specific `permissions.allow` entries or `additionalDirectories` in the synced `settings.json`, move them here after pulling this version.

## What each piece does

### `CLAUDE.md` — global instructions
Always-on rules Claude follows across every project. Highlights:

- **Core behavior** — never sycophantic, always plan before implementing, push back with confidence levels.
- **ADHD Communication Protocol** — answer first, bullets, no padding, force binary decisions when deliberation stalls.
- **Stop conditions** — when to pause for confirmation (deletes, irreversible actions, 2 failed attempts).
- **Engineering principles** — blast radius, reversibility, fail fast, YAGNI, DRY, Boy Scout rule, simplicity.
- **Tests / commits / PR reviews** — conventions I want enforced on every change.

### `settings.json` — global Claude settings
- `env` — environment variables (e.g. `ENABLE_LSP_TOOL`).
- `permissions.allow` — pre-approved `Bash`, `Read`, and tool patterns (portable ones only; machine-specific paths go in `settings.local.json`).
- `hooks` — the auto-sync hooks described above.
- `enabledPlugins` — which installed plugins are active.
- `extraKnownMarketplaces` — custom plugin marketplaces (including private ones).
- `effortLevel` — Claude's default effort tier.

### `agents/` — custom sub-agents
Sub-agents are invoked by Claude as specialized reviewers. Frontmatter defines `name`, `description`, and `model`.

- **`adversarial-code-reviewer`** — harsh review of `git diff HEAD`. Finds design flaws, edge cases, error handling gaps, performance issues, and security holes. Categorizes findings as Critical / Important / Nitpick.

### `commands/` — slash commands
- **`/pr-review [repo]`** — Discovers open PRs via `pr-agent`, fetches diffs with `gh pr diff`, produces adversarial review comments, and posts them back via `pr-agent post`. Interactive: `[y]es / [a]pprove / [d]etail / [n]o / [s]kip`.

### `skills/` — custom skills
Skills are domain-specific procedures. Each has a `SKILL.md` with frontmatter describing when it triggers and what tools it may use.

- **`adversarial-code-review`** — senior-engineer-from-hell review of the current git diff. Classifies findings by severity and confidence, requires a "verified clean" section, and outputs an explicit verdict (`BLOCK` / `PASS WITH FIXES` / `CLEAN`).
- **`adversarial-tests`** — writes edge-case and failure-mode tests for the current diff. Discovers the project's test framework, targets only changed code, stops at 20 cases per function, runs the suite, and reports bugs found.
- **`docs-accuracy-review`** — audits docstrings, JSDoc, READMEs, OpenAPI specs, and inline comments for drift against code changes. Classifies findings as Critical / Stale / Missing and fixes them.
- **`finish-pr`** — Ralph-loop hardening: runs adversarial-tests → code review → docs-accuracy-review in a loop until clean. Emits `<promise>PR CLEAN</promise>` when done.
- **`prompt-master`** — generates optimized prompts for any AI tool. Tool-aware routing (Claude, GPT-5, o3, Gemini, Qwen, Ollama, Cursor, v0, etc.). Refuses to embed techniques that cause fabrication in single-prompt execution.
- **`resolve-merge-conflicts`** — autonomously resolves merge/rebase/cherry-pick conflicts using a 3-tier strategy (lockfiles auto-regenerate, config files merge heuristically, code files analyzed with three-way diff). Escalates genuinely ambiguous conflicts in one batch.
- **`resolve-pr-comments`** — fetches GitHub PR review comments, proposes fixes for all in one pass, implements after approval, replies to every comment, pushes, and requests re-review.

### `docs/`
Design specs and reference material I reuse across skills.

## Updating from `~/.claude`

With the symlink install, edits made live in `~/.claude/` land directly in the repo, and the `SessionEnd` hook commits and pushes them automatically. To sync manually (e.g. after editing outside a Claude session):

```sh
cd ~/src/claude-config
git add -A && git commit -m "sync from ~/.claude" && git push
```

To refresh the plugin snapshots after installing or removing plugins:

```sh
cp ~/.claude/plugins/installed_plugins.json  ./plugins/installed_plugins.json
cp ~/.claude/plugins/known_marketplaces.json ./plugins/known_marketplaces.json
```

## What's deliberately NOT in this repo

- `.credentials.json`, MCP auth caches, token caches — secrets.
- `settings.local.json` — machine-specific permission allowlist.
- `cache/`, `backups/`, `debug/`, `history.jsonl`, `paste-cache/`, `plans/`, `projects/`, `sessions/`, `session-env/`, `shell-snapshots/`, `statsig/`, `tasks/`, `telemetry/`, `todos/` — runtime state.
- `plugins/cache/`, `plugins/marketplaces/` — upstream plugin content (refetched on install).

## License

MIT — do whatever you want with the configs and skills. Attribution appreciated but not required.
