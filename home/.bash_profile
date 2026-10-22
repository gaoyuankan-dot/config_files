# ~/.bash_profile: read by LOGIN bash only (a WSL tab, a tty, an ssh login).
#
# A login bash reads the first of ~/.bash_profile, ~/.bash_login, ~/.profile
# and then STOPS: it never reads ~/.bashrc on its own. So this file does two
# things: load the shared POSIX environment, then hand over to ~/.bashrc
# (which returns at once when the shell is not interactive).

# (shellcheck: these are linted separately, don't follow them from here)
if [ -r "$HOME/.profile" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.profile"
fi
if [ -r "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.bashrc"
fi
