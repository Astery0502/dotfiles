#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
BACKED_UP=0

# Symlink map: source (relative to DOTFILES_DIR) -> target (absolute)
declare -a LINKS=(
    "bash/.bashrc:$HOME/.bashrc"
    "bash/.bash_profile:$HOME/.bash_profile"
    "bash/.bash_aliases:$HOME/.bash_aliases"
    "vim/.vimrc:$HOME/.vimrc"
    "git/.gitconfig:$HOME/.gitconfig"
    "claude/settings.json:$HOME/.claude/settings.json"
    "tmux/.tmux.conf:$HOME/.tmux.conf"
)

backup_file() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        if [ $BACKED_UP -eq 0 ]; then
            mkdir -p "$BACKUP_DIR"
            BACKED_UP=1
        fi
        local relpath="${target#$HOME/}"
        local backup_path="$BACKUP_DIR/$relpath"
        mkdir -p "$(dirname "$backup_path")"
        cp -a "$target" "$backup_path"
        echo "  backed up: $target -> $backup_path"
    fi
}

create_symlink() {
    local src="$1"
    local target="$2"

    mkdir -p "$(dirname "$target")"
    backup_file "$target"

    if [ -d "$target" ] && [ ! -L "$target" ]; then
        rm -rf "$target"
    else
        rm -f "$target"
    fi

    ln -s "$src" "$target"
    echo "  linked: $target -> $src"
}

echo "=== dotfiles install ==="
echo "Source: $DOTFILES_DIR"
echo ""

echo "Creating symlinks..."
for entry in "${LINKS[@]}"; do
    src_rel="${entry%%:*}"
    target="${entry##*:}"
    src_abs="$DOTFILES_DIR/$src_rel"

    if [ ! -e "$src_abs" ]; then
        echo "  SKIP (missing): $src_abs"
        continue
    fi

    create_symlink "$src_abs" "$target"
done

echo ""
if [ $BACKED_UP -eq 1 ]; then
    echo "Backups saved to: $BACKUP_DIR"
else
    echo "No backups needed (no existing real files were replaced)."
fi

echo ""
echo "Bootstrapping local override files..."
if [ ! -f "$HOME/.bashrc.local" ]; then
    cp "$DOTFILES_DIR/local/.bashrc.local.example" "$HOME/.bashrc.local"
    echo "  created: ~/.bashrc.local (edit to customize)"
else
    echo "  already exists: ~/.bashrc.local (skipped)"
fi

echo ""
echo "Done. Other local override files to create manually:"
echo "  ~/.vimrc.local           (see local/.vimrc.local.example)"
echo "  ~/.gitconfig.local       (for machine-specific git config)"
