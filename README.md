# claude-config

Personal Claude configuration, mirrored from `~/.claude/`.

## Layout
- `CLAUDE.md` — global Claude instructions
- `settings.json` — global settings (env, permissions, enabled plugins, marketplaces)
- `agents/` — custom sub-agents
- `commands/` — custom slash commands
- `docs/` — authored docs
- `plugins/installed_plugins.json` — snapshot of installed plugins/versions
- `plugins/known_marketplaces.json` — registered marketplaces
- `skills/` — custom skills (each with its own `SKILL.md`)

## Sync
To refresh from `~/.claude`:

```sh
cp ~/.claude/CLAUDE.md ./CLAUDE.md
cp ~/.claude/settings.json ./settings.json
rsync -a --delete ~/.claude/agents/ ./agents/
rsync -a --delete ~/.claude/commands/ ./commands/
rsync -a --delete ~/.claude/docs/ ./docs/
rsync -a --delete ~/.claude/skills/ ./skills/
cp ~/.claude/plugins/installed_plugins.json ./plugins/installed_plugins.json
cp ~/.claude/plugins/known_marketplaces.json ./plugins/known_marketplaces.json
```
