" scientific network is inevitable, my option is xray + vps

silent! packadd! editexisting
" source $vimruntime/vimrc_example.vim does more than $vimruntime/defaults.vim.
silent! source $VIMRUNTIME/defaults.vim
silent! source $VIMRUNTIME/ftplugin/man.vim

":set <opntion>? or :echo &<option>, two different commands to show these option values.
set enc=utf-8
set spelllang+=cjk
set linebreak
set formatoptions+=mM
" this is for how vim decodes an existing file, which tries one by one.
set fileencodings=ucs-bom,utf-8,gb18030,latin1

"set signcolum=yes
set scrolloff=0
set keywordprg=:Man
set ignorecase smartcase
set number relativenumber
set splitright splitbelow

if has('termguicolors')
  "set termguicolors
endif

set nobackup
if has('persistent_undo')
  set undofile
  set undodir=~/.vim/undodir
  if !isdirectory(&undodir)
    "call is for function invocation, but discards the returning value.
    call mkdir(&undodir, 'p', 0700)
  endif
endif

nmap Q <Nop>
tnoremap <Esc><Esc> <C-\><C-N>
nnoremap <silent> <Esc> :noh <CR>
map <silent> <S-Tab> :pyxf /usr/share/clang/clang-format.py<CR>

if has('clipboard')
  vnoremap <silent> <F1> "+y
else
  if !empty($WAYLAND_DISPLAY)
    vnoremap <silent> <F1> :w !wl-copy <CR><CR>
  elseif !empty($DISPLAY)
    vnoremap <silent> <F1> :w !xclip -selection clipboard <CR><CR>
  endif
endif

" :verbose set grepprg?
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case\ --hidden\ --glob\ '!**/.git/**'
  set grepformat=%f:%l:%c:%m
endif

" unspecified default scope to let variable assignment depending on current scope.
if has('gui_running')
  "set guifont=
  "set guifontwide=
  let g:do_syntax_sel_menu = 1
  let g:do_no_lazyload_menu = 1
endif

function! s:CheckCPP() abort
  if expand('%:t') !~ '\.'
    setfiletype cpp
  endif
endfunction

aug filetypedetect
  au! BufRead */c++/*     call s:CheckCPP()
  au! BufRead */include/* call s:CheckCPP()
aug END

let g:c_gnu = 1
let g:c_no_cformat = 1
let g:c_no_curly_error = 1
let g:c_space_errors = 1
if exists('g:c_comment_strings')
  unlet g:c_comment_strings
endif

" before plug#begin() call, Note: nvim is shorthand of Neovim
let data_dir = has('nvim') ? stdpath('data') . '/site' : expand('~/.vim')
if !filereadable(data_dir . '/autoload/plug.vim') && executable('curl')
  silent execute '!curl -fLo ' . shellescape(data_dir) . '/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin()
Plug 'airblade/vim-gitgutter'
Plug 'google/vim-searchindex'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'mg979/vim-visual-multi'
Plug 'mattn/calendar-vim'
Plug 'morhetz/gruvbox'
Plug 'preservim/nerdtree'
Plug 'preservim/nerdcommenter'
Plug 'preservim/tagbar'
Plug 'skywind3000/asyncrun.vim'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'yegappan/mru'
Plug 'ycm-core/YouCompleteMe', { 'do': './install.py --clangd-completer' }
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
call plug#end()

let g:asyncrun_open = 10
let g:tagbar_autofocus = 1
let g:airline_powerline_fonts = 1
let g:airline_theme = 'gruvbox'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_tab_nr = 0
let g:airline#extensions#tabline#buffer_nr_show = 1
" Universal Ctags commands: ctags --fields=+iaS --extras=+q -R .
set tags=./tags;,tags,/usr/local/etc/systags
command! -nargs=1 RR YcmCompleter RefactorRename <args>
command! -bang -nargs=* -complete=file Make AsyncRun<bang> -program=make @ <args>
"command! -bang -nargs=* -complete=file Rg silent grep! <args> | redraw! | copen
" Vim env vars are set like below
let $FZF_DEFAULT_COMMAND="rg --files --hidden --glob='!**/.git/**' --sortr=modified"
au vimenter * ++nested colorscheme gruvbox

function! s:BuildToggle() abort
  " Toggle: stop if running, build if idle
  if g:asyncrun_status ==# 'running'
    AsyncStop
    return
  endif

  " Save before building
  if &modifiable && &modified
    update
  endif

  Make
endfunction

nnoremap <silent><F1> :NERDTreeToggle<CR>
nnoremap <silent><F2> :MRUToggle<CR>
nnoremap <silent><F3> :TagbarToggle<CR>
nnoremap <silent><F4> :YcmDiags<CR>
nnoremap <silent><F5> :call <SID>BuildToggle()<CR>
nnoremap <silent><F6> :call asyncrun#quickfix_toggle(10)<CR>
nnoremap <silent><F7> :CalendarH<CR>
nnoremap <silent><Leader>b :Buffers<CR>
nnoremap <silent><Leader>f :Files<CR>
nnoremap <silent><Leader>g :Rg<CR>
nnoremap <silent><Leader>r :FZFMru<CR>
nnoremap <silent><Leader>/ :Blines<CR>

nnoremap <Leader>fi :YcmCompleter FixIt<CR>
nnoremap <Leader>gt :YcmCompleter GoTo<CR>
nnoremap <Leader>gd :YcmCompleter GoToDefinition<CR>
nnoremap <Leader>gh :YcmCompleter GoToDeclaration<CR>
nnoremap <Leader>gr :YcmCompleter GoToReferences<CR>

let g:ycm_auto_hover = ''
let g:ycm_autoclose_preview_window_after_insertion = 1
" Important to use stable and correct version of clang tools
let g:ycm_clangd_binary_path = "/usr/bin/clangd"
let g:ycm_clangd_args = ['--header-insertion=iwyu', '--background-index', '-j=4']
let g:ycm_complete_in_comments = 1
let g:ycm_complete_in_strings = 1
let g:ycm_goto_buffer_command = 'split-or-existing-window'
let g:ycm_key_invoke_completion = '<C-Z>'


function! GnuIndent() abort
  setlocal cinoptions=>4,n-2,{2,^-2,:2,=2,g0,h2,p5,t0,+2,(0,u0,w1,m1
  setlocal shiftwidth=2 tabstop=8
endfunction

if has('autocmd')
  " tabstop means width of a real tab char in the file
  " expandtab isnerts spaces instead of a real tab char
  " softtabstop means how Tab and Backspace behave while editing
  " shiftwidth control indentation commands in vim such as >>, <<
  augroup ft_config
    au!
    au FileType c,cpp,objc setlocal expandtab shiftwidth=4 softtabstop=4 tabstop=4 cinoptions=:0,g0,(0,w1
    au FileType sh,vim     setlocal expandtab shiftwidth=2 softtabstop=2
    au FileType json       setlocal expandtab shiftwidth=2 softtabstop=2
    au FileType help       nnoremap <buffer><silent> q <C-W>c
    au FileType man        nnoremap <buffer><silent> q :quit<CR>
    au FileType qf         nnoremap <buffer><silent> q :cclose<CR>
    au BufRead  /usr/include/*  call GnuIndent()
  augroup END
endif
