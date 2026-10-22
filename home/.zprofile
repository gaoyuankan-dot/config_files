# ~/.zprofile: read by LOGIN zsh only (Windows Terminal starts WSL as a login
# shell; so does a tty or ssh login). Job: the session's ENVIRONMENT.
#
# Why /etc/profile is sourced here: Arch's /etc/zsh/zprofile already sources
# /etc/profile; Ubuntu's does NOT. Without this line, zsh on Ubuntu silently
# misses /etc/profile.d/*.sh (e.g. the WSL proxy from install-wsl-proxy.sh).
# Re-sourcing it on Arch is harmless: Arch's /etc/profile only appends missing
# PATH entries and re-runs idempotent profile.d scripts.
#
# `emulate sh -c` runs these POSIX files in sh mode, so zsh-isms (like
# unquoted $var not word-splitting) cannot change their meaning.
emulate sh -c '. /etc/profile'
[[ -r ~/.profile ]] && emulate sh -c '. ~/.profile'
