#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file() {
    [ -f "$1" ] || fail "expected regular file: $1"
}

assert_symlink_to() {
    [ -L "$1" ] || fail "expected symlink: $1"
    [ "$(readlink "$1")" = "$2" ] || fail "unexpected target for $1"
}

assert_contains() {
    grep -Fq "$2" "$1" || fail "expected '$2' in $1"
}

assert_not_contains() {
    if grep -Fq "$2" "$1"; then
        fail "did not expect '$2' in $1"
    fi
}

assert_count() {
    actual="$(grep -Fc "$2" "$1" || true)"
    [ "$actual" = "$3" ] || fail "expected $3 occurrences of '$2' in $1, got $actual"
}

make_repo() {
    fixture="$TEST_ROOT/repo"
    mkdir -p "$fixture"
    cp "$REPO_ROOT/install.sh" "$fixture/install.sh"
    chmod +x "$fixture/install.sh"
    mkdir -p \
        "$fixture/config/shells/bash/rc.d/nested" \
        "$fixture/config/shells/bash/profile.d" \
        "$fixture/config/editors/vim/nested" \
        "$fixture/config/terminals/tmux/nested" \
        "$fixture/config/development/git/nested"
    printf '%s\n' 'export FIRST=1' > "$fixture/config/shells/bash/rc.d/10-first.bash"
    printf '%s\n' 'export LAST=1' > "$fixture/config/shells/bash/rc.d/nested/20-last.bash"
    printf '%s\n' 'source ~/.bashrc' > "$fixture/config/shells/bash/profile.d/10-login.bash"
    printf '%s\n' 'set number' > "$fixture/config/editors/vim/nested/10-options.vim"
    printf '%s\n' 'set -g mouse on' > "$fixture/config/terminals/tmux/nested/10-options.conf"
    printf '%s\n' '[init]' '    defaultBranch = main' > "$fixture/config/development/git/nested/10-core.gitconfig"
    printf '%s\n' 'do not load me' > "$fixture/config/shells/bash/rc.d/README.md"
}

test_install_preserves_native_files() {
    make_repo
    home="$TEST_ROOT/home"
    mkdir -p "$home"
    printf '%s\n' 'export MACHINE_ONLY=1' > "$home/.bashrc"

    HOME="$home" "$TEST_ROOT/repo/install.sh"

    assert_symlink_to "$home/.config/dotfiles" "$TEST_ROOT/repo"
    assert_file "$home/.bashrc"
    assert_contains "$home/.bashrc" 'export MACHINE_ONLY=1'
    assert_contains "$home/.bashrc" '# >>> dotfiles managed loader >>>'
    assert_contains "$home/.bashrc" '10-first.bash'
    assert_contains "$home/.bashrc" 'nested/20-last.bash'
    assert_not_contains "$home/.bashrc" 'README.md'
    first_line="$(grep -n '10-first.bash' "$home/.bashrc" | cut -d: -f1)"
    last_line="$(grep -n 'nested/20-last.bash' "$home/.bashrc" | cut -d: -f1)"
    [ "$first_line" -lt "$last_line" ] || fail "Bash fragments are not sorted"
}

test_install_is_idempotent() {
    home="$TEST_ROOT/home"
    HOME="$home" "$TEST_ROOT/repo/install.sh"
    assert_count "$home/.bashrc" '# >>> dotfiles managed loader >>>' 1
    assert_count "$home/.bashrc" '# <<< dotfiles managed loader <<<' 1
}

test_install_preserves_native_files
test_install_is_idempotent
echo "PASS: install tests"
