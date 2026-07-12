# Dotfiles Repository Agent Instructions

Read `README.md` before making changes. It is the source of truth for the repository layout, installation workflow, native-file ownership, supported adapters, fragment loading, and validation steps.

## Additional Agent Constraints

- Do not add a `local/` template layer.
- Do not automatically install or merge configuration formats without a safe include mechanism.
- Never replace an unrelated symlink or a real `~/.config/dotfiles` directory.
- Add a new installer adapter before claiming support for a new tool or extension.
- Keep `install.sh` idempotent and keep `--dry-run` free of filesystem mutations.
