# `.vimrc` (config_files) — full line-by-line analysis & recommendations (2026-08-31)

**Reviewed:** the working-tree rewrite of `~/config_files/.vimrc` (315 lines, 11k, uncommitted; HEAD is `ae840e5`).
**Cross-checked against:** `git diff HEAD`, the live twin `~/.vimrc` (825 lines, "12 subsystems" version), `~/notes/vim-set-options-verified-review.md`, `~/notes/vimrc-audit-2026-08-29.md`, `~/.vim/ftdetect/cpp.vim`, and **11 fresh headless probes** on this exact build (Vim 9.2, patches 1-849, Arch; probe script kept at `/tmp/vimrc_probes.vim`, results at `/tmp/vimprobe.txt` — re-runnable).
**Method:** every ❌ below has a probe or an on-disk citation; every "probed clean" line was actually run headlessly today. Nothing is folklore.

---

## 0. The one picture

The rewrite is a **net upgrade of HEAD** — it adopted nearly everything the verified-options review recommended (`hidden`, `scrolloff=3`, `updatetime`, `wildignore`, `fuzzy`, the `Q` fix, the clipboard redesign, `let &grepprg`) and added whole working subsystems HEAD lacked (Shift-Tab formatters, F4/F5 toggles, asm support, airline index jump). But it also **regressed three things HEAD had fixed** and **added three new broken call paths** — and every one of the eight bugs already has a corrected twin sitting in `~/.vimrc`, so the fix is a port, not an invention.

Verdict classes used below: ✅ keep as-is · 🔧 fix (bug) · 🔀 diverges from `~/.vimrc` · 🧹 cleanup (dead/redundant/typo).

### The 8 confirmed bugs, ranked

| # | Line | Bug | Severity | Proof |
|---|---|---|---|---|
| 1 | `.vimrc:92-93` | `au FileType c.cpp` — pattern is a *single regex* `c.cpp`, not two filetypes → **Shift-Tab formatting never fires in C/C++**. Plus a trailing space in the map RHS on line 92 (typed as a keystroke). | **High** (daily path) | probe G: `c.cpp_fired=no  c,cpp_fired=YES` |
| 2 | `.vimrc:129` | `PasteClipboard(0)` — passing `0` still counts as **one** vararg (`a:0=1`) → normal-mode `<Leader>p` takes the *visual* branch → `gv` re-selects your **old** selection and pastes there. On the **active** path: this build is `-clipboard` (probe: `vim --version`). | **High** (daily path) | probe K: `a:0 when called as F(0) = 1` |
| 3 | `.vimrc:232` | `win_gotoid(s:QfWinid())` — `s:QfWinid()` is **defined nowhere in the file** (grep: only the call site) → **F5 throws E117 after every build**. HEAD had the helpers; the rewrite deleted them but kept one call. | **High** | `grep -n QfWinid .vimrc` → line 232 only |
| 4 | `.vimrc:164` | `autocmd VimEnter * PlugInstall --sync \| source $MYVIMRC` was moved **outside** the bootstrap `if` (HEAD had it inside) → runs on **every startup**: plug window flashes, vimrc re-sources (stacking the bare autocmd at line 206), and throws E492 if plug.vim is absent. | **High** (every startup) | git diff; vim-plug's documented snippet guards it |
| 5 | `.vimrc:148-151` | Inline `aug filetypedetect` block is **dead code**: `plug#begin()` (`plug.vim:325`) runs `:filetype off`, wiping the group; the rebuild (`plug.vim:399`) re-sources only `ftdetect/*.vim` — where these same two rules already live (`~/.vim/ftdetect/cpp.vim:19-20`, header documents this exact death, "verified dead 2026-08-22"). | Medium (silent no-op) | plug.vim:325/399 + ftdetect/cpp.vim header |
| 6 | `.vimrc:309` | `au FileType sh,vim` lost the `textwidth=0` that HEAD had shipped (notes §9, fix at repo `.vimrc:196` before the rewrite) → `$VIMRUNTIME/ftplugin/vim.vim:133` re-applies `tw=78` → **comment auto-wrap at column 78 returns in `.vim` files**. `~/.vimrc:816` still has the fix. | Medium (annoyance, verified) | notes §9 probe; home:816 |
| 7 | `.vimrc:241` | F8 → bare `:MarkdownPreview` — the plugin is **lazy** (`'for': ['markdown',…]`, line 170), so in any non-markdown buffer the command doesn't exist yet → **E492 on F8**. Home guards it (`~/.vimrc:651-665`). | Medium | plugin `'for'` opt; home's documented fix |
| 8 | `.vimrc:227-229` | `update` on a modified **unnamed** buffer throws **E32** (probed) → F5 aborts before `Make` runs. Home warns instead (`~/.vimrc:628-636`). | Low-Med (edge case) | probe I: `E32: No file name` |

Everything else — including several things that *look* wrong — probed **clean** (see §3's "probed innocent" table).

---

## 1. Bug walkthrough (What → Why → How, with the transferable lesson)

### Bug 1 — `au FileType c.cpp` never matches (`.vimrc:92-93`)

**What.** In an `:autocmd` line, patterns are **comma**-separated. `c.cpp` is one pattern, and autocmd patterns are **regexes**: `c.cpp` means "c, any character, c-p-p" — a filetype literally spelled like `cXcpp`. Neither `c` nor `cpp` matches it.

**Why it hides.** `:au FileType c,cpp` and `:au FileType c.cpp` both *register without error* — autocmd registration never validates that a pattern will ever match. The mapping table looks right, smells right, and is dead.

**How (probe).** Registered both patterns, set a cpp buffer, fired the event:
```
G: c.cpp_fired=no   c,cpp_fired=YES      (probe, /tmp/vimprobe.txt)
```
**Fix:** `au FileType c,cpp  nnoremap <buffer><silent> <S-Tab> :call <SID>ClangFormat()<CR>` (and the `xnoremap` twin on line 93). Also delete the **trailing space** on line 92 — for `:map` the rest of the line is the RHS, so `<CR> ` types a space as a keystroke after the call (cursor jerks one char). Line 92 is the only trailing-space line in the file (`grep -n ' $'`).

> **Common beginner confusion:** "autocmd events take a filename pattern, so `c.cpp` is the C++ filetype with a dot like a file extension." No — for `FileType` the pattern is matched against the *value* of `'filetype'` (`c`, `cpp`, `python`…), as a regex, comma-separated. Dots are regex wildcards here, not extension dots.

**Lesson:** An autocmd that never matches is a *silent* failure — vim has no "unused pattern" warning. The ground-truth check is `:autocmd shifttab_format` to see it registered, then `:doautocmd FileType cpp` (or open a real `.cpp`) to see it *fire*.

---

### Bug 2 — `PasteClipboard(0)` takes the visual branch in normal mode (`.vimrc:129`)

**What.** The function branches on `if a:0` — "how many *extra* arguments did I get?". The rewrite's normal-mode map passes a literal `0` as that argument. But `a:0` counts *arguments*, not their *values*: `PasteClipboard(0)` has one argument → `a:0 == 1` → truthy → the visual branch runs `normal! gv"sp` — from **normal mode**, where `gv` re-selects whatever you last selected visually, and the paste clobbers *that* region instead of pasting at the cursor.

**Why it matters here specifically.** This Arch vim is `-clipboard` (probed; the notes already proved the `+` register dead, W24/E354 on 2026-08-21) — so the **fallback wl-copy/xclip branch is the branch that actually runs on this machine**. This is not dormant portability code; `<Leader>p` in normal mode misbehaves on every paste.

**How (probe).** `func! ProbeVararg(...) | return a:0 | endfunc` → `ProbeVararg(0)` returned **1**.

**Fix (exactly what `~/.vimrc:313` does):** call with **no argument** from normal mode —
```vim
nnoremap <silent> <Leader>p :call <SID>PasteClipboard()<CR>
```
`a:0` is then 0 → `else` branch → charwise/linewise paste at cursor. (Or branch on `if a:0 && a:1` — but the no-arg call is home's proven shape.)

> **Common beginner confusion:** "`call F(0)` is how I say 'no argument'." A literal `0` is *an argument*. `a:0` is the **count** of varargs; `a:1` is their value. Want "none"? Call `F()` — or check the value, not the count.

**Lesson:** For any `...`-style function, `a:0` answers *how many*, `a:1…` answer *what*. Branch on the one you actually mean.

---

### Bug 3 — `s:QfWinid()` does not exist (`.vimrc:232`)

**What.** The rewritten `s:ToggleBuild()` ends with `win_gotoid(s:QfWinid())` — a script-local function the file never defines. HEAD's version (per the 2026-08-31 memory note) had a full helper family (`s:QfWinid`, `s:LLWinid`, `s:JumpToList`); the rewrite **removed the definitions and kept one call**. Result: F5 opens the quickfix via `Make`… then dies with `E117: Unknown function s:QfWinid`, so focus never lands in the panel.

**Why script-local makes it worse.** `s:` functions are visible **only inside the script that defined them**. If `s:QfWinid` existed in some *other* sourced file, this line would still fail — there is no cross-script `s:` lookup. The `s:` prefix guarantees the failure is total.

**Fix — port home's replacement** (`~/.vimrc:573-604`), which deleted the helper family in favor of one general panel-finder:
```vim
" Return the current tab's quickfix/location-list window, or 0.
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
  return l:winid > 0 && win_gotoid(l:winid)
endfunction
```
…and in `s:ToggleBuild()`: replace line 232 with `call s:FocusPanel('quickfix')`. This shape is *better* than resurrecting `s:QfWinid`: it finds qf **or** loclist windows by type, per tab, and `win_gotoid()` is verified to cross tab pages (memory note, 2026-08-31).

**Lesson:** When a rewrite deletes a helper, the compiler can't save you — vimscript resolves function names at **call time**, so the file sources cleanly and fails at first press. Grep every `s:Name(` you call for a matching `function! s:Name(` before shipping.

---

### Bug 4 — `PlugInstall --sync` on every startup (`.vimrc:164`)

**What.** HEAD had the `autocmd VimEnter * PlugInstall --sync | source $MYVIMRC` **inside** the `if !filereadable(…plug.vim) && executable('curl')` guard — the standard vim-plug first-boot snippet. The rewrite moved it **outside** (the diff shows the line migrating past the `endif`). Consequences, in order of pain:

1. **Every** `vim` start registers a VimEnter that runs `:PlugInstall --sync` — the plug split flashes open, checks every plugin dir, and blocks until done.
2. It then **re-sources `$MYVIMRC`** — harmless for the `augroup`-wrapped blocks (their `au!` makes them idempotent), but it **stacks a duplicate** of the *bare* autocmd at line 206 (`au vimenter * ++nested colorscheme gruvbox`), re-runs the `for s:i` loop, re-defines every function, etc.
3. If plug.vim is missing *and* curl is missing (the `if` on line 161 then never downloads), VimEnter fires `:PlugInstall` → **E492** at startup — the exact case the bootstrap was supposed to heal.

**Fix:** move the `autocmd` back inside the guard (HEAD's placement), or adopt home's hardened version (`~/.vimrc:446-474`): wrap it in `augroup plug_bootstrap`, require `executable('git')`, and warn (not just silently skip) when curl or plug.vim is missing.

**Lesson:** vim-plug's bootstrap snippet keeps the autocmd inside the `if` on purpose — the *registration* of the autocmd is itself the one-time action. An autocmd line at script level runs at every source; what makes it conditional is placement inside the `if`, not anything in the command itself.

---

### Bug 5 — the inline `filetypedetect` block is dead code (`.vimrc:148-151`)

**What.** The two `au! BufRead */c++/*` / `*/include/*` rules (extension-less C++ stdlib headers) are registered at line 149-150 — **before** `call plug#begin()` at line 166. But `plug#begin()` runs `:filetype off` (`plug.vim:325`), which **empties the `filetypedetect` group**, and `plug#end()` rebuilds detection (`plug.vim:399`, `filetype plugin indent on`) re-sourcing **only** `ftdetect/*.vim`. Your in-vimrc rules are wiped and never come back. The *working* copies of these exact two rules already live in `~/.vim/ftdetect/cpp.vim:19-20` — whose header documents this precise mechanism and history ("verified dead 2026-08-22 and moved here").

**Fix:** delete lines 148-151 from the repo copy (the ftdetect file carries the duty). If you want the repo `.vimrc` self-sufficient without vim-plug, keep them — but then know they only work in a plug-less world, and the comment should say so.

> **Common beginner confusion:** "I registered an autocmd in my vimrc, so it's active." Only until something clears the group. `filetypedetect` is **vim's own** group, cleared and rebuilt wholesale by `:filetype off`/`on`; `ftdetect/*.vim` is the *only* location that participates in the rebuild. `:autocmd filetypedetect` before/after `plug#begin()` is the experiment that makes this visible.

**Lesson:** For filetype *detection* rules, `~/.vim/ftdetect/` is the canonical home precisely because it's the one path that survives the `filetype off→on` cycle. In-vimrc detection rules are eggs in a basket someone else empties.

---

### Bug 6 — `textwidth=0` regression: `.vim` comments wrap at 78 again (`.vimrc:309`)

**What.** Notes §9 (2026-08-31) proved the mechanism and shipped a fix to **both** files: `$VIMRUNTIME/ftplugin/vim.vim:133` does `if &tw == 0 | setlocal tw=78 | endif` — a deliberate `tw=0` is indistinguishable from "untouched", so the ftplugin re-imposes 78 and your comments auto-wrap mid-thought with a `" ` leader. HEAD's repo copy had the fix (`textwidth=0` on the `sh,vim` line); the rewrite dropped it (and `~/.vimrc:816` still has it, so the live file is fine — only the repo copy regressed).

**Fix:** `.vimrc:309` →
```vim
au FileType sh,vim setlocal expandtab shiftwidth=2 softtabstop=2 textwidth=0
```

**Lesson:** a vimrc runs **once**, ftplugins run **per buffer, later** — any "win over the ftplugin" setting must ride the same `FileType` event, not just sit earlier in the file. (Same reason your `formatoptions+=mM` works: probed, the ftplugins *add* to it rather than reset — but that was luck, not law.)

---

### Bug 7 — F8 throws E492 outside markdown (`.vimrc:241`)

**What.** markdown-preview is declared lazy — `Plug 'iamcco/markdown-preview.nvim', {'for': ['markdown', 'vim-plug']}` (line 170) — so `:MarkdownPreview` doesn't exist until a markdown buffer first loads it. `nnoremap <F8> :MarkdownPreview<CR>` in a `.c` buffer = `E492: Not an editor command`.

**Fix:** port home's guard (`~/.vimrc:651-665`): `s:MarkdownPreview()` checks `exists(':MarkdownPreview') == 2`, warns with the *reason* (`echomsg`, so it's recoverable via `:messages`) when not, else runs it — plus (home-only, optional) the `s:FocusBrowser()` KWin/qdbus6 focus pull.

**Lesson:** a lazy plugin's commands are **created by the plugin's loading**, so any mapping to them needs an `exists(':Cmd')` guard at *press time*, not at vimrc time. "A dead key that explains itself beats a dead key" — the rule this file already uses for formatters/clipboard, just not yet here.

---

### Bug 8 — `update` on a modified unnamed buffer = E32 (`.vimrc:227-229`)

**What.** Probed: `:update` in a modified `[No Name]` buffer throws `E32: No file name` — so F5 dies *before* `Make`. Home's version (`~/.vimrc:628-636`) checks `bufname('%') ==# ''` first and **warns** ("Build: unnamed modified buffer was not saved") instead of throwing, and also guards `&l:modifiable && !&l:readonly` before `update`.

**Fix:** port that block. Also, line 222's `g:asyncrun_status` direct read throws E121 if asyncrun ever fails to load — home's `get(g:, 'asyncrun_status', '')` is the defensive shape.

**Status: FIXED 2026-09-01 (evening)** — `.vimrc:231` now reads `get(g:, 'asyncrun_status', '')`; `.vimrc:238` guards `update` with `&& !empty(bufname())`. Both failure modes repro'd headless before the fix (`Vim(update):E32: No file name` on a modified `[No Name]` buffer, `Vim(if):E121: Undefined variable: g:asyncrun_status`); both idioms probed safe after; full vimrc sources headless clean (exit 0, plugins loaded, `ToggleBuild` defined).

---

## 2. Line-by-line verdicts — every line, comments included

Legend: ✅ keep · 🔧 bug (see §1) · 🔀 differs from `~/.vimrc` · 🧹 cleanup · ✔️ probed clean today.

### Bootstrap (lines 1-7)

| Line | Content (gist) | Verdict |
|---|---|---|
| 1 | `" STFW, RTFM, RTFS, scientific network…` | ✅ personal note, identical in both files. Opaque to any future reader — if you keep it, one extra word (`proxy note`) would make it self-explanatory. |
| 3 | `silent! packadd! editexisting "For gvim to open the same file` | ✔️ **probed innocent**: the trailing `"` comment *is* stripped after `:packadd` — `&rtp` gains the package identically with and without the comment (probe B/B2: match=95 both). Two nits: (a) home keeps comments on their own lines above (its documented discipline), (b) the comment is imprecise — this build is `+clientserver`, so editexisting works in **terminal** vim too, not just gvim. |
| 4 | `" unlet! skip_defaults_vim` | ✅ commented out is fine. See §4.1 — the `unlet!` is pure ritual on Arch: `/etc/vimrc:18` ships it commented out, and your explicit `source defaults.vim` ignores the flag anyway. Answers home's "Maybe redundant?" — yes. |
| 5 | `" source …vimrc_example.vim does more than defaults.vim` | ✅ accurate (vimrc_example.vim = defaults.vim + more). Missing the *decision*: why you chose defaults.vim anyway (vimrc_example carries settings you'd rather own yourself). One clause would fix it. |
| 6 | `silent! source $VIMRUNTIME/defaults.vim` | ✅ the load-bearing line. Notes probed what it sets on this build: `nocompatible`, `ttimeout`+`ttimeoutlen=100`, `display=truncate`, `scrolloff=5`, `incsearch`, `mouse=a`, `nrformats-=octal`, `filetype plugin indent on`, `syntax on`, `nolangremap`. |
| 7 | `silent! source $VIMRUNTIME/ftplugin/man.vim "To support :Man…` | ✔️ **probed innocent**: `exists(':Man')` = 2 with the trailing comment (probe C/C2). Comment grammar: "To support the `:Man` command and the `K` key". |

### Option header comment (lines 9-12)

| Line | Verdict |
|---|---|
| 9-12 | ✅ the four-form comment block (`set`/`let &`, `?`/`echo`, booleans, `<`) — this is the corrected version of HEAD's typo'd block (`opntion`), and it now includes the `!` and `<` forms the notes asked for. One nit: "`:let &<opt> = val` (raw string)" — more precisely, `:let &opt` assigns via an *expression* (no backslash-escaping, spaces legal); ":set" parses the rest of the line with its own syntax. "Type-aware" undersells it; the notes' wording ("expression") is the one to steal. |

### Core options (lines 13-28)

| Line | Setting | Verdict |
|---|---|---|
| 13 | `set enc=utf-8` | 🔀/🧹 notes verdict (probed): **redundant** on this machine — `LANG=en_US.UTF-8` already derives utf-8 at startup. Keep only if this file travels to odd machines; harmless either way. Home keeps it too. |
| 14 | `set formatoptions+=mM` | ✔️ probed in notes: survives into buffers (`fo=mMcroql` in C, `mMtcqln` in md) — ftplugins *add* here. Correct CJK wrap/join behavior. |
| 15 | `set spell spelllang+=cjk` | ✅ notes-blessed shape ("merged switch + payload"). 🔀 home does **not** turn spell on globally — decide which behavior you want and make the twins agree. Spell is window-local; squiggles follow windows, not the global setting (notes §6.4). |
| 16 | `set linebreak breakindent` | ✅ display-only pair (probed note); `breakindent` is an *adoption from the notes* that home hasn't taken (§4.3). |
| 17 | `set fileencodings=…` | ✔️ probed innocent: trailing comment stripped (probe D). Order is right: `ucs-bom` first, `gb18030` before `latin1`, `latin1` last as the always-succeeds catch-all (notes). Comment "Decoding one by one" → "decode candidates, tried in order" reads better. |
| 19 | `"set signcolumn=auto` | 🧹 dead comment: `auto` **is** the default in 9.2 — even uncommented it's a no-op. Delete, or keep as documentation with a word saying so. (HEAD's typo `signcolum` is fixed — good.) |
| 20 | `set hidden` | ✅ new in the rewrite (HEAD lacked it — notes called it a staple). |
| 21 | `set scrolloff=3` | ✅ deliberate override of defaults.vim's 5 (notes: "your line wins"). 🔀 same in home. |
| 22 | `set updatetime=300` | ✅ new in rewrite (notes-recommended). Paces gitgutter/YCM `CursorHold`. |
| 23 | `set keywordprg=:Man` | ✅ correct — and **dependency-paired** with line 7 (notes probe: `:Man` exists only after it). The pair travels together. |
| 24 | `set ignorecase smartcase` | ✅ classic pair. **But its partner `hlsearch` is missing** — your `:noh` map at line 48 is inert without it, and notes verified `hlsearch` is a real gap on 9.2 (still `nohlsearch` in `--clean`). Add `set hlsearch`. |
| 25 | `set number relativenumber` | ✅ hybrid numbering idiom (notes-blessed). |
| 26 | `set splitright splitbelow` | ✅. |
| 27 | `set wildoptions+=fuzzy,puzzy` → `fuzzy,pum` | ✅ both parts accepted (probed, notes §10). Remember the **fuzzy gotcha**: it never applies to file/dir-name completion — its value is commands/help/colorschemes/buffer names. `wildmode` is the missing sibling (§5). |
| 28 | `set wildignore=…` | ✅ notes-blessed verbatim. Scope note (§10): it only silences **vim's own** cmdline file completion — fzf/rg/YCM never consult it. Cheap and complementary. |

### Terminal colors (lines 30-33) — 🔀 the biggest quality gap vs home

| Verdict |
|---|
| 🧹 **stale comment + missing fix.** "Due to weird `:term` mode shell color rendering" describes a problem home **solved** on 2026-08-31: `set termguicolors` + `let g:terminal_ansi_colors = [Konsole's catppuccin-mocha 16]` (`~/.vimrc:65-89`, screenshot-pixel-verified). Without `termguicolors`, gruvbox falls back to 256-color mapping (muddier), and `:terminal` children render through vim's stock VGA-ish ANSI palette — the exact "weird rendering" the comment blames. **Port home's 25-line block** (option + palette + comments); it's verified active on this Konsole/Wayland host, and gruvbox provably never touches `g:terminal_ansi_colors`. |

### Undo persistence (lines 35-43)

| Verdict |
|---|
| ✔️ **fully probed clean today** (this specific block had never been probe-verified before): `set undodir=~/.vim/undodir` **expands `~` at set-time** — `echo &undodir` → `/home/ken/.vim/undodir`, `isdirectory()` → 1, no literal-`~` dirs exist anywhere. `+persistent_undo` compiled in. `call mkdir(&undodir, 'p', 0700)` correct. Home is character-identical in behavior. Keep as-is. |

### Key escapes (lines 45-49)

| Line | Verdict |
|---|---|
| 45-46 | ✅ `nnoremap`/`xnoremap Q <Nop>` — fixes HEAD's recursive `nmap Q`. Note this deliberately overrides defaults.vim's own `Q`→`gq` remap; `gq` remains available directly if you ever want text formatting. |
| 47 | ✅ `tnoremap <Esc><Esc> <C-\><C-N>` — the humane terminal escape. |
| 48 | ✅ `:noh<CR>` — also fixes HEAD's `:noh <CR>` stray space. **Add `set hlsearch` to give it a job** (line 24 verdict). |
| 49 | 🧹 commented-out `pyxf clang-format.py` map — dead documentation of the *superseded* approach (the functions below replaced it). Delete; history keeps it in git. |

### Formatter bridge (lines 51-98)

| Lines | Verdict |
|---|---|
| 51-87 | 🔀 **port home's guards.** The five formatter functions are otherwise faithful ports of home's, but they lack `s:MissingTool()` / `s:FilterFailed()` (`~/.vimrc:132-151`). As written, a missing binary or a parse error means: `silent!` hides the error, the buffer is **left holding the tool's stderr** (shellredir merges it into filter output), and you must discover `u` yourself. Home's guard `silent! undo`s the clobber back and warns with the exit code. One-line summary for the doc: *filter failure is a data-destroying event unless you undo it.* |
| 57 | 🧹 comment typo: "Afer" → "After". Content is good and correctly placed (comment *above*, none trailing on the `map` lines below). |
| 90-98 | ✅ augroup + `au!` idempotency correct; `<buffer>` scoping correct; no trailing comments on au lines (the file obeys its own rule). 🔧 lines 92-93: **Bug 1** (`c.cpp` → `c,cpp`; trailing space on 92). |

### Clipboard (lines 100-132)

| Lines | Verdict |
|---|---|
| 100-104 | ✅ native `+`-register branch — never taken on this build (`-clipboard`), correct to keep for travel. 🔀 home binds visual copy to `<F1>` instead of `<Leader>y`; repo's `nnoremap/xnoremap <Leader>y "+y` is actually *more* complete (home has no normal-mode copy). Pick one convention and mirror it in both files. |
| 106-112 | 🔀 **add `executable()` checks** like home (`~/.vimrc:267-272`): today `$WAYLAND_DISPLAY` alone gates the choice, so a half-installed box (env var set, `wl-copy` gone) yields mappings that error at press time. |
| 114-125 | ✅ logic sound (`s:` scratch register save/restore; `'v'`/`'V'` type pick; `gv"sp` visual replace). 🔀 add home's early-out: `if v:shell_error \|\| empty(l:clip) \| return \| endif` (empty/failed read currently pastes an empty register). 🔧 line 129: **Bug 2** — `(0)` → `()`. |
| 127-131 | ✅ `exists()` guard prevents dead mappings when headless/SSH — good. 🔀 home adds the final `else`: a `<Leader>p` that *echoes* "no clipboard backend: install wl-clipboard or xclip" — "a dead key that explains itself beats a dead key". |

### Grep plumbing (lines 134-138)

| Line | Verdict |
|---|---|
| 134-137 | ✅ `let &grepprg` rewrite of HEAD's backslash-escaped `set grepprg=rg\ …` — strictly better (no escaping; expression assignment). `grepformat=%f:%l:%c:%m` correct. 🔀 home additionally ships the `has('unix')` `let &shellpipe = '>%s 2>&1'` fix (verified 25× headless 2026-08-29) so hand-typed `:grep`/`:make` stay quiet — consider porting. |
| 138 | 🔀 **three deltas vs home (`~/.vimrc:405`)**: (a) drop `-complete=file` — the first argument is a *pattern*; filename Tab-completion misleads (home documents why); (b) `-bang` instead of hardcoded `AsyncRun!` — bang currently *always* suppresses quickfix auto-scroll; home keeps both reachable (`:Grep` scrolls, `:Grep!` doesn't); (c) home's version is identical otherwise, `@` end-of-options and all (its asyncrun.txt:298 rationale is quoted there). |

### GUI block (lines 140-146)

| Line | Verdict |
|---|---|
| 140 | 🧹 comment/code mismatch: "unspecified default scope…" describes *bare* `let` scoping, but every line below uses explicit `g:`. The comment explains a rule the block doesn't demonstrate. Delete or move under a line that does. |
| 141-146 | 🔀 dead on this terminal host (`has('gui_running')` false). **Line 145 typo confirmed against runtime:** `menu.vim:399` checks `do_no_lazyload_menu**s**` (plural) — as written the variable is a no-op. `g:do_syntax_sel_menu` (line 144) is correct (`menu.vim:1220`). Either fix the plural + keep for portability, or drop the block. |

### C++ header detection (lines 148-151)

| Verdict |
|---|---|
| 🔧 **Bug 5** — dead code (wiped by `plug#begin`'s `filetype off`, never re-sourced; the live twins sit in `~/.vim/ftdetect/cpp.vim:19-20`). The inline `if … | setfiletype cpp | endif` rewrite of HEAD's `s:CheckCPP()` is behaviorally equivalent — the problem is *placement*, not form. Note the rewrite also dropped `s:CheckCPP`'s definition — no dangling reference there, so the function-block analog of Bug 3 was avoided. |

### C syntax knobs (lines 153-157)

| Verdict |
|---|---|
| ✅ identical set to home (`c_gnu`, `c_no_cformat`, `c_space_errors`, `c_no_curly_error`, `unlet! g:c_comment_strings` — the `unlet!` form is the tidy replacement of HEAD's `if exists() | unlet | endif`). These are read at C-syntax-load time; set-anywhere-before-first-buffer works. Keep. |

### Plugin bootstrap & manifest (lines 159-188)

| Lines | Verdict |
|---|---|
| 159 | ✅ accurate placement note ("before plug#begin() call"). "nvim is shorthand of Neovim" → "nvim is the binary name of Neovim". |
| 160-163 | ✅ nvim/vim `data_dir` split correct. 🔀 if curl is missing, the bootstrap fails **silently** — home echoes a warning; and `silent execute '!curl …'` correctly suppresses the hit-enter prompt. The `--create-dirs` double space is cosmetic. |
| 164 | 🔧 **Bug 4** — autocmd escaped its `if`. Move back inside (or adopt home's `plug_bootstrap` augroup + git check, `~/.vimrc:458-463`). |
| 166-188 | 🔀 manifest deltas vs home: (a) `yegappan/mru` (line 185) is now **orphaned** — the rewrite repointed F2 to `:History` and dropped `<Leader>r :FZFMru`, but the plugin still installs and loads; home dropped it (documented: fzf `:History` needs no state file; leftover DB `~/.vim/.mru_files` is deletable). (b) `preservim/nerdcommenter` (177) — home replaced it with `tpope/vim-commentary` (documented reasons: heavyweight, per-ft `commentstring` support, frees the whole `<Leader>c*` prefix). (c) missing `mattn/emmet-vim` and `pangloss/vim-javascript` (home's CS50W additions). (d) dropping `vim-airline-themes` vs HEAD is **correct** — gruvbox ships its own airline theme (home documents this) — but the file nowhere says why; one comment would prevent a future "was this lost?" moment. (e) the per-plugin comments home carries are worth porting — they're the manifest's own documentation. |

### Plugin tuning & commands (lines 190-206)

| Line | Verdict |
|---|---|
| 190-197 | ✅ all match home (`asyncrun_open=10`, `tagbar_sort=0` new-and-good — 0 = source order, `tagbar_autofocus`, airline set incl. `buffer_idx_mode`). 🔀 home adds the documented `buffer_nr_show` OFF rationale (double numbers, gappy bufnrs) — port the comment so the *absence* is explained. |
| 198 | ✅ closetag list = home's; home's comment explains the jsx/tsx-vs-plain-js choice — worth copying. |
| 200 | ✅ comment accurate — "Universal Ctags" is the project's name, not a grammar slip. |
| 201 | 🔀 `,/usr/local/etc/systags` — **file does not exist** (probed). Harmless (vim skips missing tags files) but misleading; home dropped it. Drop, or actually build systags there. |
| 202 | ✅ `RR` = home. |
| 203 | 🔀 `Make`: keep `-bang`, but drop `-complete=file` (args are make **targets**) and consider home's `-cwd=<root>` (asyncrun walks up to the project marker — same walk-up idea as `'tags'` `./tags;`). |
| 205 | ✔️ verified `--sortr=modified` is a **valid rg flag** (`rg --files --sortr=modified` exit 0). Equivalent to home's differently-quoted line. ✅ |
| 206 | 🧹 bare autocmd (no augroup) — fine until something re-sources the file… which Bug 4 makes happen **every startup**. Wrap in an augroup like home (`~/.vimrc:555-558`). `++nested` is correct and load-bearing. |

### Toggles & mappings (lines 208-257)

| Lines | Verdict |
|---|---|
| 208-214 | ✅ `ToggleYcmDiags` works; the `get(getloclist(0,{'winid':0}),'winid',0)` shape correctly follows the memory note's what-dict gotcha (guard against silent `{}`). 🔀 home's is strictly more robust: first checks *standing inside* the loclist (`win_gettype()`) and uses `win_getid()` instead of `0` — port when convenient. |
| 216-233 | 🔧 **Bug 3** (line 232, `s:QfWinid`) and **Bug 8** (E32 on unnamed modified; line 227-229; **FIXED 2026-09-01**, guards at :231/:238). Also line 222: unguarded `g:asyncrun_status` → E121 if asyncrun isn't loaded; home: `get(g:, …, '')` — **FIXED 2026-09-01** (`get(g:, …, '')` now at :231). Also missing home's "standing in the quickfix window → close" branch and modifiable/readonly checks. **Simplest full fix: replace the body with home's `s:ToggleBuild` + `s:PanelWin`/`s:FocusPanel` trio** (`~/.vimrc:561-639`). |
| 235-240 | ✅ F1-F5 match home. F6 unused (gap only you can judge). |
| 241 | 🔧 **Bug 7** — bare `:MarkdownPreview`; port home's guarded `s:MarkdownPreview()`. |
| 242-245 | ✅ `<Leader>b/f` — `:Buffers`/`:Files` exist (grep of fzf.vim plugin). `<Leader>g :Rg` — ✔️ **probed innocent**: `:Rg` **does** exist (`fzf.vim:63`); note home switched to `:RG` (`fzf.vim:64`), the newer `grep2` async API (incremental re-query); both work — pick `:RG` when porting for symmetry. `<Leader>/ :Blines` ✅ (`fzf.vim:59`). |
| 247-251 | ✅ airline index loop — identical to home, including the script-local `s:i` (avoids the global-survives-re-source trap) and recursive `nmap` (required for `<Plug>` RHS expansion — home's deep-dive §11 documents why `nnoremap` would break it). |
| 253-257 | ✅ YCM leaders = home's `ji/jt/jd/jh/jr` (good rename away from HEAD's `fi/gt/…` which collided with fzf/grep prefixes). |

### YCM config (lines 259-267)

| Line | Verdict |
|---|---|
| 259 | ✅ `ycm_auto_hover = ''` — but 🔀 the paired manual trigger is missing: home's `nmap <Leader>K <Plug>(YCMHover)` (`~/.vimrc:755`). Without it, hover is *fully* dead (no auto, no manual). |
| 260-263 | ✅ = home (autoclose preview, distro clangd path, iwyu + background-index + `-j=4`). |
| 264 | 🧹 `ycm_complete_in_strings = 1` — YCM's default is already 1; the line is a no-op (home dropped it). Harmless as self-documentation; keep only if you *want* the default pinned. |
| 265-267 | ✅ `ycm_complete_in_comments` is a real enable (default 0) — home has it too; `goto_buffer_command`, `<C-Z>` invoke all match. |

### Indent policy (lines 270-315)

| Line | Verdict |
|---|---|
| 270-273 | ✅ content = home's `s:GnuIndent`. 🧹 style: `function! GnuIndent()` is **global** (no `s:`) — home scopes it `s:`; the global name needlessly publishes into the `g:` function namespace. |
| 275-290 | ✅ `s:AsmIndent` identical to home's; `indentexpr=s:AsmIndent()` set from this script works (the `s:` resolves in the defining script's context). |
| 292-298 | ✅ `s:CloseTransientList` = home (correctly closes *either* list type — better than HEAD's bare `:cclose`). |
| 300-303 | 🧹 comment typos: line 301 "isnerts" → "inserts"; line 303 "control" → "controls". The four definitions themselves are the best comment block in the file. |
| 304-315 | ✅ augroup discipline correct. 🔧 line 309 = **Bug 6** (`textwidth=0` regression). Line 311's asm `indentexpr` ✅. Lines 312-314 `q`-closes ✅ = home. Note line 308: `cinoptions=:0,g0,(0,w1` — the `cindent` switch arrives via `filetype plugin indent on` loading `indent/c.vim` (notes §4 probe), so these knobs actually apply — the switch/payload pack is complete by construction. |

---

## 3. Probed innocent — things that *look* wrong but are fine

You asked for care over every line, *especially* comment lines. Several suspicious patterns were probed today and are **clean** — don't "fix" these:

| Suspicion | Probe result |
|---|---|
| Trailing `"` comment after `:packadd` (line 3) | Stripped correctly; `editexisting` lands in `&rtp` identically with/without comment (match=95 both). |
| Trailing comment after `:source` (line 7) | Stripped; `exists(':Man')` = 2 with the comment. |
| Trailing comment after `:set` (line 17) | Stripped; `&enc` set correctly. |
| Trailing comment after `:if` (the style `~/.vimrc:95` uses) | Body **runs**; no error. The `:map`/`:au` no-trailing-comment rule does *not* extend to `:if`/`:set`/`:source`/`:packadd`. (A trailing comment on an `au …setlocal …` line even registered fine — but keep following home's "comments above" discipline; it's where the *safe* habit lives.) |
| `set undodir=~/.vim/undodir` — does `~` expand? | Yes, at set-time: raw value is `/home/ken/.vim/undodir`, `isdirectory` = 1. No literal-`~` dirs exist. The whole undo block is sound. |
| `--sortr=modified` in `$FZF_DEFAULT_COMMAND` (line 205) | Valid rg flag (exit 0). |
| `<Leader>g :Rg` — wrong command name? | `:Rg` exists (`fzf.vim:63`); `:RG` (line 64) is the newer async variant home uses. Not broken — just the older API. |
| `au FileType c.cpp` — maybe vim parses it as two filetypes? | No — probed: `c.cpp_fired=no`. Bug 1 stands. |
| `Plug 'airline-themes'` removed vs HEAD | Correct removal — gruvbox ships its own airline theme. |

---

## 4. Answers to the questions the comments ask

### 4.1 `~/.vimrc:22` — "Maybe redundant?" (`unlet! skip_defaults_vim`)

**Yes, redundant — on Arch, and in this file.** Two independent reasons, both verified: (1) `skip_defaults_vim` only gates vim's *automatic* loading of defaults.vim, which happens **only when no vimrc exists** — but you have a vimrc, and you `source defaults.vim` **explicitly** (line 6), which ignores the flag entirely. (2) Nothing on this box sets it anyway: `/etc/vimrc:18` ships `let skip_defaults_vim=1` commented out. The repo's commented-out line 4 and home's live line 23 are behaviorally identical. Keep whichever reads better; know that it's ritual.

### 4.2 `~/.vimrc:42` — "Here whether we need set spell firstly?"

**No.** `spelllang` is the *payload*, `spell` is the *switch* — the payload can be configured while the switch is off, in any order (probed: `set spelllang+=cjk` with spell off → `spelllang=en,cjk`, no error, nothing checked until spell turns on). That's the whole point of the switch/payload pattern the notes use (`cindent`+`cinoptions`, `textwidth`+`formatoptions`). The *remaining* question is behavioral, and the twins currently disagree: repo line 15 **sets spell** (checking on everywhere, notes-blessed "correct — merged switch + payload"), home leaves it off. Decide once, mirror it.

### 4.3 Line 30-33's "weird `:term` color rendering" — solved, not open

The comment describes the exact problem home's `g:terminal_ansi_colors` block fixed (2026-08-31, screenshot pixel-pass): `termguicolors` covers vim's own paint but *not* the ANSI 0-15 palette child programs emit inside `:terminal`; left unset, vim's stock VGA palette glows. Port the block; delete the stale comment.

---

## 5. Prioritized patch list (drop-in, in order)

Nothing below is applied — the file is untouched. Copy/merge at your leisure.

**P0 — the three daily-path bugs**

```vim
" 1. fix lines 92-93: comma, and no trailing space
au FileType c,cpp  nnoremap <buffer><silent> <S-Tab> :call <SID>ClangFormat()<CR>
au FileType c,cpp  xnoremap <buffer><silent> <S-Tab> :call <SID>ClangFormatRange()<CR>

" 2. fix line 129: no argument means "normal mode" (a:0 == 0)
nnoremap <silent> <Leader>p :call <SID>PasteClipboard()<CR>

" 3. fix line 232 + add helpers (port from ~/.vimrc:573-604, quoted in §1 Bug 3)
call s:FocusPanel('quickfix')
```

**P1 — startup & regression**

```vim
" 4. move line 164 back INSIDE the if at 161-163 (first-boot only), or:
augroup plug_bootstrap
  au!
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
augroup END
" …placed inside the !filereadable(plug.vim) guard

" 6. line 309 — restore the lost fix
au FileType sh,vim setlocal expandtab shiftwidth=2 softtabstop=2 textwidth=0
```

**P2 — dead code & traps**

```vim
" 5. delete lines 148-151 (live twins in ~/.vim/ftdetect/cpp.vim:19-20)
" 7. F8 — port s:MarkdownPreview() guard from ~/.vimrc:651-665
" 8. ToggleBuild: port ~/.vimrc:609-639 (unnamed-buffer warning, modifiable/
"    readonly guards, get(g:,'asyncrun_status',''), standing-in-qf branch)
```

**P3 — quality ports from `~/.vimrc`** (each already verified there, with rationale in its comments): the `termguicolors` + `terminal_ansi_colors` block (65-89) · `shellpipe` fix (423-425) · formatter guards `s:MissingTool`/`s:FilterFailed` (132-151) · clipboard hardening (267-273, 300-302, 315-319) · `Grep`/`Make` command tweaks (405, 570) · colorscheme augroup (555-558) · `<Leader>K <Plug>(YCMHover)` (755) · manifest sync: `+commentary +emmet +vim-javascript, −nerdcommenter −mru` · per-plugin comments · `buffer_nr_show` OFF comment.

**P4 — new settings the notes verified as real 9.2 gaps**

```vim
set autoindent    " still OFF out of the box in 9.2 — load-bearing for md/text
                   " (engine-less buffers: without it, Enter lands at col 1)
set hlsearch      " still OFF out of the box — your :noh map (line 48) presupposes it
set wildmode=longest:full,full  " Tab: longest prefix + menu, then cycle
```
(`backspace`, `wildmenu`, `history`, `undolevels`, `showcmd`, `ruler` — all default-on in this 9.2 binary; **do not** add them.) Optional, taste-level: `colorcolumn=80`, `sidescroll=1 sidescrolloff=5`, drop `set enc=utf-8` as redundant.

**P5 — 🧹 janitor list:** typos `Afer`→After (57), `isnerts`→inserts (301), `control`→controls (303), `do_no_lazyload_menu`→`do_no_lazyload_menus` (145, verified against `menu.vim:399`) · delete the dead `"set signcolumn=auto` (19), stale `pyxf` map (49), dead comment at 140 · drop `,/usr/local/etc/systags` (201, file missing) · consider `s:`-scoping `GnuIndent` (270) · decide spell on/off and F1-vs-`<Leader>y` copy, then mirror in both files.

---

## 6. What the rewrite got right (credit where due)

- **Adopted nearly every verified-review recommendation:** `hidden` (20), `scrolloff 0→3` (21), `updatetime=300` (22), `wildignore` (28), `wildoptions+=fuzzy,pum` (27), `nnoremap/xnoremap Q` (45-46), `:noh<CR>` cleanup (48), `let &grepprg` over escaped `set` (135) — plus the notes-blessed merged `spell` line (15).
- **New working subsystems HEAD lacked entirely:** the whole Shift-Tab formatter family, F4/F5 toggles, asm indent engine, airline index-jump loop, `tagbar_sort=0`, closetag config, `textwidth`-aware (mostly) indent table, `q`-closes for help/man/qf (qf now via `CloseTransientList` — better than HEAD).
- **Structural hygiene:** every `augroup` carries `au!` (re-source idempotent); no trailing comments on `:au`/`:map` lines (except the one trailing *space*); clipboard falls back through three backends with `exists()` gating; mappings consistently `<silent>`; the `s:` script-local discipline is nearly uniform (`s:i` in the loop, all helpers).
- **The what-dict gotcha from the memory note is correctly applied** in both toggles: `get(…, 'winid', 0)` guards the silent-`{}` trap.

---

## 7. The short version of the whole story

The rewrite took HEAD, folded in the options-review's verdicts, and grew a leaner twin of `~/.vimrc` with real new machinery — formatters, toggles, asm — and better hygiene throughout (non-recursive maps, augroups, guards). But a rewrite is a re-diff of every fix you ever shipped, and three classes of casualty showed up: **call sites outliving their deleted helpers** (`s:QfWinid`), **HEAD fixes silently dropped** (`textwidth=0`), and **snippet lines migrating out of their guarding `if`** (`PlugInstall`). On top of that, two new code paths encode a beginner-shaped misunderstanding — `c.cpp` as a "filetype list" (it's one regex) and `PasteClipboard(0)` as "no argument" (`a:0` counts arguments, not values). All eight bugs are confirmed by probe or on-disk citation, and every one already has a proven corrected twin in `~/.vimrc` — the port list in §5 is therefore assembly, not design.

---

## 8. The transferable principles (the part you keep)

1. **Autocmd patterns are regexes, comma-separated.** `c.cpp` is one pattern matching a filetype spelled `c?cpp`. Registering succeeds; matching silently fails. Verify with `:doautocmd FileType cpp`.
2. **`a:0` counts; `a:1` values.** `call F(0)` passes one argument. "No argument" is `F()`.
3. **A rewrite must re-diff its own git history**, not just its sources — every deleted helper needs a grep for surviving call sites (`grep -n 's:Name(' | vs 'function! s:Name('`), every dropped line a check against "which bug did this fix?" (the commit message and `~/notes/vimrc-audit-2026-08-29.md` are the index).
4. **Autocmds at script level are conditional by placement, not content.** vim-plug's bootstrap keeps `autocmd VimEnter … PlugInstall` inside its `if` because *registration* is the one-time act.
5. **`filetypedetect` is vim's group; `ftdetect/*.vim` is the only survivor of the `filetype off→on` cycle.** In-vimrc detection rules are eggs in a basket `plug#begin()` empties.
6. **A vimrc runs once; ftplugins run per-buffer, later.** To beat `ftplugin/vim.vim:133`'s `tw=78`, the `textwidth=0` must ride the same `FileType` event — earlier-in-file doesn't mean later-in-time.
7. **Lazy plugins create their commands at load time** — any mapping to `:MarkdownPreview` needs `exists(':Cmd') == 2` at press time, not at vimrc time.
8. **Trailing-comment legality is per-command-family**: stripped after `:set`/`:if`/`:source`/`:packadd` (probed), *not* after `:map` (becomes keystrokes) — and the safe discipline is comments on their own lines above.
9. **Options are checked in packs** (switch + payload): `spell`+`spelllang`, `hlsearch`+your `:noh` map, `cindent`(from indent/c.vim)+`cinoptions`. A payload without its switch, or a switch without its payload, is the most common silent dead setting.
10. **The twins must be re-synced as one act.** `~/.vimrc` and the repo copy are separate files (verified again: not symlinks); every port you accept from §5 should land in both, or the next rewrite of either re-opens the same bugs.

---

## 9. Where to go next

- Apply P0 first — three lines, three daily-path fixes — then `vim -es -u NONE -S /tmp/vimrc_probes.vim` still works as a regression probe (probe G/K/I are your canaries).
- Re-run the F4/F5 verification flow from the 2026-08-31 memory note after porting `s:PanelWin`/`s:FocusPanel`.
- Decision points that are yours alone: spell on/off · F1 vs `<Leader>y` for visual copy · keep or drop the GUI block / `enc=utf-8` · `nerdcommenter`→`commentary` swap · `:Rg`→`:RG`.
- Related: `~/notes/vim-set-options-verified-review.md` (§5.1 for the 9.2 compiled-in defaults), `~/notes/vimrc-audit-2026-08-29.md`, and the memory notes on qf-window APIs.

---

## 10. Second-pass verification (2026-08-31, evening)

An independent redo of this review (fresh session): re-probed every claim
headlessly, audited this file's verdicts, found one new bug, and made three
corrections. **The 8 bugs in §1's table all stand** — each mechanically
checkable one was re-verified live: `c.cpp` never fires (`au FileType c.cpp`
→ 0 hits / `c,cpp` → 1), `ProbeVararg(0)` → `a:0=1`, `:update` on a modified
unnamed buffer → `E32: No file name`, `function /QfWinid` → *nothing* while
`.vimrc:232` calls it, `exists(':MarkdownPreview')=0` with F8 mapped bare,
VimEnter handlers stack ×2 after one re-source (Bugs 10-11), `grep -n ' $'`
confirms line 92 is the file's only trailing-space line.

### 10.1 NEW — Bug 9: `s:GnuIndent()` does not exist (`E117` on `/usr/include/*`)

`.vimrc:270` defines **`function! GnuIndent()`** (global), but the call site at
`.vimrc:306` is `call s:GnuIndent()` — a *script-local* name that was never
defined. Probe (opening `stdio.h` with the repo vimrc, messages captured):

```
Error detected while processing command line..BufRead Autocommands for "/usr/include/*":
E117: Unknown function: <SNR>1_GnuIndent
```

So browsing glibc headers throws once per file. Fix: add the `s:` at line 270
(home's shape, `~/.vimrc:774`); the call site is already correct. **One-line
fix — promote it into §5's P0 list.** (Bugs 3 + 9 are the same shape: the
rewrite kept call sites whose definitions it renamed/deleted; grep every
`s:Name(` call against `function! s:Name(` before shipping.)

### 10.2 CORRECTION — `:set <opt><` is *not* "reset to the default value"

Repo line 12's comment, my old note (`vim-set-options-verified-review.md` §7),
and §2's endorsement of the cheat-sheet block here all describe `set <opt><`
wrong. Probed:

```
tw:  set tw=79 → set tw<     → tw stays 79, no error   (plain-local: silent no-op)
     set tw=79 → set tw&     → tw = 0                  (& is the real reset)
so:  set so=10 (g=10,l=-1) → setlocal so=5 (l=5) → setlocal so< → l=-1 (inherits g)
```

**True semantics:** `:setlocal <opt><` *clears the local side* so the option
inherits its global value (meaningful only for global-local options like
`scrolloff`); on plain-local options it is a silent no-op. Reset-to-default is
`:set <opt>&`. The cheat comment at `.vimrc:12` should say:

```vim
" Reset:     :set <opt>& (default value)    :setlocal <opt>< (inherit global)
```

> **Common beginner confusion:** "`<` must be *less-than the default*, so it
> resets." `<` here means *"look up-arrow to the global value"*, and only
> `:setlocal` has a local side to clear. `:set <opt><` on a plain-local option
> doesn't even warn — the most dangerous comment is one with false confidence.

### 10.3 CORRECTION — `wildignore` and `__pycache__` (`.vimrc:28`)

§2 called the line "notes-blessed verbatim". Probed `glob('/tmp/wi/**/*')`:

| Pattern set | `__pycache__` dir itself | `__pycache__/x.pyc` |
|---|---|---|
| bare `__pycache__` (repo) | hidden ✔ | **still listed ✗** |
| `*/__pycache__/*` | listed | hidden ✔ |

A bare pattern matches the directory *entry* but not its *contents*; a
slash pattern matches contents but not the entry. For full coverage use both:
`set wildignore=*.o,*.a,*.so,*.d,*.min.*,__pycache__,*/__pycache__/*`.
(Added to the P4 patch list.)

### 10.4 CORRECTION — the map trailing-space claim is *true* (own false negative)

A first headless probe suggested `<S-Tab>`'s RHS was clean. The probe *file*
had its trailing space silently trimmed by the file-writer — harness bug, not
vim mercy. Rebuilt with a guaranteed space:

```
nnoremap <silent> <S-Tab> :call Foo()<CR>·  →  maparg RHS = ':call Foo()<CR> '
nnoremap <silent> <F9> :echo 1<CR> " a comment → RHS = ':echo 1<CR> " a comment'
```

Both trailing blanks *and* comments become part of a `:map` RHS (contrast with
§3: `:packadd`/`:source`/`:set` strip trailing comments — probed identical with
and without). Line 92's trailing space would type a space after formatting —
except Bug 1's `c.cpp` pattern means the mapping is never installed anyway.
Methodology lesson: **verify the probe harness before trusting the probe** —
the same flake class as the 2026-08-29 `:Grep` scare.

### 10.5 NEW — facts from the live inventory (sourcing the repo vimrc headlessly)

- `has('clipboard') == 0` — the native `"+` branch (lines 100-104) is **dormant
  on this build**; the `wl-copy` fallback path (incl. Bug 2) is the live one.
  `has('clientserver') == 1` → editexisting works in *terminal* vim, so line 3's
  comment "For gvim" undersells it.
- `enc == utf-8` even with `-u NONE` (derived from `LANG=en_US.UTF-8`) → line 13
  is locally redundant (keep only for travel; the notes' verdict stands).
- Plugged-dir drift: `~/.vim/plugged/` does **not** contain `nerdcommenter` or
  `mru` (home dropped both), but the repo manifest still lists them → Bug 4's
  unconditional `PlugInstall` would *reinstall* them next startup. Conversely
  `emmet-vim` and `vim-javascript` exist on disk (home's additions) but not in
  the repo manifest → `:PlugClean` would delete them. The manifest, the twin,
  and the disk must be synced as one act.
- `\K` is already mapped — by the man ftplugin sourced at line 7
  (`:call dist#man#PreGetPage(0)<CR>`). Home's `<Leader>K <Plug>(YCMHover)`
  port would *override* it (later definition wins): fine if deliberate, but
  know you're trading "man page for word under cursor" for YCM hover.
- `exists(':RG') == 2` already (`fzf.vim` ships both: `:Rg` = fixed query,
  `:RG` = re-query per keystroke via `grep2`). The repo can switch with one
  letter; no new command needed.
- `defaults.vim:62` still maps `Q`→`gq` — the rewrite's `Q <Nop>` (line 45-46)
  wins because line 6 sources defaults.vim first; order is load-bearing.

### 10.6 Updated verdict for this file

§0's "8 bugs" → **9 bugs** (add Bug 9, P0). The remaining claims of this file
were re-checked against either a re-run probe or on-disk citation and stand.
Probe harnesses kept this time: redir-to-file output (in `-es`, `:echo` to a
captured stdout pipe prints nothing), `-S` scripts instead of `-c` chains (the
10-`-c`-argument limit bit once), and printf-built files when whitespace
matters.

---

## 11. Third pass — after Ken's partial fix (2026-08-31, 23:30 edit)

Ken hand-applied part of §5 at 23:30 (working file now 325 lines). Fresh
headless probes against the CURRENT file (`/tmp/vrc_probe.vim` →
`/tmp/vrc_probe_out.txt`; replica function `/tmp/paste_replica.vim`).

### 11.1 Fixed by Ken's edit (probe- or grep-verified gone)

- **Bug 1** — `au FileType c,cpp` on both lines (96-97); the trailing space
  is gone too (`grep -n ' $' .vimrc` → empty file-wide).
- **Bug 2's call sites** — `PasteClipboard()` normal / `PasteClipboard(1)`
  visual (lines 133-134). But the body broke — see new Bug 10 below.
- **Bug 3** — `s:QfWinid()` replaced by the documented
  `get(getqflist({'winid':0}),'winid',0)` API, inline (lines 222/237).
- **Bug 4** — `autocmd VimEnter * PlugInstall --sync | source $MYVIMRC` is
  back INSIDE the bootstrap `if` (lines 159-163).
- **Bug 9** — `function! s:GnuIndent()` now `s:`-scoped (line 275); call
  site (316) matches.
- **Bug 5** — *effectively* fixed by relocation: the filetypedetect block
  (207-210) now sits AFTER `plug#end()`, so `plug#begin()`'s `:filetype off`
  can no longer wipe it. Probe P4: the rule fires (fired=1). What remains is
  harmless redundancy with `~/.vim/ftdetect/cpp.vim:19-20`.
- Also landed from P3/P4: `set hlsearch` (the `:noh` map now has a job), the
  `termguicolors` + `g:terminal_ansi_colors` block, manifest synced with
  disk (commentary/emmet/vim-javascript in; nerdcommenter/mru out), the
  colorscheme autocmd augrouped as `theme`, `:Make` gained `-bang`.

### 11.2 NEW — Bug 10: `else if` is not vimscript (E488 on every paste)

Ken's Bug-2 fix changed the call sites but the body now reads
(`.vimrc:121-127`):

```vim
if a:0
  ...
else if a:1 == 1   " legacy VimL has NO 'else if' — the keyword is :elseif
  ...
endif
```

Probe (byte-faithful replica): the function **defines** without complaint
(legacy vimscript parses commands lazily), but EVERY call throws:

```
P1b ProbePaste(1) -> ERROR: Vim(else):E488: Trailing characters: if a:1 == 1
P1c ProbePaste()  -> ERROR: Vim(else):E488: Trailing characters: if a:1 == 1
```

Both arities fail — when an `:if` is true, Vim still *parses* the skipped
`:else` line while scanning for the matching `:endif`, and `:else` accepts
no trailing characters. This build is `-clipboard` + Wayland, so this
fallback path IS the live one → **`<Leader>p` currently throws in all
modes.** Fix for the new call sites (`()`=normal, `(1)`=visual): plain
`else` for the normal branch. (The `if a:1 == 1` was dead weight anyway: in
the `else` you are guaranteed `a:0 == 0`, so `a:1` doesn't exist —
referencing it would have been E121 had E488 not fired first.)

### 11.3 Still standing from the original 9 (re-probed today)

- **Bug 6** — P2: `ft=vim` → `tw=78` with current line 319 (`textwidth=0`
  still missing). Wrap-at-78 regression is LIVE in `.vim` files.
- **Bug 7** — P5: `exists(':MarkdownPreview')=0` pre-lazy-load → F8 is E492
  outside markdown (line 246).
- **Bug 8** — P3: modified unnamed buffer + `:update` →
  `E32: No file name` → F5 aborts before `Make` (lines 232-234); line 227's
  unguarded `g:asyncrun_status` is still an E121 risk if asyncrun is absent.

### 11.4 Verdict

Original 9 → **3 still standing**; **1 new** (Bug 10, daily path, introduced
by tonight's partial fix). Remaining repairs = §5 P1/P2 remnants + the
two-word `else if`→`else` fix. Everything else re-probed clean or matches
earlier verdicts.

## 12. Fourth pass — 2026-09-01 re-review (file state: Sep 1, 00:44, 325 lines)

The 00:44 edit closed **bug 6**: `textwidth=0` is back inside the
ft_config block, now `.vimrc:319` (probed live: `ft=vim` buffer → tw=0,
`:verbose set tw` credits line 319). Also gone: the wrong
`:set <opt><` teaching comment from the first rewrite. Lint pass
(smoke-test.vim's own regexes, run against the repo file): **0**
trailing-whitespace lines, **0** `PasteClipboard(0)` sites, **1**
`else if` (line 125), **1** `:Blines` (line 250). Startup re-probe:
zero E-numbers in `:messages`; every command/map/group alive except the
items below. Clean bill: `--sortr=modified` in `$FZF_DEFAULT_COMMAND`
(:206) verified working on ripgrep 15.2.0 (exit 0, newest-first).

### 12.1 New findings this pass

- `.vimrc:250` `:Blines` — **Bug 11**: fzf.vim:59 defines `:BLines`
  only; user commands are case-sensitive → `<Leader>/` = E492.
  One-character fix.
- `.vimrc:143` `:Grep` hardcodes `AsyncRun!`. **Corrected claim** (the
  earlier "won't auto-open qf" framing was wrong): per asyncrun.vim:11
  the bang disables quickfix auto-SCROLL — opening is `g:asyncrun_open`'s
  job (=10 here, line 191). Net effect stands: you can never get
  auto-scroll back. Home:405 passes `<bang>` through and drops
  `-complete=file` (the argument is a pattern, not a filename).
- `.vimrc:204` `:Make` still lacks `-cwd=<root>` (macro documented at
  asyncrun.vim:26, implemented :2183; home:570 and proposal v2:619 carry
  it) → make runs in the buffer's directory, not the project root.
  Also `-complete=file` is wrong for make targets.

### 12.2 Still standing (re-verified)

Bugs 7 (F8 `:MarkdownPreview` E492, :246), 8 (`update` → E32 on a
modified unnamed buffer, :232-234; plus :227 `g:asyncrun_status`
unguarded → E121 pre-PlugInstall), 10 (`else if`, :125). Plus the §5
P2-P4 remnants that never got bug numbers: formatter guards absent
(:56-93; home:132-151 / v2:194+221 shape), bare `__pycache__` lost from
wildignore (:30), `<Leader>y` nnoremap exists only in the non-live
`has('clipboard')` branch (:106 vs :133), YCM bundled-clangd mismatch
✅ fixed repo 2026-09-01 — :188 hook now bare `./install.py` + why
comment; verified on-disk: distro clangd 22.1.8 (`pacman -Q clang`),
`g:ycm_use_clangd` default '1' = "third-party *or* ycm_clangd_binary_path"
(ycm doc:3946), flag's only job is to *download* (ycm doc:1333);
fresh-clone PlugInstall re-verify still owed; home:516/:759 same shape —
decide once, systags path dead
(:202), ftdetect rules duplicated repo:208-211 ↔
`~/.vim/ftdetect/cpp.vim:19-20` (currently deduped by the inline
`au!` since plug#end's sweep runs first; drift trap, not a bug).

### 12.3 Attribution note

Third-pass memory recorded Claude porting the tw=0 fix onto the repo
copy "at :322 with a two-line comment" — disk truth is :319, no
comment. The 00:44 mtime fits either Ken's hand-edit or that parallel
pass (line-count arithmetic — 23:54's 327 lines vs today's 325 —
permits a commented intermediate, but also fits Ken editing alone);
not resolvable from mtimes. `git diff` audits the full uncommitted
state either way. Surfaced to Ken in the re-review reply.

### 12.4 Verdict

Original 9 → **2 standing** (7, 8). Bug 10 came with the 23:54 fix;
**Bug 11 (`:Blines`)** found this pass. Priority for the current file:
:125 `else if`→`else` (P0) → :250 `:BLines` (P1) → :246 guard (P1) →
:227/:232 hardening (P2) → :204 `-cwd=<root>` (P2) → :143 `-bang`
passthrough (P3) → formatter guards (P3) → P4s (wildignore twin entry,
systags, ftdetect single-source, `<Leader>y` symmetry; YCM
double-clangd fixed repo-side 2026-09-01). The v2 proposal at `vimrc-claude/` already carries
every one; its smoke-test.vim lints the else-if/arity/F8 classes
(verdict: ALL CHECKS PASS).

## 13. Fifth pass — 2026-09-01 (plugin-analysis session; working tree now 329 lines)

Read-verified on disk: **bugs 7, 10, 11 are FIXED** — F8 now carries an
expr-guard `exists(':MarkdownPreview') == 2` (`.vimrc:249`), the legacy
`else if` is `elseif` (`.vimrc:126`), and `<Leader>/` maps `:BLines`
correctly (`.vimrc:253`). **Bug 8 — the last one standing — FIXED
2026-09-01 evening (clang-format session)**: `.vimrc:231` now reads
`get(g:, 'asyncrun_status', '')` and `.vimrc:238` adds `&& !empty(bufname())`
to the `update` guard; both failure modes were repro'd headless (E32, E121)
and both idioms verified safe; working tree now 331 lines, full vimrc
re-sources clean. Net: original 9 + 10 + 11 → **zero standing bugs**.
Side records from the same session:
plugin inventory measured — 22 plugins, manifest == disk, ~70 ms total
script sourcing (heaviest nerdtree 19.6 ms); 2.28 s startup wall was 2.0 s
of a single `Warning delay` (startup-message pause, not plugin cost);
gitgutter's default maps verified ON (plugin/gitgutter.vim:77) though the
vimrc never documents them. Full inventory + recommendations:
`vimrc-plugin-analysis-2026-09-01.md`.