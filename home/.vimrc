" STFW, RTFM, RTFS, scientific network is inevitable, my option is xray + vps
" The important one is that the following code is the single concise config, no defensive.

" Combine the same file to one buffer
silent! packadd! editexisting
" Follow a project's .editorconfig (indent, tabs, trailing spaces); Vim ships it off
silent! packadd! editorconfig
" source $vimruntime/vimrc_example.vim does more than $vimruntime/defaults.vim.
silent! source $VIMRUNTIME/defaults.vim
" To support the :Man command and the K key
silent! source $VIMRUNTIME/ftplugin/man.vim

" Options: :set <opt>=val (type-aware)  or  :let &<opt> = val (raw string)
" Show:    :set <opt>?  or :echo &<opt>   |  who set it: :verbose set <opt>?
" Booleans:  :set <opt> (on)    :set no<opt> (off)    :set <opt>! (toggle)
set enc=utf-8
set autoindent
set formatoptions+=mM
set spell spelllang+=cjk
set linebreak breakindent
set fileencodings=ucs-bom,utf-8,gb18030,latin1 "decode candidates, tried in order

set hidden
set hlsearch
set scrolloff=3
set updatetime=300
set keywordprg=:Man
set ignorecase smartcase
set number relativenumber
set splitright splitbelow
set signcolumn=yes " LSP and gitgutter signs never shift the text sideways
set wildoptions+=fuzzy,pum
set wildmode=longest:full,full
set wildignore=*.o,*.a,*.so,*.d,*.min.*,__pycache__,*/__pycache__/*

" gruvbox follows 'background', which Vim only GUESSES: Konsole says "dark"
" via $COLORFGBG, Windows Terminal says nothing, so Vim picked gruvbox light.
set background=dark
let g:gruvbox_contrast_dark = 'soft'
if has('termguicolors')
  set termguicolors
endif

let g:terminal_ansi_colors = ['#6c7086', '#f38ba8', '#a6e3a1', '#f9e2af',
      \ '#89b4fa', '#cba6f7', '#89dceb', '#cdd6f4',
      \ '#6c7086', '#f38ba8', '#a6e3a1', '#f9e2af',
      \ '#89b4fa', '#cba6f7', '#89dceb', '#cdd6f4']

set nobackup
if has('persistent_undo')
  set undofile
  set undodir=~/.vim/undodir
  if !isdirectory(&undodir)
    "call is for function invocation, but discards the returning value.
    call mkdir(&undodir, 'p', 0700)
  endif
endif

nnoremap Q <Nop>
xnoremap Q <Nop>
tnoremap <Esc><Esc> <C-\><C-N>
nnoremap <silent> <Esc> :noh<CR>

" A failed filter REPLACES the text with its error output ("command not
" found", a syntax error): one :w later the source file is gone. Undo it at
" once and say why. (v:shell_error survives silent!.)
function! s:FilterFailed(tool) abort
  if v:shell_error
    silent! undo
    echomsg a:tool . ' failed (exit ' . v:shell_error . '): not installed, or a syntax error?'
  endif
endfunction

function! s:ClangFormat() abort
  let l:view = winsaveview()
  silent! execute '%!clang-format --assume-filename=' . shellescape(expand('%:p'))
  call s:FilterFailed('clang-format')
  call winrestview(l:view)
endfunction

" After typing : in visual mode, vim auto-inserts '<,'> The `range` attribute makes the function receive it as a:firstline/a:lastline.
function! s:ClangFormatRange() range abort
  let l:view = winsaveview()
  silent! execute a:firstline . ',' . a:lastline . '!clang-format --assume-filename=' . shellescape(expand('%:p'))
  call s:FilterFailed('clang-format')
  call winrestview(l:view)
endfunction

function! s:PythonFormat() abort
  let l:view = winsaveview()
  silent! execute '%!black --quiet --stdin-filename=' . shellescape(expand('%:p')) . ' -'
  call s:FilterFailed('black')
  call winrestview(l:view)
endfunction

function! s:PythonFormatRange() range abort
  let l:view = winsaveview()
  silent! execute '%!black --quiet --stdin-filename=' . shellescape(expand('%:p'))
        \ . ' --line-ranges=' . a:firstline . '-' . a:lastline . ' -'
  call s:FilterFailed('black')
  call winrestview(l:view)
endfunction

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


augroup shifttab_format
  au!
  au FileType c,cpp  nnoremap <buffer><silent> <S-Tab> :call <SID>ClangFormat()<CR>
  au FileType c,cpp  xnoremap <buffer><silent> <S-Tab> :call <SID>ClangFormatRange()<CR>
  au FileType python nnoremap <buffer><silent> <S-Tab> :call <SID>PythonFormat()<CR>
  au FileType python xnoremap <buffer><silent> <S-Tab> :call <SID>PythonFormatRange()<CR>
  au FileType asm    nnoremap <buffer><silent> <S-Tab> :call <SID>AsmFormat()<CR>
  au FileType asm    xnoremap <buffer><silent> <S-Tab> :call <SID>AsmFormatRange()<CR>
augroup END

if has('clipboard')
  nnoremap <silent> <Leader>y "+y
  xnoremap <silent> <Leader>y "+y
  nnoremap <silent> <Leader>p "+p
  xnoremap <silent> <Leader>p "+p
else
  " WSL: Windows' own clipboard through PowerShell, which reads and writes
  " UTF-8 exactly (clip.exe misreads a lone CJK char: U+4E2D came back "-N");
  " tr drops the \r of Windows line ends. ''...'' = a literal '...' here.
  if exists('$WSLENV')
    let s:clip_write = 'powershell.exe -NoProfile -Command ''[Console]::InputEncoding=[Text.UTF8Encoding]::new($false); Set-Clipboard -Value ([Console]::In.ReadToEnd())'''
    let s:clip_read  = 'powershell.exe -NoProfile -Command ''[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); [Console]::Write((Get-Clipboard -Raw))'' | tr -d ''\r'''
  elseif !empty($WAYLAND_DISPLAY)
    let s:clip_write = 'wl-copy'
    let s:clip_read  = 'wl-paste -n'
  elseif !empty($DISPLAY)
    let s:clip_write = 'xclip -selection clipboard'
    let s:clip_read  = 'xclip -selection clipboard -o'
  endif

  function! s:PasteClipboard(...) abort range
    let l:clip = system(s:clip_read)
    let l:save = [getreg('s'), getregtype('s')]
    if !a:0
      call setreg('s', l:clip, (l:clip =~# '\n') ? 'V' : 'v')
      normal! "sp
    elseif a:1 == 1
      call setreg('s', l:clip, 'v')
      normal! gv"sp
    endif
    call setreg('s', l:save[0], l:save[1])
  endfunction

  " A mapping runs when you PRESS it, outside this script, so its RHS cannot
  " see s:clip_write (E121: Undefined variable). Read it inside a function
  " and call that through <SID>, like PasteClipboard below.
  function! s:Copy(text) abort
    call system(s:clip_write, a:text)
  endfunction

  if exists('s:clip_write') && exists('s:clip_read')
    nnoremap <silent> <Leader>y :call <SID>Copy(getline('.'))<CR>
    xnoremap <silent> <Leader>y y:call <SID>Copy(@")<CR>
    nnoremap <silent> <Leader>p :call <SID>PasteClipboard()<CR>
    xnoremap <silent> <Leader>p :call <SID>PasteClipboard(1)<CR>
  endif
endif

if executable('rg')
  let &grepprg = "rg --vimgrep --smart-case --hidden --glob '!**/.git/**'"
  set grepformat=%f:%l:%c:%m
endif
command! -nargs=+ -complete=file Grep AsyncRun! -program=grep @ <args>

if has('gui_running')
  "set guifont=
  "set guifontwide=
  let g:do_syntax_sel_menu = 1
  let g:do_no_lazyload_menus = 1
endif

let g:c_gnu = 1
let g:c_no_cformat = 1
let g:c_space_errors = 1
let g:c_no_curly_error = 1
unlet! g:c_comment_strings

" before plug#begin() call, Note: nvim is shorthand of Neovim
let data_dir = has('nvim') ? stdpath('data') . '/site' : expand('~/.vim')
if !filereadable(data_dir . '/autoload/plug.vim') && executable('curl')
  silent execute '!curl -fLo ' . shellescape(data_dir) . '/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  " Maybe one-shot is better
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin()
Plug 'airblade/vim-gitgutter'
Plug 'alvan/vim-closetag'
Plug 'google/vim-searchindex'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'mg979/vim-visual-multi'
Plug 'mattn/calendar-vim'
Plug 'mattn/emmet-vim'
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
Plug 'morhetz/gruvbox'
Plug 'pangloss/vim-javascript'
Plug 'preservim/nerdtree'
Plug 'preservim/tagbar'
Plug 'skywind3000/asyncrun.vim'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'yegappan/lsp' " LSP client in Vim9 script: clangd errors as you type, no compile step (replaced YCM)
Plug 'vim-airline/vim-airline'
call plug#end()

let g:asyncrun_open = 10
let g:tagbar_sort = 0
let g:tagbar_autofocus = 1
let g:airline_powerline_fonts = 1
let g:airline_theme = 'gruvbox'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_tab_nr = 0
let g:airline#extensions#tabline#buffer_idx_mode = 1
let g:airline#extensions#tabline#ignore_bufadd_pat =
      \ '!|defx|gundo|nerd_tree|startify|tagbar|term://|undotree|vimfiler|diffpanel'
let g:closetag_filenames = '*.html,*.htm,*.xhtml,*.phtml,*.xml,*.svg,*.vue,*.jsx,*.tsx'

" Universal Ctags commands: ctags --fields=+iaS --extras=+q -R .
set tags=./tags;,tags,/usr/local/etc/systags
command! -nargs=? RR LspRename <args>
command! -bang -nargs=* -complete=file Make AsyncRun<bang> -program=make -cwd=<root> @ <args>
" Vim env vars are set like below
let $FZF_DEFAULT_COMMAND="rg --files --hidden --glob='!**/.git/**' --sortr=modified"

aug filetypedetect
  au! BufRead */c++/*     if expand('%:t') !~ '\.' | setfiletype cpp | endif
  au! BufRead */include/* if expand('%:t') !~ '\.' | setfiletype cpp | endif
aug END

function! s:ToggleDiags() abort
  if get(getloclist(0, {'winid': 0}), 'winid', 0) != 0
    lclose
    return
  endif
  LspDiag show
endfunction

function! s:ToggleBuild() abort
  if get(getqflist({'winid': 0}), 'winid', 0) != 0
    cclose
    return
  endif

  " get() with a default: an unguarded g: read throws E121 if asyncrun.vim
  " has not defined g:asyncrun_status yet.
  if get(g:, 'asyncrun_status', '') ==# 'running'
    AsyncStop
    return
  endif

  " update on a modified buffer with no name throws E32; bufname() is empty
  " for [No Name], so save only real, named file buffers.
  if &l:buftype ==# '' && &l:modified && !empty(bufname())
    update
  endif

  Make
  " `call` is required: a bare `win_gotoid(...)` parses as the Ex command
  " :win[size] with argument "_gotoid(...)" -> E475 after every build.
  call win_gotoid(get(getqflist({'winid': 0}), 'winid', 0))
endfunction

nnoremap <silent><F1> :NERDTreeToggle<CR>
nnoremap <silent><F2> :History<CR>
nnoremap <silent><F3> :TagbarToggle<CR>
nnoremap <silent><F4> :call <SID>ToggleDiags()<CR>
nnoremap <silent><F5> :call <SID>ToggleBuild()<CR>
nnoremap <silent><F6> :UndotreeToggle<CR>
nnoremap <silent><F7> :CalendarH<CR>
" F8 (markdown preview) is mapped per markdown buffer in ft_config below.
nnoremap <silent><Leader>b :Buffers<CR>
nnoremap <silent><Leader>f :Files<CR>
nnoremap <silent><Leader>g :RG<CR>
nnoremap <silent><Leader>/ :BLines<CR>

for s:i in range(10)
  execute 'nmap <Leader>' . s:i . ' <Plug>AirlineSelectTab' . s:i
endfor
nmap <Leader>- <Plug>AirlineSelectPrevTab
nmap <Leader>+ <Plug>AirlineSelectNextTab

nnoremap <Leader>ji :LspCodeAction<CR>
nnoremap <Leader>jt :LspGotoDefinition<CR>
nnoremap <Leader>jd :LspGotoDefinition<CR>
nnoremap <Leader>jh :LspGotoDeclaration<CR>
nnoremap <Leader>jr :LspShowReferences<CR>
nnoremap <Leader>K :LspHover<CR>
nnoremap ]d :LspDiag nextWrap<CR>
nnoremap [d :LspDiag prevWrap<CR>

" LSP: clangd checks C/C++ as you type. It needs compile_commands.json
" (bear -- make -B) to know your real compiler flags: templates/README.md.
" The plugin loads after this file, so it calls back via User LspSetup.
let s:lsp_options = {'autoComplete': v:true, 'completionMatcher': 'fuzzy',
      \ 'showDiagWithVirtualText': v:true, 'diagVirtualTextAlign': 'after',
      \ 'showDiagOnStatusLine': v:true, 'noNewlineInCompletion': v:true,
      \ 'ignoreMissingServer': v:true}
let s:lsp_servers = [{'name': 'clangd', 'filetype': ['c', 'cpp'], 'path': 'clangd',
      \ 'args': ['--background-index', '--clang-tidy', '--header-insertion=iwyu',
      \          '--function-arg-placeholders=0', '--query-driver=/usr/bin/*gcc*,/usr/bin/*g++*']}]
augroup lsp_setup
  au!
  au User LspSetup call LspOptionsSet(s:lsp_options)
  au User LspSetup call LspAddServer(s:lsp_servers)
augroup END


function! s:GnuIndent() abort
  setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=8
  setlocal cinoptions=>4,n-2,{2,^-2,:2,=2,g0,h2,p5,t0,+2,(0,u0,w1,m1
endfunction

function! s:AsmIndent() abort
  if getline(v:lnum) =~# '^\s*\.\?\k\+:'
    return 0
  endif

  let l:prev_lnum = prevnonblank(v:lnum-1)
  if l:prev_lnum == 0
    return 0
  endif
  let l:prev_line = getline(l:prev_lnum)
  if l:prev_line =~# '^\s*\.\?\k\+:'
    return &shiftwidth
  endif

  return indent(l:prev_lnum)
endfunction

function! s:CloseTransientList() abort
  if win_gettype() ==# 'loclist'
    lclose
  else
    cclose
  endif
endfunction

augroup theme
  au!
  au vimenter * ++nested silent! colorscheme gruvbox
augroup END
" First start on a new machine: the plug bootstrap re-sources this file
" DURING VimEnter, and the au! above deletes the still-pending autocmd.
if v:vim_did_enter | silent! colorscheme gruvbox | endif

" tabstop means width of a real tab char in the file
" expandtab inserts spaces instead of a real tab char
" softtabstop means how Tab and Backspace behave while editing
" shiftwidth controls indentation commands in vim such as >>, <<, and =
augroup ft_config
  au!
  au BufRead /usr/include/*            call s:GnuIndent()
  au FileType html,css,scss,javascript setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2
  au FileType c,cpp,objc setlocal expandtab shiftwidth=4 softtabstop=4 tabstop=4 cinoptions=:0,g0,(0,w1
  au FileType sh,vim     setlocal expandtab shiftwidth=2 softtabstop=2 textwidth=0
  au FileType json       setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2
  au FileType asm        setlocal noexpandtab shiftwidth=4 softtabstop=4 tabstop=4 indentexpr=s:AsmIndent()
  au FileType markdown   nnoremap <buffer><silent> <F8> :MarkdownPreview<CR>
  au FileType help       nnoremap <buffer><silent> q <C-W>c
  au FileType man        nnoremap <buffer><silent> q :quit<CR>
  au FileType qf         nnoremap <buffer><silent> q :call <SID>CloseTransientList()<CR>
augroup END
