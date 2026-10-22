" ============================================================================
" smoke-test.vim — headless regression harness for vimrc-claude/.vimrc (v2)
"
" Run (the </dev/null matters; -es swallows :echo to piped stdout, which is
" why everything below writes through redir! into a file):
"   vim -u ~/config_files/vimrc-claude/.vimrc -es \
"       -S ~/config_files/vimrc-claude/smoke-test.vim </dev/null
"   cat /tmp/proposal_smoke.txt
"
" It re-sources the whole vimrc (idempotency) and then checks, one by one,
" every class of bug the 2026-08-31 review found in the repo rewrite,
" INCLUDING Bug 10 (else-if → E488): a source lint, and a LIVE dual-arity
" fire of s:PasteClipboard with a primed clipboard — the bug only surfaces
" when execution reaches the if/else block, so the test must get past the
" empty-clipboard early-out. Finish with the VERDICT line.
" ============================================================================
redir! > /tmp/proposal_smoke.txt
let s:rc    = expand('~/config_files/vimrc-claude/.vimrc')
let s:bugs  = []

" --- 1. Idempotency: source the ENTIRE vimrc a second time -----------------
try
  execute 'source ' . s:rc
  echo 'CHECK 1  re-source: OK (no error, all augroups rebuilt cleanly)'
catch
  call add(s:bugs, 're-source threw ' . v:exception)
  echo 'CHECK 1  re-source: ERROR ' . v:exception
endtry

" --- 2. Every helper exists (bug-3 class: call to deleted helper) ----------
let s:needed = ['MissingTool','FilterFailed','ClangFormat','ClangFormatRange',
      \ 'PythonFormat','PythonFormatRange','AsmFormat','AsmFormatRange',
      \ 'HealPyFormatters','AuditTools','MaybePlugUpdate','PanelWin',
      \ 'FocusPanel','ToggleYcmDiags','ToggleBuild','MarkdownPreview',
      \ 'FocusBrowser','GnuIndent','AsmIndent','CloseTransientList']
" The two clipboard helpers exist only when a tool backend was picked.
let s:mp = ''
try
  let s:mp = execute('nnoremap <Leader>p') . execute('xnoremap <Leader>p')
catch
  let s:mp = '(no Leader-p mapping)'
endtry
if s:mp =~# 'PasteClipboard'
  call extend(s:needed, ['CopySelection','PasteClipboard'])
  echo 'CHECK 2  clipboard branch: tool backend (wl-copy/xclip) — active'
else
  echo 'CHECK 2  clipboard branch: no-backend echo map — PasteClipboard correctly NOT defined'
endif
for s:f in s:needed
  let s:ok = 0
  try
    let s:listed = execute('function /' . s:f)
    let s:ok = s:listed =~# s:f
  catch
    let s:ok = 0
  endtry
  if s:ok
    echo 'CHECK 2  function ' . s:f . ': defined'
  else
    call add(s:bugs, 'function ' . s:f . ' not defined')
    echo 'CHECK 2  function ' . s:f . ': MISSING <<<'
  endif
endfor
" And the rewrite's zombie must stay dead:
try
  let s:zombie = execute('function /QfWinid')
  if s:zombie =~# 'QfWinid'
    call add(s:bugs, 'QfWinid resurrected?!')
    echo 'CHECK 2  function QfWinid: PRESENT <<<'
  endif
catch
  echo 'CHECK 2  function QfWinid: absent (bug 3 stays dead)'
endtry
" And no GLOBAL GnuIndent may leak (bug 9):
if exists('*GnuIndent')
  call add(s:bugs, 'global GnuIndent exists (should be s:-only)')
  echo 'CHECK 2  global GnuIndent: EXISTS <<<'
else
  echo 'CHECK 2  global GnuIndent: absent (bug 9 fixed)'
endif

" --- 3. Autocmd patterns: comma list, not the dead single regex -----------
" HARNESS LESSON (learned the hard way 2026-08-31): the :autocmd LISTING
" expands a comma pattern across display lines (one line per pattern) and
" prints "Group  Event" on ONE line — so the listing can never contain the
" literal "c,cpp", and event lines never stand alone. The reliable probes:
" exists() for presence, a FIRED FileType for the real test, and the listing
" only to assert the dead single-regex pattern is absent.
if exists('#shifttab_format#FileType') != 1
  call add(s:bugs, 'shifttab_format has no FileType autocmds')
  echo 'CHECK 3  exists(#shifttab_format#FileType): NO <<<'
else
  echo 'CHECK 3  exists(#shifttab_format#FileType): YES'
endif
let s:au = execute('autocmd shifttab_format')
echo 'CHECK 3  shifttab dead c.cpp in listing: ' . (s:au =~# 'c\.cpp' ? 'PRESENT <<< BUG 1' : 'absent (bug 1 fixed)')
if s:au =~# 'c\.cpp'
  call add(s:bugs, 'dead c.cpp pattern registered')
endif
" End-to-end: fire FileType c and cpp on fresh scratch buffers; the
" buffer-local S-Tab map must appear BOTH times — this is exactly what the
" dead pattern broke (the FIRING, not the registration). One buffer per
" fire: :setfiletype is a NO-OP on a buffer whose &ft is already set.
enew!
setfiletype c
let s:fired_c = maparg('<S-Tab>', 'n') =~# 'ClangFormat'
enew!
setfiletype cpp
let s:fired_cpp = maparg('<S-Tab>', 'n') =~# 'ClangFormat'
echo 'CHECK 3  S-Tab map after FileType c: ' . (s:fired_c ? 'installed' : 'MISSING <<< BUG 1')
echo 'CHECK 3  S-Tab map after FileType cpp: ' . (s:fired_cpp ? 'installed' : 'MISSING <<< BUG 1')
if !s:fired_c || !s:fired_cpp
  call add(s:bugs, 'S-Tab not mapped for c/cpp after FileType fire')
endif
" colorscheme au must be registered EXACTLY once — the re-source above must
" not stack a duplicate (second-pass probe: bare au vimenter stacks x2).
" Count 'gruvbox' occurrences in the group listing: 1 = clean rebuild.
" HARNESS LESSON #2: split() DROPS empty pieces unless keepempty=1 is passed
" — and 'gruvbox' is the LAST word of the listing, so without it the empty
" tail piece vanishes and a healthy group reads as 0.
if exists('#colorscheme_setup#VimEnter') != 1
  call add(s:bugs, 'colorscheme_setup has no VimEnter autocmd')
  echo 'CHECK 3  exists(#colorscheme_setup#VimEnter): NO <<<'
else
  echo 'CHECK 3  exists(#colorscheme_setup#VimEnter): YES'
endif
let s:cs = ''
try
  let s:cs = execute('autocmd colorscheme_setup')
catch
  let s:cs = ''
endtry
let s:cs_n = len(split(s:cs, 'gruvbox', 1)) - 1
echo 'CHECK 3  colorscheme gruvbox registrations: ' . s:cs_n . ' (want 1)'
if s:cs_n != 1
  call add(s:bugs, 'colorscheme au count = ' . s:cs_n)
endif
" PlugInstall autocmd must NOT exist (plug.vim present -> bootstrap skipped;
" the rewrite's bug 4 ran it every startup):
try
  let s:boot = execute('autocmd plug_bootstrap')
  if s:boot =~# 'PlugInstall'
    call add(s:bugs, 'PlugInstall au registered at every startup')
    echo 'CHECK 3  plug_bootstrap PlugInstall au: REGISTERED <<< BUG 4'
  endif
catch
  echo 'CHECK 3  plug_bootstrap PlugInstall au: absent (bug 4 fixed)'
endtry

" --- 4. Source lints — the bug classes reading CAN catch -------------------
" (a) trailing whitespace anywhere: after :map/:au it becomes keystrokes.
" (b) `else if` at line start: E488 on every call (Bug 10, 2026-08-31).
" (c) PasteClipboard(0) call sites: arity-vs-value (Bug 2).
" Comment lines start with `"`, so neither prose mention trips these.
let s:src    = readfile(s:rc)
let s:lint_t = filter(copy(s:src), 'v:val =~# " $"')
let s:lint_e = filter(copy(s:src), 'v:val =~# "^\\s*else\\s\\+if"')
let s:lint_p = filter(copy(s:src), 'v:val =~# "PasteClipboard(0)"')
echo 'CHECK 4  trailing-whitespace lines: ' . len(s:lint_t) . ' (want 0)'
echo 'CHECK 4  else-if lines:             ' . len(s:lint_e) . ' (want 0 — Bug 10 lint)'
echo 'CHECK 4  PasteClipboard(0) sites:   ' . len(s:lint_p) . ' (want 0 — Bug 2 lint)'
if !empty(s:lint_t) | call add(s:bugs, len(s:lint_t) . ' trailing-whitespace lines') | endif
if !empty(s:lint_e) | call add(s:bugs, 'else-if in source: ' . string(s:lint_e)) | endif
if !empty(s:lint_p) | call add(s:bugs, 'PasteClipboard(0) call site present') | endif

" --- 5. Bug-10 live-fire: call s:PasteClipboard with BOTH arities ----------
" Only conclusive when the tool backend is active (wl-copy + Wayland) and the
" clipboard is NON-empty — an empty clipboard early-outs BEFORE the if/else
" block, which is exactly where the E488 bug lived. Prime it ourselves.
if s:mp =~# 'PasteClipboard' && !empty($WAYLAND_DISPLAY) && executable('wl-copy') && executable('wl-paste')
  call system('wl-copy', 'smoke-probe-7f8a')
  if v:shell_error
    echo 'CHECK 5  live paste-fire: SKIP (wl-copy failed: exit ' . v:shell_error . ')'
  else
    sleep 150m
    " Find this vimrc's script number so we can reach its s: functions.
    " HARNESS LESSON #3 (2026-09-01, earned right here — the first version of
    " this check matched 'vimrc-claude' and TWO things bit us):
    "  · re-sourcing the SAME absolute path REUSES its script number — no new
    "    scriptnames entry, the rc stays <SNR>1 forever;
    "  · this harness file ALSO lives under vimrc-claude/, so its own
    "    scriptnames entry matched the loose pattern LAST, and we called
    "    <SNR>112_PasteClipboard — a function of the harness, not the vimrc
    "    (E117). Match the rc's exact tail, anchored at end-of-line.
    let s:snr = ''
    for s:ln in split(execute('scriptnames'), '\n')
      if s:ln =~# 'vimrc-claude/\.vimrc$'
        let s:snr = matchstr(s:ln, '^\s*\zs\d\+')
      endif
    endfor
    if empty(s:snr)
      call add(s:bugs, 'could not find vimrc script number in :scriptnames')
      echo 'CHECK 5  live paste-fire: FAIL (no <SNR> resolved) <<<'
    else
      enew!
      try
        execute 'call <SNR>' . s:snr . '_PasteClipboard()'
        echo 'CHECK 5  PasteClipboard() normal-mode call: clean (no E488/E121/E117)'
      catch
        call add(s:bugs, 'PasteClipboard() threw: ' . v:exception)
        echo 'CHECK 5  PasteClipboard() normal-mode call: THREW ' . v:exception . ' <<<'
      endtry
      try
        execute 'call <SNR>' . s:snr . '_PasteClipboard(1)'
        echo 'CHECK 5  PasteClipboard(1) visual-mode call: clean'
      catch
        call add(s:bugs, 'PasteClipboard(1) threw: ' . v:exception)
        echo 'CHECK 5  PasteClipboard(1) visual-mode call: THREW ' . v:exception . ' <<<'
      endtry
      enew!
    endif
  endif
else
  echo 'CHECK 5  live paste-fire: SKIP (no tool backend / no Wayland — lint at CHECK 4 still guards)'
endif
" Arity protocol on the maps themselves:
if s:mp =~# 'PasteClipboard()' && s:mp =~# 'PasteClipboard(1)'
  echo 'CHECK 5  Leader-p arities: () normal / (1) visual — correct'
else
  call add(s:bugs, 'Leader-p arity maps wrong: ' . s:mp)
  echo 'CHECK 5  Leader-p arities: WRONG <<<'
endif

" --- 6. textwidth guard on a vim buffer (bug 6) ----------------------------
enew!
setfiletype vim
echo 'CHECK 6  tw in vim buffer: ' . &l:tw . ' (want 0; 78 = regression)'
echo 'CHECK 6  fo in vim buffer: ' . &l:formatoptions . ' (want m and M present)'
if &l:tw != 0
  call add(s:bugs, 'tw=' . &l:tw . ' in vim buffer')
endif
if &l:formatoptions !~# 'm' || &l:formatoptions !~# 'M'
  call add(s:bugs, 'fo lost mM: ' . &l:formatoptions)
endif

" --- 7. Option policy -------------------------------------------------------
echo 'CHECK 7  hlsearch=' . &hls . ' autoindent=' . &ai . ' spell=' . &spell . ' spelllang=' . &spelllang
echo 'CHECK 7  wildmode=[' . &wildmode . '] wildoptions=[' . &wildoptions . '] enc=' . &enc
if &hls != 1   | call add(s:bugs, 'hlsearch off') | endif
if &ai  != 1   | call add(s:bugs, 'autoindent off') | endif
" v2 keeps global spell ON (Ken's call); the toggle is <Leader>S.
if &spell != 1 | call add(s:bugs, 'global spell off (v2 keeps it on)') | endif
if &enc !=# 'utf-8' | call add(s:bugs, 'enc=' . &enc) | endif
if &wildmode !=# 'longest:full,full' | call add(s:bugs, 'wildmode=' . &wildmode) | endif
" \V = very nomagic: '*' stays literal (wildignore is a pattern string).
if match(&wildignore, '\V*/__pycache__/*') < 0
  call add(s:bugs, 'wildignore missing */__pycache__/*')
  echo 'CHECK 7  wildignore pycache-contents twin: MISSING <<<'
else
  echo 'CHECK 7  wildignore pycache-contents twin: present'
endif

" --- 8. ftdetect: extension-less C++ headers get ft=cpp ---------------------
" v2 registers the rules TWICE by design: ~/.vim/ftdetect/cpp.vim (during
" plug#end's ftdetect sweep) and the inline post-plug#end block (which then
" au!-deds them to one per pattern). Presence is what matters.
let s:fd = execute('autocmd filetypedetect')
echo 'CHECK 8  ftdetect c++ rule: ' . (s:fd =~# 'c++' ? 'present' : 'MISSING <<<')
echo 'CHECK 8  travel copy vimrc-claude/ftdetect/cpp.vim readable: ' . filereadable(expand('~/config_files/vimrc-claude/ftdetect/cpp.vim'))
echo 'CHECK 8  installed twin ~/.vim/ftdetect/cpp.vim readable: ' . filereadable(expand('~/.vim/ftdetect/cpp.vim'))
if s:fd !~# 'c++'
  call add(s:bugs, 'ftdetect c++ rule gone')
endif

" --- 9. Commands and key maps ----------------------------------------------
echo 'CHECK 9  exists(:Make)=' . exists(':Make') . ' exists(:Grep)=' . exists(':Grep') . ' exists(:RR)=' . exists(':RR')
if exists(':Make') != 2 | call add(s:bugs, ':Make missing') | endif
if exists(':Grep') != 2 | call add(s:bugs, ':Grep missing') | endif
try
  echo 'CHECK 9  Leader-g -> ' . matchstr(execute('nnoremap <Leader>g'), ':RG\|:Rg')
catch
  call add(s:bugs, 'Leader-g map missing')
endtry
try
  echo 'CHECK 9  Leader-S -> ' . matchstr(execute('nnoremap <Leader>S'), 'spell!')
catch
  call add(s:bugs, 'Leader-S map missing')
endtry
try
  echo 'CHECK 9  Leader-K -> ' . matchstr(execute('nmap <Leader>K'), 'YCMHover')
catch
  call add(s:bugs, 'Leader-K map missing')
endtry
" The F-keys must call the GUARDED helpers, not the raw plugin commands
" (bug 7 class: bare :MarkdownPreview is E492 pre-lazy-load):
try
  let s:f8 = execute('nnoremap <F8>')
  echo 'CHECK 9  F8 -> ' . (s:f8 =~# 'MarkdownPreview()' ? 'guarded helper (bug 7 fixed)' : 'RAW COMMAND <<< BUG 7')
  if s:f8 !~# 'MarkdownPreview()' | call add(s:bugs, 'F8 not guarded') | endif
catch
  call add(s:bugs, 'F8 map missing')
endtry
try
  let s:f5 = execute('nnoremap <F5>')
  echo 'CHECK 9  F5 -> ' . (s:f5 =~# 'ToggleBuild()' ? 'ToggleBuild helper' : 'UNEXPECTED <<<')
  if s:f5 !~# 'ToggleBuild()' | call add(s:bugs, 'F5 map wrong') | endif
catch
  call add(s:bugs, 'F5 map missing')
endtry

" --- 10. Any error messages left behind by startup or the re-source? --------
" (:source errors PRINT but do not THROW — CHECK 1 would report OK on a
" mid-file abort; this messages scan is the only silent-abort detector, so
" the pattern covers every E-code class.)
let s:msg = execute('messages')
if s:msg =~# 'E[0-9][0-9]'
  call add(s:bugs, 'error-class messages present')
  echo 'CHECK 10 messages contain E-numbers: <<< (see tail below)'
  echo '--- messages tail ---'
  echo strpart(s:msg, len(s:msg) > 600 ? len(s:msg) - 600 : 0)
else
  echo 'CHECK 10 messages: no E-numbers (clean)'
endif

echo ''
if empty(s:bugs)
  echo '=== VERDICT: ALL CHECKS PASS ==='
else
  echo '=== VERDICT: ' . len(s:bugs) . ' FAILURES: ' . join(s:bugs, '; ') . ' ==='
endif
redir END
qa!
