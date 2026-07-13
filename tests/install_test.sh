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
    local path="$1"
    [ -f "$path" ] || fail "expected regular file: $path"
}

assert_symlink_to() {
    local path="$1"
    local target="$2"
    [ -L "$path" ] || fail "expected symlink: $path"
    [ "$(readlink "$path")" = "$target" ] || fail "unexpected target for $path"
}

assert_contains() {
    local path="$1"
    local text="$2"
    grep -Fq "$text" "$path" || fail "expected '$text' in $path"
}

assert_not_contains() {
    local path="$1"
    local text="$2"
    if grep -Fq "$text" "$path"; then
        fail "did not expect '$text' in $path"
    fi
}

assert_count() {
    local path="$1"
    local text="$2"
    local expected="$3"
    local actual
    actual="$(grep -Fc "$text" "$path" || true)"
    [ "$actual" = "$expected" ] || fail "expected $expected occurrences of '$text' in $path, got $actual"
}

make_repo() {
    local fixture="$TEST_ROOT/repo"
    mkdir -p "$fixture"
    cp "$REPO_ROOT/install.sh" "$fixture/install.sh"
    chmod +x "$fixture/install.sh"
    mkdir -p \
        "$fixture/config/shells/bash/rc.d/nested" \
        "$fixture/config/shells/bash/profile.d" \
        "$fixture/config/editors/vim/nested" \
        "$fixture/config/terminals/tmux/nested" \
        "$fixture/config/development/git/nested" \
        "$fixture/config/applications/ghostty"
    printf '%s\n' 'export FIRST=1' > "$fixture/config/shells/bash/rc.d/10-first.bash"
    printf '%s\n' 'export LAST=1' > "$fixture/config/shells/bash/rc.d/nested/20-last.bash"
    printf '%s\n' 'source ~/.bashrc' > "$fixture/config/shells/bash/profile.d/10-login.bash"
    printf '%s\n' 'set number' > "$fixture/config/editors/vim/nested/10-options.vim"
    printf '%s\n' 'set -g mouse on' > "$fixture/config/terminals/tmux/nested/10-options.conf"
    printf '%s\n' '[init]' '    defaultBranch = main' > "$fixture/config/development/git/nested/10-core.gitconfig"
    printf '%s\n' 'font-size = 18' > "$fixture/config/applications/ghostty/10-main.ghostty"
    printf '%s\n' 'do not load me' > "$fixture/config/shells/bash/rc.d/README.md"
}

test_install_lifecycle() {
    local home="$TEST_ROOT/home"
    local bin="$TEST_ROOT/darwin-bin"
    local first_line last_line inode
    mkdir -p "$home" "$bin"
    printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" Darwin' > "$bin/uname"
    chmod +x "$bin/uname"
    printf '%s\n' 'export MACHINE_ONLY=1' > "$home/.bashrc"

    HOME="$home" PATH="$bin:$PATH" "$TEST_ROOT/repo/install.sh" > "$TEST_ROOT/first-install.out"
    assert_contains "$TEST_ROOT/first-install.out" 'Install report:'
    assert_contains "$TEST_ROOT/first-install.out" 'npx skills@latest add mattpocock/skills'
    assert_contains "$TEST_ROOT/first-install.out" 'Select the promoted engineering and productivity skills only'
    assert_contains "$TEST_ROOT/first-install.out" 'exclude deprecated, in-progress, miscellaneous, and personal skills'
    assert_contains "$TEST_ROOT/first-install.out" 'Restart Codex, then configure each project interactively by running:'
    assert_contains "$TEST_ROOT/first-install.out" '/setup-matt-pocock-skills'
    assert_contains "$TEST_ROOT/first-install.out" 'under docs/agents/'
    assert_contains "$TEST_ROOT/first-install.out" 'npx skills@latest add Astery0502/asterism'

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

    inode="$(ls -di "$home/.bashrc" | awk '{ print $1 }')"
    HOME="$home" PATH="$bin:$PATH" "$TEST_ROOT/repo/install.sh" > "$TEST_ROOT/second-install.out"
    assert_contains "$TEST_ROOT/second-install.out" 'No managed changes.'
    assert_count "$home/.bashrc" '# >>> dotfiles managed loader >>>' 1
    assert_count "$home/.bashrc" '# <<< dotfiles managed loader <<<' 1
    [ "$(ls -di "$home/.bashrc" | awk '{ print $1 }')" = "$inode" ] || fail "idempotent install rewrote .bashrc"

    assert_contains "$home/.bash_profile" 'profile.d/10-login.bash'
    assert_contains "$home/.vimrc" 'nested/10-options.vim'
    assert_contains "$home/.tmux.conf" 'nested/10-options.conf'
    assert_contains "$home/.gitconfig" '[include]'
    assert_contains "$home/.gitconfig" 'nested/10-core.gitconfig'
    assert_contains "$home/.config/ghostty/config" 'config/applications/ghostty/10-main.ghostty'

    HOME="$home" PATH="$bin:$PATH" "$TEST_ROOT/repo/install.sh" --uninstall > "$TEST_ROOT/uninstall.out"
    assert_contains "$TEST_ROOT/uninstall.out" 'Uninstall report:'
    assert_not_contains "$TEST_ROOT/uninstall.out" 'npx skills@latest add'
    assert_contains "$home/.bashrc" 'export MACHINE_ONLY=1'
    assert_not_contains "$home/.bashrc" '# >>> dotfiles managed loader >>>'
    assert_not_contains "$home/.config/ghostty/config" '# >>> dotfiles managed loader >>>'
    [ ! -e "$home/.config/dotfiles" ] || fail "uninstall retained anchor"
}

test_skips_ghostty_off_macos() {
    local home="$TEST_ROOT/linux-home"
    local bin="$TEST_ROOT/linux-bin"
    mkdir -p "$home" "$bin"
    printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" Linux' > "$bin/uname"
    chmod +x "$bin/uname"

    HOME="$home" PATH="$bin:$PATH" "$TEST_ROOT/repo/install.sh"

    [ ! -e "$home/.config/ghostty/config" ] || fail "installer configured Ghostty off macOS"
}

test_dry_run_changes_nothing() {
    local dry_home="$TEST_ROOT/dry-home"
    local before after
    mkdir -p "$dry_home"
    printf '%s\n' 'native=true' > "$dry_home/.bashrc"
    before="$(cksum "$dry_home/.bashrc")"
    HOME="$dry_home" "$TEST_ROOT/repo/install.sh" --dry-run > "$TEST_ROOT/dry-run.out"
    after="$(cksum "$dry_home/.bashrc")"
    [ "$before" = "$after" ] || fail "dry-run modified .bashrc"
    [ ! -e "$dry_home/.config/dotfiles" ] || fail "dry-run created anchor"
    assert_contains "$TEST_ROOT/dry-run.out" 'would update:'
    assert_contains "$TEST_ROOT/dry-run.out" 'Dry-run operations:'
    assert_contains "$TEST_ROOT/dry-run.out" 'npx skills@latest add mattpocock/skills'
    assert_contains "$TEST_ROOT/dry-run.out" 'Select the promoted engineering and productivity skills only'
    assert_contains "$TEST_ROOT/dry-run.out" '/setup-matt-pocock-skills'
    assert_contains "$TEST_ROOT/dry-run.out" 'npx skills@latest add Astery0502/asterism'
}

test_refuses_unrelated_anchor() {
    local blocked_home="$TEST_ROOT/blocked-home"
    mkdir -p "$blocked_home/.config/dotfiles"
    if HOME="$blocked_home" "$TEST_ROOT/repo/install.sh" > "$TEST_ROOT/blocked.out" 2>&1; then
        fail "installer replaced unrelated anchor directory"
    fi
    assert_contains "$TEST_ROOT/blocked.out" 'Refusing to replace non-symlink anchor'
}

test_refuses_unrelated_symlink() {
    local linked_home="$TEST_ROOT/linked-home"
    mkdir -p "$linked_home"
    printf '%s\n' 'unrelated=true' > "$TEST_ROOT/unrelated-bashrc"
    ln -s "$TEST_ROOT/unrelated-bashrc" "$linked_home/.bashrc"
    if HOME="$linked_home" "$TEST_ROOT/repo/install.sh" > "$TEST_ROOT/linked.out" 2>&1; then
        fail "installer replaced unrelated .bashrc symlink"
    fi
    assert_contains "$TEST_ROOT/linked.out" 'Refusing to replace unrelated symlink'
}

test_refuses_unsafe_fragment_name() {
    local unsafe_home="$TEST_ROOT/unsafe-home"
    mkdir -p "$unsafe_home"
    printf '%s\n' 'export UNSAFE=1' > "$TEST_ROOT/repo/config/shells/bash/rc.d/50-unsafe name.bash"
    if HOME="$unsafe_home" "$TEST_ROOT/repo/install.sh" > "$TEST_ROOT/unsafe.out" 2>&1; then
        fail "installer accepted an unsafe fragment path"
    fi
    assert_contains "$TEST_ROOT/unsafe.out" 'Unsupported fragment path:'
    rm "$TEST_ROOT/repo/config/shells/bash/rc.d/50-unsafe name.bash"
}

test_refuses_reversed_markers() {
    local malformed_home="$TEST_ROOT/malformed-home"
    mkdir -p "$malformed_home"
    printf '%s\n' \
        '# <<< dotfiles managed loader <<<' \
        'native=true' \
        '# >>> dotfiles managed loader >>>' > "$malformed_home/.bashrc"
    if HOME="$malformed_home" "$TEST_ROOT/repo/install.sh" > "$TEST_ROOT/malformed.out" 2>&1; then
        fail "installer accepted reversed managed markers"
    fi
    assert_contains "$TEST_ROOT/malformed.out" 'Malformed managed block'
    assert_contains "$malformed_home/.bashrc" 'native=true'
}

test_migrates_legacy_repo_symlink() {
    local legacy_home="$TEST_ROOT/legacy-home"
    mkdir -p "$legacy_home"
    ln -s "$TEST_ROOT/repo/bash/.bashrc" "$legacy_home/.bashrc"
    HOME="$legacy_home" "$TEST_ROOT/repo/install.sh"
    assert_file "$legacy_home/.bashrc"
    [ ! -L "$legacy_home/.bashrc" ] || fail "legacy .bashrc remained a symlink"
    assert_contains "$legacy_home/.bashrc" '# >>> dotfiles managed loader >>>'
}

test_bash_os_route() {
    local route_home="$TEST_ROOT/route-home"
    local route_bin="$TEST_ROOT/route-bin"
    mkdir -p "$route_home/.config" "$route_bin"
    ln -s "$REPO_ROOT" "$route_home/.config/dotfiles"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$route_bin/notify-send"
    chmod +x "$route_bin/notify-send"

    HOME="$route_home" PATH="$route_bin:/usr/bin:/bin" bash --noprofile --norc -ic '
        unset BASH_SILENCE_DEPRECATION_WARNING
        export HOMEBREW_PREFIX=/test
        OSTYPE=darwin
        source "$HOME/.config/dotfiles/config/shells/bash/rc.d/30-os-route.bash"
        [ "$BASH_SILENCE_DEPRECATION_WARNING" = 1 ]
        ! alias alert >/dev/null 2>&1
    ' 2>/dev/null
    HOME="$route_home" PATH="$route_bin:/usr/bin:/bin" bash --noprofile --norc -ic '
        unset BASH_SILENCE_DEPRECATION_WARNING
        OSTYPE=linux-gnu
        source "$HOME/.config/dotfiles/config/shells/bash/rc.d/30-os-route.bash"
        alias alert >/dev/null 2>&1
        [ -z "${BASH_SILENCE_DEPRECATION_WARNING:-}" ]
    ' 2>/dev/null

    HOME="$route_home" OSTYPE=darwin bash -c '
        unset BASH_SILENCE_DEPRECATION_WARNING
        source "$HOME/.config/dotfiles/config/shells/bash/rc.d/30-os-route.bash"
        [ -z "${BASH_SILENCE_DEPRECATION_WARNING:-}" ]
    '
}

make_repo
test_install_lifecycle
test_dry_run_changes_nothing
test_refuses_unsafe_fragment_name
test_refuses_reversed_markers
test_refuses_unrelated_anchor
test_refuses_unrelated_symlink
test_migrates_legacy_repo_symlink
test_bash_os_route
test_skips_ghostty_off_macos
echo "PASS: install tests"
