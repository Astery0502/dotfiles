# dotfiles

Shared configuration fragments loaded by native application configuration files.

## Install

Clone the repository anywhere, using any directory name, then run:

```bash
./install.sh
```

The installer creates `~/.config/dotfiles` as a stable symlink to the repository. It preserves native files such as `~/.bashrc` and manages only marked loader blocks inside them. Existing files are backed up under `~/dotfiles-backup/<timestamp>/` before modification.

Preview changes or remove managed integration with:

```bash
./install.sh --dry-run
./install.sh --uninstall
```

After a successful install or dry run, the final report lists managed changes or planned dry-run operations and prints optional commands for selecting skills from `mattpocock/skills` and `Astery0502/asterism`. The installer does not run these commands or access the network. If needed, set `HTTP_PROXY` and `HTTPS_PROXY` in the invoking environment before running a suggested command.

## Structure

```text
config/
├── shells/bash/
│   ├── rc.d/          # Recursively loaded by ~/.bashrc
│   ├── profile.d/     # Recursively loaded by ~/.bash_profile
│   └── os/            # Selected by the Bash OS route
├── editors/vim/       # Recursively loaded by ~/.vimrc
├── terminals/tmux/    # Recursively loaded by ~/.tmux.conf
├── development/git/   # Included by ~/.gitconfig
└── applications/      # Application configs without universal integration
```

Categories organize tools but do not define installer behavior. Each registered tool adapter accepts only its own extension and loads matching files in `LC_ALL=C` relative-path order. Use numeric prefixes such as `10-options` and `20-bindings` when order matters.

Bash configuration shared by every OS belongs in `rc.d/`. The `rc.d/30-os-route.bash` fragment selects platform-specific configuration from `shells/bash/os/`; files in `os/` are loaded only through that route and are not installer fragments.

Fragment relative paths may contain only ASCII letters, digits, `/`, `.`, `_`, and `-`. This keeps generated Bash, Vim, tmux, and Git syntax deterministic and safe.

## Native Ownership

Machine-specific settings remain in native files outside the managed block:

```bash
# >>> dotfiles managed loader >>>
source "$HOME/.config/dotfiles/config/shells/bash/rc.d/20-main.bash"
# <<< dotfiles managed loader <<<

export MACHINE_SPECIFIC_PATH="/local/path"
```

Do not commit secrets, credentials, private endpoints, or machine-specific paths. Shared fragments may use capability checks such as `command -v` when a setting is portable across machines.

## Supported Adapters

| Tool | Fragment pattern | Native target | Method |
|---|---|---|---|
| Bash interactive | `config/shells/bash/rc.d/**/*.bash` | `~/.bashrc` | `source` |
| Bash login | `config/shells/bash/profile.d/**/*.bash` | `~/.bash_profile` | `source` |
| Vim | `config/editors/vim/**/*.vim` | `~/.vimrc` | `source` |
| tmux | `config/terminals/tmux/**/*.conf` | `~/.tmux.conf` | `source-file` |
| Git | `config/development/git/**/*.gitconfig` | `~/.gitconfig` | `[include]` |
| Ghostty (macOS) | `config/applications/ghostty/**/*.ghostty` | `~/.config/ghostty/config` | `config-file` |

Claude's JSON settings do not support includes. `config/applications/claude/settings.json` is retained as a reference and is not installed, copied, linked, or merged.

## Adding Configuration

1. Put the file under the appropriate registered tool directory.
2. Use the adapter's recognized extension.
3. Add a numeric prefix when its relative load order matters.
4. Run `./install.sh --dry-run` and inspect the proposed update.
5. Run `./install.sh` to regenerate native managed blocks.
6. Run `tests/install_test.sh` before committing.
