# ~/.config/shell/common.sh: interactive helpers shared by bash AND zsh.
#
# Sourced by ~/.bashrc and ~/.zshrc, so it must parse in both shells: POSIX-ish
# syntax, `name() { ...; }` functions, no arrays, no [[ ]]. Only aliases and
# functions live here; inherited environment belongs in ~/.profile.
#
# The "is a human typing?" test used below is `[ -t 0 ]`: stdin is a terminal.
# Scripts, pipes, cron jobs and AI agents (Claude Code, Copilot CLI) run
# commands with stdin NOT a terminal, and they inherit these definitions too.

# Drop aliases a distro or an older config may have defined under the same
# names: in zsh, `ls() {...}` would otherwise be alias-expanded while defining.
for _n in ls ll lt cat rm cp mv; do unalias "$_n" 2>/dev/null; done
unset _n

# ── ls / ll / lt: eza for humans, real ls for everyone else ─────────────
# eza is NOT a drop-in ls. With no path argument and a non-terminal stdin it
# reads file names FROM stdin: `ls -la` printed nothing at all (exit 0) inside
# scripts and agents, which then believe the directory is empty. Its flags
# also differ (`ls -ltr` is an error in eza). So: eza only at a terminal.
if command -v eza >/dev/null 2>&1; then
    ls() {
        if [ -t 0 ] && [ -t 1 ]; then eza --icons=auto --group-directories-first "$@"
        else command ls "$@"; fi
    }
    ll() {
        if [ -t 0 ]; then eza -la --icons=auto --group-directories-first --git "$@"
        else command ls -alF "$@"; fi
    }
    lt() {
        if [ -t 0 ]; then eza --tree --icons=auto --level=2 "$@"
        else command ls -R "$@"; fi
    }
else
    alias ls='ls --color=auto'
    alias ll='ls -alF'
fi

# ── cat: bat when a human reads the output, plain cat for pipes ─────────
# Ubuntu ships bat as `batcat` (a name clash with an older package);
# install.sh adds a ~/.local/bin/bat shim, this covers machines without it.
# The real name goes in a VARIABLE, read when cat() runs. Using an alias
# inside the function would fail: a shell expands aliases while PARSING, and
# an alias defined in the same block as the function is not active yet
# (shellcheck SC2262).
_dotfiles_bat=
if command -v bat >/dev/null 2>&1; then
    _dotfiles_bat=bat
elif command -v batcat >/dev/null 2>&1; then
    _dotfiles_bat=batcat
    alias bat='batcat'
fi
if [ -n "$_dotfiles_bat" ]; then
    cat() {
        if [ -t 1 ]; then "$_dotfiles_bat" --style=auto "$@"
        else command cat "$@"; fi
    }
fi
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    alias fd='fdfind'
fi

# ── rm / cp / mv: confirm for humans only ───────────────────────────────
# rm -I asks ONCE when deleting more than three files or recursing, instead of
# per file like -i. Without a terminal there is nobody to answer: rm -i would
# read EOF as "no" and silently delete nothing, so non-humans get plain rm.
rm() { if [ -t 0 ]; then command rm -I "$@"; else command rm "$@"; fi; }
cp() { if [ -t 0 ]; then command cp -i "$@"; else command cp "$@"; fi; }
mv() { if [ -t 0 ]; then command mv -i "$@"; else command mv "$@"; fi; }

# ── Colors and small conveniences ───────────────────────────────────────
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ports='ss -tulpn'
alias journal='journalctl -xe'
command -v htop >/dev/null 2>&1 && alias top='htop'

# ── Git ─────────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# ── Package manager: same names on both distros = same muscle memory ────
# File tests, not `command -v`: on WSL every lookup of a MISSING command
# (pacman on Ubuntu) walks the slow /mnt/c part of PATH.
if [ -x /usr/bin/pacman ]; then
    alias pS='sudo pacman -S'
    alias pSyu='sudo pacman -Syu'
    alias pSs='pacman -Ss'
    alias pQi='pacman -Qi'
    alias pRns='sudo pacman -Rns'
    if command -v yay >/dev/null 2>&1; then
        alias yS='yay -S'
        alias ySyu='yay -Syu'
    fi
elif [ -x /usr/bin/apt ]; then
    alias pS='sudo apt install'
    alias pSyu='sudo apt update && sudo apt full-upgrade'
    alias pSs='apt search'
    alias pQi='apt show'
    alias pRns='sudo apt purge --autoremove'   # remove + unneeded deps + config files
fi

# ── WSL ─────────────────────────────────────────────────────────────────
if [ -n "${WSL_DISTRO_NAME-}" ]; then
    alias open='explorer.exe'   # `open .` shows the current directory in Explorer
fi

# ── Proxy (Xray mixed inbound: SOCKS5 + HTTP on ONE port) ───────────────
# http(s)_proxy use http:// because many tools (apt, pip, git over https) do
# not speak SOCKS there. all_proxy uses socks5h://: the "h" makes the proxy
# resolve DNS, so lookups neither leak nor fail locally.
PROXY_ADDR=${PROXY_ADDR:-127.0.0.1:10808}
proxy-on() {
    export http_proxy="http://$PROXY_ADDR" https_proxy="http://$PROXY_ADDR"
    export all_proxy="socks5h://$PROXY_ADDR"
    export no_proxy='localhost,127.0.0.1,::1'
    # Some programs read only the UPPERCASE names, others only lowercase.
    export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy" ALL_PROXY="$all_proxy" NO_PROXY="$no_proxy"
    [ "${1-}" = -q ] || echo "Proxy ON ($PROXY_ADDR)"
}
proxy-off() {
    unset http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
    echo "Proxy OFF"
}
proxy-test() { curl -s --max-time 8 -x "socks5h://$PROXY_ADDR" https://ipinfo.io; echo; }

# _proxy_listening: does anything accept TCP connections on $PROXY_ADDR?
# A refused connection to localhost fails instantly, so this costs ~1 ms.
_proxy_listening() {
    if [ -n "${ZSH_VERSION-}" ]; then
        zmodload zsh/net/tcp 2>/dev/null || return 1
        ztcp "${PROXY_ADDR%:*}" "${PROXY_ADDR##*:}" 2>/dev/null || return 1
        ztcp -c "$REPLY"
    else
        (exec 3<>"/dev/tcp/${PROXY_ADDR%:*}/${PROXY_ADDR##*:}") 2>/dev/null
    fi
}

# WSL: /etc/profile.d/proxy.sh (from install-wsl-proxy.sh) is the single source
# of truth, shared with bash/sudo/apt. Elsewhere, enable the proxy only when
# Xray is actually listening: exporting a dead proxy breaks every download.
if [ -r /etc/profile.d/proxy.sh ]; then
    # shellcheck source=/dev/null  # a per-machine file: absent in CI and the sandbox
    . /etc/profile.d/proxy.sh
elif _proxy_listening; then
    proxy-on -q
fi
