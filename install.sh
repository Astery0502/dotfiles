#!/usr/bin/env bash
set -euo pipefail

case "$0" in
    /*) REPO_DIR="${0%/*}" ;;
    *) REPO_DIR="$(cd "$(dirname "$0")" && pwd)" ;;
esac
ANCHOR="$HOME/.config/dotfiles"
BACKUP_DIR="$HOME/dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
BEGIN_MARKER='# >>> dotfiles managed loader >>>'
END_MARKER='# <<< dotfiles managed loader <<<'
VIM_BEGIN='" >>> dotfiles managed loader >>>'
VIM_END='" <<< dotfiles managed loader <<<'
MODE=install
DRY_RUN=0
BACKED_UP=0

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

backup_file() {
    target="$1"
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
    run mkdir -p "$HOME/.config"
    if [ -L "$ANCHOR" ]; then
        current="$(readlink "$ANCHOR")"
        [ "$current" = "$REPO_DIR" ] && return 0
        run rm "$ANCHOR"
    elif [ -e "$ANCHOR" ]; then
        echo "Refusing to replace non-symlink anchor: $ANCHOR" >&2
        exit 1
    fi
    run ln -s "$REPO_DIR" "$ANCHOR"
}

prepare_native_file() {
    target="$1"
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
    target="$1"
    begin="$2"
    end="$3"
    begin_count="$(grep -Fc "$begin" "$target" || true)"
    end_count="$(grep -Fc "$end" "$target" || true)"
    if [ "$begin_count" -gt 1 ] || [ "$end_count" -gt 1 ] || [ "$begin_count" != "$end_count" ]; then
        echo "Malformed managed block in $target" >&2
        exit 1
    fi
}

remove_block_to() {
    target="$1"
    begin="$2"
    end="$3"
    output="$4"
    awk -v begin="$begin" -v end="$end" '
        $0 == begin { inside = 1; next }
        $0 == end { inside = 0; next }
        !inside { print }
    ' "$target" > "$output"
}

write_block() {
    target="$1"
    begin="$2"
    end="$3"
    body_file="$4"
    prepare_native_file "$target"
    [ "$DRY_RUN" -eq 1 ] && { echo "would update: $target"; return 0; }
    validate_markers "$target" "$begin" "$end"
    temp="$(mktemp "${TMPDIR:-/tmp}/dotfiles-block.XXXXXX")"
    clean="$(mktemp "${TMPDIR:-/tmp}/dotfiles-clean.XXXXXX")"
    remove_block_to "$target" "$begin" "$end" "$clean"
    sed -e '${/^[[:space:]]*$/d;}' "$clean" > "$temp"
    [ ! -s "$temp" ] || printf '\n' >> "$temp"
    printf '%s\n' "$begin" >> "$temp"
    cat "$body_file" >> "$temp"
    printf '%s\n' "$end" >> "$temp"
    backup_file "$target"
    mv "$temp" "$target"
    rm -f "$clean"
}

remove_managed_block() {
    target="$1"
    begin="$2"
    end="$3"
    [ -f "$target" ] || return 0
    validate_markers "$target" "$begin" "$end"
    grep -Fq "$begin" "$target" || return 0
    [ "$DRY_RUN" -eq 1 ] && { echo "would remove managed block: $target"; return 0; }
    backup_file "$target"
    temp="$(mktemp "${TMPDIR:-/tmp}/dotfiles-uninstall.XXXXXX")"
    remove_block_to "$target" "$begin" "$end" "$temp"
    mv "$temp" "$target"
}

discover() {
    root="$1"
    pattern="$2"
    [ -d "$ANCHOR/$root" ] || return 0
    find "$ANCHOR/$root" -type f -name "$pattern" -print | LC_ALL=C sort
}

validate_relative_path() {
    relative="$1"
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
    kind="$1"
    root="$2"
    pattern="$3"
    output="$4"
    : > "$output"
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        relative="$(relative_to_anchor "$file")"
        validate_relative_path "$relative"
        case "$kind" in
            bash) printf 'source "$HOME/.config/dotfiles/%s"\n' "$relative" >> "$output" ;;
            vim) printf "execute 'source ' . fnameescape(expand('~/.config/dotfiles/%s'))\n" "$relative" >> "$output" ;;
            tmux) printf 'source-file ~/.config/dotfiles/%s\n' "$relative" >> "$output" ;;
            git) printf '[include]\n    path = ~/.config/dotfiles/%s\n' "$relative" >> "$output" ;;
        esac
    done < <(discover "$root" "$pattern")
}

install_adapter() {
    target="$1"
    kind="$2"
    root="$3"
    pattern="$4"
    body="$(mktemp "${TMPDIR:-/tmp}/dotfiles-body.XXXXXX")"
    render_source_block "$kind" "$root" "$pattern" "$body"
    if [ "$kind" = vim ]; then
        write_block "$target" "$VIM_BEGIN" "$VIM_END" "$body"
    else
        write_block "$target" "$BEGIN_MARKER" "$END_MARKER" "$body"
    fi
    rm -f "$body"
}

install_all() {
    ensure_anchor
    install_adapter "$HOME/.bashrc" bash config/shells/bash/rc.d '*.bash'
    install_adapter "$HOME/.bash_profile" bash config/shells/bash/profile.d '*.bash'
    install_adapter "$HOME/.vimrc" vim config/editors/vim '*.vim'
    install_adapter "$HOME/.tmux.conf" tmux config/terminals/tmux '*.conf'
    install_adapter "$HOME/.gitconfig" git config/development/git '*.gitconfig'
}

uninstall_all() {
    remove_managed_block "$HOME/.bashrc" "$BEGIN_MARKER" "$END_MARKER"
    remove_managed_block "$HOME/.bash_profile" "$BEGIN_MARKER" "$END_MARKER"
    remove_managed_block "$HOME/.vimrc" "$VIM_BEGIN" "$VIM_END"
    remove_managed_block "$HOME/.tmux.conf" "$BEGIN_MARKER" "$END_MARKER"
    remove_managed_block "$HOME/.gitconfig" "$BEGIN_MARKER" "$END_MARKER"
    if [ -L "$ANCHOR" ] && [ "$(readlink "$ANCHOR")" = "$REPO_DIR" ]; then
        run rm "$ANCHOR"
    fi
}

if [ "$MODE" = uninstall ]; then
    uninstall_all
else
    install_all
fi

if [ "$BACKED_UP" -eq 1 ]; then
    echo "Backups saved to: $BACKUP_DIR"
fi
