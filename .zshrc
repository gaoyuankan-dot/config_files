# ── History ────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE      # commands starting with space not saved
setopt SHARE_HISTORY          # share history across terminals
setopt HIST_VERIFY            # show expanded history before running

# ── Completion ─────────────────────────────────────────────────────────
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}%B--- %d ---%b%f'

# ── Options ────────────────────────────────────────────────────────────
setopt AUTO_CD                # type directory name to cd into it
setopt CORRECT                # suggest corrections for typos
setopt GLOB_DOTS              # include dotfiles in glob patterns

# ── Aliases — Modern CLI replacements ──────────────────────────────────
# Install: sudo pacman -S eza bat fd ripgrep
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --icons --level=2'
alias cat='bat --style=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'

# ── Aliases — Safety ───────────────────────────────────────────────────
alias rm='rm -i'              # confirm before delete
alias cp='cp -i'
alias mv='mv -i'

# ── Aliases — Navigation ───────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# ── Aliases — Pacman shortcuts ─────────────────────────────────────────
alias pS='sudo pacman -S'
alias pSyu='sudo pacman -Syu'
alias pSs='pacman -Ss'
alias pQi='pacman -Qi'
alias pRns='sudo pacman -Rns'
alias yS='yay -S'
alias ySyu='yay -Syu'

# ── Aliases — System ───────────────────────────────────────────────────
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias top='htop'
alias ports='ss -tulpn'
alias journal='journalctl -xe'

# ── Aliases — Git ──────────────────────────────────────────────────────
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# ── Proxy (xray on port 10808) ─────────────────────────────────────────
alias proxy-on='export http_proxy=socks5://127.0.0.1:10808 https_proxy=socks5://127.0.0.1:10808 all_proxy=socks5://127.0.0.1:10808 && echo "Proxy ON"'
alias proxy-off='unset http_proxy https_proxy all_proxy && echo "Proxy OFF"'
alias proxy-test='curl --socks5 127.0.0.1:10808 https://ipinfo.io'
proxy-on

# ── Zoxide (smart cd) ──────────────────────────────────────────────────
# Install: sudo pacman -S zoxide
eval "$(zoxide init zsh)"    # type 'z proj' to jump to ~/Projects/myproject

# ── FZF (fuzzy finder) ─────────────────────────────────────────────────
# Install: sudo pacman -S fzf
source /usr/share/fzf/key-bindings.zsh 2>/dev/null
source /usr/share/fzf/completion.zsh 2>/dev/null
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
# Ctrl+R → fuzzy search history
# Ctrl+T → fuzzy search files
# Alt+C  → fuzzy cd into subdirectory

# ── Plugins ────────────────────────────────────────────────────────────
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh 2>/dev/null

# Plugin keybindings:
bindkey '^[[C' autosuggest-accept       # right arrow accepts suggestion
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ── Starship prompt ────────────────────────────────────────────────────
eval "$(starship init zsh)"
