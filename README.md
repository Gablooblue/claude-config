# claude-config

Personal Claude configuration: top-level `CLAUDE.md` and `skills/` directory, mirrored from `~/.claude/`.

## Layout
- `CLAUDE.md` — global Claude instructions
- `skills/` — custom skills (each with its own `SKILL.md`)

## Sync
To refresh from `~/.claude`:

```sh
cp ~/.claude/CLAUDE.md ./CLAUDE.md
rsync -a --delete ~/.claude/skills/ ./skills/
```
