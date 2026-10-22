#!/bin/sh
# scripts/bootstrap.sh: install the programs these dotfiles use.
#
# Usage:  scripts/bootstrap.sh [--dry-run]
#
# Supports Arch (pacman) and Debian/Ubuntu (apt). Prints the exact command,
# then runs it with sudo (it asks for your password). Safe to re-run:
# installed packages are skipped. Afterwards run ./install.sh.
#
# Every package name below was checked against Ubuntu 26.04 and Arch
# (Oct 2026). The two lists differ only where the distros name things
# differently (fd-find/fd, universal-ctags/ctags, clangd+clang-format/clang).

set -eu

DRY=0
case ${1-} in
    -n|--dry-run) DRY=1 ;;
    -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    '') ;;
    *) echo "bootstrap.sh: unknown option $1" >&2; exit 2 ;;
esac

say() { printf '%s\n' "$*"; }
run() {
    say "+ $*"
    [ "$DRY" -eq 1 ] || "$@"
}

[ "$(id -u)" -ne 0 ] || { say 'run as yourself; the script calls sudo where needed'; exit 1; }
[ -r /etc/os-release ] || { say 'no /etc/os-release: unknown system, install packages by hand (see README)'; exit 1; }
# shellcheck source=/dev/null
. /etc/os-release

# Shared by both distros:
#   shells, editor, git     zsh vim git curl
#   modern CLI              ripgrep fzf zoxide starship tmux bat eza
#   C toolchain + LSP       gdb bear (compile_commands.json) and clangd/clang-format
#   linters for this repo   shellcheck shfmt
#   tests                   bubblewrap (scripts/arch-sandbox.sh), python yaml
#   clipboard (Wayland)     wl-clipboard
COMMON='zsh vim git curl ca-certificates ripgrep fzf zoxide starship tmux bat eza gdb bear
        zsh-autosuggestions zsh-syntax-highlighting shellcheck shfmt bubblewrap wl-clipboard'

# sudo drops your environment by default, and pacman reads the proxy only
# from it (apt has its own proxy setting). Keep the proxy variables.
SUDO='sudo --preserve-env=http_proxy,https_proxy,all_proxy,no_proxy,HTTP_PROXY,HTTPS_PROXY,ALL_PROXY,NO_PROXY'

case " ${ID-} ${ID_LIKE-} " in
    *" arch "*)
        # clang = clangd + clang-format + clang-tidy; ctags = universal-ctags.
        # (shellcheck pulls ~40 Haskell libraries on Arch; drop it if disk matters.)
        # shellcheck disable=SC2086  # word splitting of the package lists is intended
        run $SUDO pacman -S --needed $COMMON fd ctags clang base-devel \
            zsh-history-substring-search python-black python-yaml
        ;;
    *" debian "*|*" ubuntu "*)
        # Ubuntu renames fd and bat (fdfind, batcat): install.sh adds shims.
        # shellcheck disable=SC2086
        run $SUDO apt-get update
        # shellcheck disable=SC2086
        run $SUDO apt-get install -y $COMMON fd-find universal-ctags clangd clang-format clang-tidy \
            build-essential black python3-yaml
        # Not packaged on Ubuntu: clone it where ~/.zshrc looks (no sudo needed).
        dir=$HOME/.local/share/zsh/plugins/zsh-history-substring-search
        if [ -d "$dir/.git" ]; then
            run git -C "$dir" pull --ff-only --quiet
        else
            run git clone --depth 1 --quiet https://github.com/zsh-users/zsh-history-substring-search "$dir"
        fi
        ;;
    *)
        say "unsupported distro '${ID-unknown}': install by hand, see README.md (Packages)"
        exit 1
        ;;
esac

say ''
case ${SHELL-} in
    */zsh) ;;
    *) say "Your login shell is ${SHELL-unknown}. To make zsh the default:  chsh -s \"\$(command -v zsh)\"" ;;
esac
if [ -n "${WSL_DISTRO_NAME-}" ] && ! grep -qs 'appendWindowsPath *= *false' /etc/wsl.conf; then
    say 'WSL tip: shell startup is ~2x faster without the Windows PATH (docs/GUIDE.md, "WSL PATH").'
fi
say 'Next: ./install.sh --dry-run, then ./install.sh'
