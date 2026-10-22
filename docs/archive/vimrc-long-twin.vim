" STFW, RTFM, RTFS, scientific network is inevitable, my option is xray + vps

" ============================================================================
" ~/.vimrc — 12 subsystems, in boot order. vim 9.2 (Host is Arch, terminal).
" Every non-obvious line carries its reason. Ground truth for any mapping or
" option is always `:verbose map <key>` / `:verbose set <opt>?` — not memory.
" ============================================================================

" ============================================================================
" 1. RUNTIME BOOTSTRAP — load vim's built-in extras BEFORE my own rules,
"    so everything below overrides factory settings instead of losing to them.
" ============================================================================
" silent! = muzzle BOTH messages and errors (plain `silent` muzzles only
" messages; the bang to silent adds error-swallowing).
" packadd! = add an optional package (from 'packpath') onto 'runtimepath'
" WITHOUT sourcing it; the bang defers sourcing to the plugin-load step.
" editexisting: a second `vim file` jumps into the first vim's window instead
" of editing a stale copy (needs +clientserver; silently dormant without it).
silent! packadd! editexisting
" A system vimrc can suppress vim's factory defaults via g:skip_defaults_vim;
" clearing it guarantees the next line always loads them. (unlet's bang
" tolerates the variable not existing.) Maybe redundant?
unlet! skip_defaults_vim
" defaults.vim = vim's sane factory settings (syntax, filetype detection,
" incsearch, wildmenu, civilized backspace…). Vim auto-loads it ONLY when no
" vimrc exists, so source it explicitly here.
silent! source $VIMRUNTIME/defaults.vim
" The :Man plugin — powers `K` (keywordprg=:Man in section 2) to open man
" pages INSIDE vim with highlighting instead of dumping into the terminal.
silent! source $VIMRUNTIME/ftplugin/man.vim

" ============================================================================
" 2. CORE BEHAVIOR — encoding, display, search, splits
"    (assign: `:let &opt = "value"` or `:set opt=value`; inspect: `:set opt?`
"     or `:echo &opt` — two different command families, ask vs tell)
" ============================================================================
" enc = vim's INTERNAL encoding: how text lives in buffers and NEW files are
" written. utf-8 so Chinese and English coexist in one buffer.
set enc=utf-8
" Wrap long lines at WORD boundaries instead of mid-word (display-only).
set linebreak
" Here whether we need set spell firstly?
" += appends to default (en): don't flag CJK characters as misspellings.
set spelllang+=cjk
" m: wrapped CJK lines may break at any character (Chinese has no spaces);
" M: joining CJK lines with J does NOT insert a space between them.
set formatoptions+=mM
" fileencodings = the GUESS LIST for decoding EXISTING files, tried in order.
" enc vs fileencodings: enc is how vim THINKS; fileencodings is how it GUESSES.
set fileencodings=ucs-bom,utf-8,gb18030,latin1

set scrolloff=3           " keep 3 context lines above/below the cursor
set hidden                " switch buffers without saving; airline tabline needs it
set updatetime=300        " CursorHold plugins (gitgutter, YCM) react in 0.3 s not 4 s
set keywordprg=:Man       " K opens a man page inside vim
set ignorecase smartcase  " together: /foo matches Foo; /Foo matches only Foo
set number relativenumber " current line absolute, others show the distance (5j, d3k)
set splitright splitbelow " :vsplit/:split put the NEW window right/below
" defaults.vim turned on wildmenu (cmdline Tab completion); pum renders the
" candidates as a vertical popup menu like insert-mode completion.
set wildoptions+=pum

" 24-bit true color: gruvbox renders rich instead of muddy. Konsole/Wayland
" supports it; the has() guard keeps this harmless on terminals that don't.
if has('termguicolors')
  set termguicolors
endif
" tgc's blind spot (bit us 2026-08-31): it covers vim's OWN paint, not the
" ANSI palette inside :terminal. The child program (starship prompt,
" zsh-syntax-highlighting, `ls`) emits ANSI 0-15 and vim maps those through
" g:terminal_ansi_colors (terminal.txt:179). Left unset, vim's stock 16 are
" saturated VGA — '#e00000' red, '#40ff40' neon green (measured live!) — so
" :terminal glowed "way too bright" next to Konsole. These 16 ARE Konsole's
" active palette, catppuccin-mocha, lifted from
" ~/.local/share/konsole/catppuccin-mocha.colorscheme; its Intense variants
" equal the normal ones, so rows 8-15 mirror 0-7. Re-lift them if the
" Konsole scheme ever changes. Position is free: gruvbox never touches this
" variable (grep-verified 2026-08-31), and vim reads it when a terminal
" window is created.
" ACTIVE (verified by screenshot pixel-pass 2026-08-31): without this, ANSI
" 0-15 inside :terminal fall back to vim's stock VGA — the neon glow.
" terminal.txt:179 semantics: the variable is consulted when a NEW terminal
" window is created only. Re-sourcing this file with a :term already open
" repaints nothing — that reads as "doesn't work" but is just stale buffers;
" term_setansicolors() retunes an existing one.
let g:terminal_ansi_colors = ['#6c7086', '#f38ba8', '#a6e3a1', '#f9e2af',
      \ '#89b4fa', '#cba6f7', '#89dceb', '#cdd6f4',
      \ '#6c7086', '#f38ba8', '#a6e3a1', '#f9e2af',
      \ '#89b4fa', '#cba6f7', '#89dceb', '#cdd6f4']
"
" ============================================================================
" 3. FILES & HISTORY — no backup litter, but undo survives reboots
" ============================================================================
set nobackup               " never leave file.txt~ droppings next to the file
if has('persistent_undo')  " has() checks the builtin option
  set undofile             " undo history to disk: reopen tomorrow, u still works
  set undodir=~/.vim/undodir " in a private central dir, not next to files
  if !isdirectory(&undodir)
    " &option reads the builtin option's VALUE in expression context; `call` runs
    " mkdir() discarding its return; 'p' = mkdir -p; 0700 octal = rwx------.
    call mkdir(&undodir, 'p', 0700)
  endif
endif

" ============================================================================
" 4. KEY ESCAPES — disarm traps, humane exits
" ============================================================================
" Q enters Ex mode (a modal cryptic prompt almost nobody wants); disarm it in
" normal and visual mode.
nnoremap Q <Nop>
xnoremap Q <Nop>
" Inside a :terminal keys go to the SHELL, not vim; the only escape hatch vim
" intercepts is <C-\><C-N>. Double-Esc is the humane alias; i/a sends you back.
" RULE (bitten 2026-08-23): for :map commands the ENTIRE rest of the line is
" the RHS — trailing spaces or comments would be literally typed. Comments on
" map-adjacent topics belong on their own lines ABOVE the map.
tnoremap <Esc><Esc> <C-\><C-N>
" Esc in normal mode also clears search highlight.
nnoremap <silent> <Esc> :noh<CR>

" ============================================================================
" 5. FORMATTER BRIDGE — Shift-Tab pipes the buffer through an external
"    formatter and puts it back with the cursor where it was.
"
"    Two vimscript rules this design depends on:
"    · script-local functions need their `s:` prefix at every call site, and a
"      function-call statement needs `call`.
"    · a helper CANNOT `return` out of its caller — `return` exits the helper
"      only. Helpers signal with a return VALUE; the caller checks it.
" ============================================================================
" s:MissingTool(tool) → 1 (and a warning) if `tool` is not on PATH.
function! s:MissingTool(tool) abort
  if !executable(a:tool)
    " echomsg, not echo: echo never enters the message history, so this warning
    " scrolled away unread -- :messages now keeps it (:h :echomsg).
    echohl WarningMsg | echomsg a:tool . ' not found in $PATH' | echohl None
    return 1
  endif
  return 0
endfunction

" s:FilterFailed(tool) → 1 if the filter exited non-zero. On failure the
" buffer holds the tool's STDERR ('shellredir' merges stderr into filter
" output) — so undo the clobber, THEN warn. v:shell_error survives silent!.
function! s:FilterFailed(tool) abort
  if v:shell_error
    " suppress the possible stdout and stderr
    silent! undo
    " echomsg, same reason as s:MissingTool: a formatter failure MUST survive in
    " :messages, or Shift-Tab just looks like it silently did nothing.
    echohl WarningMsg | echomsg a:tool . ' failed (exit ' . v:shell_error . ')' | echohl None
    return 1
  endif
  return 0
endfunction

" :%!cmd explained: % ranges over every line, ! pipes <range> to the command's
" stdin, vim replaces the range with its stdout.
" --assume-filename exists because the formatter reads STDIN — it cannot see
" the real file, so it can't find the project's .clang-format. %:p is the FULL
" path (not %:t basename) so the search starts in the file's real directory.
function! s:ClangFormat() abort
  if s:MissingTool('clang-format') | return | endif
  let l:view = winsaveview()
  silent! execute '%!clang-format --assume-filename=' . shellescape(expand('%:p'))
  call s:FilterFailed('clang-format')
  call winrestview(l:view)
endfunction

" Range-aware variant for VISUAL mode — format only the selected lines.
" Vim auto-inserts '<,'> when you press : with a selection; the `range`
" attribute makes the function receive it as a:firstline/a:lastline.
function! s:ClangFormatRange() range abort
  if s:MissingTool('clang-format') | return | endif
  let l:view = winsaveview()
  silent! execute a:firstline . ',' . a:lastline . '!clang-format --assume-filename=' . shellescape(expand('%:p'))
  call s:FilterFailed('clang-format')
  call winrestview(l:view)
endfunction

" Python: BLACK — "the uncompromising formatter", the clang-format of Python.
" (Was ruff until 2026-08-26; ruff has NO range support, and real range
" formatting is the requirement — black --line-ranges is its exact answer.
" Head-to-head: yapf's --lines leaked blank lines OUTSIDE the selection.)
" Lives in ~/.local/venvs/pyfmt, symlinked to ~/.local/bin; section 7
" SELF-HEALS this venv if it's ever wiped.
" `black ... -` = stdin→stdout. --stdin-filename lets it discover the real
" file's pyproject.toml. --quiet silences 'reformatted -' chatter; errors
" still print, and non-zero exit (123 on unparseable input) trips the guard.
function! s:PythonFormat() abort
  if s:MissingTool('black') | return | endif
  let l:view = winsaveview()
  silent! execute '%!black --quiet --stdin-filename=' . shellescape(expand('%:p')) . ' -'
  call s:FilterFailed('black')
  call winrestview(l:view)
endfunction

" Visual variant — REAL range formatting (why black won). Measured semantics
" (2026-08-26): granularity is the STATEMENTS/BLOCKS the range touches, not
" surgical line-exact — a sibling statement in the same suite may normalize
" too; unrelated regions stay byte-identical.
" The vim filter range stays whole-file (%!) on purpose: black needs the full
" buffer on stdin to parse context and returns the whole file with only its
" hunks applied — swap-back and undo guard keep working as-is. If the painted
" range cuts mid-statement, black exits non-zero and the guard restores.
function! s:PythonFormatRange() range abort
  if s:MissingTool('black') | return | endif
  let l:view = winsaveview()
  silent! execute '%!black --quiet --stdin-filename=' . shellescape(expand('%:p'))
        \ . ' --line-ranges=' . a:firstline . '-' . a:lastline . ' -'
  call s:FilterFailed('black')
  call winrestview(l:view)
endfunction

" Assembly: clang-format doesn't speak .S; use vim's built-in `=` machinery
" (gg=G = re-indent top to bottom, driven by the AsmIndent indentexpr in
" section 12). keepjumps keeps the sweep out of the jumplist.
function! s:AsmFormat() abort
  let l:view = winsaveview()
  silent! keepjumps normal! gg=G
  call winrestview(l:view)
endfunction

function! s:AsmFormatRange() range abort
  let l:view = winsaveview()
  silent! execute a:firstline . ',' . a:lastline . 'normal! =='
  call winrestview(l:view)
endfunction

" Disabled format-on-save experiment, kept as documentation of the idiom:
" BufWritePre fires on EVERY save (proved annoying); on-demand Shift-Tab won.
"autocmd BufWritePre *.{c,cpp,h,hpp}
"      \ | let b:cf_view = winsaveview()
"      \ | silent! execute '%!clang-format --assume-filename=' . expand('%:t')
"      \ | call winrestview(b:cf_view)

" The augroup wrapper + bare `au!` makes the set idempotent: a BARE :autocmd
" APPENDS, so every `:source $MYVIMRC` would stack duplicates; au! empties the
" group first, then refills one clean set. NO trailing comments on au lines
" (rest-of-line is parsed as event arguments → E216). <buffer> scopes each map
" to buffers of that filetype, so Shift-Tab in a markdown file is untouched.
augroup shifttab_format
  au!
  au FileType c,cpp  nnoremap <buffer><silent><S-Tab> :call <SID>ClangFormat()<CR>
  au FileType c,cpp  xnoremap <buffer><silent><S-Tab> :call <SID>ClangFormatRange()<CR>
  au FileType python nnoremap <buffer><silent><S-Tab> :call <SID>PythonFormat()<CR>
  au FileType python xnoremap <buffer><silent><S-Tab> :call <SID>PythonFormatRange()<CR>
  au FileType asm    nnoremap <buffer><silent><S-Tab> :call <SID>AsmFormat()<CR>
  au FileType asm    xnoremap <buffer><silent><S-Tab> :call <SID>AsmFormatRange()<CR>
augroup END

" ============================================================================
" 6. CLIPBOARD BRIDGES — this Arch build's `+` register is PROVABLY dead
"    (W24/E354 roundtrip, 2026-08-21), so the system clipboard is reached
"    through external tools. Not a workaround — the only road on this box.
"
"    THREE backends, probed ONCE here; both directions share the pick:
"      1. native + register (clipboard-capable builds — not this one)
"      2. Wayland: wl-copy (WRITER) / wl-paste -n (READER, no appended NL)
"      3. X11:     xclip -selection clipboard         (writer)
"                  xclip -selection clipboard -o      (reader, -o = stdout)
"    Same executable() guard discipline as sections 5/7/10: probe before use.
" ============================================================================
if has('clipboard')
  " Native path — trivial; kept for when this vimrc travels to a build whose
  " + register works.
  xnoremap <silent> <F1> "+y
  nnoremap <silent> <Leader>p "+p
  xnoremap <silent> <Leader>p "+p
else
  if !empty($WAYLAND_DISPLAY) && executable('wl-copy') && executable('wl-paste')
    let s:clip_write = 'wl-copy'
    let s:clip_read  = 'wl-paste -n'
  elseif !empty($DISPLAY) && executable('xclip')
    let s:clip_write = 'xclip -selection clipboard'
    let s:clip_read  = 'xclip -selection clipboard -o'
  endif

  if exists('s:clip_write') && exists('s:clip_read')
    " <F1> in Visual = COPY the exact selection to the system clipboard.
    " The map's leading `y` yanks the selection into @" AND exits Visual mode
    " (so the : runs in normal mode). system({cmd}, {input}) pipes the text —
    " NOT `:w !cmd`, which is LINE-granular and would copy whole lines for a
    " 3-character selection (the original bug, 2026-08-21).
    function! s:CopySelection() abort
      call system(s:clip_write, @")
    endfunction
    xnoremap <silent> <F1> y:call <SID>CopySelection()<CR>

    " <Leader>p = PASTE, symmetric to F1. Notes:
    "  · a flat-bytes clipboard carries ONE type fact (trailing NL) — charwise
    "    and linewise survive the round-trip, blockwise does not.
    "  · normal mode: multi-line content is forced LINEWISE (clean new lines
    "    below the cursor) because charwise "p used to SPLICE into the cursor
    "    line; single-line stays charwise (inline after the cursor).
    "  · visual mode: replaces the selection (symmetric with F1's copy).
    "  · register s is scratch — saved+restored so "sy users are unaffected.
    " (The `range` attribute is load-bearing, not decoration: pressing : from
    "  Visual mode inserts '<,'>, and a function WITHOUT `range` would answer
    "  that with E481 'No range allowed'. CopySelection is only called from an
    "  xnoremap RHS after `y` already exited Visual, so it doesn't need it.)
    function! s:PasteClipboard(...) abort range
      let l:clip = system(s:clip_read)
      if v:shell_error || empty(l:clip)
        return
      endif
      let l:save = [getreg('s'), getregtype('s')]
      if a:0
        call setreg('s', l:clip, 'v')
        normal! gv"sp
      else
        call setreg('s', l:clip, (l:clip =~# '\n') ? 'V' : 'v')
        normal! "sp
      endif
      call setreg('s', l:save[0], l:save[1])
    endfunction
    nnoremap <silent> <Leader>p :call <SID>PasteClipboard()<CR>
    xnoremap <silent> <Leader>p :call <SID>PasteClipboard(1)<CR>
  else
    " Fourth branch: no backend at all — say so on press instead of dying
    " silently (a dead key that explains itself beats a dead key).
    nnoremap <Leader>p :echo 'no clipboard backend: install wl-clipboard or xclip'<CR>
  endif
endif

" ============================================================================
" 7. TOOLCHAIN SELF-HEAL
" ============================================================================
" 7a. The Python formatter venv is fully repairable in userspace (no sudo):
"     python -m venv + pip + symlinks into ~/.local/bin (already on PATH).
function! s:HealPyFormatters() abort
  if executable('black')
    return
  endif
  let l:venv = expand('~/.local/venvs/pyfmt')
  if !executable(l:venv . '/bin/pip')
    if !executable('python')
      return
    endif
    call system('python -m venv ' . shellescape(l:venv))
  endif
  if executable(l:venv . '/bin/pip')
    call system(l:venv . '/bin/pip install -q black')
    call mkdir(expand('~/.local/bin'), 'p')
    call system('ln -sf '
          \ . shellescape(l:venv . '/bin/black') . ' '
          \ . shellescape(expand('~/.local/bin/black')))
  endif
endfunction
call s:HealPyFormatters()

" 7b. Distro tools can't be installed without sudo, so the defensive action is
"     a single consolidated warning naming the pacman line (packages dedup'd —
"     wl-copy and wl-paste both come from wl-clipboard). Clipboard tools are
"     audited only when this build needs them (!has('clipboard'), section 6)
"     and only for the session type actually running (Wayland vs X11).
function! s:AuditTools() abort
  let l:pkg_of = {'git': 'git', 'curl': 'curl', 'rg': 'ripgrep',
        \ 'clang-format': 'clang', 'ctags': 'ctags', 'fzf': 'fzf'}
  if !has('clipboard')
    if !empty($WAYLAND_DISPLAY)
      call extend(l:pkg_of, {'wl-copy': 'wl-clipboard', 'wl-paste': 'wl-clipboard'})
    elseif !empty($DISPLAY)
      call extend(l:pkg_of, {'xclip': 'xclip'})
    endif
  endif
  let l:missing = {}
  for l:tool in keys(l:pkg_of)
    if !executable(l:tool)
      let l:missing[l:pkg_of[l:tool]] = 1
    endif
  endfor
  if !empty(l:missing)
    echohl WarningMsg
    echo '[vimrc] missing tools — fix: sudo pacman -S ' . join(sort(keys(l:missing)), ' ')
    echohl None
  endif
endfunction

augroup tool_audit
  au!
  au VimEnter * call s:AuditTools()
augroup END

" ============================================================================
" 8. SEARCH PLUMBING — :grep bolted onto ripgrep
" ============================================================================
" Search ASYNC through AsyncRun (same engine as :Make, section 11); matches
" stream into the quickfix, auto-opened by g:asyncrun_open (section 6).
" Builtin `:grep` runs grepprg in the FOREGROUND through the shell — vim
" hands the terminal to the child process and waits, so the screen flashes
" to the shell prompt and STAYS there while rg grinds a huge tree. AsyncRun
" instead job_starts rg with stdout PIPED back into vim: no terminal
" handover, and vim stays editable while the search runs.
" -program=grep builds the job as `&grepprg <args>` and parses output with
" &grepformat instead of &errorformat — the rg settings just below are
" reused unchanged. <bang> passes to AsyncRun: :Grep! stops qf auto-scroll.
" The `@` is AsyncRun's END-OF-OPTIONS placeholder (asyncrun.txt:298: "stop
" parsing options now, the following string is all my command" — like POSIX
" '--'): the option parser silently eats any LEADING -token, so `@` is what
" lets `:Grep -w needle` reach rg intact. It strips itself and expands to
" nothing (verified 2026-08-30: AsyncRun -program=grep @ -w X => "rg ... -w X").
" One job at a time (:AsyncStop kills a long search). No -complete: the
" first argument is a PATTERN, and filename completion on it would mislead
" (Tab does nothing).
"command! -nargs=+ Grep silent grep! <args> | copen | redraw!
"command! -bang -nargs=* Make AsyncRun<bang> -program=make -cwd=<root> @ <args>

command! -bang -nargs=+ Grep AsyncRun<bang> -program=grep @ <args>

if executable('rg')
  " `let &opt = expr` assigns via a string EXPRESSION — no backslash-escaping
  " of spaces (compare `set grepprg=rg\ --vimgrep\ ...` needing \ per space).
  " --vimgrep == one match per line with columns; --hidden includes dotfiles;
  " --glob excludes .git. grepformat teaches vim to PARSE each output line
  " into quickfix entries (file:line:col:message); use :copen to view them.
  let &grepprg = "rg --vimgrep --smart-case --hidden --glob '!**/.git/**'"
  let &grepformat = '%f:%l:%c:%m'
endif
" Unix's default shellpipe uses `tee`, which echoes external grep/make output
" to the terminal.  Redirect both output streams into Vim's error file so
" `:silent grep` is actually quiet while quickfix still receives the matches.
" (Re-verified 2026-08-29, 25x headless. Trade-off: a no-match search briefly
" flashes "shell returned 1" — rg's normal exit for zero hits, informative.
" :Make and :Grep are unaffected — both go through AsyncRun's job_start,
" never through shellpipe; this only guards hand-typed :grep/:make.)
if has('unix')
  let &shellpipe = '>%s 2>&1'
endif

" ============================================================================
" 9. C-FAMILY FILETYPE POLICY
" ============================================================================
" Detection of extension-less C++ stdlib headers lives in
" ~/.vim/ftdetect/cpp.vim — the ONLY location the filetype off→on cycle
" re-sources (filetype.vim ends with `runtime! ftdetect/*.vim`).

" Tuning knobs for vim's built-in C SYNTAX HIGHLIGHTER (ft=c):
let g:c_gnu = 1            " treat GNU extensions (__attribute__ etc.) as valid
let g:c_no_cformat = 1     " don't special-highlight %escapes in format strings
let g:c_no_curly_error = 1 " tolerate {} brace oddities (system headers need this)
let g:c_space_errors = 1   " DO flag trailing whitespace / space-before-tab
unlet! g:c_comment_strings


" ============================================================================
" 10. PLUGIN MANIFEST — vim-plug: bootstrap once, then SELF-MAINTAIN weekly.
" ============================================================================
" ~/.vim for vim, stdpath('data')/site for neovim — the same vimrc serves both.
let data_dir = has('nvim') ? stdpath('data') . '/site' : expand('~/.vim')
if !filereadable(data_dir . '/autoload/plug.vim')
  if executable('curl')
    silent execute '!curl -fLo '
          \ . ' '
          \ . shellescape(data_dir . '/autoload/plug.vim')
          \ . ' --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  else
    echohl WarningMsg
    echo 'vim-plug missing and curl not on PATH — plugins will not load'
    echohl None
  endif
  if filereadable(data_dir . '/autoload/plug.vim') && executable('git')
    augroup plug_bootstrap
      au!
      autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
    augroup END
  endif
  if !filereadable(data_dir . '/autoload/plug.vim')
    echohl WarningMsg
    echo 'vim-plug missing'
    echohl None
  endif
  if !executable('git')
    echohl WarningMsg
    echo 'git not on PATH — plugins will not load'
    echohl None
  endif
endif

function! s:MaybePlugUpdate() abort
  if !executable('git') || exists(':PlugUpdate') != 2
    return
  endif
  let l:stamp = expand('~/.vim/.plug_update_stamp')
  if getftime(l:stamp) > localtime() - 7 * 24 * 3600
    return
  endif
  call writefile([strftime('%F %T')], l:stamp)
  PlugUpdate
endfunction
augroup plug_maintenance
  au!
  au VimEnter * call timer_start(3000, {-> s:MaybePlugUpdate()})
augroup END

call plug#begin()
Plug 'airblade/vim-gitgutter'       " +/-/~ diff signs in the gutter (updatetime=300 keeps it snappy)
Plug 'alvan/vim-closetag'           " auto-close HTML-ish tags on '>' (filetype list below)
Plug 'google/vim-searchindex'       " shows 'match 3 of 27' while /-searching
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']} " live browser preview of .md; lazy-loads
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " the fuzzy-finder binary + vim glue
Plug 'junegunn/fzf.vim'             " the commands: :Files :Buffers :RG :BLines :History
Plug 'mg979/vim-visual-multi'       " multiple cursors (<C-n> adds next match)
Plug 'mattn/calendar-vim'           " calendar panel (F7)
Plug 'mattn/emmet-vim'              " HTML/CSS abbreviation expander (<C-y> prefix)
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
Plug 'morhetz/gruvbox'              " colorscheme (applied post-plugin-load below)
Plug 'pangloss/vim-javascript'      " better JS syntax/indent (CS50W)
Plug 'preservim/nerdtree'           " file drawer (F1)
Plug 'preservim/tagbar'             " symbol outline via ctags (F3)
Plug 'skywind3000/asyncrun.vim'     " run make/tests async into quickfix (F5)
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-commentary'         " gcc comments a line, gc{motion} a range — tiny,
                                    "   uses each filetype's 'commentstring'. Replaced
                                    "   heavyweight nerdcommenter (2026-08-23); bonus:
                                    "   the whole <Leader>c* prefix is free again.
Plug 'tpope/vim-eunuch'             " shell sugar: :Rename :Delete :Chmod :SudoWrite …
Plug 'tpope/vim-fugitive'           " git porcelain inside vim (:Git blame alone justifies it)
Plug 'tpope/vim-repeat'             " makes surround/commentary/etc. repeatable with `.`
Plug 'tpope/vim-surround'           " cs\"' changes quotes, ysiw) wraps a word, ds( deletes
Plug 'ycm-core/YouCompleteMe', { 'do': './install.py --clangd-completer' } " LSP completion/goto via clangd
Plug 'vim-airline/vim-airline'      " statusline + buffer tabline (theme ships in morhetz/gruvbox)
call plug#end()
" Dropped 2026-08-23: preservim/nerdcommenter (→ vim-commentary) and
" yegappan/mru (→ fzf :History needs no state file; F2 opens :History).
" mru's leftover DB ~/.vim/.mru_files is orphaned junk — safe to delete.

let g:asyncrun_open = 10            " auto-open a 10-line quickfix when an async job starts
" tagbar_sort defaults to 1 = ALPHABETICAL; 0 orders by position in source, so
" the F3 panel reads top-to-bottom like the code.
let g:tagbar_sort = 0
let g:tagbar_autofocus = 1          " cursor jumps into the F3 panel when it opens
let g:airline_powerline_fonts = 1
let g:airline_theme = 'gruvbox'
let g:airline#extensions#tabline#enabled = 1        " top bar listing open buffers
let g:airline#extensions#tabline#show_tab_nr = 0    " hide TAB-PAGE numbers (buffers, not tabs)
"let g:airline#extensions#tabline#buffer_nr_show = 1 " OFF — reason below
" Off since 2026-08-30: with idx_mode on it prints TWO numbers per entry
" ("³ 4: t.c" = index 3 + bufnr 4), and bufnrs go GAPPY (fzf/quickfix scratch
" buffers burn IDs forever). <Leader>N jumps by INDEX, never bufnr — idx-only
" is WYSIWYG: the number you see is the number you press.
let g:airline#extensions#tabline#buffer_idx_mode = 1 " number = bar INDEX (1-10): <Leader>N jumps (§11)
" (2026-09-01) undotree's SECOND buffer — the diff panel, "diffpanel_N" — was
" what poisoned this bar: ":new" creates it LISTED, BufAdd drops airline's
" buflist cache (autoshow.vim:39), and the rebuild that follows captures it in
" the milliseconds before "setlocal nobuflisted" lands (undotree.vim
" s:diffpanel.Show). Once captured it sits in THREE render-time snapshots at
" once — the drawn tabline, the <Plug>AirlineSelectTab jump table
" (s:current_visible_buffers), and the mouse-click regions — and all three
" stay STALE after F6 closes the panel. The buffer lingers as an unlisted
" zombie (bufhidden=delete deletes from the list, doesn't wipe), so jumping
" into it (<Leader>2 or a click; &mouse is 'nvi' here, clicks reach vim) fires
" its buffer-local BufEnter exitIfLast(), which :quits the last window — the
" WHOLE SESSION EXITS (repro'd live in a pty 2026-09-01, vim exit 0). The
" upstream default pattern filters "undotree" but not "diffpanel"; setting the
" var REPLACES the default wholesale (airline get()s var-or-default, never
" merges), so every upstream entry is restated and diffpanel appended.
let g:airline#extensions#tabline#ignore_bufadd_pat =
      \ '!|defx|gundo|nerd_tree|startify|tagbar|term://|undotree|vimfiler|diffpanel'
" --- Web (HTML/CSS/SCSS/JS) plugin tuning, added for CS50W ---
" closetag auto-closes on '>' for these types. Plain *.js/*.ts are NOT JSX
" (auto-closing a comparison's '>' there would be wrong); only jsx/tsx count.
let g:closetag_filenames = '*.html,*.htm,*.xhtml,*.phtml,*.xml,*.svg,*.vue,*.jsx,*.tsx'

" tags search: (1) './tags;' — 'tags' in the current FILE's dir, then walk UP
" parent dirs until one is found (the ';' is the magic); (2) 'tags' — the same
" file name relative to Vim's working directory (:pwd).
" Build one with: ctags --fields=+iaS --extras=+q -R .
set tags=./tags;,tags
" :RR newname = rename symbol under cursor via clangd (poor-man's LSP rename).
command! -nargs=1 RR YcmCompleter RefactorRename <args>
" Feed fzf with rg: hidden files, no .git internals, most-recently-modified
" first — so :Files floats your working files to the top.
let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --glob=''!**/.git/**'' --sortr=modified'
" gruvbox ships as a PLUGIN, so it doesn't exist until plug#end; apply on
" VimEnter. ++nested lets FileType/syntax autocmds on the startup buffer run.
augroup colorscheme_setup
  au!
  au VimEnter * ++nested colorscheme gruvbox
augroup END

" ============================================================================
" 11. KEY MAPPING DASHBOARD — F-keys open tools; q closes transient panels
" ============================================================================
" :Make[!] = -program=make through AsyncRun  (<bang> to AsyncRun stops auto-scroll).
" -cwd=<root>: asyncrun walks UP from the current file to the nearest project
" marker (.git/.hg/.svn/.project/.root) and runs make THERE — same walk-up idea
" as the 'tags' './tags;', but marker-driven. No marker up-tree = the file's
" own directory; for non-git projects, `touch .root` at the project top.
" asyncrun chdirs vim there while the job runs and restores after.
" No -complete: arguments are make TARGETS, not filenames.
command! -bang -nargs=* Make AsyncRun<bang> -program=make -cwd=<root> @ <args>

" Return the current tab's quickfix/location-list window, or 0.
function! s:PanelWin(type) abort
  for l:info in getwininfo()
    if l:info.tabnr == tabpagenr() && win_gettype(l:info.winid) ==# a:type
      return l:info.winid
    endif
  endfor
  return 0
endfunction

" F4: toggle YCM diagnostics. Opening focuses the location list; closing
" returns to the source window.
function! s:ToggleYcmDiags() abort
  if win_gettype() ==# 'loclist'
    lclose
    return
  endif

  " Close this source window's existing list, if any; otherwise open YCM's.
  " getloclist({nr} [, {what}]) — :h getloclist(), nr == 0 for current window
  " get({dict}, {key} [, {default}]) — :h get(), extracts key from {key:value}
  " :lclose acts on the current window's displayed list — no jumping needed.
  if get(getloclist(win_getid(), {'winid': 0}), 'winid', 0) > 0
    lclose
    return
  endif
  YcmDiags
endfunction

function! s:FocusPanel(type) abort
  let l:winid = s:PanelWin(a:type)
  return l:winid > 0 && win_gotoid(l:winid)
endfunction

" F5: build toggle. While a build runs, F5 stops it. When the quickfix panel
" is open, F5 closes it without focus falling in (F4-style). Otherwise: save,
" build, focus the panel. q also closes it from inside.
function! s:ToggleBuild() abort
  " Standing IN the quickfix window? Second press closes it.
  if win_gettype() ==# 'quickfix'
    cclose
    return
  endif

  " Build running? F5 stops it (panel stays for inspection).
  if get(g:, 'asyncrun_status', '') ==# 'running'   " ==#  strict sensitive match
    AsyncStop
    return
  endif

  " Panel already showing build output? :cclose is tab-global — close from here.
  if get(getqflist({'winid': 0}), 'winid', 0) > 0
    cclose
    return
  endif

  if &l:buftype ==# '' && &l:modifiable && !&l:readonly && &l:modified
    if bufname('%') ==# ''
      echohl WarningMsg
      echomsg 'Build: unnamed modified buffer was not saved'
      echohl None
    else
      update
    endif
  endif
  Make
  call s:FocusPanel('quickfix')
endfunction

" F8 target: markdown live preview, then FOCUS THE BROWSER (2026-08-31).
" markdown-preview is LAZY ('for': markdown), so :MarkdownPreview doesn't
" exist until an .md buffer loads the plugin — a bare map would throw E492
" everywhere else. Guard and say so instead (a dead key that explains
" itself beats a dead key).
" MarkdownPreview, not Toggle: start-or-reopen for THIS buffer, never kill —
" F8's contract is "show me the preview". open_preview_page() is idempotent
" (server down → start it; up → just reopen the page; mkdp/util.vim:36), and
" the preview still ends itself on buffer switch / VimLeave, so an explicit
" stop is :MarkdownPreviewStop's job, typed by hand.
function! s:MarkdownPreview() abort
  if exists(':MarkdownPreview') != 2
    " echomsg, not echo: echo is wiped by the next redraw, echomsg lands in
    " :messages — the reason must be recoverable, see :h echo vs :h echomsg
    echohl WarningMsg
    echomsg printf("F8: markdown-preview not loaded — needs a markdown buffer, this one's filetype is '%s' (open a .md file, or :setf markdown)", empty(&ft) ? 'none' : &ft)
    echohl None
    return
  endif
  MarkdownPreview
  " The browser tab opens from the plugin's node server asynchronously (up to
  " ~1 s on a cold start), so raising the browser must not fire instantly: a
  " one-shot 400 ms timer gives the tab a beat to appear, THEN pulls focus.
  call timer_start(400, {-> s:FocusBrowser()})
endfunction

" Why F8 needs this at all: the plugin shells out to xdg-open, and KWin's
" focus-stealing prevention refuses to let a background process yank focus —
" so the tab opens BEHIND vim and focus never moves (the original complaint).
" Why KWin scripting and not wmctrl: on Wayland clients are isolated BY
" DESIGN — only the compositor may move focus, and KWin exposes that only
" through its scripting channel (no wmctrl-style grabber exists without
" kdotool from the AUR). qdbus6 ships with Plasma. Verified live 2026-08-31
" on Plasma 6.7: windowList()/activeWindow are the KWin 6 API (clientList is
" gone); loadScript→start→unloadScript runs a one-shot cleanly, and
" unloading a RUNNING script returns true with isScriptLoaded false after —
" so this never calls stop(), which would halt unrelated user scripts too.
" Firefox matches window class/name 'firefox' (verified live; Chromium's
" class would be 'chromium' if the default browser ever changes).
" Degrade, never die (sections 5/7 discipline): no qdbus6 → warn per press,
" the preview itself still opens.
function! s:FocusBrowser() abort
  if !executable('qdbus6')
    echohl WarningMsg
    echomsg 'F8: preview opened, but focus cannot move — qdbus6 missing (pacman -S qt6-tools)'
    echohl None
    return
  endif
  " getpid() keys the file so two vim instances never clobber each other's
  " script; /tmp is tmpfs, so the 9-line file costs nothing across reboots.
  let l:js = '/tmp/kwin-focus-browser-' . getpid() . '.js'
  call writefile([
        \ 'const wins = workspace.windowList();',
        \ 'for (let i = 0; i < wins.length; i++) {',
        \ '  const cls = "" + wins[i].resourceClass;',
        \ '  const nm  = "" + wins[i].resourceName;',
        \ '  if (cls.indexOf("firefox") !== -1 || nm.indexOf("firefox") !== -1) {',
        \ '    workspace.activeWindow = wins[i];',
        \ '    break;',
        \ '  }',
        \ '}',
        \ ], l:js)
  " The verified one-shot cycle; 2>/dev/null muzzles qdbus stderr so a dead
  " session (SSH with no KWin) can't flash a message mid-screen.
  call system('qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript '
        \ . shellescape(l:js) . ' vimrcFocusBrowser 2>/dev/null')
  call system('qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start 2>/dev/null')
  call system('qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript vimrcFocusBrowser 2>/dev/null')
endfunction

" file drawer
nnoremap <silent><F1> :NERDTreeToggle<CR>
" recent files via fzf
nnoremap <silent><F2> :History<CR>
" symbol outline
nnoremap <silent><F3> :TagbarToggle<CR>
" diagnostics (location list) — toggle; focus lands in the list
nnoremap <silent><F4> :call <SID>ToggleYcmDiags()<CR>
" make / stop / toggle panel — q also closes it from inside
nnoremap <silent><F5> :call <SID>ToggleBuild()<CR>
nnoremap <silent><F6> :UndotreeToggle<CR>
" calendar
nnoremap <silent><F7> :CalendarH<CR>
" .md live preview + focus the browser (guarded — the plugin lazy-loads, see s:MarkdownPreview)
nnoremap <silent><F8> :call <SID>MarkdownPreview()<CR>
" fzf: open buffers
nnoremap <silent><Leader>b :Buffers<CR>
" fzf: files by name
nnoremap <silent><Leader>f :Files<CR>
" fzf: files by CONTENT
nnoremap <silent><Leader>g :RG<CR>
" fzf: lines in THIS buffer
nnoremap <silent><Leader>/ :BLines<CR>

" airline buffer index: <Leader>N jumps to the Nth buffer in the top bar
" (0 = the 10th; - and + = prev/next; counts work on both: 3<Leader>+ = 3 on).
" airline only exposes <Plug> handles — WE bind them. One loop replaces ten
" near-identical lines (the same for+execute trick airline itself uses to
" define the plugs, buffers.vim s:map_keys). nmap per the plugins' documented
" recipe (Vim 9.2 expands a <Plug> RHS even through nnoremap — deep-dive §11).
" s:i is script-local — a bare `i` at vimrc top level would be a GLOBAL that
" survives sourcing.
for s:i in range(10)
  execute 'nmap <Leader>' . s:i . ' <Plug>AirlineSelectTab' . s:i
endfor
nmap <Leader>- <Plug>AirlineSelectPrevTab
nmap <Leader>+ <Plug>AirlineSelectNextTab

nnoremap <Leader>ji :YcmCompleter FixIt<CR>
nnoremap <Leader>jt :YcmCompleter GoTo<CR>
nnoremap <Leader>jd :YcmCompleter GoToDefinition<CR>
nnoremap <Leader>jh :YcmCompleter GoToDeclaration<CR>
nnoremap <Leader>jr :YcmCompleter GoToReferences<CR>

" deliberate exception: a <Plug> target needs recursive nmap (like <Leader>N above).
nmap <Leader>K <Plug>(YCMHover)

let g:ycm_auto_hover = ''                                  " no unsolicited popups; <Leader>K on demand
let g:ycm_autoclose_preview_window_after_insertion = 1     " close scratch preview after completing
let g:ycm_clangd_binary_path = '/usr/bin/clangd'           " distro clangd, not YCM's bundled one
let g:ycm_clangd_args = ['--header-insertion=iwyu', '--background-index', '-j=4'] " iwyu includes; background index = instant goto
let g:ycm_complete_in_comments = 1                         " a REAL enable (default 0)
let g:ycm_goto_buffer_command = 'split-or-existing-window' " goto REUSES a window showing the target
let g:ycm_key_invoke_completion = '<C-Z>'                  " manual trigger — never pops uninvited

" ============================================================================
" 12. INDENT POLICY — per-language whitespace law
"     expandtab = Tab inserts spaces
"     tabstop = visual width of a REAL tab byte
"     shiftwidth = what >>, << or = and auto-indent use
"     softtabstop = Tab/Backspace behavior while typing
"     Keep softtabstop == shiftwidth.
" ============================================================================
" GNU C indent shape for browsing glibc (15 knobs; :h cinoptions-values).
function! s:GnuIndent() abort
  setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=8
  setlocal cinoptions=>4,n-2,{2,^-2,:2,=2,g0,h2,p5,t0,+2,(0,u0,w1,m1
endfunction

" Why SEPARATE from a formatting orchestrator rather than merged: two CONTRACTS.
function! s:AsmIndent() abort
  if getline(v:lnum) =~# '^\s*\.\?\k\+:'
    return 0
  endif

  let l:prev_lnum = prevnonblank(v:lnum - 1)
  if l:prev_lnum == 0
    return 0
  endif
  let l:prev_line = getline(l:prev_lnum)
  if l:prev_line =~# '^\s*\.\?\k\+:'
    return &shiftwidth
  endif

  return indent(l:prev_lnum)
endfunction

" Close whichever transient list owns the current window.
function! s:CloseTransientList() abort
  if win_gettype() ==# 'loclist'
    lclose
  else
    cclose
  endif
endfunction

augroup ft_config
  " au! cancels/empties the group first so re-sourcing refills one clean set.
  " NO trailing comments on autocmd lines like map lines (rest-of-line = event args, E216).
  au!
  " glibc-style indent when browsing system headers (see s:GnuIndent above).
  au BufRead /usr/include/*            call s:GnuIndent()
  au FileType html,css,scss,javascript setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2
  au FileType c,cpp,objc setlocal expandtab shiftwidth=4 softtabstop=4 tabstop=4 cinoptions=:0,g0,(0,w1
  " textwidth=0 beats $VIMRUNTIME/ftplugin/vim.vim, which sets tw=78 (auto-wrap
  " comments at col 78) if &tw==0 at ftplugin time -- see :h ft-vim-plugin.
  au FileType sh,vim     setlocal expandtab shiftwidth=2 softtabstop=2 textwidth=0
  au FileType json       setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2
  " Here, we can see if we wanna get the functio return value, we shouldn't add call to the function invocation
  au FileType asm        setlocal noexpandtab shiftwidth=4 softtabstop=4 tabstop=4 indentexpr=s:AsmIndent()
  " q == close, for the transient panel buffers (help / man / quickfix)
  au FileType help       nnoremap <buffer><silent> q <C-W>c
  au FileType man        nnoremap <buffer><silent> q :quit<CR>
  au FileType qf         nnoremap <buffer><silent> q :call <SID>CloseTransientList()<CR>
augroup END
