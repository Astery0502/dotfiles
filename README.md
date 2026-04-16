# dotfiles

Personal configuration files managed with git and symlinks.

## Quick Start

```bash
git clone https://github.com/Astery0502/.dotfiles ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Then create local override files as needed from the examples in `local/`.

## Structure

```text
~/.dotfiles/
├── bash/          # Bash config (.bashrc, .bash_profile, .bash_aliases)
├── vim/           # Vim config (.vimrc)
├── git/           # Git config (.gitconfig)
├── claude/        # Shared Claude settings
├── tmux/          # Tmux config
├── local/         # Example templates for machine-specific overrides
├── install.sh     # Symlink installer (backs up existing files)
└── CLAUDE.md      # Repo instructions for Claude-assisted setup
```

## How It Works

- Shared config files live in this repo under category directories
- `install.sh` creates symlinks from `$HOME` pointing into this repo
- Machine-specific values go in `*.local` files which are git-ignored
- Main configs source or extend their local counterparts if they exist

## Local Override Files

These are not tracked by git. Create them from the examples:

| Example Template | Create As |
|---|---|
| `local/.bashrc.local.example` | `~/.bashrc.local` |
| `local/.vimrc.local.example` | `~/.vimrc.local` |

## Adding a New Config

1. Place the shared version in the appropriate directory, for example `tool/.toolrc`
2. Add a symlink entry in `install.sh`
3. If it needs machine-specific overrides, add a `local/*.example` template
4. Make the main config source or extend the local file conditionally

## Assistant Setup

Open Claude Code in this directory and use the repo instructions in `CLAUDE.md` to walk through setup.

## Rules

- Never commit secrets, API keys, tokens, or private endpoints
- Machine-specific paths belong in `*.local` files
- `install.sh` is idempotent and safe to re-run
