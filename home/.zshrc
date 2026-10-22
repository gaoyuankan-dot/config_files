# ~/.zshrc: INTERACTIVE zsh, shared by Arch (Konsole) and Ubuntu on WSL2
# (Windows Terminal). Environment (PATH, EDITOR, ...) lives in ~/.profile.
# Secrets and machine-only settings go in ~/.zshrc.local, which is NEVER committed.
#
# Startup cost is measured, not guessed: `zsh -i -c exit` with timing, or
# profile with  zsh -i -c 'zmodload zsh/zprof; source ~/.zshrc; zprof'.

# ── PATH ───────────────────────────────────────────────────────────────
typeset -U path PATH fpath FPATH  # -U: unique entries, so re-sourcing never piles up duplicates
path=("$HOME/.local/bin" $path)   # also for non-login shells that never read ~/.profile

# ── Helpers ────────────────────────────────────────────────────────────
has() { (( $+commands[$1] )) }    # is $1 on PATH? hash-table lookup, no subprocess

# Source the first readable file among the arguments. Arch and Ubuntu install
# the same plugin at different paths, so list every candidate instead of
# hard-coding one. A missing plugin warns instead of failing silently.
source_first() {
  local f
  for f in "$@"; do
    [[ -r $f ]] && { source "$f"; return 0 }
  done
  print -u2 "zshrc: not found: ${1:t} (install it or fix the path)"
  return 1
}

# _cached_init CMD ARGS...: source the shell code that CMD prints (like
# `eval "$(starship init zsh)"`), but run CMD only when its binary is newer
# than the cache. Each such tool costs ~2 ms per shell when run every time.
# - The cache key is the binary's full PATH plus the arguments: the generated
#   code embeds that path (/usr/bin/starship), so a moved binary or changed
#   flags must get a fresh cache, never a stale one.
# - The temp file + mv makes the update atomic: a crash mid-write can never
#   leave a half-written file that every later shell would source.
_cached_init() {
  local bin=${commands[$1]}
  [[ -n $bin ]] || return 1
  local key="$bin ${(j: :)@[2,-1]}"          # (j: :) joins the args into ONE string
  key=${key//[^A-Za-z0-9._-]/_}              # make it a safe file name
  local cache=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init/$key.zsh
  if [[ ! -s $cache || $bin -nt $cache ]]; then
    mkdir -p -- "${cache:h}" || return 1
    if ! "$@" >| "$cache.$$" 2>/dev/null || [[ ! -s $cache.$$ ]]; then
      rm -f -- "$cache.$$"
      return 1
    fi
    mv -f -- "$cache.$$" "$cache"
  fi
  source "$cache"
}

# ── History ────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS       # skip a command identical to the previous one
setopt HIST_IGNORE_SPACE      # commands starting with a space are not saved
setopt HIST_EXPIRE_DUPS_FIRST # when trimming, drop duplicates before unique lines
setopt HIST_FIND_NO_DUPS      # Ctrl-R/Up never show the same line twice
setopt SHARE_HISTORY          # share history across terminals (implies incremental append)
setopt HIST_VERIFY            # show expanded history (!!, !$) before running it
setopt EXTENDED_HISTORY       # save timestamps (`history -i` shows them)
setopt HIST_REDUCE_BLANKS     # "ls   -la" and "ls -la" count as the same command

# ── Completion ─────────────────────────────────────────────────────────
# LS_COLORS is empty until dircolors runs; the list-colors zstyle needs it.
_cached_init dircolors -b
autoload -Uz compinit
# compinit's security audit (compaudit) checks every completion directory for
# unsafe permissions: thorough but slow. Run it once a day (full compinit when
# the dump is missing or older than 24 h), and trust the dump (-C) otherwise.
() {
  local dump=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION
  local -a stale=( $dump(N.mh+24) )   # (N.mh+24): the file, if modified >24 h ago
  mkdir -p -- "${dump:h}"
  if [[ ! -s $dump ]] || (( $#stale )); then
    compinit -d "$dump"
  else
    compinit -C -d "$dump"
  fi
}
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}%B--- %d ---%b%f'
zstyle ':completion:*' use-cache on    # cache slow completions (apt, pacman package lists)
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache"

# ── Options ────────────────────────────────────────────────────────────
setopt AUTO_CD                # type a directory name to cd into it
setopt CORRECT                # offer to fix mistyped command names
setopt GLOB_DOTS              # globs include dotfiles (careful: `rm *` hits .files too)
setopt INTERACTIVE_COMMENTS   # `cmd  # note` works when pasting commands from docs
setopt NO_BEEP

# ── Keys ───────────────────────────────────────────────────────────────
# zsh binds almost nothing beyond the basics: without these, Home/End/Delete
# print "~" or letters. Both escape forms are bound because terminals send
# `^[[H` or `^[OH` depending on their mode (Ubuntu's /etc/zsh/zshrc switches
# the terminal to "application keypad" mode).
bindkey -e                    # emacs keymap (EDITOR=vim would otherwise flip zsh into vi mode)
bindkey '^[[H'    beginning-of-line
bindkey '^[OH'    beginning-of-line
bindkey '^[[F'    end-of-line
bindkey '^[OF'    end-of-line
bindkey '^[[3~'   delete-char
bindkey '^[[1;5C' forward-word      # Ctrl+Right
bindkey '^[[1;5D' backward-word     # Ctrl+Left
bindkey '^H'      backward-kill-word # Ctrl+Backspace (Windows Terminal sends ^H)

# ── Shared aliases and functions (also used by bash) ───────────────────
# ls/cat/rm/cp/mv wrappers, git and package-manager aliases, proxy-on/off.
[[ -r ~/.config/shell/common.sh ]] && source ~/.config/shell/common.sh

# ── Tools ──────────────────────────────────────────────────────────────
_cached_init zoxide init zsh     # `z proj` jumps to the best-matching visited dir
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# Ubuntu: "command not found, install it with: sudo apt install ..."
[[ -r /etc/zsh_command_not_found ]] && source /etc/zsh_command_not_found

# ── Local / secret settings (API keys etc.): not in git ────────────────
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local

# ── Line-editor features: only when a human has a terminal ─────────────
# Shells driven by scripts or AI agents are interactive (-i) but have no
# terminal, so key bindings, suggestions and highlighting are dead weight
# there, and fzf's init even prints "can't change option: zle".
# Careful: `[[ -o zle ]]` alone is NOT enough. zsh -i reports zle ON even with
# stdin = /dev/null (verified); the option records the request, not whether a
# line editor can run. `-t 0` (stdin is a terminal) is the real test.
if [[ -o zle && -t 0 ]]; then
  # `fzf --zsh` (fzf >= 0.48) prints its own bindings, no distro-specific
  # paths: Ctrl+R history, Ctrl+T files, Alt+C cd into a subdirectory.
  _cached_init fzf --zsh

  # Plugins, ORDER MATTERS: autosuggestions -> syntax-highlighting ->
  # history-substring-search. syntax-highlighting wraps every widget defined
  # before it; history-substring-search's README requires loading after it.
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)   # suggest from history, then from completion
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=40              # no suggestions while pasting long lines
  ZSH_HIGHLIGHT_MAXLENGTH=512                     # same idea for highlighting
  source_first \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  source_first \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  # Not packaged on Ubuntu: scripts/bootstrap.sh clones it to ~/.local/share.
  source_first \
    /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh \
    ~/.local/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

  # Up/Down search history by what you've typed. Both escape forms again
  # (normal `^[[A` vs application-mode `^[OA`).
  if (( $+widgets[history-substring-search-up] )); then
    bindkey '^[[A' history-substring-search-up
    bindkey '^[OA' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    bindkey '^[OB' history-substring-search-down
  fi
  # Right arrow already accepts an autosuggestion by default (forward-char is
  # in ZSH_AUTOSUGGEST_ACCEPT_WIDGETS), so no extra binding is needed.
fi

# ── Prompt ─────────────────────────────────────────────────────────────
_cached_init starship init zsh
