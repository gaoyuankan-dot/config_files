#!/usr/bin/env bash
# scripts/arch-sandbox.sh: test these dotfiles on Arch Linux from any Linux
# box (WSL Ubuntu included). No root, no Docker, nothing installed system-wide.
#
# Usage:
#   scripts/arch-sandbox.sh setup          download + verify + unpack Arch, install packages
#   scripts/arch-sandbox.sh test [--full]  run scripts/test.sh inside Arch
#   scripts/arch-sandbox.sh shell          interactive bash inside Arch
#   scripts/arch-sandbox.sh run CMD...     run one command inside Arch
#   scripts/arch-sandbox.sh clean          delete the sandbox (~1.5 GB)
#
# Environment:
#   MIRROR            Arch mirror (default: geo.mirror.pkgbuild.com; in China
#                     https://mirrors.ustc.edu.cn/archlinux is ~6x faster)
#   ARCH_SANDBOX_DIR  where it lives (default: ~/.cache/dotfiles/arch-sandbox)
#
# How it works: the official Arch "bootstrap" tarball is a complete root
# filesystem. bubblewrap (bwrap) starts a process in new Linux NAMESPACES:
# a user namespace maps your uid to 0, so pacman believes it is root, and a
# mount namespace makes that unpacked tree its "/". It is the same kernel
# trick containers use, without a daemon. The network is shared, so a proxy
# on 127.0.0.1 keeps working.
# Needs: bwrap, curl, sha256sum, and python3 >= 3.14 or zstd (to unpack).

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
MIRROR=${MIRROR:-https://mirrors.ustc.edu.cn/archlinux}
DIR=${ARCH_SANDBOX_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/arch-sandbox}
ROOT=$DIR/root
TARBALL=$DIR/dl/archlinux-bootstrap-x86_64.tar.zst
# Same tools as CI's Arch job, so `test` skips nothing. shellcheck costs the
# most: ~55 Haskell packages (22 MB download, ~160 MiB unpacked).
PACKAGES='zsh vim git curl ripgrep fd bat eza fzf zoxide starship tmux gdb bear clang ctags
          zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
          base-devel python python-yaml shellcheck shfmt which diffutils less'

die() { printf 'arch-sandbox: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "needs '$1' (Ubuntu: sudo apt install ${2:-$1})"; }

# in_sandbox CMD...: run CMD with the Arch tree as "/", the repo mounted at
# the SAME path as outside (so absolute symlinks made by install.sh resolve).
in_sandbox() {
    [[ -x $ROOT/usr/bin/pacman ]] || die "not set up yet: run '$0 setup'"
    local proxy=() v
    for v in http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY; do
        [[ -n ${!v-} ]] && proxy+=(--setenv "$v" "${!v}")
    done
    bwrap --unshare-user --uid 0 --gid 0 --unshare-pid --die-with-parent \
        --bind "$ROOT" / --dev /dev --proc /proc --tmpfs /tmp \
        --ro-bind /etc/resolv.conf /etc/resolv.conf \
        --bind "$REPO" "$REPO" --chdir "$REPO" \
        --clearenv --setenv HOME /root --setenv USER tester --setenv LANG C.UTF-8 \
        --setenv TERM "${TERM:-xterm-256color}" --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/bin \
        "${proxy[@]}" "$@"
}

# unpack ARCHIVE DEST: extract the .tar.zst. Prefer the zstd program; else
# Python 3.14's built-in zstd. The Python filter keeps paths inside DEST and
# strips setuid bits, but allows ABSOLUTE symlinks: a root filesystem has them,
# and they are only followed later, inside the sandbox.
unpack() {
    if command -v zstd >/dev/null 2>&1; then
        tar --zstd -xpf "$1" -C "$2" --no-same-owner
        return
    fi
    python3 -I - "$1" "$2" <<'EOF' || die "unpacking needs zstd or python3 >= 3.14"
import sys, tarfile
def keep(member, dest):
    if member.isdev():                      # device nodes need root; bwrap gives /dev
        return None
    try:
        return tarfile.tar_filter(member, dest)
    except (tarfile.AbsoluteLinkError, tarfile.LinkOutsideDestinationError):
        if member.issym():
            return member.replace(mode=member.mode & 0o755, deep=False)
        raise
with tarfile.open(sys.argv[1], "r:zst") as tf:
    tf.extractall(sys.argv[2], filter=keep)
EOF
}

cmd_setup() {
    need bwrap bubblewrap; need curl; need sha256sum coreutils
    mkdir -p "$DIR/dl"
    if [[ ! -f $TARBALL ]]; then
        echo "downloading the Arch bootstrap tarball (~120 MB) from $MIRROR"
        curl -fL --retry 3 -o "$TARBALL.part" "$MIRROR/iso/latest/archlinux-bootstrap-x86_64.tar.zst"
        mv "$TARBALL.part" "$TARBALL"
    fi
    # Integrity: compare with the checksum list published next to the tarball.
    curl -fsSL --retry 3 -o "$DIR/dl/sha256sums.txt" "$MIRROR/iso/latest/sha256sums.txt"
    (cd "$DIR/dl" && grep ' archlinux-bootstrap-x86_64.tar.zst$' sha256sums.txt | sha256sum -c --quiet -) \
        || { rm -f "$TARBALL"; die "checksum mismatch: deleted the download, run setup again"; }
    if [[ ! -x $ROOT/usr/bin/pacman ]]; then
        rm -rf "$DIR/unpack"; mkdir -p "$DIR/unpack"
        unpack "$TARBALL" "$DIR/unpack"
        # The tarball's root dir is mode 0555. Moving a directory to a NEW
        # parent rewrites its '..' entry, which needs write permission on it.
        chmod u+w "$DIR/unpack/root.x86_64"
        mv "$DIR/unpack/root.x86_64" "$ROOT"
        rm -rf "$DIR/unpack"      # left: pkglist.x86_64.txt and version (metadata)
    fi
    # pacman inside a one-uid namespace: it cannot switch to its 'alpm'
    # download user, and has no real mounts for the free-space check.
    sed -i -e 's/^DownloadUser/#DownloadUser/' -e 's/^CheckSpace/#CheckSpace/' "$ROOT/etc/pacman.conf"
    # $repo and $arch are LITERAL here: pacman substitutes them itself.
    # shellcheck disable=SC2016
    printf 'Server = %s/$repo/os/$arch\n' "$MIRROR" > "$ROOT/etc/pacman.d/mirrorlist"
    # Packages travel as ARGUMENTS ("$@" inside), never pasted into the script
    # text: the list contains newlines, which would end the pacman command.
    # pipefail + `|| true` on grep: the pipeline fails exactly when pacman does.
    # shellcheck disable=SC2016,SC2086  # $@ expands inside; the list is split on purpose
    in_sandbox bash -euo pipefail -c '
        [[ -s /etc/pacman.d/gnupg/pubring.gpg ]] || { pacman-key --init; pacman-key --populate archlinux; }
        # The filtered lines are expected: only one uid exists in the namespace.
        pacman -Syu --noconfirm --needed --disable-sandbox "$@" 2>&1 \
            | { grep -v -E "fchownat|ACL|Skipped: Current root is not booted" || true; }
        pacman -Q zsh vim clang tmux | tr "\n" " "; echo' bash $PACKAGES \
        || die "pacman failed"
    echo "ready: $ROOT"
}

cmd_clean() {
    [[ -d $DIR ]] || { echo "nothing to clean"; return; }
    chmod -R u+w "$DIR"       # unpacked dirs like /proc are 0555: rm needs write access
    rm -rf "$DIR"
    echo "removed $DIR"
}

case ${1-} in
    setup) cmd_setup ;;
    test)  shift; in_sandbox scripts/test.sh "$@" ;;
    shell) in_sandbox bash -l ;;
    run)   shift; [[ $# -gt 0 ]] || die "run: missing command"; in_sandbox "$@" ;;
    clean) cmd_clean ;;
    *) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; [[ -z ${1-} || $1 == -h || $1 == --help ]] ;;
esac
