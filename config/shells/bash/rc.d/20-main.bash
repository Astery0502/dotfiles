# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
# case $- in
#     *i*) ;;
#       *) return;;
# esac

# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# set a fancy prompt (non-color, unless we know we "want" color)
case "${TERM:-}" in
    xterm-color|*-256color) color_prompt=yes;;
esac

#force_color_prompt=yes

if [ -n "${force_color_prompt:-}" ]; then
    if command -v tput >/dev/null 2>&1 && tput setaf 1 >&/dev/null; then
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "${color_prompt:-}" = yes ]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "${TERM:-}" in
xterm*|rxvt*)
    PS1="\[\e]0;\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

export EDITOR=vim

# pipx
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$PATH:$HOME/.local/bin" ;;
esac
