# claude-config

My personal [Claude Code](https://docs.claude.com/en/docs/claude-code) configuration — global instructions, custom skills, slash commands, sub-agents, and a snapshot of installed plugins.

This repo mirrors the contents of my `~/.claude/` directory so I can version, share, and restore it across machines.

## Contents

```
.
├── CLAUDE.md                       # Global Claude instructions (always active)
├── settings.json                    # Global settings: env, permissions, enabled plugins, marketplaces
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

Clone into a temporary location, then symlink (or copy) the pieces you want into `~/.claude/`.

```sh
git clone https://github.com/Gablooblue/claude-config.git ~/src/claude-config
cd ~/src/claude-config

# Back up anything existing first
mkdir -p ~/.claude-backup && cp -R ~/.claude/* ~/.claude-backup/ 2>/dev/null || true

# Symlink approach — edits in the repo take effect immediately
ln -sf "$PWD/CLAUDE.md"       ~/.claude/CLAUDE.md
ln -sf "$PWD/settings.json"   ~/.claude/settings.json
ln -sfn "$PWD/agents"         ~/.claude/agents
ln -sfn "$PWD/commands"       ~/.claude/commands
ln -sfn "$PWD/skills"         ~/.claude/skills
# plugins/*.json are informational; copy if you want them in ~/.claude
mkdir -p ~/.claude/plugins
cp plugins/installed_plugins.json   ~/.claude/plugins/installed_plugins.json
cp plugins/known_marketplaces.json  ~/.claude/plugins/known_marketplaces.json
```

To reproduce the plugin setup, open Claude Code and re-add each marketplace listed in `plugins/known_marketplaces.json`, then install the plugins listed in `plugins/installed_plugins.json`. The `settings.json` file already contains `enabledPlugins` and `extraKnownMarketplaces` so Claude Code will pick them up once the marketplaces are reachable.

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
- `permissions.allow` — pre-approved `Bash`, `Read`, and tool patterns.
- `permissions.additionalDirectories` — extra repo paths Claude may access.
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

After editing anything live in `~/.claude/`, sync it back into this repo:

```sh
cp ~/.claude/CLAUDE.md       ./CLAUDE.md
cp ~/.claude/settings.json   ./settings.json
rsync -a --delete ~/.claude/agents/   ./agents/
rsync -a --delete ~/.claude/commands/ ./commands/
rsync -a --delete ~/.claude/docs/     ./docs/
rsync -a --delete ~/.claude/skills/   ./skills/
cp ~/.claude/plugins/installed_plugins.json  ./plugins/installed_plugins.json
cp ~/.claude/plugins/known_marketplaces.json ./plugins/known_marketplaces.json
git add -A && git commit -m "sync from ~/.claude"
```

If you use the symlink install above, this is a no-op — the repo *is* the source of truth.

## What's deliberately NOT in this repo

- `.credentials.json`, MCP auth caches, token caches — secrets.
- `settings.local.json` — machine-specific permission allowlist.
- `cache/`, `backups/`, `debug/`, `history.jsonl`, `paste-cache/`, `plans/`, `projects/`, `sessions/`, `session-env/`, `shell-snapshots/`, `statsig/`, `tasks/`, `telemetry/`, `todos/` — runtime state.
- `plugins/cache/`, `plugins/marketplaces/` — upstream plugin content (refetched on install).

## License

MIT — do whatever you want with the configs and skills. Attribution appreciated but not required.
