" ~/.vim/ftdetect/cpp.vim — C++ filetype detection for extension-less
" headers (…/c++/14/vector, …/include/stdio.h's dotless neighbors).
" Installed by install.sh (a symlink into the repo). The repo .vimrc keeps
" the same two rules inline after plug#end(); this file is the copy that
" survives a `:filetype off | filetype on` reload.
"
" Sourced by plug#end's `filetype plugin indent on` via
" `runtime! ftdetect/*.vim` (filetype.vim:1642). That runs INSIDE the open
" `augroup filetypedetect` context, so a bare `au` lands in that group — the
" standard ftdetect convention (see :help ftdetect). It runs AFTER
" plug#begin's `:filetype off` (ftoff.vim: `au! filetypedetect *`) has
" cleared the group, so the group is fresh each `:filetype on` and a plain
" `au` can't stack duplicates.
"
" Why this survives when an inline `aug filetypedetect` block in the vimrc
" (placed before plug#begin) did not: that block was wiped by plug#begin's
" `:filetype off` and, not being in ftdetect/, was never re-sourced by the
" rebuild — verified dead 2026-08-22 and moved here.
"
" Why only the no-extension case: a header like `vector` (no dot) matches
" no extension rule and would otherwise get no filetype. A .h file is
" already content-sniffed by dist/ft.vim (class/namespace/template -> cpp,
" else c), so the `!~ '\.'` guard skips it and lets that sniff decide.
au BufRead */c++/*     if expand('%:t') !~ '\.' | setfiletype cpp | endif
au BufRead */include/* if expand('%:t') !~ '\.' | setfiletype cpp | endif
