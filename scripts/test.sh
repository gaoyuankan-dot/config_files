#!/usr/bin/env bash
# scripts/test.sh: prove the dotfiles work, inside a throwaway HOME.
#
# Usage:  scripts/test.sh [--full] [--keep]
#   (default)  syntax and lint, install.sh behavior, bash/zsh/sh startup,
#              vim startup without plugins, and every config file checked by
#              the program that reads it. No network access.
#   --full     also let vim install its plugins (network), then run the LSP
#              test: open a C file, type two typos, and require clangd's
#              errors to appear in vim within 10 seconds.
#   --keep     keep the throwaway HOME afterwards (its path is printed).
#
# Exit status 0 = no FAIL. A check whose tool is missing is SKIPPED, not
# failed; CI installs every tool, so CI skips nothing.
# Linux only (GNU find/stat/date); install.sh itself stays POSIX.
# Each validator also gets a NEGATIVE CONTROL: a deliberately broken input
# that must be rejected. A check that cannot fail proves nothing (e.g.
# `tmux source-file -n` accepts unknown options: it only parses).

set -uo pipefail    # no -e: run every check, then report them all

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
FULL=0 KEEP=0
for arg in "$@"; do
    case $arg in
        --full) FULL=1 ;;
        --keep) KEEP=1 ;;
        -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
        *) echo "test.sh: unknown option $arg" >&2; exit 2 ;;
    esac
done

TMP=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
# tmux servers use socket FILES (-S) in a private dir, not named sockets in
# /tmp/tmux-$UID (-L): a killed server can leave its socket file behind, and
# here the cleanup deletes them. The dir is in /tmp, NOT under $TMP: a Unix
# socket path may be at most 108 bytes, and a long TMPDIR made tmux fail with
# "File name too long" (found 2026-10-20 with a deep scratch TMPDIR).
SOCKS=$(mktemp -d /tmp/dft.XXXXXX)
TMUX_SOCKS=()
cleanup() {
    local s
    for s in "${TMUX_SOCKS[@]}"; do tmux -S "$s" kill-server 2>/dev/null; done
    rm -rf "$SOCKS"
    if [[ $KEEP == 1 ]]; then
        echo "kept test files in $TMP"
    else
        chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

if [[ -t 1 ]]; then G=$'\e[32m' R=$'\e[31m' Y=$'\e[33m' B=$'\e[1m' N=$'\e[0m'; else G='' R='' Y='' B='' N=''; fi
npass=0 nfail=0 nskip=0
pass() { printf '%sPASS%s %s\n' "$G" "$N" "$1"; npass=$((npass + 1)); }
fail() {
    printf '%sFAIL%s %s\n' "$R" "$N" "$1"; nfail=$((nfail + 1))
    [[ -n ${2-} ]] && printf '%s\n' "$2" | head -25 | sed 's/^/     | /'
    return 0
}
skip() { printf '%sSKIP%s %s\n' "$Y" "$N" "$1"; nskip=$((nskip + 1)); }
info() { printf '     %s\n' "$1"; }
section() { printf '\n%s== %s ==%s\n' "$B" "$1" "$N"; }
have() { command -v "$1" >/dev/null 2>&1; }
# check NAME CMD...: PASS if CMD exits 0, else FAIL showing its output.
check() {
    local name=$1 out; shift
    if out=$("$@" 2>&1); then pass "$name"; else fail "$name" "$out"; fi
}
# reject NAME CMD...: the negative control; PASS if CMD FAILS.
reject() {
    local name=$1; shift
    if "$@" >/dev/null 2>&1; then fail "$name (validator accepted a broken input!)"; else pass "$name"; fi
}

# A clean, predictable user environment: nothing inherited from the real
# HOME (aliases, rc files, caches). WSL variables are passed through so the
# WSL code paths run where they exist.
CLEAN_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
T=$TMP/home
mkdir -p "$T"
henv() {
    env -i HOME="$T" USER="${USER:-tester}" LOGNAME="${USER:-tester}" PATH="$CLEAN_PATH" \
        TERM=xterm-256color LANG=C.UTF-8 XDG_CONFIG_HOME="$T/.config" \
        ${WSLENV+WSLENV="$WSLENV"} ${WSL_DISTRO_NAME+WSL_DISTRO_NAME="$WSL_DISTRO_NAME"} \
        ${http_proxy+http_proxy="$http_proxy"} ${https_proxy+https_proxy="$https_proxy"} \
        ${HTTPS_PROXY+HTTPS_PROXY="$HTTPS_PROXY"} ${all_proxy+all_proxy="$all_proxy"} \
        ${no_proxy+no_proxy="$no_proxy"} "$@"
}

cd "$REPO" || exit 2
printf '%sdotfiles test%s  repo=%s  host=%s\n' "$B" "$N" "$REPO" \
    "$( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || uname -s)"

# ═══════════════════════════════════════════════════════════════════════
section "1. Syntax"
check "sh -n  install.sh, .profile" sh -c 'sh -n install.sh && sh -n home/.profile'
if have dash; then
    check "dash -n (strict POSIX) install.sh, .profile" sh -c 'dash -n install.sh && dash -n home/.profile'
fi
for f in home/.bashrc home/.bash_profile home/.config/shell/common.sh scripts/*.sh; do
    check "bash -n $f" bash -n "$f"
done
if have zsh; then
    for f in home/.zshenv home/.zprofile home/.zshrc home/.config/shell/common.sh; do
        check "zsh -n  $f" zsh -n "$f"
    done
else
    skip "zsh -n (zsh not installed)"
fi
if have python3; then
    check "python3 parses scripts/lsp-probe.py" python3 -I -c \
        'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' scripts/lsp-probe.py
fi

# ═══════════════════════════════════════════════════════════════════════
section "2. Lint"
if have shellcheck; then
    check "shellcheck -s sh   install.sh home/.profile" shellcheck -s sh install.sh home/.profile
    check "shellcheck -s bash .bashrc .bash_profile common.sh scripts/" \
        shellcheck -s bash -x home/.bashrc home/.bash_profile home/.config/shell/common.sh scripts/*.sh
else
    skip "shellcheck (not installed)"
fi

# ═══════════════════════════════════════════════════════════════════════
section "3. install.sh"
TI=$TMP/install-home
mkdir -p "$TI"
echo 'old zshrc' > "$TI/.zshrc"
ienv() { HOME="$TI" XDG_STATE_HOME="$TI/.local/state" DOTFILES_ALLOW_ROOT=1 "$@"; }
snapshot() { (cd "$TI" && find . -printf '%p %y %l\n' | LC_ALL=C sort); }
before=$(snapshot)
out=$(ienv ./install.sh --dry-run 2>&1)
if [[ $(snapshot) == "$before" && $out == *"dry-run"* ]]; then
    pass "--dry-run changes nothing"
else
    fail "--dry-run changed files" "$out"
fi
if out=$(ienv ./install.sh 2>&1); then pass "install exits 0"; else fail "install failed" "$out"; fi
bad=""
while IFS= read -r rel; do
    [[ $(readlink "$TI/$rel") == "$REPO/home/$rel" ]] || bad+="$rel "
done < <(cd home && find . \( -type f -o -type l \) ! -name '*.sw?' ! -name '*~' | sed 's|^\./||')
if [[ -z $bad ]]; then pass "every file under home/ is linked"; else fail "not linked: $bad"; fi
backup=$(find "$TI/.local/state/dotfiles/backup" -name .zshrc -type f 2>/dev/null | head -1)
if [[ -n $backup && $(cat "$backup") == 'old zshrc' ]]; then
    pass "existing ~/.zshrc was backed up, content intact"
else
    fail "existing ~/.zshrc was not backed up" "$out"
fi
out=$(ienv ./install.sh 2>&1)
if [[ $out == *"Done: 0 linked"* ]]; then pass "second run is idempotent (0 new links)"; else fail "second run changed things" "$out"; fi
ienv ./install.sh --uninstall >/dev/null 2>&1
left=$(find "$TI" -type l -lname "$REPO/*" | wc -l)
if [[ $left == 0 && -n $backup && -f $backup ]]; then
    pass "--uninstall removes only our links, keeps backups"
else
    fail "--uninstall left $left link(s) or lost the backup"
fi
if [[ $(id -u) == 0 ]]; then
    reject "refuses to run as root without DOTFILES_ALLOW_ROOT" env -u DOTFILES_ALLOW_ROOT HOME="$TI" ./install.sh --dry-run
else
    info "(the refuse-root check runs only when the tests run as root, e.g. in CI)"
fi
# Regression: run while Vim had ~/.vimrc open, install.sh linked the swap
# file too (--dry-run printed `link ~/.vimrc.swp`). A fake repo holds one
# real file plus the editor litter that must be skipped.
FR=$TMP/fake-repo FH=$TMP/fake-home
mkdir -p "$FR/home" "$FH"
cp install.sh "$FR/"
touch "$FR/home/.vimrc" "$FR/home/.vimrc.swp" "$FR/home/.vimrc~"
HOME="$FH" XDG_STATE_HOME="$FH/.local/state" DOTFILES_ALLOW_ROOT=1 "$FR/install.sh" >/dev/null 2>&1
if [[ -L $FH/.vimrc && ! -L $FH/.vimrc.swp && ! -L "$FH/.vimrc~" ]]; then
    pass "editor litter under home/ (*.swp, *~) is not linked"
else
    fail "editor litter under home/ was linked" "$(ls -la "$FH")"
fi

# The real test HOME for the rest of the run.
HOME="$T" XDG_STATE_HOME="$T/.local/state" DOTFILES_ALLOW_ROOT=1 ./install.sh >/dev/null 2>&1 \
    || fail "install into the test HOME"
touch "$T/.hushlogin" "$T/.motd_shown"     # silence Ubuntu's once-a-day motd banner

# ═══════════════════════════════════════════════════════════════════════
section "4. Shell startup (no terminal: how scripts and AI agents see it)"
# bash prints these two lines whenever -i runs without a terminal: harmless.
benign='no job control in this shell|cannot set terminal process group'
for mode in "zsh -i" "zsh -l -i" "bash -i" "bash -l -i" "sh -l"; do
    shell=${mode%% *}
    have "$shell" || { skip "$mode (not installed)"; continue; }
    # `-c :` lets the shell end on its own: an interactive bash running the
    # `exit` BUILTIN prints "exit" (or "logout") to stderr, like at a prompt.
    # shellcheck disable=SC2086  # $mode is deliberately split into words
    err=$(henv $mode -c ':' 2>&1 >/dev/null </dev/null | grep -v -E "$benign")
    if [[ -z $err ]]; then pass "$mode: starts with empty stderr"; else fail "$mode: printed to stderr" "$err"; fi
done
if have zsh; then
    best=99999
    for _ in 1 2 3 4 5 6; do
        s=$(date +%s%N); henv zsh -i -c 'exit 0' </dev/null >/dev/null 2>&1; e=$(date +%s%N)
        ms=$(( (e - s) / 1000000 )); (( ms < best )) && best=$ms
    done
    info "zsh -i startup: ${best} ms (best of 6; no terminal, so line-editor plugins are skipped)"
fi
# Regression test for the eza bug: `ls` with no path and no terminal printed NOTHING.
for shell in zsh bash; do
    have "$shell" || continue
    out=$(henv "$shell" -i -c 'ls -a /' 2>/dev/null </dev/null)
    if [[ $out == *etc* ]]; then pass "$shell: ls without a terminal lists files"; else fail "$shell: ls printed nothing without a terminal" "$out"; fi
done
victim=$T/delete-me
touch "$victim"
henv zsh -i -c "rm '$victim'" </dev/null >/dev/null 2>&1
if [[ ! -e $victim ]]; then pass "zsh: rm without a terminal does not prompt (agent-safe)"; else fail "zsh: rm prompted or failed without a terminal"; fi
# shellcheck disable=SC2016  # $PATH must expand in the CHILD shell, not here
out=$(henv bash -l -i -c 'printf %s "$PATH"' 2>/dev/null </dev/null)
if [[ :$out: == *":$T/.local/bin:"* ]]; then pass "bash login PATH contains HOME/.local/bin"; else fail "HOME/.local/bin missing from bash PATH" "$out"; fi

# Interactive, WITH a terminal (tmux gives us a real pty): what a human sees.
if have tmux && have zsh; then
    sock="$SOCKS/zsh"; TMUX_SOCKS+=("$sock")
    tmux -S "$sock" -f /dev/null new-session -d -x 150 -y 40 \
        "$(printf '%q ' env -i HOME="$T" USER="${USER:-tester}" PATH="$CLEAN_PATH" TERM=xterm-256color LANG=C.UTF-8 zsh -l)"
    sleep 2
    tmux -S "$sock" send-keys "print -r -- \"RESULT zle=\$options[zle] fzf=\${+widgets[fzf-history-widget]} ls=\$(whence -w ls)\"" Enter
    sleep 1
    screen=$(tmux -S "$sock" capture-pane -p)
    tmux -S "$sock" kill-server 2>/dev/null
    if [[ $screen == *"RESULT zle=on"* && $screen == *"ls: function"* ]]; then
        pass "zsh in a real terminal: line editor on, wrappers loaded"
    else
        fail "zsh in a real terminal" "$screen"
    fi
    missing=$(grep -o 'zshrc: not found: [^ ]*' <<<"$screen" | sort -u | tr '\n' ' ')
    [[ -n $missing ]] && info "optional plugins not installed here: $missing(scripts/bootstrap.sh)"
    errs=$(grep -E 'command not found|parse error|bad (option|pattern)|no such' <<<"$screen")
    if [[ -z $errs ]]; then pass "zsh in a real terminal: no errors on screen"; else fail "zsh terminal errors" "$errs"; fi
else
    skip "zsh in a real terminal (needs tmux)"
fi

# ═══════════════════════════════════════════════════════════════════════
section "5. Vim"
# vim_in_tmux OUT TIMEOUT VIMARGS...: run vim in a real pty; a test script
# inside vim writes OUT. Prints the screen if OUT never appears.
# VIM_ENV=(NAME=value ...) adds variables for the next calls (e.g. a fake DISPLAY).
VIM_ENV=()
vim_in_tmux() {
    local out=$1 timeout=$2; shift 2
    local sock="$SOCKS/vim-$RANDOM"; TMUX_SOCKS+=("$sock")
    rm -f "$out"
    tmux -S "$sock" -f /dev/null new-session -d -x 160 -y 45 \
        "$(printf '%q ' env -i HOME="$T" PATH="$CLEAN_PATH" TERM=xterm-256color COLORTERM=truecolor \
            LANG=C.UTF-8 XDG_CONFIG_HOME="$T/.config" OUT="$out" \
            ${http_proxy+http_proxy="$http_proxy"} ${https_proxy+https_proxy="$https_proxy"} \
            ${HTTPS_PROXY+HTTPS_PROXY="$HTTPS_PROXY"} ${all_proxy+all_proxy="$all_proxy"} \
            "${VIM_ENV[@]}" vim "$@"); sleep 2"
    local i
    for ((i = 0; i < timeout * 10; i++)); do
        [[ -s $out ]] && break
        sleep 0.1
    done
    [[ -s $out ]] || tmux -S "$sock" capture-pane -p > "$out.screen" 2>/dev/null
    tmux -S "$sock" kill-server 2>/dev/null
    [[ -s $out ]]
}
cat > "$TMP/dump.vim" <<'EOF'
" Record :messages and a few facts after startup, then quit.
function! s:Dump(...) abort
  let l:f8_global = maparg('<F8>', 'n')
  enew | setfiletype markdown
  let l:facts = ['signcolumn=' . &signcolumn, 'spell=' . &spell, 'RR=' . exists(':RR'),
        \ 'F5=' . !empty(maparg('<F5>', 'n')), 'F8_global=' . !empty(l:f8_global),
        \ 'F8_markdown=' . (maparg('<F8>', 'n') =~# 'MarkdownPreview'),
        \ 'background=' . &background, 'colors=' . get(g:, 'colors_name', 'default')]
  call writefile(split(execute('messages'), "\n") + ['--facts--'] + l:facts, $OUT)
  qa!
endfunction
autocmd VimEnter * call timer_start(500, function('s:Dump'))
EOF
if have vim && have tmux; then
    # A STUB vim-plug, i.e. a test double: same function names, but they do
    # nothing. With it the vimrc loads completely offline, without plugins,
    # and without a single line of the vimrc changing for the test.
    mkdir -p "$T/.vim/autoload"
    printf '%s\n' 'function! plug#begin(...) abort' 'endfunction' \
        'function! plug#end() abort' 'endfunction' 'command! -nargs=+ -bar Plug :' \
        > "$T/.vim/autoload/plug.vim"
    if vim_in_tmux "$TMP/vim0.out" 20 -N -i NONE -S "$TMP/dump.vim"; then
        msgs=$(sed '/^--facts--$/,$d' "$TMP/vim0.out")
        if grep -q -E 'E[0-9]+:|Error detected' <<<"$msgs"; then
            fail "vim with plugins stubbed out: errors at startup" "$msgs"
        else
            pass "vim with plugins stubbed out: starts with no errors"
        fi
        if grep -q '^signcolumn=yes$' "$TMP/vim0.out" && grep -q '^spell=1$' "$TMP/vim0.out" \
                && grep -q '^RR=2$' "$TMP/vim0.out" && grep -q '^F5=1$' "$TMP/vim0.out"; then
            pass "vim settings and commands applied (signcolumn, spell, :RR, F5)"
        else
            fail "vim settings not applied" "$(cat "$TMP/vim0.out")"
        fi
        # Regression: Vim GUESSES 'background' (from $COLORFGBG, which Konsole sets
        # and Windows Terminal doesn't) and fell back to light: gruvbox's bright
        # palette on WSL. This tmux has no COLORFGBG either, so the test is real.
        if grep -q '^background=dark$' "$TMP/vim0.out"; then
            pass "background is dark on a terminal that doesn't announce it"
        else
            fail "background guessed wrong" "$(grep '^background=' "$TMP/vim0.out")"
        fi
        # Regression: a global F8 -> :MarkdownPreview threw E492 outside markdown
        # (the plugin loads only for markdown). F8 must exist only there.
        if grep -q '^F8_global=0$' "$TMP/vim0.out" && grep -q '^F8_markdown=1$' "$TMP/vim0.out"; then
            pass "F8 is mapped only in markdown buffers"
        else
            fail "F8 mapping scope" "$(grep '^F8' "$TMP/vim0.out")"
        fi
        if [[ -d $T/.vim/undodir && $(stat -c %a "$T/.vim/undodir") == 700 ]]; then
            pass "undo dir created, private (0700)"
        else
            fail "undo dir missing or not 0700"
        fi
    else
        fail "vim did not finish starting" "$(cat "$TMP/vim0.out.screen" 2>/dev/null)"
    fi

    # Clipboard keys end to end, with a FAKE xclip (another test double) that
    # keeps the "clipboard" in a file: works on any machine, CI included.
    # Regression: the mappings once read s:clip_write in their RHS, which a
    # mapping cannot see (E121), so \y failed on every machine.
    mkdir -p "$TMP/fakebin"
    printf '#!/bin/sh\n# fake xclip: -o prints the clipboard, otherwise stdin replaces it\ncase " $* " in\n  *" -o "*) cat "%s" 2>/dev/null ;;\n  *) cat > "%s" ;;\nesac\n' \
        "$TMP/clipboard" "$TMP/clipboard" > "$TMP/fakebin/xclip"
    chmod +x "$TMP/fakebin/xclip"
    cat > "$TMP/clip.vim" <<'EOF'
" Press the keys like a user, one step per timer tick (Leader = \).
let s:step = 0
function! s:Tick(t) abort
  let s:step += 1
  if s:step == 1
    enew | call setline(1, ['first line', 'x中y', '', '']) | call cursor(1, 1)
    call feedkeys("\\y", 't')
  elseif s:step == 2
    call cursor(3, 1) | call feedkeys("\\p", 't')
  elseif s:step == 3
    call cursor(2, 2) | call feedkeys("v\\y", 't')
  elseif s:step == 4
    call cursor(4, 1) | call feedkeys("\\p", 't')
  else
    call writefile(['line3=' . getline(3), 'line4=' . getline(4), '--messages--']
          \ + split(execute('messages'), "\n"), $OUT)
    qa!
  endif
endfunction
call timer_start(300, function('s:Tick'), {'repeat': 5})
EOF
    VIM_ENV=(DISPLAY=:99 "PATH=$TMP/fakebin:$CLEAN_PATH")
    if vim_in_tmux "$TMP/clip.out" 20 -N -i NONE -S "$TMP/clip.vim"; then
        if grep -q '^line3=first line$' "$TMP/clip.out" && grep -q '^line4=中$' "$TMP/clip.out" \
                && ! grep -q -E 'E[0-9]+:' "$TMP/clip.out"; then
            pass "clipboard keys: \\y copies, \\p pastes (line, and one CJK char)"
        else
            fail "clipboard keys" "$(cat "$TMP/clip.out")"
        fi
    else
        fail "clipboard test did not finish" "$(cat "$TMP/clip.out.screen" 2>/dev/null)"
    fi

    # Regression: Shift-Tab with a FAILING formatter (here a fake clang-format
    # that exits 1) replaced the whole buffer with the error message; one :w
    # later the source file was gone. The buffer must come back untouched.
    mkdir -p "$TMP/failbin" "$TMP/fmt"
    printf '#!/bin/sh\necho "clang-format: simulated failure" >&2\nexit 1\n' > "$TMP/failbin/clang-format"
    chmod +x "$TMP/failbin/clang-format"
    printf '%s\n' '#include <stdio.h>' 'int main(void){return 0;}' > "$TMP/fmt/demo.c"
    cat > "$TMP/stab.vim" <<'EOF'
" Press Shift-Tab like a user, then record the buffer and the messages.
function! s:Done(...) abort
  call writefile(['lines=' . join(getline(1, '$'), '|'), 'modified=' . &modified, '--messages--']
        \ + split(execute('messages'), "\n"), $OUT)
  qa!
endfunction
autocmd VimEnter * call timer_start(500, {-> feedkeys("\<S-Tab>", 't')})
autocmd VimEnter * call timer_start(1500, function('s:Done'))
EOF
    VIM_ENV=("PATH=$TMP/failbin:$CLEAN_PATH")
    if vim_in_tmux "$TMP/stab.out" 20 -N -i NONE -S "$TMP/stab.vim" "$TMP/fmt/demo.c"; then
        if grep -q '^lines=#include <stdio.h>|int main(void){return 0;}$' "$TMP/stab.out" \
                && grep -q '^modified=0$' "$TMP/stab.out" && grep -q 'clang-format failed' "$TMP/stab.out"; then
            pass "Shift-Tab with a failing formatter keeps the buffer and says why"
        else
            fail "Shift-Tab with a failing formatter" "$(cat "$TMP/stab.out")"
        fi
    else
        fail "Shift-Tab test did not finish" "$(cat "$TMP/stab.out.screen" 2>/dev/null)"
    fi
    VIM_ENV=()

    # Regression: Vim ships EditorConfig support switched off, and the vimrc
    # never ran `packadd! editorconfig`, so .editorconfig did nothing in Vim.
    # Two shell files, one Vim: the file under a .editorconfig must get its
    # indent (3, a value nothing else sets); the other keeps the vimrc's 2.
    mkdir -p "$TMP/ec/with" "$TMP/ec/without"
    printf '%s\n' 'root = true' '[*.sh]' 'indent_style = space' 'indent_size = 3' > "$TMP/ec/with/.editorconfig"
    touch "$TMP/ec/with/a.sh" "$TMP/ec/without/b.sh"
    cat > "$TMP/ec.vim" <<'EOF'
" Visit each file on the command line and record its indent settings.
function! s:Check(...) abort
  let l:facts = ['pkg=' . !empty(globpath(&packpath, 'pack/*/opt/editorconfig'))]
  for l:i in range(1, argc())
    execute 'argument' l:i
    call add(l:facts, expand('%:p:h:t') . '=' . &l:shiftwidth . (&l:expandtab ? ' spaces' : ' tabs'))
  endfor
  call writefile(l:facts + ['--messages--'] + split(execute('messages'), "\n"), $OUT)
  qa!
endfunction
autocmd VimEnter * call timer_start(300, function('s:Check'))
EOF
    if vim_in_tmux "$TMP/ec.out" 20 -N -i NONE -S "$TMP/ec.vim" "$TMP/ec/with/a.sh" "$TMP/ec/without/b.sh"; then
        if grep -q '^pkg=0$' "$TMP/ec.out"; then
            skip "EditorConfig in vim (this vim has no editorconfig package; Vim 9.1 ships it)"
        elif grep -q '^with=3 spaces$' "$TMP/ec.out" && grep -q '^without=2 spaces$' "$TMP/ec.out" \
                && ! grep -q -E 'E[0-9]+:' "$TMP/ec.out"; then
            pass "vim follows .editorconfig (indent 3 under it, the vimrc's 2 elsewhere)"
        else
            fail "vim ignores .editorconfig" "$(cat "$TMP/ec.out")"
        fi
    else
        fail "EditorConfig test did not finish" "$(cat "$TMP/ec.out.screen" 2>/dev/null)"
    fi
    rm -f "$T/.vim/autoload/plug.vim"     # the --full test must bootstrap the real one
else
    skip "vim startup (needs vim and tmux)"
fi

if [[ $FULL == 1 ]] && have vim && have tmux && have git && have curl; then
    # First launch with network: vim downloads vim-plug and installs every plugin.
    if vim_in_tmux "$TMP/vim1.out" 900 -N -i NONE -S "$TMP/dump.vim"; then
        n=$(find "$T/.vim/plugged" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        msgs=$(sed '/^--facts--$/,$d' "$TMP/vim1.out")
        if (( n >= 15 )) && ! grep -q -E 'E[0-9]+:|Error detected' <<<"$msgs"; then
            pass "first launch installed $n plugins with no errors"
        else
            fail "plugin bootstrap ($n plugins)" "$msgs"
        fi
        # Regression: the post-install re-source used to delete the pending
        # VimEnter colorscheme autocmd, leaving the first session uncolored.
        if grep -q '^colors=gruvbox$' "$TMP/vim1.out"; then
            pass "first launch applies the colorscheme"
        else
            fail "first launch: colorscheme not applied" "$(grep '^colors=' "$TMP/vim1.out")"
        fi
    else
        fail "plugin bootstrap did not finish" "$(cat "$TMP/vim1.out.screen" 2>/dev/null)"
    fi
    # Regression: F5's build toggle once ended with a bare `win_gotoid(...)`,
    # which Vim parses as the Ex command :win[size] -> E475 after every build.
    mkdir -p "$TMP/f5"
    printf 'all:\n\t@echo built\n' > "$TMP/f5/Makefile"
    cat > "$TMP/f5.vim" <<'EOF'
" Press F5 like a user, give the async build time to run, record :messages.
function! s:Check(...) abort
  call writefile(['--messages--'] + split(execute('messages'), "\n"), $OUT)
  qa!
endfunction
autocmd VimEnter * call timer_start(300, {-> feedkeys("\<F5>")})
autocmd VimEnter * call timer_start(3000, function('s:Check'))
EOF
    if (cd "$TMP/f5" && vim_in_tmux "$TMP/f5.out" 20 -N -i NONE -S "$TMP/f5.vim" Makefile); then
        if grep -q -E 'E[0-9]+:|Error detected' "$TMP/f5.out"; then
            fail "F5 build: errors" "$(cat "$TMP/f5.out")"
        else
            pass "F5 runs the build without errors"
        fi
    else
        fail "F5 test did not finish" "$(cat "$TMP/f5.out.screen" 2>/dev/null)"
    fi
    if have clangd; then
        mkdir -p "$TMP/cproj"
        printf '%s\n' -std=gnu11 -Wall > "$TMP/cproj/compile_flags.txt"
        printf '%s\n' '#include <stdio.h>' '' 'int main(void) {' '    printf("hello\n");' '    return 0;' '}' > "$TMP/cproj/main.c"
        cat > "$TMP/typo.vim" <<'EOF'
" Open a clean C file, wait for clangd, type two typos, wait for the errors.
let s:t0 = reltime()
let s:phase = 'server'
function! s:Ms(t) abort
  return float2nr(reltimefloat(reltime(a:t)) * 1000)
endfunction
function! s:Tick(timer) abort
  if s:phase ==# 'done' | return | endif
  if s:Ms(s:t0) > 30000
    let s:phase = 'done'
    call writefile(['TIMEOUT'] + split(execute('LspShowAllServers'), "\n"), $OUT) | qa!
  elseif s:phase ==# 'server' && exists('*LspServerReady') && LspServerReady()
    let [s:ready, s:phase, s:tb] = [s:Ms(s:t0), 'baseline', reltime()]
  elseif s:phase ==# 'baseline' && s:Ms(s:tb) > 1500
    let s:base = lsp#lsp#ErrorCount().Error
    call append(line('$') - 1, ['    printff("x");', '    int y = undeclared_thing;'])
    let [s:phase, s:te] = ['errors', reltime()]
  elseif s:phase ==# 'errors' && lsp#lsp#ErrorCount().Error > s:base
    let s:phase = 'done'
    call writefile(['ready_ms=' . s:ready, 'baseline_errors=' . s:base,
          \ 'errors=' . lsp#lsp#ErrorCount().Error, 'latency_ms=' . s:Ms(s:te)], $OUT)
    qa!
  endif
endfunction
" poll every 20 ms: the reported latency is accurate to one poll interval
call timer_start(20, function('s:Tick'), {'repeat': -1})
EOF
        if (cd "$TMP/cproj" && vim_in_tmux "$TMP/lsp.out" 40 -N -i NONE -S "$TMP/typo.vim" main.c); then
            if grep -q '^baseline_errors=0$' "$TMP/lsp.out" && grep -q '^errors=[1-9]' "$TMP/lsp.out"; then
                pass "LSP: typos in vim produce clangd errors ($(tr '\n' ' ' < "$TMP/lsp.out"))"
            else
                fail "LSP: unexpected diagnostics" "$(cat "$TMP/lsp.out")"
            fi
        else
            fail "LSP test did not finish" "$(cat "$TMP/lsp.out.screen" 2>/dev/null)"
        fi
    else
        skip "LSP test in vim (clangd not installed)"
    fi
elif [[ $FULL == 1 ]]; then
    skip "--full vim tests (need vim, tmux, git, curl)"
else
    info "(run with --full to install vim plugins and test clangd inside vim)"
fi

# ═══════════════════════════════════════════════════════════════════════
section "6. Config files, each checked by the program that reads it"
# clang-format: parses, and formatting is idempotent (format twice = once).
if have clang-format; then
    v=$(clang-format --version | grep -o '[0-9][0-9.]*' | head -1)
    check "clang-format $v accepts ~/.clang-format" clang-format --style=file:home/.clang-format --dump-config
    printf 'namespace demo {\nint   add (int a,int b){return a+b;}\n}\n' > "$TMP/fmt.cpp"
    f1=$(clang-format --style=file:home/.clang-format "$TMP/fmt.cpp")
    f2=$(printf '%s\n' "$f1" | clang-format --style=file:home/.clang-format --assume-filename=x.cpp)
    if [[ $f1 == "$f2" ]]; then pass "clang-format output is stable (idempotent)"; else fail "clang-format not idempotent"; fi
    printf 'BasedOnStyle: LLVM\nIndentWidht: 4\n' > "$TMP/bad.clang-format"
    reject "clang-format rejects a misspelled key (negative control)" \
        clang-format --style="file:$TMP/bad.clang-format" --dump-config
else
    skip "clang-format (not installed)"
fi

# clangd: the user config has no unknown keys, and clang-tidy really runs.
if have clangd && have python3; then
    v=$(clangd --version | grep -o '[0-9][0-9.]*' | head -1)
    mkdir -p "$TMP/probe"
    printf '%s\n' -std=gnu11 -Wall > "$TMP/probe/compile_flags.txt"
    cat > "$TMP/probe/bug.c" <<'EOF'
void set(int *a, int n) {
    if (n > 0) {
        a[0] = 1;
    } else {
        a[0] = 1;
    }
}
EOF
    warnings=$(cd "$TMP/probe" && XDG_CONFIG_HOME="$T/.config" clangd --check=bug.c --log=verbose 2>&1 | grep -E 'config (warning|error) at')
    if [[ -z $warnings ]]; then pass "clangd $v accepts ~/.config/clangd/config.yaml"; else fail "clangd config warnings" "$warnings"; fi
    mkdir -p "$TMP/badcfg/clangd" && printf 'Diagnostics:\n  Bogus: 1\n' > "$TMP/badcfg/clangd/config.yaml"
    reject "clangd flags an unknown key (negative control)" bash -c \
        "cd '$TMP/probe' && XDG_CONFIG_HOME='$TMP/badcfg' clangd --check=bug.c --log=verbose 2>&1 | grep -q 'config warning at' && exit 1 || exit 0"
    out=$(cd "$TMP/probe" && XDG_CONFIG_HOME="$T/.config" python3 -I "$REPO/scripts/lsp-probe.py" bug.c 2>&1)
    if [[ $out == *bugprone-branch-clone* ]]; then pass "clang-tidy checks run inside clangd (bugprone-branch-clone found)"; else fail "clang-tidy did not run" "$out"; fi
else
    skip "clangd (not installed)"
fi

# tmux: EXECUTE the file in a throwaway server; -n would only parse it.
tmux_conf_ok() {
    local sock="$SOCKS/conf-$RANDOM" rc; TMUX_SOCKS+=("$sock")
    tmux -S "$sock" -f /dev/null new-session -d 'sleep 30' || return 2
    tmux -S "$sock" source-file "$1"; rc=$?
    tmux -S "$sock" kill-server 2>/dev/null
    return $rc
}
if have tmux; then
    check "tmux $(tmux -V | cut -d' ' -f2) runs tmux.conf without errors" tmux_conf_ok home/.config/tmux/tmux.conf
    printf 'set -g no-such-option on\n' > "$TMP/bad.tmux"
    reject "tmux rejects an unknown option (negative control)" tmux_conf_ok "$TMP/bad.tmux"
else
    skip "tmux (not installed)"
fi

if have gdb; then
    out=$(gdb -nx -batch -x home/.config/gdb/gdbinit 2>&1)
    if [[ -z $out ]]; then pass "gdb runs gdbinit silently"; else fail "gdb complained about gdbinit" "$out"; fi
else
    skip "gdb (not installed)"
fi

check "git parses .config/git/config" git config -f home/.config/git/config --list

if have starship; then
    # henv (a fresh environment) matters: starship prints a given warning only
    # once per STARSHIP_SESSION_KEY, and a key inherited from your own shell
    # silently hid the negative control's warning (found 2026-10-19).
    err=$(henv STARSHIP_CONFIG="$REPO/home/.config/starship.toml" starship print-config 2>&1 >/dev/null)
    if [[ -z $err ]]; then pass "starship accepts starship.toml"; else fail "starship warnings" "$err"; fi
    printf '[os]\nstyel = "bold"\n' > "$TMP/bad.toml"
    starship_quiet() { [[ -z $(henv STARSHIP_CONFIG="$1" starship print-config 2>&1 >/dev/null) ]]; }
    reject "starship warns on a misspelled key (negative control)" starship_quiet "$TMP/bad.toml"
else
    skip "starship (not installed)"
fi

if have python3; then
    check "TOML parses: starship.toml" python3 -I -c \
        'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' home/.config/starship.toml
    if python3 -I -c 'import yaml' 2>/dev/null; then
        for y in home/.config/clangd/config.yaml .github/workflows/*.yml templates/*/.clangd; do
            [[ -f $y ]] && check "YAML parses: $y" python3 -I -c \
                'import sys, yaml; list(yaml.safe_load_all(open(sys.argv[1])))' "$y"
        done
    else
        skip "YAML parsing (python3-yaml not installed)"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════
printf '\n%s%d passed, %d failed, %d skipped%s\n' "$B" "$npass" "$nfail" "$nskip" "$N"
(( nfail == 0 ))
