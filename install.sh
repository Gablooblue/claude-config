#!/usr/bin/env bash
# Symlink this repo's config into ~/.claude so the repo is the source of truth.
# Safe to re-run; existing real files are backed up first, existing symlinks are replaced.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"

SYMLINKS=(CLAUDE.md settings.json agents commands skills docs)

mkdir -p "$CLAUDE_DIR"

backup() {
  local target="$1"
  # Only back up real files/dirs; symlinks from a previous install are just replaced.
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/$(basename "$target")"
    echo "backed up: $target -> $BACKUP_DIR/$(basename "$target")"
  fi
}

for name in "${SYMLINKS[@]}"; do
  src="$REPO_DIR/$name"
  dest="$CLAUDE_DIR/$name"
  if [ ! -e "$src" ]; then
    echo "skip (not in repo): $name"
    continue
  fi
  backup "$dest"
  ln -sfn "$src" "$dest"
  echo "linked: $dest -> $src"
done

# Plugin snapshots are informational; copy rather than symlink so Claude Code
# can rewrite them freely without dirtying the repo.
mkdir -p "$CLAUDE_DIR/plugins"
for f in installed_plugins.json known_marketplaces.json; do
  if [ -e "$REPO_DIR/plugins/$f" ] && [ ! -e "$CLAUDE_DIR/plugins/$f" ]; then
    cp "$REPO_DIR/plugins/$f" "$CLAUDE_DIR/plugins/$f"
    echo "copied: $CLAUDE_DIR/plugins/$f"
  fi
done

# Stub for machine-specific settings (permissions.allow paths, additionalDirectories).
# Claude Code merges this with the synced settings.json. Never committed.
if [ ! -e "$CLAUDE_DIR/settings.local.json" ]; then
  printf '{\n}\n' > "$CLAUDE_DIR/settings.local.json"
  echo "created: $CLAUDE_DIR/settings.local.json (put machine-specific settings here)"
fi

echo
echo "Done. Repo: $REPO_DIR"
echo "Auto-sync hooks in settings.json will pull on session start and commit+push on session end."
