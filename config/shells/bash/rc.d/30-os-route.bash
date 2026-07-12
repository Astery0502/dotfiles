case $- in
    *i*) ;;
    *) return ;;
esac

case "${OSTYPE:-}" in
    darwin*)
        source "$HOME/.config/dotfiles/config/shells/bash/os/darwin.bash"
        ;;
    linux*)
        source "$HOME/.config/dotfiles/config/shells/bash/os/linux.bash"
        ;;
esac
