#!/usr/bin/env bash
set -euo pipefail

case "$0" in
    /*) REPO_DIR="${0%/*}" ;;
    *) REPO_DIR="$(cd "$(dirname "$0")" && pwd)" ;;
esac
ANCHOR_REL='.config/dotfiles'
ANCHOR="$HOME/$ANCHOR_REL"
BACKUP_DIR="$HOME/dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
BEGIN_MARKER='# >>> dotfiles managed loader >>>'
END_MARKER='# <<< dotfiles managed loader <<<'
VIM_BEGIN='" >>> dotfiles managed loader >>>'
VIM_END='" <<< dotfiles managed loader <<<'
MODE=install
DRY_RUN=0
BACKED_UP=0
TEMP_DIR=
REPORT_CHANGES=()

cleanup() {
    [ -z "$TEMP_DIR" ] || rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

usage() {
    echo "Usage: $0 [--dry-run | --uninstall]"
}

case "${1:-}" in
    '') ;;
    --dry-run) DRY_RUN=1 ;;
    --uninstall) MODE=uninstall ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf 'would run:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

record_change() {
    REPORT_CHANGES+=("$1")
}

backup_file() {
    local target="$1"
    local relpath
    [ -e "$target" ] || [ -L "$target" ] || return 0
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "would back up: $target"
        return 0
    fi
    relpath="${target#$HOME/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$relpath")"
    [ ! -e "$BACKUP_DIR/$relpath" ] && [ ! -L "$BACKUP_DIR/$relpath" ] || return 0
    if [ -L "$target" ]; then
        ln -s "$(readlink "$target")" "$BACKUP_DIR/$relpath"
    else
        cp -a "$target" "$BACKUP_DIR/$relpath"
    fi
    BACKED_UP=1
}

ensure_anchor() {
    local current
    run mkdir -p "$HOME/.config"
    if [ -L "$ANCHOR" ]; then
        current="$(readlink "$ANCHOR")"
        [ "$current" = "$REPO_DIR" ] && return 0
        record_change "replace stable anchor: $ANCHOR"
        run rm "$ANCHOR"
    elif [ -e "$ANCHOR" ]; then
        echo "Refusing to replace non-symlink anchor: $ANCHOR" >&2
        exit 1
    else
        record_change "create stable anchor: $ANCHOR"
    fi
    run ln -s "$REPO_DIR" "$ANCHOR"
}

prepare_native_file() {
    local target="$1"
    local link
    run mkdir -p "$(dirname "$target")"
    if [ -L "$target" ]; then
        link="$(readlink "$target")"
        case "$link" in
            "$REPO_DIR"/*|"$ANCHOR"/*)
                backup_file "$target"
                run rm "$target"
                [ "$DRY_RUN" -eq 1 ] || : > "$target"
                ;;
            *)
                echo "Refusing to replace unrelated symlink: $target -> $link" >&2
                exit 1
                ;;
        esac
    elif [ ! -e "$target" ]; then
        [ "$DRY_RUN" -eq 1 ] || : > "$target"
    elif [ ! -f "$target" ]; then
        echo "Refusing to modify non-file target: $target" >&2
        exit 1
    fi
}

validate_markers() {
    local target="$1"
    local begin="$2"
    local end="$3"
    if ! awk -v begin="$begin" -v end="$end" '
        $0 == begin {
            if (seen_begin || seen_end) exit 1
            seen_begin = 1
        }
        $0 == end {
            if (!seen_begin || seen_end) exit 1
            seen_end = 1
        }
        END { if (seen_begin != seen_end) exit 1 }
    ' "$target"; then
        echo "Malformed managed block in $target" >&2
        exit 1
    fi
}

remove_block_to() {
    local target="$1"
    local begin="$2"
    local end="$3"
    local output="$4"
    awk -v begin="$begin" -v end="$end" '
        $0 == begin { inside = 1; next }
        $0 == end { inside = 0; next }
        !inside { print }
    ' "$target" > "$output"
}

write_block() {
    local target="$1"
    local begin="$2"
    local end="$3"
    local body_file="$4"
    local temp="$TEMP_DIR/block"
    local clean="$TEMP_DIR/clean"
    prepare_native_file "$target"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "would update: $target"
        record_change "update managed block: $target"
        return 0
    fi
    validate_markers "$target" "$begin" "$end"
    remove_block_to "$target" "$begin" "$end" "$clean"
    sed -e '${/^[[:space:]]*$/d;}' "$clean" > "$temp"
    [ ! -s "$temp" ] || printf '\n' >> "$temp"
    printf '%s\n' "$begin" >> "$temp"
    cat "$body_file" >> "$temp"
    printf '%s\n' "$end" >> "$temp"
    if cmp -s "$temp" "$target"; then
        rm -f "$temp" "$clean"
        return 0
    fi
    backup_file "$target"
    mv "$temp" "$target"
    rm -f "$clean"
    record_change "updated managed block: $target"
}

remove_managed_block() {
    local target="$1"
    local begin="$2"
    local end="$3"
    local temp="$TEMP_DIR/uninstall"
    [ -f "$target" ] || return 0
    validate_markers "$target" "$begin" "$end"
    grep -Fq "$begin" "$target" || return 0
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "would remove managed block: $target"
        record_change "remove managed block: $target"
        return 0
    fi
    backup_file "$target"
    remove_block_to "$target" "$begin" "$end" "$temp"
    mv "$temp" "$target"
    record_change "removed managed block: $target"
}

discover() {
    local root="$1"
    local pattern="$2"
    [ -d "$ANCHOR/$root" ] || return 0
    find "$ANCHOR/$root" -type f -name "$pattern" -print | LC_ALL=C sort
}

validate_relative_path() {
    local relative="$1"
    case "$relative" in
        *[!A-Za-z0-9_./-]*)
            echo "Unsupported fragment path: $relative" >&2
            exit 1
            ;;
    esac
}

relative_to_anchor() {
    printf '%s\n' "${1#$ANCHOR/}"
}

render_source_block() {
    local kind="$1"
    local root="$2"
    local pattern="$3"
    local output="$4"
    local file relative
    : > "$output"
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        relative="$(relative_to_anchor "$file")"
        validate_relative_path "$relative"
        case "$kind" in
            bash) printf 'source "$HOME/%s/%s"\n' "$ANCHOR_REL" "$relative" >> "$output" ;;
            vim) printf "execute 'source ' . fnameescape(expand('~/%s/%s'))\n" "$ANCHOR_REL" "$relative" >> "$output" ;;
            tmux) printf 'source-file ~/%s/%s\n' "$ANCHOR_REL" "$relative" >> "$output" ;;
            git) printf '[include]\n    path = ~/%s/%s\n' "$ANCHOR_REL" "$relative" >> "$output" ;;
            ghostty) printf 'config-file = ~/%s/%s\n' "$ANCHOR_REL" "$relative" >> "$output" ;;
        esac
    done < <(discover "$root" "$pattern")
}

install_adapter() {
    local target="$1"
    local kind="$2"
    local root="$3"
    local pattern="$4"
    local begin="$5"
    local end="$6"
    local body="$TEMP_DIR/body"
    if [ "$DRY_RUN" -eq 1 ]; then
        write_block "$target" "$begin" "$end" /dev/null
        return
    fi
    render_source_block "$kind" "$root" "$pattern" "$body"
    write_block "$target" "$begin" "$end" "$body"
    rm -f "$body"
}

uninstall_adapter() {
    remove_managed_block "$1" "$5" "$6"
}

for_each_adapter() {
    local action="$1"
    "$action" "$HOME/.bashrc" bash config/shells/bash/rc.d '*.bash' "$BEGIN_MARKER" "$END_MARKER"
    "$action" "$HOME/.bash_profile" bash config/shells/bash/profile.d '*.bash' "$BEGIN_MARKER" "$END_MARKER"
    "$action" "$HOME/.vimrc" vim config/editors/vim '*.vim' "$VIM_BEGIN" "$VIM_END"
    "$action" "$HOME/.tmux.conf" tmux config/terminals/tmux '*.conf' "$BEGIN_MARKER" "$END_MARKER"
    "$action" "$HOME/.gitconfig" git config/development/git '*.gitconfig' "$BEGIN_MARKER" "$END_MARKER"
    if [ "$(uname -s)" = Darwin ]; then
        "$action" "$HOME/.config/ghostty/config" ghostty config/applications/ghostty '*.ghostty' "$BEGIN_MARKER" "$END_MARKER"
    fi
}

install_all() {
    ensure_anchor
    if [ "$DRY_RUN" -eq 1 ]; then
        for_each_adapter install_adapter
        return
    fi
    TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"
    for_each_adapter install_adapter
}

uninstall_all() {
    [ "$DRY_RUN" -eq 1 ] || TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"
    for_each_adapter uninstall_adapter
    if [ -L "$ANCHOR" ] && [ "$(readlink "$ANCHOR")" = "$REPO_DIR" ]; then
        run rm "$ANCHOR"
        record_change "removed stable anchor: $ANCHOR"
    fi
}

print_report() {
    local heading change
    if [ "$DRY_RUN" -eq 1 ]; then
        heading='Dry-run operations'
    elif [ "$MODE" = uninstall ]; then
        heading='Uninstall report'
    else
        heading='Install report'
    fi

    printf '\n%s:\n' "$heading"
    if [ "${#REPORT_CHANGES[@]}" -eq 0 ]; then
        echo '  No managed changes.'
    else
        for change in "${REPORT_CHANGES[@]}"; do
            printf '  - %s\n' "$change"
        done
    fi

    [ "$MODE" = install ] || return 0
    cat <<'EOF'

Optional Codex skill packages (not run):
  Matt Pocock skills (upstream interactive installer, global scope):
  npx skills@latest add mattpocock/skills -g
  Select only: grilling, grill-me, handoff, teach, to-spec, to-tickets, and writing-great-skills.
  Of these, grilling is model-invoked; the other six are user-invoked.
  Without setup-matt-pocock-skills, give to-spec and to-tickets an explicit publication destination when invoking them.

  Update the selected Matt Pocock skills:
  npx skills@latest update -g grilling grill-me handoff teach to-spec to-tickets writing-great-skills

  Asterism skills:
  npx skills@latest add Astery0502/asterism
  These commands inherit HTTP_PROXY and HTTPS_PROXY from your environment.
EOF
}

if [ "$MODE" = uninstall ]; then
    uninstall_all
else
    install_all
fi

if [ "$BACKED_UP" -eq 1 ]; then
    echo "Backups saved to: $BACKUP_DIR"
fi

print_report
