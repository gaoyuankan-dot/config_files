# ~/.zshenv: read by EVERY zsh, scripts included (`zsh -c ...` too), so it
# must stay tiny and silent. Everything else lives in .zprofile / .zshrc.
#
# Ubuntu's /etc/zsh/zshrc runs `compinit` itself, before ~/.zshrc runs it
# again with our settings: completion would be initialized twice (~10 ms
# wasted). Ubuntu's file checks this flag and skips its own call. Harmless on
# Arch, which has no such line.
skip_global_compinit=1
