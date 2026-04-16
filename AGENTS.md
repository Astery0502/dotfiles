# Dotfiles Repository — Agent Instructions

This repository stores shared shell, editor, git, tmux, and Claude settings and exposes them to `$HOME` with symlinks.

## Repository Structure

```text
bash/          → .bashrc, .bash_profile, .bash_aliases
vim/           → .vimrc
git/           → .gitconfig
claude/        → settings.json
tmux/          → .tmux.conf
local/         → *.example templates for machine-specific overrides
install.sh     → Creates symlinks and bootstraps local override files
```

## Setup Workflow

When the user asks to set up or install dotfiles, follow these steps:

### Step 1: Run install.sh

```bash
cd ~/.dotfiles && ./install.sh
```

This creates symlinks from `$HOME` into this repo and backs up any existing real files to `~/.dotfiles-backup/<timestamp>/`.

### Step 2: Create local override files

Guide the user to create these files from the examples:

1. `~/.bashrc.local` from `local/.bashrc.local.example`
2. `~/.vimrc.local` from `local/.vimrc.local.example`
3. `~/.gitconfig.local` for machine-specific git settings

Ask about conda paths, project `PATH` entries, sourced env files, git identity, signing, credential helpers, and Vim preferences.

### Step 3: Verify

After setup, verify the symlinks:

```bash
ls -la ~/.bashrc ~/.vimrc ~/.gitconfig ~/.claude/settings.json ~/.tmux.conf
```

## Rules

- Never commit secrets, API keys, tokens, or private credentials
- Never modify `*.local` files through git
- Machine-specific paths belong in `~/.bashrc.local`
- When adding a new shared config, add its symlink entry to `install.sh`
- If a config needs local overrides, add an example template instead of committing machine-specific values
- `install.sh` is idempotent and safe to re-run
