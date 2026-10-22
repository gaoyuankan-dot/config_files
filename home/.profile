# ~/.profile: login ENVIRONMENT, in plain POSIX sh.
#
# Who reads it:  sh/dash login shells directly; bash via ~/.bash_profile;
#                zsh via ~/.zprofile (in `emulate sh` mode).
# What belongs here: things child processes INHERIT (exported variables).
# What does not: aliases, functions, prompts, key bindings (they are not
# inherited, so they live in ~/.bashrc / ~/.zshrc).
# Rules: no output (it would break scp/rsync), safe to run twice, no bashisms.

# path_prepend DIR: put DIR at the front of PATH unless it is already there.
path_prepend() {
    case ":${PATH-}:" in
        *":$1:"*) ;;                                  # already present: no duplicate
        *) PATH="$1${PATH:+:$PATH}" ;;                # ${PATH:+...}: no stray ':' if PATH is empty
    esac
}
[ -d "$HOME/bin" ] && path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"     # XDG user bin: pipx tools, claude, the bat/fd shims from install.sh
unset -f path_prepend

# WSL only: Windows appends ~10 folders under /mnt/c to PATH. Every lookup of a
# MISSING command stats each one over the slow 9P filesystem: measured 1.9 ms
# vs 0.4 ms per lookup, and zsh startup 75 ms vs 40 ms. If you turn that off
# (/etc/wsl.conf: [interop] appendWindowsPath=false, see docs/GUIDE.md), this
# adds back only the folders whose tools you use. It is a no-op otherwise.
if [ -n "${WSL_DISTRO_NAME-}" ]; then
    case ":$PATH:" in
        *:/mnt/c/*) ;;                                # Windows PATH still appended: leave it
        *)
            for d in /mnt/c/Windows/System32 /mnt/c/Windows \
                     /mnt/c/Windows/System32/WindowsPowerShell/v1.0 \
                     /mnt/c/Users/*/AppData/Local/Programs/"Microsoft VS Code"/bin; do
                [ -d "$d" ] && PATH="$PATH:$d"        # append: Linux tools must win
            done
            unset d
            ;;
    esac
fi
export PATH

export EDITOR=vim
export VISUAL=vim
export PAGER=less
# -R: show colors  -F: quit if it fits on one screen  -i: smart-case search
# -M: long prompt (line numbers, percent)  -j.3: search hits 30% from the top
export LESS='-R -F -i -M -j.3'

# Windows Terminal renders 24-bit color but never sets COLORTERM (Konsole does).
# Without it, programs fall back to 256 colors (Claude Code's orange #D77757
# becomes pink #D78787). Exported here so every child (tmux, vim) inherits it.
if [ -n "${WT_SESSION-}" ] && [ -z "${COLORTERM-}" ]; then
    export COLORTERM=truecolor
fi

# Machine-only environment (secrets, work proxies): never committed to git.
if [ -r "$HOME/.profile.local" ]; then
    # shellcheck source=/dev/null  # (a per-machine file: nothing to lint here)
    . "$HOME/.profile.local"
fi
