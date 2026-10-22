#!/bin/sh
# install.sh: link the dotfiles under home/ into $HOME.
#
# Usage:  ./install.sh [--dry-run] [--uninstall] [--help]
#
# For every file under home/, $HOME/<same path> becomes a SYMLINK to it, so
# editing ~/.zshrc edits the repo copy (commit it with git) and `git pull`
# updates every machine at once.
#   - Already the right link: left alone. Safe to re-run any time.
#   - Anything else in the way (a file, a dir, another link): MOVED to
#     ~/.local/state/dotfiles/backup/<timestamp>/<path>, never deleted.
#   - Editor litter is skipped: Vim swap files (*.sw?) and backups (*~).
#   - Ubuntu renames two tools (bat -> batcat, fd -> fdfind); this adds
#     ~/.local/bin/bat and ~/.local/bin/fd shims so scripts and fzf find them.
# --uninstall removes only links that point into this repo (and the shims);
# your backups stay where they are, and the paths are printed.
#
# POSIX sh on purpose: it must run on a fresh machine before zsh/bash
# configs exist, on Linux and macOS alike.

set -eu

usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0"
}
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

DRY=0
MODE=install
while [ $# -gt 0 ]; do
    case $1 in
        -n|--dry-run)   DRY=1 ;;
        -u|--uninstall) MODE=uninstall ;;
        -h|--help)      usage; exit 0 ;;
        *)              die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

# ── Sanity checks before touching anything ──────────────────────────────
[ -n "${HOME-}" ] && [ -d "$HOME" ] || die 'the HOME variable is unset or not a directory'
# Running under sudo would link into /root and leave root-owned files behind.
# Tests in throwaway HOMEs inside root containers opt in explicitly.
if [ "$(id -u)" -eq 0 ] && [ "${DOTFILES_ALLOW_ROOT-}" != 1 ]; then
    die 'refusing to run as root: run it as yourself, without sudo'
fi

REPO=$(cd -- "$(dirname -- "$0")" && pwd -P)    # -P: the real path, no symlinks
SRC=$REPO/home
[ -d "$SRC" ] || die "missing $SRC"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backup/$STAMP

# run CMD...: execute, or only print in --dry-run mode.
run() {
    if [ "$DRY" -eq 1 ]; then say "    (dry-run) $*"; else "$@"; fi
}

# The file list goes to a temp file (removed on any exit) instead of a pipe:
# `find | while read` runs the loop in a subshell, and the counters below
# would be lost when it ends.
LIST=$(mktemp "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")
trap 'rm -f "$LIST"' EXIT
trap 'exit 130' INT TERM
# Vim writes a swap file next to each file it has open, and for a link next
# to the TARGET: `vim ~/.vimrc` creates home/.vimrc.swp. Never link those.
(cd "$SRC" && find . \( -type f -o -type l \) ! -name '*.sw?' ! -name '*~' | sed 's|^\./||' | LC_ALL=C sort) > "$LIST"
# A name with a newline or other control character would break `read`.
if LC_ALL=C grep -q '[[:cntrl:]]' "$LIST"; then
    die 'a file name under home/ contains a control character'
fi

linked=0 kept=0 backed=0 removed=0

# ── Links ───────────────────────────────────────────────────────────────
while IFS= read -r rel; do
    src=$SRC/$rel
    dst=$HOME/$rel
    if [ "$MODE" = uninstall ]; then
        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
            run rm "$dst"
            say "unlink  ~/$rel"
            removed=$((removed + 1))
        fi
        continue
    fi
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        kept=$((kept + 1))
        continue
    fi
    # Same file reached through a symlinked PARENT directory (e.g. someone
    # once linked ~/.config/git to the repo): moving "it" to the backup would
    # move the repo's own file. Stop and explain instead.
    if [ -e "$dst" ] && [ "$dst" -ef "$src" ]; then
        die "$dst already IS the repo file through a linked parent directory; remove that directory link first"
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then     # -L too: a dangling link is "in the way"
        run mkdir -p "$(dirname "$BACKUP/$rel")"
        run mv "$dst" "$BACKUP/$rel"
        say "backup  ~/$rel  ->  $BACKUP/$rel"
        backed=$((backed + 1))
    fi
    run mkdir -p "$(dirname "$dst")"
    run ln -s "$src" "$dst"
    say "link    ~/$rel"
    linked=$((linked + 1))
done < "$LIST"

# ── Ubuntu shims: bat -> batcat, fd -> fdfind ───────────────────────────
# shim NAME REAL: when NAME is missing but REAL exists, link
# ~/.local/bin/NAME -> REAL. An alias would not do: aliases exist only
# inside an interactive shell, so scripts and `fzf --preview 'bat ...'`
# would still fail to find `bat`.
shim() {
    link=$HOME/.local/bin/$1
    if [ "$MODE" = uninstall ]; then
        if [ -L "$link" ] && [ "$(basename "$(readlink "$link")")" = "$2" ]; then
            run rm "$link"
            say "unlink  ~/.local/bin/$1"
            removed=$((removed + 1))
        fi
        return 0
    fi
    { [ -e "$link" ] || [ -L "$link" ]; } && return 0     # ours from a previous run, or the user's
    command -v "$1" >/dev/null 2>&1 && return 0           # the real tool is installed
    real=$(command -v "$2" 2>/dev/null) || return 0       # nothing to point at
    run mkdir -p "$HOME/.local/bin"
    run ln -s "$real" "$link"
    say "shim    ~/.local/bin/$1 -> $real"
    linked=$((linked + 1))
}
shim bat batcat
shim fd fdfind

# ── Summary ─────────────────────────────────────────────────────────────
[ "$DRY" -eq 1 ] && say "(dry-run: nothing was changed)"
if [ "$MODE" = uninstall ]; then
    say "Removed $removed link(s)."
    if [ -d "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backup" ]; then
        say "Your earlier files are kept in ${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backup/<time>/;"
        say "copy back what you want, e.g.:  cp -a <backup>/.zshrc ~/"
    fi
else
    say "Done: $linked linked, $kept already in place, $backed backed up."
    [ "$backed" -gt 0 ] && say "Backups: $BACKUP"
    [ "$linked" -gt 0 ] && [ "$DRY" -eq 0 ] && say "Next: open a new terminal (or run: exec zsh). Vim installs its plugins on first start."
fi
exit 0
