# `.vimrc` plugin usage analysis + recommendations (2026-09-01)

**Reviewed:** `~/config_files/.vimrc` (working tree, 329 lines) against the live
install `~/.vim/plugged/` (22 dirs — exactly matches the manifest, `:PlugClean`
would remove nothing).
**Verified today:** default keymaps grepped from the installed plugin sources
(gitgutter, emmet, visual-multi, unimpaired); startup cost measured with
`vim --startuptime` against the *repo* vimrc, not `~/.vimrc`.

---

## 0. The one picture

Your 22 plugins sort into **four usage tiers**, and the tiers matter more than
the count:

```
TIER 1  the IDE loop (deeply wired: config + maps + commands)
        YCM · fzf.vim · asyncrun · airline
TIER 2  F-key panels (one key each, then set-and-forget)
        F1 nerdtree · F3 tagbar · F7 calendar · F8 markdown-preview
TIER 3  zero-config verbs (pure muscle memory, no setup ever needed)
        commentary · surround · repeat · unimpaired · eunuch · searchindex
TIER 4  installed but silent (no maps, no config in your vimrc)
        fugitive · emmet · visual-multi · gitgutter(keys) · vim-javascript
```

**Tier 4 is the actual finding:** 5 plugins are present on disk but your vimrc
gives them *no* keybindings or settings — they run on factory defaults you may
never have learned. Installed ≠ used.

---

## 1. What a plugin even is here (What → Why → How)

**What.** Every entry in `call plug#begin()` … `call plug#end()`
(`.vimrc:168-191`) is a git repo cloned into `~/.vim/plugged/<name>/` and added
to vim's `runtimepath`. vim-plug (`plug.vim`, bootstrapped at `.vimrc:162-166`)
is just the downloader/loader.

**Why.** Vim core deliberately stays small: no fuzzy finder, no completion
engine, no git integration. Plugins fill those gaps. Each `Plug` option has one
job: `'do'` = post-install hook (build the binary: YCM's `./install.py` at
`.vimrc:189`, fzf's `fzf#install()` at `:173`); `'for'` = lazy-load by filetype
(markdown-preview at `:172` — which is exactly why F8 needed the
`exists(':MarkdownPreview')` guard at `.vimrc:249`).

**How a plugin becomes *usage*.** Three ways to be "used": (1) a mapping in
your vimrc (fzf's five keys), (2) a setting in your vimrc
(`g:tagbar_sort = 0` at `:194`), (3) *the plugin's own default keys that you
memorized* (commentary's `gcc`). Tiers 1–2 use (1)+(2); tier 3 uses (3);
tier 4 uses (3)-only-and-nobody-taught-you-the-keys.

---

## 2. Full inventory — 22 plugins, one row each

Legend — **Wired:** where the plugin appears in your `.vimrc`. **Daily keys:**
what you actually press (verified against installed sources where marked ✓disk).

| # | Plugin | Plain-words job | Wired at | Daily keys / commands | Tier |
|---|---|---|---|---|---|
| 1 | `ycm-core/YouCompleteMe` | the completion/jump/diagnostics brain (clangd via `:271` distro override) | `:268-275` (8 settings), maps `:205,261-266`, F4 `:245` | `<C-Z>` complete, `<Leader>jd/jt/jh/jr` goto, `<Leader>ji` fix-it, `<Leader>K` hover, `:RR` rename, F4 diagnostics | **1** |
| 2 | `junegunn/fzf` + `fzf.vim` | fuzzy finding over files/buffers/grep/history | `:173-174`, `$FZF_DEFAULT_COMMAND` = rg `:208`, maps `:243,250-253` | F2 history, `<Leader>f` files, `<Leader>b` buffers, `<Leader>g` ripgrep, `<Leader>/` lines-in-buffer | **1** |
| 3 | `skywind3000/asyncrun.vim` | run shell/make/grep in background into quickfix | `:193` (open height), `:Grep` `:145`, `:Make` `:206`, F5 `:246` | `:Grep foo`, `:Make test`, F5 build-toggle | **1** |
| 4 | `vim-airline/vim-airline` | statusline + buffer tabline | `:196-200`, leader-index loop `:255-259` | `<Leader>1..0/−/+` jump buffers | **1** |
| 5 | `preservim/nerdtree` | file tree sidebar | F1 `:242` | F1 toggle | **2** |
| 6 | `preservim/tagbar` | ctags outline sidebar | `:194-195`, F3 `:244` | F3 toggle | **2** |
| 7 | `mattn/calendar-vim` | calendar/diary popup | F7 `:247` (:CalendarH exists ✓disk) | F7 | **2** |
| 8 | `iamcco/markdown-preview.nvim` | live HTML preview in browser | lazy `'for'` `:172`, F8 expr-guard `:249` | F8 (inside markdown) | **2** |
| 9 | `morhetz/gruvbox` | colorscheme | `:178` → `colorscheme gruvbox` `:310`, airline theme `:197` | passive | 2 |
| 10 | `airblade/vim-gitgutter` | git diff signs in the gutter | none — but `updatetime=300` `:24` paces it | **defaults ON** (`g:gitgutter_map_keys=1`, ✓disk `plugin/gitgutter.vim:77`): `]c`/`[c` jump hunks, `<Leader>hs` stage, `<Leader>hu` undo, `<Leader>hp` preview, `ic`/`ac` hunk text object | **4** |
| 11 | `alvan/vim-closetag` | auto-close HTML/XML tags | `g:closetag_filenames` `:201` | passive — type `>` | 3 |
| 12 | `google/vim-searchindex` | shows "match 3 of 12" counter | none needed | passive — `/` and `n` | 3 |
| 13 | `tpope/vim-commentary` | toggle comments | none needed | `gcc` line, `gc{motion}`, `gcgc` | 3 |
| 14 | `tpope/vim-surround` | change/add/delete quoting & tags | none needed | `cs"'` `ds"` `ysiw)` `S"`(visual) | 3 |
| 15 | `tpope/vim-repeat` | makes surrounding/commentary `.`-repeatable | none needed | passive plumbing for #13 #14 — **but autoload-lazy, see §9.2** | 3 |
| 16 | `tpope/vim-unimpaired` | `[`/`]` pair navigation | none needed | ✓disk (doc): `]b/[b` buffers, `]q/[q` quickfix, `]l/[l` loclist, `]f/[f` files, `]t/[t` tags, `]e/[e` swap lines, `]n/[n` conflict marks, `]<Space>` blank line, `]o*` option toggles | 3 |
| 17 | `tpope/vim-eunuch` | Unix commands on the buffer's file | none needed | `:Delete`, `:Rename`, `:Move`, `:Chmod`, `:Mkdir`, `:SudoWrite` | 3 |
| 18 | `vim-airline` … see #4 | | | | |
| 19 | `tpope/vim-fugitive` | full git porcelain inside vim | **declared `:186`, never configured — zero maps** | you must *type*: `:Git status`, `:Git blame`, `:Gdiffsplit`, `:GBrowse` | **4** |
| 20 | `mattn/emmet-vim` | HTML/CSS abbreviation expansion | **declared `:177`, never configured** | default leader `<C-y>` (✓disk `emmet.vim:95`): insert `ul>li*3` then `<C-y>,` | **4** |
| 21 | `mg979/vim-visual-multi` | multiple cursors | **declared `:175`, never configured** | `<C-n>` select word under cursor → next match (✓disk `vm/maps/all.vim:50-51`); `n` next, `q` skip | **4** |
| 22 | `pangloss/vim-javascript` | JS syntax + indent files | **declared `:179`, passive** | nothing to press — paints/indents JS buffers | 4 |

(Rows compress the tpope fleet for readability; line numbers are exact from
`.vimrc:168-191`.)

---

## 3. Beginner confusions to kill on the spot

> **"It's in the Plug list, so it's part of my workflow."** No — tier 4 proves
> otherwise. `vim-fugitive` is arguably the best plugin you own and you get
> **nothing** from it until you learn `:Git blame` / `:Gdiffsplit`. Usage is
> keys you press, not directories on disk. The fix is cheap: one cheat-sheet
> comment block, or 3-4 maps.

> **"vim-javascript gives me JS *support*."** It paints and indents; it does
> not *understand*. Three different layers do three different jobs:
> **syntax plugins paint** (vim-javascript), **engines think**
> (YCM+clangd — jump/diagnose/rename), **external tools janitor**
> (clang-format/black via your Shift-Tab bridge `:96-104`). A plugin from one
> layer never substitutes for another.

> **"More plugins = slower vim."** Measured on this build (repo vimrc,
> `--startuptime`): all 22 plugin script files together ≈ **70 ms** (heaviest
> single one: nerdtree 19.6 ms; unimpaired 11.7; emmet 5.9; gitgutter 4.7;
> fzf+rg hooks ~5). Total wall was 2.28 s — but **2.0 s of it was one
> `Warning delay` item** (vim pausing after a startup message during the
> profiling run, not plugin sourcing — check `:messages` if it ever shows in
> daily use). Don't count plugins; *measure* them. The honest cost of your
> heaviest plugin is disk: YCM = **286 MB** after `./install.py`.

> **"'for' and 'do' are decoration."** `'do'` runs once at `:PlugInstall`
> (build hook); `'for'` makes the plugin load *only* on that filetype — and
> only *after that*, its commands exist. That distinction is why F8 needed an
> `exists()` guard but a `'on': 'Command'`-lazy plugin does not: vim-plug
> creates a **stub command** for `'on'` (pressing it loads the plugin, then
> runs the real command), while `'for'` creates nothing until the filetype
> fires. (Bug-7 lesson, now applied at `:249`.)

---

## 4. Honest cons of the current set (things to know, not necessarily fix)

- **Three file-finders overlap:** NERDTree (F1), fzf `:Files` (`<Leader>f`),
  and built-in netrw (`:Explore`). That's fine — different jobs (browse tree vs
  jump-by-name vs last resort) — but know which one you reach for and why.
- **gitgutter vs fugitive** are complementary (live gutter state vs git
  porcelain), but *today* you use the passive half of the pair: signs show,
  yet no maps call gitgutter's hunk actions and fugitive is fully manual.
- **calendar-vim** is the weakest link in the manifest — niche plugin, one
  F-key, a diary you may not keep. Candidate for `:PlugClean` if unused.
- **vim-visual-multi steals `<C-n>`** (and would shadow stock keyword
  completion keys in some flows) — acceptable, but it's the most
  "personality-heavy" default on the list.
- **airline + powerline fonts** (`:196`) is a font dependency: on a fresh
  machine without a patched font the statusline shows glyph garbage. Portable
  fix if it bites: `let g:airline_powerline_fonts = 0`.
- **Standing bug, unrelated to plugins but daily-path:** Bug 8 is still live —
  F5's `update` at `:234-236` throws **E32** on a modified `[No Name]` buffer,
  and `g:asyncrun_status` at `:229` is unguarded (**E121** if asyncrun ever
  fails to load). See `vimrc-analysis-2026-08-31.md` §12.4. *Fix that before
  adding anything new.*

---

## 5. Recommendations — what to actually add

Ranked by payoff-per-keystroke *for your setup* (C/C++ + Python + CS50W web +
asm + heavy markdown notes, YCM/already-fzf/already-tpope-fleet).

### Tier A — install today (each one closes a verified gap)

**1. `mbbil/undotree` → F6.** *What:* a visual tree of your undo history.
*Why you specifically:* you already run `undofile` + `undodir` + `mkdir 0700`
(`.vimrc:42-50`) — you pay for **persistent undo across sessions** but have no
way to *see* the branches; undotree is the missing viewer. F6 is the one free
F-key (F1,2,3,4,5,7,8 taken). *Cons:* none real; ~50 KB, lazy-loaded.

**2. `justinmk/vim-sneak`.** *What:* `s{char}{char}` jumps to any visible
two-letter spot, with labeled cross-screen jumping; `;` / `,` repeat — it
extends your existing `f`/`t` muscle instead of replacing it. *Why:* your
motions are stock + unimpaired; long intra-line/vertical hops are the daily
waste. *Vs easymotion:* easymotion is a leader-prefix philosophy (heavier,
different habit loop) — for a stock-motion user, sneak wins.
*Con:* it takes `s` (substitute), which is redundant with `cl` anyway.

**3. `wellle/targets.vim`.** *What:* a text-object upgrade pack — `cin)`
(next parens), `da,` (comma-separated argument), smart quote/seek objects.
*Why:* surround, commentary, and your visual-mode habits all *consume* text
objects; targets roughly doubles the vocabulary they act on. Highest
compound-interest plugin on this list. *Con:* it re-preferences a few default
objects (the "seeking" behavior) — 10 minutes in `:h targets` settles it.

**4. `tpope/vim-sleuth`.** *What:* silently detects `expandtab`/`shiftwidth`
from the file you opened. *Why:* your `ft_config` block (`.vimrc:317-328`)
hand-rolls this per filetype — but it only covers filetypes you anticipated;
cloned classmates'/course repos with foreign conventions are exactly what
sleuth eats. Your explicit `au FileType` lines still apply (they fire on the
FileType event, after detection); treat conflicts as testable, not fatal.
*Vs `editorconfig-vim`:* editorconfig honors `.editorconfig` files when the
project ships one; sleuth sniffs the file itself and needs nothing checked in.
Start with sleuth.

```vim
" --- Tier A additions (drop inside plug#begin/end) ---
" undotree: viewer for the persistent undo history you already paid for (:42-50)
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
" sneak: s{char}{char} to any visible spot; ; / , repeat
Plug 'justinmk/vim-sneak'
" targets: text-object upgrade pack (cin), da,, next/last objects)
Plug 'wellle/targets.vim'
" sleuth: auto-detect expandtab/shiftwidth in repos that aren't yours
Plug 'tpope/vim-sleuth'

" --- with the F-key maps (:242 area) ---
" F6 was the only free F-key; 'on'-lazy commands are safe to map directly
" (vim-plug stub loads the plugin on first press — no exists() guard needed,
"  unlike 'for'-lazy plugins: the Bug-7 lesson, .vimrc:249)
nnoremap <silent><F6> :UndotreeToggle<CR>
```

### Tier B — only when the workflow shows up

| Plugin | Trigger to install | Honest con |
|---|---|---|
| `ludovicchabant/vim-gutentags` | you actually use tagbar/`]t`/`[t` on big codebases and notice stale `tags` files | redundant with clangd for C/C++; earns its keep on asm/huge trees |
| `dkarter/bullets.vim` | markdown note-taking friction (auto-continues `-`, `1.`, checkboxes) | you'll forget it's there — which is the point; near-zero cost |
| **nothing** — try `:packadd termdebug` first | you want a visual debugger (repo already has `.gdbinit`) | it's **built into vim** — gdb in a vim split, no plugin needed |
| `puremourning/vimspector` | only if termdebug proves insufficient and a course demands DAP | heavy: python deps + gadget installs; a day of setup |

### Anti-recommendations (do NOT add)

- **coc.nvim / any second LSP client** — two completion engines = two popup
  menus fighting over `<Tab>` and the preview window. One brain per editor;
  yours is YCM+clangd (`.vimrc:268-275`).
- **Another fuzzy finder** (LeaderF, ctrlp) — fzf+rg at `:208` already wins.
- **A different statusline** — airline+gruvbox is coherent; churn for zero gain.
- **auto-pairs** — comfort plugin that fights muscle memory in vimscript and
  regex; closetag already closes tags. If bracket-closing ever genuinely
  annoys you, revisit — not before.

---

## 6. The short version of the whole story

You run 22 plugins, cleanly: manifest matches disk, startup script cost is a
measured ~70 ms, and the spine (YCM → fzf → asyncrun → airline) is a real IDE
loop with every key in the vimrc. The two honest gaps are (a) **tier 4** —
fugitive, emmet, visual-multi, and gitgutter's *keybindings* sit silent
because nothing in the vimrc teaches them — and (b) one daily-path bug left
(F5/E32) that outranks any new plugin. For additions, four small plugins each
close a verified gap: undotree gives your already-persistent undo a viewer on
the free F6; sneak closes the motion gap; targets doubles your text-object
vocabulary; sleuth handles other people's indentation. Everything shinier is
either redundant (more finders), combustible (a second LSP), or already built
into vim (`:packadd termdebug`).

## 7. The transferable principles (the part you keep)

1. **Installed ≠ used.** Audit plugins by *which keys you press*, not by
   `ls ~/.vim/plugged`. A plugin with no map, no setting, and no learned
   default keys is disk decoration.
2. **Three layers never substitute:** syntax paints · engine thinks · external
   tool janitors. Classify any plugin before installing it.
3. **Measure, don't count.** `--startuptime` per-file self-times settle
   "plugins are slow" claims in one command; watch for one-off artifacts
   (a `Warning delay` line is a message pause, not sourcing cost).
4. **vim-plug laziness has two grammars:** `'on': 'Cmd'` creates a safe stub
   (map freely); `'for': 'ft'` creates nothing until the filetype — mappings
   need an `exists()` guard at press time (the Bug-7 pattern).
5. **Default keys are invisible configuration.** `g:gitgutter_map_keys=1` was
   on all along; your vimrc never said so. When you adopt a plugin, write its
   three keys into a comment — future-you reads the vimrc, not the plugin docs.
6. **New plugin checklist:** does it duplicate a tier-1 spine member? does it
   fight an engine? does vim ship it (`:packadd`)? — then add.

---

## 8. Where to go next

- Fix Bug 8 first (`vimrc-analysis-2026-08-31.md` §12.4): guard `:229` with
  `get(g:, 'asyncrun_status', '')` and `:234-236` with a `bufname('%') ==# ''`
  warn-instead-of-throw pattern.
- One concrete self-verification: open a markdown note, press `F8` (guard
  works now), then `F6` after installing undotree, and run
  `\ls` … actually: `vim --startuptime /tmp/st2.txt +qa` before/after the four
  adds — expect < +15 ms total.
- Reading: `:h plugin` (runtimepath model), vim-plug README §"On-demand
  loading", `:h text-objects` before targets.vim.

---

## 9. Addendum — second pass on the live twin (2026-09-01, later)

Sections 0–8 were verified against the *repo* `.vimrc`. This pass cross-checks
the **live `~/.vimrc`** (the ~800-line pre-rewrite twin), re-measures startup
there, and resolves one surprise the first pass filed as "passive plumbing":
**`tpope/vim-repeat` never loads at startup — and that is correct behavior, not
a bug.** Everything below was probed, not assumed.

### 9.1 Both twins carry the same 22; live-twin startup cost

`repo .vimrc:168-191` and `~/.vimrc:493-517` declare an **identical set**
(order and comments differ, plugins don't), matching the 22 dirs on disk —
`:PlugClean` stays a no-op in both. Measured with `vim --startuptime` against
`~/.vimrc` (self-time summed per plugin directory):

| plugin | ms | plugin | ms |
|---|--:|---|--:|
| nerdtree | 20.1 | emmet-vim | 4.8 |
| vim-unimpaired | 11.2 | fzf.vim | 3.5 |
| vim-visual-multi | 10.2 | fzf | 3.3 |
| vim-fugitive | 9.2 | asyncrun / closetag / YCM | ≈ 1.8 / 1.6 / 1.6 |
| vim-airline | 8.8 | remaining 7 plugins | < 1.3 each |
| vim-gitgutter | 8.7 | **all 22 summed** | **≈ 99** |
| tagbar / gruvbox | 5.1 / 5.0 | | |

Real startup without profiling artifacts lands ≈ 300 ms. If you ever profile
headlessly and see a **2.0 s `Warning delay`** line — that is Vim pausing on
"Output is not to a terminal" because stdout was piped; it is the measurement
harness, not the config. (§3's ~70 ms was against the repo vimrc; the live twin
carries more maps/settings, hence ~99 ms. Measure the copy you actually run.)

Of the 22, **two never load at startup by design**: markdown-preview
(`'for': 'markdown'`, §1) and vim-repeat (§9.2). YCM's 1.6 ms is real but
misleading — it is just the shim; the Python engine and clangd start
asynchronously after `VimEnter`, which is why completion is warm a second
later without startup paying for it.

### 9.2 The vim-repeat surprise — an investigation in four probes

**Probe 1 — `:scriptnames` (81 plugin files): repeat.vim absent.**
*Thinking:* installed, on disk, never sourced — a dead plugin?
*Lesson:* `:scriptnames` only lists what has *already been sourced*. An
autoload-only plugin is invisible there until something calls it.

**Probe 2 — fresh session, `nmap .`: "No mapping found".**
*Thinking:* the README's whole pitch is "repeat.vim remaps `.`" — no remap
means surround's `.`-repeat is broken?
*Lesson:* an absent mapping at startup proves absence *at startup*, not
absence forever. State the timepoint of every probe before concluding.

**Probe 3 — read the installed source.** `autoload/repeat.vim:132-148` defines
`<Plug>(RepeatDot)` **and** `nmap . <Plug>(RepeatDot)` at the bottom of the
autoload file itself; its own header (`:7-8`) explicitly blesses the autoload
placement ("load automatically as needed"). Upstream master (6584602, v1.2,
"One last fix attempt before I revert everything") ships **autoload-only — no
`plugin/` directory at all**, so there is nothing to source at startup *by
design*. Vim's autoload mechanism then sources the file the first time any
code calls `repeat#set()`, and the callers are on your disk already: surround
(`plugin/surround.vim:485,487,567,569`), unimpaired (`:234,242,271,…`), and
gitgutter (`autoload/gitgutter/hunk.vim:210-224`).
*Thinking:* first `cs`/`ds`/`]c` hunk action → `repeat#set()` → repeat.vim
sources → `.` gets remapped — and so do `u`/`U`/`<C-R>` (`:140-148`).
*Lesson:* installed ≠ sourced ≠ active is a *spectrum*, and "autoloaded on
first call" is the third, invisible state between installed and active.

**Probe 4 — end-to-end behavior** (headless probe, script below):

```
start: nmap . = ''                                     (dormant — matches Probe 2)
commentary gcc + .: ['/* a */', '/* b */', 'c']          (. repeated, WITHOUT repeat.vim)
surround   cs + .: ['"hello"', '"yo"']                  (. repeated — repeat.vim now loaded)
unimpaired ]<Space> + .: ['x', '', '']                  (. repeated)
```

gcc+`.` repeats while `nmap .` is still empty because **commentary never uses
repeat.vim** — `gc` is an operator (`g@` with `operatorfunc`), and native
operator-repeat is built into core. The surround repeat *is* repeat.vim,
autoloaded mid-session.
*Lesson:* only an end-to-end behavior probe settles "is this plugin working" —
the map table and `:scriptnames` both pointed the wrong way. (The probe also
surfaced harmless-in-interactive-use E495s from some plugin's
BufEnter/BufDelete autocmds when buffers are juggled headlessly; if you ever
see E495 on `:enew`/`:bd` in a real session, hunt that autocmd.)

**Net verdict:** repeat.vim is alive, correctly installed, costs 0 ms at
startup, and self-installs on first surround/unimpaired/gitgutter use — after
which `u`/`U`/`<C-R>` are also silently wrapped (harmless: `repeat#wrap()`
just preserves repeat state across undo, but it explains why `nmap u` stops
being empty partway through a session).

The probe, kept for reuse (writes incrementally so partial results survive):

```vim
" /tmp/repeat_probe3.vim — run: vim -Nu ~/.vimrc -es -S /tmp/repeat_probe3.vim
let s:out = []
let s:file = '/tmp/repeat_probe.txt'

" stage 0: state at session start
call add(s:out, 'start: nmap . = ' . string(maparg('.', 'n')))
call writefile(s:out, s:file)

" stage 1: commentary — gcc line 1, then . on line 2
enew!
call setline(1, ['a', 'b', 'c'])
execute 'normal 1Ggcc'
execute 'normal 2G.'
call add(s:out, 'commentary gcc + .: ' . string(getline(1, 3)) . ' | nmap . now = ' . string(maparg('.', 'n')))
call writefile(s:out, s:file)

" stage 2: surround — change quotes on line 1, then . on line 2
enew!
call setline(1, ["'hello'", "'yo'"])
execute "normal 1Gcs'\""        " cs ' " : swap surrounding ' for "
execute 'normal 2G.'
call add(s:out, 'surround cs + .: ' . string(getline(1, 2)))
call writefile(s:out, s:file)

" stage 3: unimpaired — blank line below, then .
enew!
call setline(1, ['x'])
execute "normal ]\<Space>"       " unimpaired: ]<Space> = blank line below
execute 'normal .'
call add(s:out, 'unimpaired ]<Space> + .: ' . string(getline(1, '$')))
call writefile(s:out, s:file)
qa!
```

### 9.3 Recommendations — reconciled from both passes

§5's Tier A stands as written (undotree→F6, sneak, targets, sleuth). Three
changes from this pass:

1. **Elevate `:packadd termdebug` from Tier B to "do this first".** Debugging
   is your one genuinely missing workflow (`.gdbinit` exists; nothing in vim
   talks to gdb), and vim 8.1+ ships the bridge — no plugin, no Plug line:

   ```vim
   " repo .vimrc, with the top-level options (near :14)
   packadd termdebug          " vim's built-in gdb front-end (:h termdebug)
   " then: :Termdebug ./a.out  → gdb window + program window; :Break sets a
   " sign breakpoint, :Step/:Over/:Continue drive it, :Evaluate inspects the
   " word under the cursor
   ```

   One line, zero install cost. vimspector stays the escalation path (§5 Tier
   B) only if termdebug proves thin — for coursework it won't.

2. **Add `rhysd/git-messenger.vim`** to Tier A (~tiny): one Plug line +
   `nmap <Leader>gm <Plug>(git-messenger)` pops the cursor line's last-commit
   blame — the cheapest bridge into the silent tier-4 (fugitive's `:Git
   blame` stays the whole-file view; gitgutter keeps the live signs).

3. **`liuchengxu/vim-which-key` stays Tier B (try, don't default).** Your
   `<Leader>` namespace is dense (`b f g / y p K j* 1-0 - +`), and a
   press-`<Leader>` cheat-sheet is a good tutor — but the standard recipe
   remaps `<Leader>` itself and adds a timeout popup on *every* leader press.
   If that tradeoff sounds annoying, it is; learn the table in §2 instead.

Anti-recommendations in §5 unchanged and re-endorsed: no second LSP client (YCM
owns completion), no second fuzzy finder, no statusline churn, no auto-pairs.

### 9.4 The one decision that matters (updated)

§6 said: fix Bug 8, then the four adds. With this pass: **fix Bug 8, add
`packadd termdebug`, then the five-plugin Tier A** (§5's four +
git-messenger). Debugging is the only place you currently leave vim for
another tool mid-loop; everything else is polish.

### 9.5 Verify it yourself in 60 seconds

In any vim session with your config:

```
:nmap .          → empty (repeat.vim dormant — Probe 2, now explained)
cs'"             → change surrounding quotes, then press . elsewhere → repeats
:nmap .          → now <Plug>(RepeatDot) — it installed itself, Probe 3
```

And the 60-second startup check for the future: `vim --startuptime /tmp/s.txt`
then `sort -k2 -gr /tmp/s.txt | head` — ignore any one `Warning delay` line;
read the rest as per-plugin self-time.
