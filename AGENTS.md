# Dotfiles Repository Agent Instructions

This repository stores categorized shared configuration fragments. Native home-directory configuration files remain regular user-owned files and load shared fragments through installer-managed blocks.

## Setup Workflow

1. Run `./install.sh --dry-run` from the repository at any location.
2. Inspect the proposed anchor and native-file changes.
3. Run `./install.sh`.
4. Verify `~/.config/dotfiles` points to the repository.
5. Verify `~/.bashrc`, `~/.bash_profile`, `~/.vimrc`, `~/.tmux.conf`, and `~/.gitconfig` are regular files containing one managed loader block.

## Configuration Contract

- Preserve native configuration outside managed loader blocks.
- Put shared fragments under `config/<category>/<tool>/`.
- Recursively discover only extensions registered for that tool.
- Sort fragments by relative path with `LC_ALL=C`.
- Use numeric filename prefixes when load order matters.
- Keep machine-specific settings and secrets in native files outside managed blocks.
- Do not add a `local/` template layer.
- Do not automatically install or merge configuration formats without a safe include mechanism.
- Run `tests/install_test.sh` after changing installer behavior or directory conventions.

## Safety Rules

- Never commit secrets, API keys, tokens, private credentials, or machine-specific paths.
- Never edit content outside installer-managed blocks in native home-directory files.
- Never replace an unrelated symlink or a real `~/.config/dotfiles` directory.
- Add a new installer adapter before claiming support for a new tool or extension.
- Keep `install.sh` idempotent and keep `--dry-run` free of filesystem mutations.
