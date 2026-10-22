" ============================================================================
" .vimrc — Claude's synthesis, v2 (2026-09-01)
"
" v1 was built from the 2026-08-31 three-pass review of the repo rewrite
" (analysis: ../vimrc-analysis-2026-08-31.md). v2 folds in what came after:
"  · THIRD-PASS lessons — Bug 10 (legacy VimL has no `else if`; E488 on every
"    call) is now a documented style rule AND a regression check in
"    smoke-test.vim.
"  · Ken's revealed preferences (from his own 23:30 hand-fix of the repo
"    copy): global spell stays ON, `set enc=utf-8` stays (explicit beats
"    derived when a file travels), the GUI block stays for gvim travel, the
"    systags slot stays, and extension-less header detection is kept INLINE
"    (placed where probing proves it alive: after plug#end) — with the
"    ftdetect/ copy still beside this file for the plug-less world.
"  · v1 rough edges: formatter/tool warnings now use echomsg (a redraw would
"    erase a bare echo — the header's own rule now applies everywhere).
"
" Style rules this file obeys — each earned by a probe, not read from docs:
"  · NO trailing text on :map / :autocmd / :command / :execute lines — the
"    rest of the line is the RHS / event args / replacement text (a trailing
"    `"` after :map becomes literal keys; after :command it joins the
"    replacement). Comments live on their own lines above. (After :set, :if,
"    :source, :packadd trailing `"` comments ARE stripped — probed — but the
"    one uniform rule is easier to trust at a glance.)
"  · Every augroup opens with au! — a BARE :autocmd APPENDS, so re-sourcing
"    would otherwise stack duplicates (probed with colorscheme 08-31).
"  · Every helper is s:-script-local, defined before its first call site —
"    the rewrite's F5 broke exactly there (call to a deleted helper, E117).
"  · NO `else if` — legacy VimL chains with `:elseif`. `:else` takes no
"    expression, and Vim PARSES even a skipped `:else` line while scanning
"    for the matching `:endif`, so the stray form throws E488 on EVERY call,
"    winning branch or not (probed 2026-08-31: both arities errored).
"  · Warnings use echomsg (recoverable via :messages), never bare echo that
"    a redraw erases.
" ============================================================================

" ============================================================================
" 1. RUNTIME BOOTSTRAP — vim's built-in extras BEFORE my rules, so the
"    sections below override factory settings instead of losing to them.
" ============================================================================
" Explicit beats derived when a file travels: enc IS utf-8 for free under
" LANG=en_US.UTF-8 (probed: even with -u NONE), but a LANG=C box would
" derive latin1. 'encoding' is startup-only and must precede anything that
" might load text — hence the very first option in the file. Never move it
" below the source lines, never change it later.
set enc=utf-8
" packadd! = put an optional package on 'runtimepath' WITHOUT sourcing it
" yet (the bang defers that to the plugin-load step; :h packadd).
" editexisting: a second `vim file` hops into the FIRST vim's window instead
" of silently editing a second copy. Needs +clientserver (this build has it)
" AND a server name — automatic in gvim, or `vim --servername VIM` in a
" terminal; without one the pack is harmlessly dormant.
silent! packadd! editexisting
" defaults.vim = vim's sane factory layer (incsearch, mouse=a, scrolloff=5,
" ttimeout, `filetype plugin indent on`, `syntax on`). Vim auto-loads it ONLY
" when NO vimrc exists, so source it explicitly.
" Vim 9.2 note (probed on THIS build 2026-08-30): the binary itself now
" defaults backspace/wildmenu/history/undolevels/showcmd/ruler ON — which is
" why this file sets none of those.
silent! source $VIMRUNTIME/defaults.vim
" The :Man plugin — powers `K` (keywordprg below) to open man pages INSIDE
" vim with highlighting. Pairs with keywordprg in section 2.
silent! source $VIMRUNTIME/ftplugin/man.vim
" NOTE — no `unlet! skip_defaults_vim` here: that flag only gates vim's
" AUTOMATIC defaults.vim load, which cannot happen once a vimrc exists, and
" Arch's /etc/vimrc ships its gate commented out anyway. Pure ritual.

" ============================================================================
" 2. CORE BEHAVIOR
" ============================================================================
" Vim 9.2 facts this section leans on (probed on this build):
"  · autoindent and hlsearch are still OFF out of the box — set below.
set autoindent              " Enter copies the previous indent in files with
                            " no indent engine (md/text); cindent/indentexpr
                            " override it in code files
set hlsearch                " keep search matches lit; <Esc> clears (section 5)
set linebreak breakindent   " display-only: fold long lines at word edges and
                            " keep the wrapped part indented — textwidth is
                            " the option that inserts REAL newlines
set ignorecase smartcase    " /foo matches Foo; /Foo matches only Foo
set number relativenumber   " hybrid numbering: 5j / d3k arithmetic on sight
set splitright splitbelow   " new windows open right / below, not left / above
set scrolloff=3             " keep 3 context lines around the cursor
set sidescrolloff=5         " the horizontal sibling of scrolloff (taste)
set updatetime=300          " CursorHold pace: gitgutter + YCM react in 0.3 s
set hidden                  " switch buffers without saving; airline's buffer
                            " tabline depends on this
set autoread                " notice files changed outside vim (checked when
                            " vim regains focus)
set keywordprg=:Man         " K -> :Man (needs man.vim sourced above — a pack)
" cmdline completion: pum renders candidates as a floating popup; fuzzy
" sorts :command/:help/:colorscheme/buffer-name completion by best match
" (it NEVER applies to file/dir completion — probed, options.txt).
" wildmode is the Tab choreography: first press fills the longest common
" prefix AND shows the menu (`longest:full` does not cycle on repeat — that
" is why the second part exists: further presses cycle full matches).
set wildoptions+=fuzzy,pum
set wildmode=longest:full,full
" Bouncer list for vim's OWN file completion (:e, :find…). fzf/rg/YCM never
" consult it. A bare `__pycache__` hides only the directory ENTRY — its
" contents still match — hence the */__pycache__/* twin (probed 2026-08-31).
set wildignore=*.o,*.a,*.so,*.d,*.min.*,*.pyc,__pycache__,*/__pycache__/*
" formatoptions is buffer-local and ftplugins may reset it, so the CJK pair
" (m: CJK lines may break anywhere; M: J joins CJK without a space) is also
" re-asserted per FileType in section 14 — immunized against resets.
set formatoptions+=mM
" Spell: switch AND payload both global (Ken's call, kept from his repo
" rewrite — he writes prose in CJK+EN across many buffer types, so checking
" everywhere is a feature, not noise). spell is WINDOW-local, so <Leader>S
" toggles it per window for one-off relief without touching the default.
" (v1 shipped prose-only; flip-back recipe in EXPLAIN.md.)
" The guard matters: += on spelllang is a DUMB textual append — an unguarded
" re-source yields en,cjk,cjk (probed 2026-09-01 by this file's own harness).
set spell
if &spelllang !~# '\ccjk'
  set spelllang+=cjk
endif
nnoremap <silent> <Leader>S :setlocal spell!<CR>
" fileencodings = the decode GUESS LIST for existing files, tried in order:
" ucs-bom first (unambiguous), gb18030 before latin1, latin1 last because it
" decodes ANY byte sequence and would otherwise hide the others.
set fileencodings=ucs-bom,utf-8,gb18030,latin1
set nobackup                " no file.txt~ droppings; 'writebackup' (still on)
                            " keeps the write itself atomic: temp copy during
                            " :write, removed on success

" gvim travel block — dead on this terminal host (has('gui_running') is
" false), kept because Ken's version keeps it and it costs nothing. Both
" variable names verified against the runtime source: menu.vim:1220 reads
" do_syntax_sel_menu; menu.vim:399 reads do_no_lazyload_menuS (plural — a
" singular spelling once shipped here as a silent no-op).
if has('gui_running')
  "set guifont=
  "set guifontwide=
  let g:do_syntax_sel_menu = 1
  let g:do_no_lazyload_menus = 1
endif

" ============================================================================
" 3. TERMINAL COLOR FIDELITY — two layers, both needed
" ============================================================================
" Layer 1: termguicolors makes vim paint with 24-bit colors — gruvbox
" renders rich instead of muddy 256-color approximations.
if has('termguicolors')
  set termguicolors
endif
" Layer 2 — tgc's blind spot (bit us 2026-08-31): it covers vim's OWN paint,
" not the ANSI 0-15 that child programs emit inside :terminal. Left unset,
" vim maps those through its stock VGA palette ('#e00000' red, neon green),
" so :terminal glowed next to Konsole. These 16 ARE Konsole's active
" catppuccin-mocha palette (rows 8-15 mirror 0-7: Intense == normal there).
" Re-lift from ~/.local/share/konsole/*.colorscheme if the scheme changes.
" terminal.txt:179 semantics: consulted when a NEW terminal window is
" created only — re-sourcing repaints nothing; term_setansicolors() retunes
" an existing one. gruvbox never touches this variable (grep-verified).
let g:terminal_ansi_colors = ['#6c7086', '#f38ba8', '#a6e3a1', '#f9e2af',
      \ '#89b4fa', '#cba6f7', '#89dceb', '#cdd6f4',
      \ '#6c7086', '#f38ba8', '#a6e3a1', '#f9e2af',
      \ '#89b4fa', '#cba6f7', '#89dceb', '#cdd6f4']

" ============================================================================
" 4. FILES & HISTORY — no backup litter, undo survives reboots
" ============================================================================
if has('persistent_undo')    " +persistent_undo on this build
  set undofile               " undo history to disk: reopen tomorrow, u works
  set undodir=~/.vim/undodir " ~ IS expanded at set time (probed 2026-08-31)
  if !isdirectory(&undodir)
    call mkdir(&undodir, 'p', 0700)  " 'p' = mkdir -p; 0700 = rwx------ (octal)
  endif
endif

" ============================================================================
" 5. KEY ESCAPES — disarm traps, humane exits
" ============================================================================
" Q would drop into Ex mode (a cryptic modal prompt nobody wants);
" defaults.vim remaps it to gq — we disarm it fully instead. gq stays
" available directly.
nnoremap Q <Nop>
xnoremap Q <Nop>
" Inside :terminal, keys go to the CHILD, not vim; the only escape vim
" intercepts is <C-\><C-N>. Double-Esc is the humane alias; i / a go back in.
tnoremap <Esc><Esc> <C-\><C-N>
" Esc in normal mode clears search highlight — a real job now that hlsearch
" is on (section 2).
nnoremap <silent> <Esc> :noh<CR>

" ============================================================================
" 6. FORMATTER BRIDGE — Shift-Tab pipes the buffer (or selection) through an
"    external formatter and puts it back with the cursor where it was.
"    Three invariants this design depends on (learned 2026-08-26..31):
"     · a helper CANNOT `return` out of its caller — helpers signal with a
"       return VALUE and the caller checks it;
"     · a failed filter REPLACES the buffer with the tool's stderr (shellredir
"       merges streams) — a formatter failure is a data-destroying event,
"       so undo the clobber FIRST, then warn. v:shell_error survives silent!;
"     · the warning must be echomsg — a redraw erases a bare echo.
" ============================================================================
" s:MissingTool(tool) -> 1 (and a warning) if `tool` is not on PATH.
function! s:MissingTool(tool) abort
  if !executable(a:tool)
    echohl WarningMsg
    echomsg a:tool . ' not found in $PATH — buffer left untouched'
    echohl None
    return 1
  endif
  return 0
endfunction

" s:FilterFailed(tool) -> 1 if the filter exited non-zero; restore first.
function! s:FilterFailed(tool) abort
  if v:shell_error
    silent! undo
    echohl WarningMsg
    echomsg a:tool . ' failed (exit ' . v:shell_error . ') — buffer restored'
    echohl None
    return 1
  endif
  return 0
endfunction

" :%!cmd — % = every line, ! pipes them through cmd's stdin, the range
" becomes cmd's stdout. --assume-filename: the formatter reads STDIN so it
" cannot see the file — %:p (full path, not %:t) points it at the project's
" .clang-format.
function! s:ClangFormat() abort
  if s:MissingTool('clang-format') | return | endif
  let l:view = winsaveview()
  silent! execute '%!clang-format --assume-filename=' . shellescape(expand('%:p'))
  call s:FilterFailed('clang-format')
  call winrestview(l:view)
endfunction

" Range variant for VISUAL mode: pressing : with a selection inserts '<,'>;
" the `range` attribute receives it as a:firstline / a:lastline.
function! s:ClangFormatRange() range abort
  if s:MissingTool('clang-format') | return | endif
  let l:view = winsaveview()
  silent! execute a:firstline . ',' . a:lastline . '!clang-format --assume-filename=' . shellescape(expand('%:p'))
  call s:FilterFailed('clang-format')
  call winrestview(l:view)
endfunction

" Python: black — "the uncompromising formatter". Chosen over ruff for REAL
" range support (--line-ranges, 2026-08-26); lives in ~/.local/venvs/pyfmt,
" self-healed by section 8 if wiped. `black … -` = stdin->stdout;
" --stdin-filename lets it find pyproject.toml; --quiet stops the chatter
" (errors still print; exit 123 on unparseable input trips the guard).
function! s:PythonFormat() abort
  if s:MissingTool('black') | return | endif
  let l:view = winsaveview()
  silent! execute '%!black --quiet --stdin-filename=' . shellescape(expand('%:p')) . ' -'
  call s:FilterFailed('black')
  call winrestview(l:view)
endfunction

" Range granularity is the STATEMENTS the range touches, not surgical lines
" (measured 2026-08-26); whole-file stdin on purpose — black needs full
" context and returns the whole file with only its hunks applied.
function! s:PythonFormatRange() range abort
  if s:MissingTool('black') | return | endif
  let l:view = winsaveview()
  silent! execute '%!black --quiet --stdin-filename=' . shellescape(expand('%:p'))
        \ . ' --line-ranges=' . a:firstline . '-' . a:lastline . ' -'
  call s:FilterFailed('black')
  call winrestview(l:view)
endfunction

" Assembly: clang-format doesn't speak .S; use vim's built-in `=` machinery
" (driven by s:AsmIndent, section 14). keepjumps keeps the sweep out of the
" jumplist.
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

" The augroup + au! makes the set idempotent. <buffer> scopes each map to
" that filetype's buffers only. Patterns are COMMA-separated regexes — `c.cpp`
" would be ONE regex matching a filetype spelled cXcpp and never fire
" (probed 2026-08-31: c.cpp fired 0, c,cpp fired 1).
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
" 7. CLIPBOARD BRIDGES — this Arch build's `+` register is PROVABLY dead
"    (W24/E354 roundtrip, 2026-08-21; -clipboard in :version), so the system
"    clipboard is reached through external tools. Three backends, probed
"    once; both directions share the pick:
"      1. native + register (clipboard-capable builds — not this one)
"      2. Wayland: wl-copy (writer) / wl-paste -n (reader, no trailing NL)
"      3. X11: xclip -selection clipboard (-o for stdout)
"    Key convention: <Leader>y / <Leader>p for both directions, both modes —
"    symmetric, and identical across backends.
" ============================================================================
if has('clipboard')
  nnoremap <silent> <Leader>y "+y
  xnoremap <silent> <Leader>y "+y
  nnoremap <silent> <Leader>p "+p
  xnoremap <silent> <Leader>p "+p
else
  " executable() gates the pick too, not just the env var — a half-installed
  " box (WAYLAND_DISPLAY set, wl-copy gone) must not install dead maps.
  if !empty($WAYLAND_DISPLAY) && executable('wl-copy') && executable('wl-paste')
    let s:clip_write = 'wl-copy'
    let s:clip_read  = 'wl-paste -n'
  elseif !empty($DISPLAY) && executable('xclip')
    let s:clip_write = 'xclip -selection clipboard'
    let s:clip_read  = 'xclip -selection clipboard -o'
  endif

  if exists('s:clip_write') && exists('s:clip_read')
    " Visual COPY: the leading `y` yanks into @" AND exits Visual mode (so
    " the : runs in normal mode). system({cmd},{input}) pipes the EXACT
    " bytes — NOT `:w !cmd`, which is line-granular and would copy whole
    " lines for a 3-char selection (the original bug, 2026-08-21).
    function! s:CopySelection() abort
      call system(s:clip_write, @")
    endfunction
    xnoremap <silent> <Leader>y y:call <SID>CopySelection()<CR>

    " PASTE. A flat-bytes clipboard carries ONE type fact (trailing NL):
    " charwise and linewise survive the round-trip, blockwise does not.
    "  · normal mode: multi-line content goes LINEWISE (clean lines below
    "    the cursor — a charwise "p used to splice into the cursor line);
    "    single line stays charwise
    "  · visual mode: replaces the selection (symmetric with the copy)
    "  · register s is scratch — saved + restored, so "sy users are unaffected
    " The `range` attribute is load-bearing: `:'<,'>call …` errors E481 in a
    " function without it.
    " THE TWO TRAPS THAT BIT THIS FUNCTION (both probed 2026-08-31):
    "  · a:0 counts ARGUMENTS, not their values — F(0) has one argument;
    "    "no argument" is F(). The normal-mode map below passes nothing.
    "  · the `else` is a BARE :else on its own line — legacy VimL has no
    "    `else if` (:else takes no expression; E488 Trailing characters,
    "    thrown even when this branch wins, because a skipped :else line is
    "    still parsed while Vim scans for :endif). Chain with :elseif if
    "    ever needed — never the C habit.
    function! s:PasteClipboard(...) abort range
      let l:clip = system(s:clip_read)
      " A dead or empty backend must NOT paste an empty/errored register —
      " say so instead (echomsg survives the redraw; :messages recalls it).
      if v:shell_error || empty(l:clip)
        echohl WarningMsg
        echomsg 'paste: empty or unreadable clipboard via ' . s:clip_read
        echohl None
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
    " No backend at all — a dead key that explains itself beats a dead key.
    nnoremap <Leader>p :echomsg 'no clipboard backend: install wl-clipboard or xclip'<CR>
  endif
endif

" ============================================================================
" 8. TOOLCHAIN SELF-HEAL — degrade, never die
" ============================================================================
" 8a. The Python formatter venv is fully repairable in userspace (no sudo):
"     venv + pip + symlink into ~/.local/bin (already on PATH).
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

" 8b. Distro tools need sudo, so the defensive action is ONE consolidated
"     warning naming the pacman line (packages dedup'd — wl-copy and
"     wl-paste are both wl-clipboard). Clipboard tools audited only when
"     this build needs them (!has('clipboard'), section 7) and only for the
"     session type actually running. echomsg, not echo: the message list is
"     the only thing that survives a redraw.
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
    echomsg '[vimrc] missing tools — fix: sudo pacman -S ' . join(sort(keys(l:missing)), ' ')
    echohl None
  endif
endfunction

augroup tool_audit
  au!
  au VimEnter * call s:AuditTools()
augroup END

" ============================================================================
" 9. SEARCH PLUMBING — :grep bolted onto ripgrep, async through AsyncRun
" ============================================================================
" `let &opt = expr` assigns via an expression — no backslash-escaping of
" spaces (compare `set grepprg=rg\ --vimgrep\ …`). --vimgrep = one match per
" line WITH columns; --hidden includes dotfiles; --glob excludes .git
" internals. grepformat teaches vim to PARSE those lines into quickfix.
if executable('rg')
  let &grepprg = "rg --vimgrep --smart-case --hidden --glob '!**/.git/**'"
  let &grepformat = '%f:%l:%c:%m'
endif
" Unix's default shellpipe uses `tee`, echoing external grep/make output to
" the terminal; redirect both streams into vim's error file instead, so
" hand-typed `:silent grep` is quiet while quickfix still gets the matches
" (re-verified 2026-08-29, 25x headless; AsyncRun jobs never touch
" shellpipe — they job_start with piped output). Trade-off: a no-match
" search flashes "shell returned 1" — rg's normal zero-hits exit,
" informative.
if has('unix')
  let &shellpipe = '>%s 2>&1'
endif
" :Grep runs rg ASYNC through AsyncRun — matches stream into the quickfix,
" auto-opened at g:asyncrun_open (section 11); no terminal handover, vim
" stays editable while the search runs. -bang passes through: :Grep! stops
" qf auto-scroll. The `@` is AsyncRun's END-OF-OPTIONS marker (asyncrun.txt,
" like POSIX `--`): the option parser would otherwise eat a LEADING -token
" of the pattern. NO -complete: the first argument is a PATTERN, filename
" completion on it would mislead (Tab then does nothing).
command! -bang -nargs=+ Grep AsyncRun<bang> -program=grep @ <args>

" ============================================================================
" 10. C-FAMILY POLICY
" ============================================================================
" Extension-less C++ stdlib header detection (…/c++/14/vector) has TWO
" copies, deliberately:
"  · an INLINE block at section 11, registered AFTER plug#end() — that
"    position is what keeps it alive. Before plug#begin() the same block is
"    dead code: plug#begin runs `:filetype off` (plug.vim:325), wiping the
"    filetypedetect group, and the rebuild re-sources only ftdetect/*.vim
"    (verified dead 2026-08-22; alive after plug#end, probed 2026-08-31 §11
"    P4). Ken chose self-containment over the v1 pure-ftdetect design.
"  · ftdetect/cpp.vim beside this file — the travel copy for the plug-less
"    world (install: cp to ~/.vim/ftdetect/). When both are present the
"    inline `au!` keeps exactly one rule per pattern; the bodies are
"    identical, so who-wins is a non-question.
" Tuning knobs for vim's built-in C syntax highlighter (ft=c):
let g:c_gnu = 1             " GNU extensions (__attribute__ etc.) are valid
let g:c_no_cformat = 1      " don't special-highlight %escapes in strings
let g:c_space_errors = 1    " DO flag trailing whitespace / space-before-tab
let g:c_no_curly_error = 1  " tolerate brace oddities (system headers need it)
unlet! g:c_comment_strings

" ============================================================================
" 11. PLUGIN MANIFEST — vim-plug: bootstrap once, then self-maintain weekly.
"     The manifest matches the DISK (~/.vim/plugged — verified 2026-08-31;
"     the repo copy's manifest had drifted BOTH ways from it).
" ============================================================================
" ~/.vim for vim, stdpath('data')/site for neovim — one vimrc serves both.
let data_dir = has('nvim') ? stdpath('data') . '/site' : expand('~/.vim')
if !filereadable(data_dir . '/autoload/plug.vim')
  if executable('curl')
    " silent :execute keeps the hit-ENTER prompt off; --create-dirs makes
    " the autoload/ path.
    silent execute '!curl -fLo '
          \ . shellescape(data_dir . '/autoload/plug.vim')
          \ . ' --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  else
    echohl WarningMsg
    echomsg 'vim-plug missing and curl not on PATH — plugins will not load'
    echohl None
  endif
  " First-boot only — the PLACEMENT inside this if is what makes it rare:
  " an autocmd at script level registers on EVERY source (the repo rewrite's
  " bug #4: PlugInstall ran at every startup). The augroup is the same
  " idempotency discipline as everywhere else.
  if filereadable(data_dir . '/autoload/plug.vim') && executable('git')
    augroup plug_bootstrap
      au!
      autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
    augroup END
  endif
endif

" Weekly self-maintenance: PlugUpdate at most every 7 days, on a 3 s timer
" so startup never waits for git. The stamp file remembers the last run.
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
Plug 'airblade/vim-gitgutter'       " +/-/~ diff signs in the gutter
Plug 'alvan/vim-closetag'           " auto-close HTML-ish tags on '>' (list below)
Plug 'google/vim-searchindex'       " 'match 3 of 27' while /-searching
Plug 'iamcco/markdown-preview.nvim', { 'do': {-> mkdp#util#install()}, 'for': ['markdown', 'vim-plug'] } " live browser preview (F8); lazy — see the F8 guard
Plug 'junegunn/fzf', { 'do': {-> fzf#install()} } " the fuzzy-finder binary + glue
Plug 'junegunn/fzf.vim'             " :Files :Buffers :RG :BLines :History
Plug 'mattn/calendar-vim'           " calendar panel (F7)
Plug 'mattn/emmet-vim'              " HTML/CSS abbreviation expander (CS50W)
Plug 'mg979/vim-visual-multi'       " multiple cursors (<C-n> adds next match)
Plug 'morhetz/gruvbox'              " colorscheme (airline theme ships here too)
Plug 'pangloss/vim-javascript'      " better JS syntax/indent (CS50W)
Plug 'preservim/nerdtree'           " file drawer (F1)
Plug 'preservim/tagbar'             " symbol outline via ctags (F3)
Plug 'skywind3000/asyncrun.vim'     " run make/grep async into quickfix (F5)
Plug 'tpope/vim-commentary'         " gcc / gc{motion} — per-ft commentstring;
                                    "   freed the whole <Leader>c* prefix
Plug 'tpope/vim-eunuch'             " :Rename :Delete :Chmod :SudoWrite
Plug 'tpope/vim-fugitive'           " git porcelain (:Git blame alone justifies it)
Plug 'tpope/vim-repeat'             " makes surround/commentary repeatable with `.`
Plug 'tpope/vim-surround'           " cs"' changes quotes, ysiw) wraps, ds( deletes
Plug 'vim-airline/vim-airline'      " statusline + buffer tabline
Plug 'ycm-core/YouCompleteMe', { 'do': './install.py --clangd-completer' } " LSP completion/goto via clangd
call plug#end()
" Dropped vs the old repo manifest, on purpose: preservim/nerdcommenter
" (-> vim-commentary, 2026-08-23) and yegappan/mru (-> fzf :History needs no
" state file; the orphaned DB ~/.vim/.mru_files is safe to delete).

" Extension-less C++ header detection, INLINE copy — the position AFTER
" plug#end() is the whole trick (section 10 explains; verified alive by
" firing probe 2026-08-31, verified dead before plug#begin 2026-08-22).
" setfiletype (not set ft=) backs off when detection already decided.
augroup filetypedetect
  au! BufRead */c++/*     if expand('%:t') !~ '\.' | setfiletype cpp | endif
  au! BufRead */include/* if expand('%:t') !~ '\.' | setfiletype cpp | endif
augroup END

let g:asyncrun_open = 10            " auto-open a 10-line qf when an async job starts
let g:tagbar_sort = 0               " 0 = source order, so F3 reads top-to-bottom
let g:tagbar_autofocus = 1          " cursor jumps INTO the F3 panel on open
let g:airline_powerline_fonts = 1
let g:airline_theme = 'gruvbox'
let g:airline#extensions#tabline#enabled = 1      " top bar listing open buffers
let g:airline#extensions#tabline#show_tab_nr = 0  " TAB-PAGE numbers off (buffers, not tabs)
" buffer_nr_show stays OFF: with idx_mode on it would print TWO numbers per
" entry, and bufnrs go gappy (fzf/quickfix scratch buffers burn IDs
" forever). <Leader>N below jumps by INDEX — the number you see is the
" number you press.
let g:airline#extensions#tabline#buffer_idx_mode = 1
" closetag auto-closes on '>' for these; plain *.js/*.ts are NOT JSX
" (auto-closing a comparison's '>' there would be wrong).
let g:closetag_filenames = '*.html,*.htm,*.xhtml,*.phtml,*.xml,*.svg,*.vue,*.jsx,*.tsx'

" tags: (1) './tags;' — 'tags' in the current FILE's dir, then walk UP the
" tree until found (the ';' is the magic); (2) 'tags' relative to :pwd;
" (3) systags — a slot for a system-wide database of /usr/include. That file
" does not exist yet (missing entries are silently skipped, so this costs
" nothing until built). Build it once with:
"   sudo ctags --fields=+iaS --extras=+q -R -f /usr/local/etc/systags /usr/include
set tags=./tags;,tags,/usr/local/etc/systags
" Per-project tags: ctags --fields=+iaS --extras=+q -R .
" :RR newname = rename the symbol under the cursor via clangd.
command! -nargs=1 RR YcmCompleter RefactorRename <args>
" Feed fzf with rg: hidden files, no .git internals, newest first — :Files
" floats your working files to the top. (--sortr=modified verified valid
" 2026-08-31.)
let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --glob=''!**/.git/**'' --sortr=modified'
" gruvbox ships as a PLUGIN, so it doesn't exist until plug#end; apply on
" VimEnter. ++nested lets FileType/syntax autocmds run on the startup
" buffer. (A bare `au vimenter …` would stack a duplicate on every
" re-source — probed 2026-08-31; the augroup is load-bearing.)
augroup colorscheme_setup
  au!
  au VimEnter * ++nested colorscheme gruvbox
augroup END

" ============================================================================
" 12. KEY MAPPING DASHBOARD — F-keys open tools; q closes transient panels
" ============================================================================
" :Make[!] = -program=make through AsyncRun. -cwd=<root>: asyncrun walks UP
" from the file to the nearest project marker (.git/.hg/.svn/.project/.root)
" and runs make THERE (no marker = the file's own dir; `touch .root` opts
" in) — the same walk-up idea as './tags;'. <bang> stops auto-scroll. No
" -complete: the arguments are make TARGETS, not filenames.
command! -bang -nargs=* Make AsyncRun<bang> -program=make -cwd=<root> @ <args>

" The current tab's quickfix/loclist window id, or 0. getwininfo()'s
" 'quickfix' flag is 1 for BOTH kinds; win_gettype() tells them apart —
" and it is the direct documented route (:h win_gettype()).
function! s:PanelWin(type) abort
  for l:info in getwininfo()
    if l:info.tabnr == tabpagenr() && win_gettype(l:info.winid) ==# a:type
      return l:info.winid
    endif
  endfor
  return 0
endfunction

function! s:FocusPanel(type) abort
  let l:winid = s:PanelWin(a:type)
  return l:winid > 0 && win_gotoid(l:winid)   " win_gotoid crosses tabs; 0 on miss
endfunction

" F4: toggle YCM diagnostics (location list). Standing IN the list closes
" it; an open list for this window closes it; otherwise YcmDiags opens it
" focused.
function! s:ToggleYcmDiags() abort
  if win_gettype() ==# 'loclist'
    lclose
    return
  endif
  if get(getloclist(win_getid(), {'winid': 0}), 'winid', 0) > 0
    lclose
    return
  endif
  YcmDiags
endfunction

" F5: build toggle — three-way: stop if running, close if the panel is up,
" else save + build + focus. `:update` on an UNNAMED buffer is E32 (probed
" 2026-08-31) — warn instead of dying; the build still runs. get(g:,…,'')
" survives asyncrun absent; the qf window exists the moment :Make returns
" (asyncrun opens it synchronously), so the focus call right after never
" races.
function! s:ToggleBuild() abort
  if win_gettype() ==# 'quickfix'
    cclose
    return
  endif
  if get(g:, 'asyncrun_status', '') ==# 'running'   " ==# case-sensitive compare
    AsyncStop
    return
  endif
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

" F8: markdown live preview, then focus the browser. markdown-preview is
" LAZY ('for': markdown), so :MarkdownPreview doesn't exist until an .md
" buffer loads it (probed 2026-08-31: exists()==0 out of the box — a bare F8
" map is E492 in every other filetype). Guard and say so (echomsg:
" recoverable via :messages). Preview, not Toggle: start-or-reopen, never
" kill — stopping is :MarkdownPreviewStop's job, typed by hand.
" open_preview_page() is idempotent (mkdp/util.vim:36).
function! s:MarkdownPreview() abort
  if exists(':MarkdownPreview') != 2
    echohl WarningMsg
    echomsg printf("F8: markdown-preview not loaded — needs a markdown buffer, this one's filetype is '%s' (open a .md file, or :setf markdown)", empty(&ft) ? 'none' : &ft)
    echohl None
    return
  endif
  MarkdownPreview
  " The browser tab opens from the plugin's node server asynchronously (up
  " to ~1 s cold) — a one-shot 400 ms timer gives it a beat, THEN pulls
  " focus.
  call timer_start(400, {-> s:FocusBrowser()})
endfunction

" KWin's focus-stealing prevention refuses to let a background process yank
" focus, so the tab opens BEHIND vim; on Wayland only the compositor may
" move focus, and KWin exposes that only through scripting (qdbus6 ships
" with Plasma; no wmctrl-style tool exists). Verified on Plasma 6.7:
" windowList()/activeWindow are the KWin 6 API (clientList is gone), and the
" loadScript/start/unloadScript one-shot runs cleanly — unloadScript on a
" RUNNING script returns true, so this never calls stop() (which would halt
" unrelated user scripts). Firefox matches class/name 'firefox'. getpid()
" keys the /tmp file so two vims never clobber each other's script.
" Degrade, never die: no qdbus6 -> warn per press, the preview still opens.
function! s:FocusBrowser() abort
  if !executable('qdbus6')
    echohl WarningMsg
    echomsg 'F8: preview opened, but focus cannot move — qdbus6 missing (pacman -S qt6-tools)'
    echohl None
    return
  endif
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
  " 2>/dev/null muzzles qdbus stderr so a dead session (SSH, no KWin) can't
  " flash a message mid-screen.
  call system('qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript '
        \ . shellescape(l:js) . ' vimrcFocusBrowser 2>/dev/null')
  call system('qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start 2>/dev/null')
  call system('qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript vimrcFocusBrowser 2>/dev/null')
endfunction

nnoremap <silent><F1> :NERDTreeToggle<CR>
nnoremap <silent><F2> :History<CR>
nnoremap <silent><F3> :TagbarToggle<CR>
nnoremap <silent><F4> :call <SID>ToggleYcmDiags()<CR>
nnoremap <silent><F5> :call <SID>ToggleBuild()<CR>
nnoremap <silent><F7> :CalendarH<CR>
nnoremap <silent><F8> :call <SID>MarkdownPreview()<CR>
nnoremap <silent><Leader>b :Buffers<CR>
nnoremap <silent><Leader>f :Files<CR>
nnoremap <silent><Leader>g :RG<CR>
nnoremap <silent><Leader>/ :BLines<CR>

" airline buffer index: <Leader>N jumps to the Nth buffer in the top bar
" (0 = the 10th; -/+ prev/next; counts work: 3<Leader>+ = 3 on). airline
" only exposes <Plug> handles — WE bind them, with the same for+execute
" trick airline's own docs use. nmap is REQUIRED: a <Plug> RHS needs
" recursive expansion. s:i script-local — a bare `i` here would be a GLOBAL
" that survives re-sourcing.
for s:i in range(10)
  execute 'nmap <Leader>' . s:i . ' <Plug>AirlineSelectTab' . s:i
endfor
nmap <Leader>- <Plug>AirlineSelectPrevTab
nmap <Leader>+ <Plug>AirlineSelectNextTab

" ============================================================================
" 13. YCM CONFIG
" ============================================================================
nnoremap <Leader>ji :YcmCompleter FixIt<CR>
nnoremap <Leader>jt :YcmCompleter GoTo<CR>
nnoremap <Leader>jd :YcmCompleter GoToDefinition<CR>
nnoremap <Leader>jh :YcmCompleter GoToDeclaration<CR>
nnoremap <Leader>jr :YcmCompleter GoToReferences<CR>
" Deliberate exception to the nnoremap discipline: a <Plug> target needs
" recursive nmap. NOTE: <Leader>K overrides man.vim's buffer-local \K inside
" man buffers — hover-on-demand beats that rare alias (deliberate trade,
" EXPLAIN.md §5).
nmap <Leader>K <Plug>(YCMHover)

let g:ycm_auto_hover = ''                                  " no unsolicited popups; <Leader>K on demand
let g:ycm_autoclose_preview_window_after_insertion = 1     " close scratch preview after completing
let g:ycm_clangd_binary_path = '/usr/bin/clangd'           " distro clangd, not YCM's bundled one
let g:ycm_clangd_args = ['--header-insertion=iwyu', '--background-index', '-j=4'] " iwyu includes; instant goto
let g:ycm_complete_in_comments = 1                         " a REAL enable (default 0); strings are 1 by default — not set
let g:ycm_goto_buffer_command = 'split-or-existing-window' " goto REUSES a window showing the target
let g:ycm_key_invoke_completion = '<C-Z>'                  " manual trigger — never pops uninvited

" ============================================================================
" 14. INDENT POLICY — per-language whitespace law
"     expandtab  = Tab inserts spaces
"     tabstop    = visual width of a REAL tab byte
"     shiftwidth = what >>, <<, = and auto-indent use
"     softtabstop= Tab/Backspace behavior while typing
"     Keep softtabstop == shiftwidth.
" ============================================================================
" GNU C indent shape for browsing glibc (:h cinoptions-values). NOTE: s:
" here AND at the call site below — the 2026-08-31 rewrite defined a GLOBAL
" GnuIndent() but called s:GnuIndent() -> E117 on every /usr/include/* open.
function! s:GnuIndent() abort
  setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=8
  setlocal cinoptions=>4,n-2,{2,^-2,:2,=2,g0,h2,p5,t0,+2,(0,u0,w1,m1
endfunction

" asm labels (`.name:` / `name:`) start a new indent block; everything else
" inherits the previous non-blank line's indent. v:lnum is supplied by the
" indentexpr machinery (:h indentexpr).
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
  " au! first: a BARE :autocmd APPENDS, so every re-source would stack
  " duplicates. NO trailing comments on these lines (rest-of-line = args).
  au!
  " glibc-style indent when browsing system headers.
  au BufRead /usr/include/*            call s:GnuIndent()
  au FileType c,cpp,objc setlocal expandtab shiftwidth=4 softtabstop=4 tabstop=4 cinoptions=:0,g0,(0,w1
  au FileType html,css,scss,javascript setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2
  " textwidth=0 beats $VIMRUNTIME/ftplugin/vim.vim:133, which does
  " `if &tw == 0 | setlocal tw=78 | endif` — a deliberate 0 and "untouched"
  " are both just 0, so the vimrc must re-assert ON THE SAME EVENT, later in
  " registration order (probed: this line wins; without it, .vim comments
  " auto-wrap at 78 with a " leader).
  au FileType sh,vim     setlocal expandtab shiftwidth=2 softtabstop=2 textwidth=0
  au FileType json       setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2
  au FileType asm        setlocal noexpandtab shiftwidth=4 softtabstop=4 tabstop=4 indentexpr=s:AsmIndent()
  " Re-assert the CJK formatoptions after any ftplugin that resets fo
  " (probed: vim/c ftplugins only ADD today; this immunizes against resets).
  au FileType * setlocal formatoptions+=mM
  " q == close, for the transient panel buffers (help / man / quickfix)
  au FileType help       nnoremap <buffer><silent> q <C-W>c
  au FileType man        nnoremap <buffer><silent> q :quit<CR>
  au FileType qf         nnoremap <buffer><silent> q :call <SID>CloseTransientList()<CR>
augroup END
