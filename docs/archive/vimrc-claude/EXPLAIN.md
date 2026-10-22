# EXPLAIN.md — companion to `vimrc-claude/.vimrc` (v2)

Written 2026-08-31 as v1; revised to **v2 on 2026-09-01**. This is Claude's
synthesis `.vimrc`: everything the three-pass review of your rewrite
established (`../vimrc-analysis-2026-08-31.md`, §11 = the night pass), the
verified subsystems of `~/.vimrc`, my calls on the open decision points —
and, new in v2, **your** revealed preferences from the 23:30 hand-fix, which
I treat as votes. It is still a *proposal*: nothing here touches your
existing files until you say so.

## The files in this directory

| File | Role |
|---|---|
| `.vimrc` | The vimrc itself — 14 numbered sections, every non-obvious line commented |
| `EXPLAIN.md` | This document — decisions, flip-back recipes, verification |
| `ftdetect/cpp.vim` | Travel copy of `~/.vim/ftdetect/cpp.vim` for the plug-less world (v2 also keeps the rules inline, placed where they survive — §4 below) |
| `smoke-test.vim` | Headless regression harness, v2 — re-runnable any time (§8) |

## Changelog v1 → v2 (what changed and why)

1. **Bug 10 class is now covered**: the repo's 23:30 hand-fix for Bug 2
   (paste arity) left `else if a:1 == 1` in the body — legacy VimL has no
   `else if`, and Vim *parses* skipped `:else` lines while scanning for
   `:endif`, so **every** call threw E488. v2 adds: a header style rule, a
   source **lint** in the harness (CHECK 4b), and a **live dual-arity fire**
   of `s:PasteClipboard` with a primed clipboard (CHECK 5) — the empty-
   clipboard early-out would otherwise skip the buggy block entirely, which
   is exactly how it survived an evening unnoticed.
2. **Your votes folded in** (things you kept when fixing by hand, which v1
   had changed): global `set spell spelllang+=cjk` (v1 was prose-only; v2
   keeps your global default and adds the `<Leader>S` per-window toggle) •
   `set enc=utf-8` kept, first line of section 1 (explicit beats derived on
   a traveling file) • the `has('gui_running')` block kept (with the
   variable names verified against `menu.vim:399/1220`) •
   `/usr/local/etc/systags` kept in 'tags' — now with the one-liner that
   builds it • the extension-less C++ header rules kept **inline**, moved
   after `plug#end()` where probing proves them alive.
3. **v1 inconsistency fixed**: v1's header said "warnings use echomsg" but
   `s:MissingTool`/`s:FilterFailed`/`s:AuditTools` used bare `echo` (a redraw
   erases it). v2 uses `echomsg` everywhere a warning matters.
4. The prose-only spell autocmd (`markdown,gitcommit setlocal spell`) is
   gone — redundant once the global switch stands.

## Three ways to try it

```bash
# 1. Test drive (nothing installed; ftdetect copy already on this machine)
vim -u ~/config_files/vimrc-claude/.vimrc somefile.c

# 2. Adopt as the live config (reversible: keep ~/.vimrc as ~/.vimrc.old first)
mv ~/.vimrc ~/.vimrc.old && ln -s ~/config_files/vimrc-claude/.vimrc ~/.vimrc

# 3. Adopt as the tracked repo copy too (the repo is your config archive)
cp ~/config_files/vimrc-claude/.vimrc ~/config_files/.vimrc
```

On a new plug-less machine, also: `mkdir -p ~/.vim/ftdetect && cp
vimrc-claude/ftdetect/cpp.vim ~/.vim/ftdetect/` — the inline copy keeps
working only while vim-plug is in the loop (§4).

## The one picture

The vimrc is a **pipeline in load order**, and the order is load-bearing:

```
defaults.vim  ->  core options  ->  terminal colors  ->  undo/files
     ->  key escapes  ->  formatters  ->  clipboard  ->  self-heal
     ->  grep plumbing  ->  C policy  ->  PLUGINS (manifest + vars)
     ->  [ftdetect inline block]  ->  commands & key dashboard
     ->  YCM  ->  per-filetype policy
```

Everything that must *survive* plugins comes **after** `plug#end()` in the
file (commands, mappings, per-ft rules, and now the inline detection rules —
because `plug#begin()` runs `:filetype off`, which wipes detection rules
registered earlier). The one thing that must come **before** is
`defaults.vim` (and `set enc=utf-8` before everything), so factory settings
lose to ours, never the reverse.

## Where each of the ten bug classes is prevented

| # | Bug (provenance) | Prevented at | How |
|---|---|---|---|
| 1 | `au FileType c.cpp` — one regex, never matches (+ trailing space) | §6 `shifttab_format` | `c,cpp` comma list; lint CHECK 4a guards trailing whitespace file-wide |
| 2 | `PasteClipboard(0)` — a:0 counts arguments, not values | §7 | normal map passes **no argument**; visual passes `1`; lint CHECK 4c; live-fire CHECK 5 |
| 3 | F5 called deleted `s:QfWinid()` → E117 | §12 | `s:PanelWin`/`s:FocusPanel` (the `win_gettype()` route); CHECK 2 asserts the zombie stays dead |
| 4 | `PlugInstall --sync` autocmd outside its bootstrap `if` | §11 | autocmd lives **inside** the `!filereadable(plug.vim)` guard, in its own augroup; CHECK 3 asserts it stays unregistered here |
| 5 | inline filetypedetect block wiped by `plug#begin` | §11 | the block sits **after** `plug#end()` (probed alive: §11 P4 of the analysis); travel copy in `ftdetect/`; CHECK 8 |
| 6 | lost `textwidth=0` → .vim comments wrap at 78 | §14 | re-asserted on the same `FileType` event, later in registration order; CHECK 6 reads tw in a live vim buffer |
| 7 | F8 bare `:MarkdownPreview` → E492 in non-md buffers | §12 | `exists(':MarkdownPreview') == 2` guard + `echomsg` naming the buffer's filetype; CHECK 9 asserts the map points at the guard |
| 8 | `update` on unnamed modified buffer → E32, F5 dies before Make | §12 `ToggleBuild` | `bufname('%') ==# ''` → warn, build still runs; `&modifiable`/`&readonly` gates; `get(g:,'asyncrun_status','')` |
| 9 | global `GnuIndent()` defined, `s:GnuIndent()` called → E117 | §14 | `s:` on **both** sides; CHECK 2 asserts no global leaks |
| 10 | `else if a:1 == 1` → E488 on **every** call, both arities | §7 + header rule 4 | bare `:else`; lint CHECK 4b; live dual-arity fire CHECK 5 with primed clipboard |

## My calls on the open decision points

Each was genuinely open; here is what I chose and why — plus the exact edit
to flip it back if you disagree.

**Spell: switch and payload GLOBAL, `<Leader>S` toggles per window.** v1
chose prose-only; your repo edit kept `set spell spelllang+=cjk` globally,
and you write prose in CJK+EN across many buffers — your vote wins. 'spell'
is window-local, so the toggle gives per-window relief without touching the
default. *Flip to prose-only:* delete `set spell` in §2 and add
`au FileType markdown,gitcommit setlocal spell` to §14. *Flip to off:*
also delete `<Leader>S` and the `spelllang` term.

**`<Leader>y` / `<Leader>p` for clipboard, both modes — not F1.** Symmetric
pair, identical across the native and wl-copy branches; F1 is help-key
muscle memory and already NERDTree's. *Flip back:* re-add F1 maps in §12.

**vim-commentary over nerdcommenter; no mru.** This is disk *truth*:
`~/.vim/plugged/` has commentary, emmet-vim, vim-javascript and NOT
nerdcommenter/mru (verified 2026-08-31). Orphan cleanup: `~/.vim/.mru_files`
is safe to delete.

**`:RG` over `:Rg`.** Both exist (`fzf.vim:63/64`); `:RG` is the grep2-based
command — incremental re-query per keystroke instead of a frozen initial
pattern. *Flip back:* one letter in the §12 `<Leader>g` map.

**GUI block: kept.** You kept it on 23:30; it's harmless dead weight on
terminal builds and correct on gvim (variable names verified against the
runtime). v1 dropped it on tidiness grounds; your vote wins.

**`set enc=utf-8`: kept, first option line.** Probed redundant on this box
(LANG provides it even under `-u NONE`), but this file is your traveling
config — explicitness is worth one line. 'encoding' is startup-only; the
comment at §1 says never to move it.

**systags: kept + recipe.** The file doesn't exist; the slot is inert
(missing entries are skipped silently) until the documented one-liner builds
a system-wide database of `/usr/include`.

**`<Leader>K` = YCMHover, overriding man.vim's buffer-local `\K` in man
buffers.** Deliberate trade: hover-on-demand in code beats a rare alias
inside man pages, where plain `K` already opens man pages via
`keywordprg=:Man`.

**inline filetypedetect + ftdetect copy: both.** You relocated the inline
block past `plug#end()` — probed alive there. The ftdetect copy stays for
the plug-less world; when both register, the inline `au!` dedups to one rule
per pattern and the bodies are identical, so who-wins is a non-question.

## What's new here vs BOTH of your files

- `set autoindent`, `set hlsearch` — the two genuine Vim 9.2 gaps (probed
  2026-08-30: everything else you'd set is now a compiled-in default).
- `set wildmode=longest:full,full` — first Tab fills longest common prefix +
  menu; further Tabs cycle.
- `wildignore` gains `*/__pycache__/*` — the bare `__pycache__` entry hides
  only the directory *entry*; its contents still matched (probed).
- `set autoread`, `set sidescrolloff=5` — cheap quality-of-life.
- The `au FileType * setlocal formatoptions+=mM` re-assert — immunizes the
  CJK formatoptions against any future ftplugin that *resets* fo.
- Formatter guards: a failed `%!tool` **replaces the buffer with the tool's
  stderr** — `s:MissingTool`/`s:FilterFailed` make failure loud (`echomsg`)
  and undo the clobber.
- `shellpipe='>%s 2>&1'` — hand-typed `:grep`/`:make` stop echoing through
  the terminal (25× headless-verified).
- Weekly `PlugUpdate` self-maintenance on a timer + stamp file.
- `Make -cwd=<root>` — builds run from the project root marker, not the
  file's dir.
- Warnings use `echomsg` (recoverable via `:messages`) everywhere.

## What I deliberately did NOT add (and why)

Folklore (verified off or harmful on this build): `set nocompatible`
(defaults.vim does it), `set backspace=…` / `wildmenu` / `history` /
`undolevels` / `showcmd` / `ruler` (Vim 9.2 compiled-in defaults — setting
them is noise), `ttyfast`, `lazyredraw` (old terminal folklore; can cause
redraw glitches), `laststatus=2` (airline sets it when loaded).

Taste-level, available if you want them (none are load-bearing):
`set colorcolumn=80` (noise in your long-line notes), `set cursorline`,
`set noshowmode` (airline shows the mode — but if plugins ever fail to load
you lose the indicator entirely), `<C-h/j/k/l>` terminal-window navigation.

No vim9script (`:def` functions): every plugin in the manifest is legacy
Vimscript; mixing buys nothing and risks subtle incompatibilities.

## Common beginner confusions (the ones this project kept hitting)

1. **"I added the autocmd, why doesn't it fire?"** — `au FileType c.cpp` is
   ONE *regex* (`c\.cpp`-shaped) matched against the filetype string. The
   pattern must be `c,cpp`. Registration never validates matching — a
   pattern that can never match registers silently.
2. **"`call F(0)` means no argument, right?"** — no: `a:0` counts arguments
   *given*. `F(0)` gave one (whose value is 0). "No argument" is `F()`.
3. **"The bootstrap lines are inside the if-block, so they're
   conditional."** — only *registration* is conditional. An autocmd at
   script level registers on **every** source of the script; the `if`
   guards the *registration*.
4. **"textwidth=0 is the default, so I don't need to set it."** — vim's own
   vim ftplugin runs *after* the vimrc and does `if &tw == 0 | setlocal
   tw=78 | endif`. A deliberate 0 and an untouched 0 are indistinguishable —
   re-assert 0 on the same event, later in order.
5. **"linebreak stops at 78 columns, right?"** — no: `linebreak` is
   display-only. Real newlines come from `textwidth` + `formatoptions`.
6. **"`:autocmd` shows my pattern twice — did it register twice?"** — no:
   one autocmd with a pattern *list* is displayed expanded, one line per
   pattern. Test matching by *firing* (`:setf cpp` on a fresh scratch
   buffer), never by reading the listing.
7. **NEW — "`else if` works in every language I know."** Vimscript predates
   that grammar: it's line-oriented, one keyword per line — `:if`,
   `:elseif`, `:else`, `:endif`. `:else` takes NO expression (E488 Trailing
   characters), and a *skipped* `:else` is still parsed while Vim scans for
   `:endif`, so the bad form breaks BOTH branches, not just the else path.
   The scarier half of the story: the function *defined* without complaint —
   legacy VimL parses commands lazily — so nothing warns you until the key
   is pressed. That is why the harness *presses it for you*.

## Verification

`smoke-test.vim` re-sources the entire vimrc (idempotency) and checks every
bug class above. Run it any time:

```bash
vim -u ~/config_files/vimrc-claude/.vimrc -es \
    -S ~/config_files/vimrc-claude/smoke-test.vim </dev/null
cat /tmp/proposal_smoke.txt
```

The VERDICT line at the bottom of the output is authoritative. v2 additions
over v1's harness: the source lints (trailing whitespace / `else if` /
`PasteClipboard(0)` — CHECK 4) and the live dual-arity paste fire with a
primed clipboard (CHECK 5; skips cleanly on machines without wl-copy or a
Wayland session — the lint still guards there).

Latest harness result (filled in after each run):

> **2026-09-01: ALL CHECKS PASS** (Vim 9.2 1-849, this machine). The live
> dual-arity `PasteClipboard` fire ran against a real `wl-copy`-primed
> clipboard on Wayland — clean on both arities; lints found no trailing
> whitespace, no `else if`, no `(0)` call site; `tw=0`/`fo=croqlmM` in a vim
> buffer; `spelllang=en,cjk` (single `cjk` even after the re-source — the
> guard in §2 holds); 22/22 helpers defined, zombie `QfWinid` dead, no
> global `GnuIndent`; S-Tab fires on FileType c AND cpp; gruvbox VimEnter
> registered exactly once after the re-source; messages hold no E-numbers.
> One harness bug was found and fixed en route (scriptnames matched this
> harness's own path — lesson #3 is recorded inside `smoke-test.vim`; also
> newly established: re-sourcing the same path REUSES its script number).

What the headless harness does NOT cover (needs a real session): Shift-Tab
formatting on real code, F8 → browser focus (qdbus6), and gruvbox's
rendering — all verified interactively in the home twin; the code here is
the same lines.

## Where to go next

- `vim -u ~/config_files/vimrc-claude/.vimrc` on a real C file: try `F5`
  (build), `<Leader>g` (`:RG` live grep), `S-Tab` (clang-format),
  `<Leader>p` after a real copy — the four paths the rewrite broke.
- If you adopt it: keep `smoke-test.vim` — after ANY future edit, one
  command re-runs all ten bug-class checks.
- The deep background for every fact cited in the comments:
  `~/notes/vim-set-options-verified-review.md` (options) and
  `~/config_files/vimrc-analysis-2026-08-31.md` (the full bug walkthroughs,
  §11 for the third pass).
