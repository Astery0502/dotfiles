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

test_all_adapters() {
    home="$TEST_ROOT/home"
    assert_contains "$home/.bash_profile" 'profile.d/10-login.bash'
    assert_contains "$home/.vimrc" 'nested/10-options.vim'
    assert_contains "$home/.tmux.conf" 'nested/10-options.conf'
    assert_contains "$home/.gitconfig" '[include]'
    assert_contains "$home/.gitconfig" 'nested/10-core.gitconfig'
}

test_dry_run_changes_nothing() {
    dry_home="$TEST_ROOT/dry-home"
    mkdir -p "$dry_home"
    printf '%s\n' 'native=true' > "$dry_home/.bashrc"
    before="$(cksum "$dry_home/.bashrc")"
    HOME="$dry_home" "$TEST_ROOT/repo/install.sh" --dry-run > "$TEST_ROOT/dry-run.out"
    after="$(cksum "$dry_home/.bashrc")"
    [ "$before" = "$after" ] || fail "dry-run modified .bashrc"
    [ ! -e "$dry_home/.config/dotfiles" ] || fail "dry-run created anchor"
    assert_contains "$TEST_ROOT/dry-run.out" 'would update:'
}

test_uninstall_preserves_native_content() {
    home="$TEST_ROOT/home"
    HOME="$home" "$TEST_ROOT/repo/install.sh" --uninstall
    assert_contains "$home/.bashrc" 'export MACHINE_ONLY=1'
    assert_not_contains "$home/.bashrc" '# >>> dotfiles managed loader >>>'
    [ ! -e "$home/.config/dotfiles" ] || fail "uninstall retained anchor"
}

test_refuses_unrelated_anchor() {
    blocked_home="$TEST_ROOT/blocked-home"
    mkdir -p "$blocked_home/.config/dotfiles"
    if HOME="$blocked_home" "$TEST_ROOT/repo/install.sh" > "$TEST_ROOT/blocked.out" 2>&1; then
        fail "installer replaced unrelated anchor directory"
    fi
    assert_contains "$TEST_ROOT/blocked.out" 'Refusing to replace non-symlink anchor'
}

test_refuses_unrelated_symlink() {
    linked_home="$TEST_ROOT/linked-home"
    mkdir -p "$linked_home"
    printf '%s\n' 'unrelated=true' > "$TEST_ROOT/unrelated-bashrc"
    ln -s "$TEST_ROOT/unrelated-bashrc" "$linked_home/.bashrc"
    if HOME="$linked_home" "$TEST_ROOT/repo/install.sh" > "$TEST_ROOT/linked.out" 2>&1; then
        fail "installer replaced unrelated .bashrc symlink"
    fi
    assert_contains "$TEST_ROOT/linked.out" 'Refusing to replace unrelated symlink'
}

test_refuses_unsafe_fragment_name() {
    unsafe_home="$TEST_ROOT/unsafe-home"
    mkdir -p "$unsafe_home"
    printf '%s\n' 'export UNSAFE=1' > "$TEST_ROOT/repo/config/shells/bash/rc.d/50-unsafe name.bash"
    if HOME="$unsafe_home" "$TEST_ROOT/repo/install.sh" > "$TEST_ROOT/unsafe.out" 2>&1; then
        fail "installer accepted an unsafe fragment path"
    fi
    assert_contains "$TEST_ROOT/unsafe.out" 'Unsupported fragment path:'
    rm "$TEST_ROOT/repo/config/shells/bash/rc.d/50-unsafe name.bash"
}

test_migrates_legacy_repo_symlink() {
    legacy_home="$TEST_ROOT/legacy-home"
    mkdir -p "$legacy_home"
    ln -s "$TEST_ROOT/repo/bash/.bashrc" "$legacy_home/.bashrc"
    HOME="$legacy_home" "$TEST_ROOT/repo/install.sh"
    assert_file "$legacy_home/.bashrc"
    [ ! -L "$legacy_home/.bashrc" ] || fail "legacy .bashrc remained a symlink"
    assert_contains "$legacy_home/.bashrc" '# >>> dotfiles managed loader >>>'
}

test_install_preserves_native_files
test_install_is_idempotent
test_all_adapters
test_dry_run_changes_nothing
test_refuses_unsafe_fragment_name
test_uninstall_preserves_native_content
test_refuses_unrelated_anchor
test_refuses_unrelated_symlink
test_migrates_legacy_repo_symlink
echo "PASS: install tests"
