# ~/.bashrc: INTERACTIVE bash. Read by interactive non-login bash, and by
# login bash through ~/.bash_profile.
#
# bash also reads this file for `ssh host command`, which is not interactive:
# leave at once unless a human is typing. Nothing above this guard may print,
# or scp/rsync/sftp break.
case $- in
    *i*) ;;
    *) return ;;
esac

# Non-login shells (a VS Code terminal, `bash` typed in zsh) never read
# ~/.profile, so make sure user tools (`claude`, pipx apps) are found anyway.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac

# ── History ─────────────────────────────────────────────────────────────
HISTCONTROL=ignoreboth:erasedups   # skip lines starting with a space, and duplicates
HISTSIZE=50000                     # lines kept in memory
HISTFILESIZE=100000                # lines kept in ~/.bash_history
HISTTIMEFORMAT='%F %T  '           # `history` shows when each command ran
shopt -s histappend cmdhist        # append, never overwrite; multi-line command = one entry
# Write each command to the file as soon as it runs, so a crashed or killed
# terminal loses nothing. (starship's init keeps this and still sees $?.)
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# ── Shell options ───────────────────────────────────────────────────────
shopt -s checkwinsize              # re-read LINES/COLUMNS after each command
# bash 4+ options; `2>/dev/null` keeps bash 3.2 (macOS) quiet instead of failing.
shopt -s globstar autocd cdspell dirspell 2>/dev/null   # ** recursion; `dir` = cd dir; fix cd typos

# ── Completion ──────────────────────────────────────────────────────────
# Some distros load bash-completion from /etc already; the version variable
# tells us, so it is never loaded twice.
if ! shopt -oq posix && [ -z "${BASH_COMPLETION_VERSINFO-}" ]; then
    for _f in /usr/share/bash-completion/bash_completion /etc/bash_completion; do
        # shellcheck source=/dev/null  # a system file, not ours to lint
        if [ -r "$_f" ]; then . "$_f"; break; fi
    done
    unset _f
fi

# ── Colors ──────────────────────────────────────────────────────────────
if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b)"         # LS_COLORS for ls and completion
fi
# Ubuntu: `less file.gz` or `less archive.tar` shows the contents.
if [ -x /usr/bin/lesspipe ]; then
    eval "$(SHELL=/bin/sh lesspipe)"
fi

# ── Shared aliases and functions (also used by zsh) ─────────────────────
if [ -r "$HOME/.config/shell/common.sh" ]; then
    # shellcheck source=/dev/null  # linted on its own by scripts/test.sh
    . "$HOME/.config/shell/common.sh"
fi

# ── Tools ───────────────────────────────────────────────────────────────
# `fzf --bash` (fzf >= 0.48) prints its own key bindings: Ctrl-R history,
# Ctrl-T files, Alt-C cd. An older fzf rejects the flag; then skip quietly.
if command -v fzf >/dev/null 2>&1 && _out=$(fzf --bash 2>/dev/null); then
    eval "$_out"
fi
unset _out
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"     # `z proj` jumps to the best-matching visited dir
fi

# ── Local / secret settings: never committed ────────────────────────────
if [ -r "$HOME/.bashrc.local" ]; then
    # shellcheck source=/dev/null  # a per-machine file
    . "$HOME/.bashrc.local"
fi

# ── Prompt: starship if installed, a plain colored one otherwise ────────
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
else
    PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
fi
