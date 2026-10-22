# Fix notes: what broke, why, how it was fixed, what to keep

Newest first. Each entry is one change, written to be learned from.

---

## 2026-10-21 · The three loose ends from the ATLAS

> **Status:** ✅ fixed and tested on Ubuntu 26.04 (WSL2): `make test`
> **57/57**, `make test-full` **61/61**. Not committed yet: like the rest of
> the rebuild, it waits for GUIDE §9.5. Every ✅ below was run on this machine
> on 2026-10-21.

### 1. In plain words

1. **`install.sh` linked Vim's swap files.** Vim keeps a crash-recovery copy,
   a *swap file*, next to each file it has open. The installer linked *every*
   file under `home/` into `~`, so with `~/.vimrc` open in Vim it also linked
   `~/.vimrc.swp`. It now skips Vim swap files (`*.sw?`) and backups (`*~`).
2. **A comment told the opposite story.** `~/.config/git/ignore` said "the
   vimrc keeps them in ~/.vim". Neither vimrc (this one or the long twin) does
   that; both move only *undo* files. The comment now says where swap files go.
3. **`.editorconfig` did nothing in Vim.** Vim 9.1 ships EditorConfig support
   switched off. One vimrc line turns it on, after four of its rules were
   corrected to match how the files are really indented.

### 2. Analogy: the stockroom and the shop window

The repo is a stockroom; `install.sh` is the clerk who puts every item from
the `home/` shelf on display in the shop window (`~`). Vim's swap files are
sticky notes a worker leaves on whatever item is in their hands. The old
clerk displayed the sticky notes too; the new one leaves them on the shelf.

`.editorconfig` is the style guide pinned to the stockroom door. Vim owned a
copy but never read it. Now it reads it, but only when you walk in through
the stockroom door (`vim ~/config_files/home/.zshrc`), not when you reach in
through the shop window (`vim ~/.zshrc`, the link). Section 5 shows why.

### 3. What, why, how

| Where | What was wrong | Why | How it is fixed |
|---|---|---|---|
| `install.sh:68` | a swap file in `home/` was linked into `~` | `find` listed every file, and Vim writes a swap file next to a link's *target*, inside the repo | `! -name '*.sw?' ! -name '*~'` in the `find` |
| `home/.config/git/ignore:6` | "the vimrc keeps them in ~/.vim" | the comment described a setting neither vimrc has | the comment states the real rule |
| `home/.vimrc:7`, `.editorconfig:14` | Vim ignored `.editorconfig` | the plugin ships as an *optional* package (`pack/dist/opt/`) | `silent! packadd! editorconfig`, after aligning 4 rules |
| `scripts/test.sh:167`, `:400` | nothing guarded either bug | — | 2 regression tests; 55 → 57 offline, 59 → 61 `--full` |

The changed lines:

```sh
# install.sh
# Vim writes a swap file next to each file it has open, and for a link next
# to the TARGET: `vim ~/.vimrc` creates home/.vimrc.swp. Never link those.
(cd "$SRC" && find . \( -type f -o -type l \) ! -name '*.sw?' ! -name '*~' | sed 's|^\./||' | LC_ALL=C sort) > "$LIST"
```

```vim
" home/.vimrc, lines 6-7 (every later line moved down by 2)
" Follow a project's .editorconfig (indent, tabs, trailing spaces); Vim ships it off
silent! packadd! editorconfig
```

```ini
# .editorconfig: the 2-space list gained *vimrc, .clang-format, .clang-tidy, *.html
[{*.vim,*vimrc,.zshrc,.zshenv,.zprofile,*.yml,*.yaml,.clangd,.clang-format,.clang-tidy,*.html}]
indent_size = 2
```

```gitignore
# home/.config/git/ignore
# Vim swap/backup files: Vim writes them next to the file it edits (for a
# symlink, next to its target), not into ~/.vim (only undo files go there).
```

### 4. Worked walkthrough, hand-traced

**The installer, before and after** (✅ with a real Vim holding the file):

```text
$ vim ~/.vimrc              # ~/.vimrc -> ~/config_files/home/.vimrc
                            # Vim follows the link: the swap file is
                            # ~/config_files/home/.vimrc.swp, INSIDE the repo
$ ./install.sh --dry-run    # before
    (dry-run) ln -s /home/ken/config_files/home/.vimrc.swp /home/ken/.vimrc.swp
link    ~/.vimrc.swp
Done: 1 linked, 17 already in place, 0 backed up.
$ ./install.sh --dry-run    # after, same swap file present
Done: 0 linked, 17 already in place, 0 backed up.
```

Without `--dry-run` the old installer would have made `~/.vimrc.swp` a real
link. The moment Vim quits, its target is deleted and the link dangles; and
what the installer did depended on which files you happened to have open.

**EditorConfig, by the path you open** (✅ your real vimrc and plugins). Ask
Vim who set an option with `:verbose`:

```text
vim ~/config_files/scripts/test.sh     :verbose setlocal shiftwidth?
  shiftwidth=4   Last set from .../pack/dist/opt/editorconfig/plugin/editorconfig.vim line 479
vim ~/.config/shell/common.sh          (a link into the repo)
  shiftwidth=2   Last set from ~/.vimrc line 377          <- your `au FileType sh` rule
```

| File, opened by its **repo** path | indent | | File, opened by its **`~` link** | indent |
|---|---|---|---|---|
| `install.sh`, `scripts/test.sh`, `common.sh` | 4 spaces | | `~/.config/shell/common.sh` | 2 (vimrc) |
| `home/.zshrc` | 2 spaces | | `~/.zshrc` | 8, tabs (Vim default) |
| `Makefile`, `home/.config/git/config` | tabs | | `~/.bashrc` | 2 (vimrc) |
| `templates/.clang-tidy`, `docs/ATLAS.html`, `vimrc` | 2 spaces | | | |
| `docs/GUIDE.md` | 4, trailing spaces kept | | | |

No buffer was marked modified on open: EditorConfig changed no file content.

### 5. Common beginner confusions (read these twice)

- **"Vim keeps swap files in `~/.vim` (or `/tmp`)."** Not with this vimrc.
  `'directory'` is Vim's default `.,~/tmp,/var/tmp,/tmp` (✅), and `.`, the
  folder of the file, comes first. Only undo files moved, to `~/.vim/undodir`.
- **"Editing `~/.vimrc` puts the swap file in `~`."** Vim follows the link and
  writes `~/config_files/home/.vimrc.swp`, in the repo (✅). That is how a swap
  file got into `home/` in the first place.
- **"A `.editorconfig` file works on its own."** It is only text. An editor
  plugin must read it. Vim 9.1 ships the plugin but leaves it off until
  `packadd! editorconfig` (VS Code needs its EditorConfig extension).
- **"`packadd!` loads the plugin right there."** The `!` only adds the package
  to `'runtimepath'`. The plugin loads later, in Vim's normal plugin step,
  like every other plugin: position #89 of 150 in the startup trace (✅).
- **"`.editorconfig` covers the repo however I open a file."** The plugin
  searches upward from the path you *typed*. A symlink has two paths, and
  tools disagree about which one they use: Vim's swap file uses the target,
  EditorConfig uses the path you typed.
- **"My vimrc's `au FileType sh ... shiftwidth=2` beats `.editorconfig`."**
  For files under a `.editorconfig`, the reverse. Filetype detection runs your
  `FileType` rule inside its `BufReadPost` autocommand; EditorConfig's
  `BufReadPost` autocommand was defined later, and Vim "executes all matching
  autocommands in the order that you specify them" (`:help autocmd-use`). It
  runs last, so it wins.
- **"Changing the filetype re-applies EditorConfig."** `:set ft=sh` re-runs
  your `FileType` rule (shiftwidth back to 2, ✅) but not EditorConfig, which
  listens only to reading and naming events. `:EditorConfigReload` puts it
  back (4 again, ✅).

### 6. How it went, stage by stage

**Stage 1 · Is anyone editing these files?**
*Thinking:* the day before, five swap files sat in the repo with three Vim
sessions open. Editing a file under someone's open buffer invites a "file
changed" conflict, so the first command listed the swap files (`vim -r`
prints each owner's PID and an unsaved-changes flag). None were left, and no
Vim was running.
*Lesson:* before editing files a person may have open, ask the editor's own
locks. But a check is only true when it is made: see Stage 7.

**Stage 2 · Tests first, and watch them fail**
*Thinking:* `test.sh` already proves each fixed bug with a test that failed
on the old code. Two new tests: a fake repo holding `.vimrc`, `.vimrc.swp`
and `.vimrc~`, of which only the first may be linked; and a Vim test with
two shell files, one under a `.editorconfig` asking for indent 3 (a value
nothing else sets), one without (the control, which must keep the vimrc's
2). Run before any fix (✅): **55 passed, 2 failed**, both new tests, for the
right reasons: the litter became links, and `pkg=1 with=2`, meaning the
package was on disk but never loaded.
*Lesson:* a test you have not seen fail proves nothing. The control proves
the measurement can tell the two cases apart.

**Stage 3 · Reproduce the reported symptom, not a lookalike**
*Thinking:* the fake repo plants files by hand, but the original report came
from a real Vim. So a test Vim opened `~/.vimrc`, the real dry run ran, and
it printed the ATLAS's exact line (`link ~/.vimrc.swp`, `1 linked`). It also
answered *why* a swap file was in the repo at all: Vim follows the link.
*Lesson:* reproduce the exact report once, end to end; then let a small
hermetic test guard it forever.

**Stage 4 · Audit a config that has never run, before switching it on**
*Thinking:* `.editorconfig` had never been live in Vim, so switching it on
was its first deployment. Two questions: will saving now change a file's
content, and do the rules match the files? A survey of all 40 text files:
0 with trailing whitespace, CRLF endings or a BOM, so saving changes nothing.
But 3 files were indented with 2 spaces where the rules said 4
(`templates/.clang-tidy`, `docs/ATLAS.html`, the root `vimrc`), and
`.clang-format` is YAML like `.clang-tidy`. The rules were fixed first.
*Lesson:* turning on a config that has never run is a deployment. Check it
against the files it will touch.

**Stage 5 · Green, then one check in the real setup**
*Thinking:* after the fixes: **57/57** offline and **61/61** with plugins and
clangd (✅). The offline Vim tests use a stub plugin manager, so one more
check ran your real vimrc with the real plugins on 10 repo files (the table
in section 4). The startup trace grew from 148 to 150 scripts:
EditorConfig's `ftdetect` file (#23) and its plugin (#89).
*Lesson:* hermetic tests guard the logic; one run in the real environment
catches what the stubs hide.

**Stage 6 · A result that looked too clean**
*Thinking:* in that real check, `~/.zshrc` (the link) also got the repo's
rule. That contradicts the plugin's source, which looks up `.editorconfig`
from the typed path. The name column gave it away: both rows said
`home/.zshrc`. Vim saw the same file already open under its repo path and
reused that buffer. Run alone, the link paths got no repo rules (table above).
*Lesson:* when a result is cleaner than the mechanism allows, check the
experiment's isolation before believing it.

**Stage 7 · My own slips, and what caught them**
*Thinking:*
(a) After the second real-Vim dry run a swap file was still there. Before
deleting it as mine, `vim -r` named its owner: PID 1489304,
`vim /home/ken/.vimrc`, opened at 22:27:28. It was **your** session. My test
Vim had hit Vim's "swap file exists" prompt, and the `q` of my `:qa!`
answered it with Quit. Nothing of yours was touched; every later check ran
`vim -n` (no swap file).
(b) Your Vim opened `~/.vimrc` 46 s before my vimrc edit (22:28:14), so
that buffer is older than the file on disk. Another Claude session working
in this repo flagged it. The Stage 1 check was a few minutes old.
(c) The new test's skip message first said "needs 9.0.1799+", from memory.
Vim's own `version9.txt` says patch 9.0.1799 is a Russian menu update and
that EditorConfig ships with Vim 9.1. Corrected.
(d) The session scratch folder was wiped by another session's startup
cleanup, backups included. Nothing was lost (no original had been changed
yet); the backups moved to `~/.cache/claude-fix-20261021/`, deleted at the end.
*Lesson:* check ownership (a PID) before deleting; re-check locks right
before each edit; take version numbers from the docs, not from memory.

**Stage 8 · A fix is not done until the notes agree**
*Thinking:* the knock-on effects. Vimrc lines after 5 moved down by 2 (13
references in the ATLAS, 12 of them in Plate 8; F5 is now line 289, ✅
`:verbose nmap <F5>`). `*.swp` moved to line 8 of the git ignore file
(Plate 15 quotes `git check-ignore -v`). Test counts appeared in four docs. GUIDE §1.4 and
LEARN-AND-SYNC repeated the false "swap files go into ~/.vim". The worst one:
`dots_status` in LEARN-AND-SYNC walks every file under `home/` like the old
installer, so with Vim open it reported `not linked: ~/.vimrc.swp` and sent
you to an installer that, correctly, does nothing. It got the same filter,
✅ in dash, bash and zsh.
*Lesson:* grep for the claim and the numbers, not only the file name. Two
loops that must agree should use the same filter.

### 7. The professional upgrade: the options, compared

**Keeping editor litter out of `~`**

| Option | Pros | Cons |
|---|---|---|
| **A. `! -name` filters in `find` (chosen)** | one line, no dependencies, the rule is visible in the script | the patterns repeat what the git ignore file knows; another editor's litter needs another pattern |
| B. `git check-ignore` on each file | one source of truth: every ignore file | needs git; the global ignore file is itself installed by `install.sh`, so a fresh machine and the test HOME don't have it yet; results differ per machine |
| C. link only tracked files (`git ls-files home`) | installs exactly what is committed | today the whole rebuild is untracked, so it would link nothing; a new file needs a commit before you can try it |
| D. move swap files out of every folder (`set directory^=~/.vim/swap//`) | no litter in any repo | Vim only, and a behavior change nobody asked for; you would keep A anyway |

**Making `.editorconfig` count in Vim**

| Option | Pros | Cons |
|---|---|---|
| **A. `packadd! editorconfig` (chosen)** | built into Vim 9.1: no download, no plugin manager | rules follow the typed path; first time live, so it needed the audit |
| B. `Plug 'editorconfig/editorconfig-vim'` | same plugin, updated more often | a network download of what Vim already ships |
| C. delete `.editorconfig` | nothing to keep in sync | VS Code and other editors lose the rules |
| D. a modeline per file (`# vim: sw=4`) | works through links too | one line of noise per file; modelines have a security history (CVE-2019-12735) |

**The false comment:** correcting it (chosen) changes no behavior; making it
true would mean option D above.

### 8. How to improve (not applied, your call)

- **Close the `~` gap.** A dotfile opened through its link still gets your
  vimrc's rules, so `common.sh`, written with 4 spaces, gets 2. Cheapest
  first: (1) habit: edit dotfiles from the repo
  (`cd ~/config_files && vim home/.zshrc`); (2) settle one style for shell
  scripts: your vimrc says 2 and the repo's scripts use 4, so change one of
  them; (3) make Vim open links under their real path. That is not a
  one-liner: renaming a buffer with `:file` makes Vim treat it as a new
  file, and the next `:w` asks for `!`.
- **Commit it.** These fixes live only on this disk until GUIDE §9.5 runs.
- **Re-run Arch.** GUIDE's Arch result (59/59) predates the two new tests:
  `make arch-test` once the sandbox exists.
- **Bleeding edge.** Managers that cannot have this bug by design: yadm uses
  git itself as the list of files, and chezmoi names its managed files
  `dot_zshrc`, so a stray `.dot_zshrc.swp` is never a candidate.

### 9. Expansion: edge cases and gotchas

- **Swap names:** `.name.swp`, then `.swo`, `.swn` … down to `.swa` when
  several Vims open one file; `*.sw?` covers them all. `vim -r` lists them
  with the owner's PID, `STILL RUNNING`, and `modified: YES/no`.
- **Central swap folders:** a trailing `//` in `'directory'` makes Vim encode
  the full path into the swap name, so it still notices one file opened twice.
- **EditorConfig rules:** `*` matches a leading dot (`*vimrc` matches
  `.vimrc`, ✅), `{a,b}` lists alternatives, a later matching section beats an
  earlier one (so `Makefile` gets tabs, ✅), and `root = true` stops the
  upward search: without it a `~/.editorconfig` would join in.
- **Commands:** `:EditorConfigDisable`, `:EditorConfigEnable`,
  `:EditorConfigReload`. The plugin can also map `max_line_length` to
  `'textwidth'`; this repo sets none.
- **Final newlines:** `home/.clang-format` has none. Vim's `'fixendofline'`
  adds it on the next save, EditorConfig or not.
- **The open-buffer trap (Stage 7b):** when a file changes on disk under an
  open Vim, Vim says W11 (or W12 if you have edits). `L` reloads; with edits,
  `:DiffOrig` (from `defaults.vim`, ✅ in your Vim) shows both versions, `do`
  pulls a hunk in, and `:w!` saves the merge.

### 10. The short version

The ATLAS drawing pass found three loose ends. Tests came first and failed
for the right reasons (55 of 57). A real Vim reproduced the exact symptom
and explained it: Vim writes the swap file next to the symlink's target,
inside the repo. Before EditorConfig was switched on, an audit showed that
saving would rewrite no file but that four indent rules contradicted the
files, so those were fixed first. Then the fixes: a two-pattern filter, one
`packadd!` line, an honest comment, and 57/57 and 61/61. A suspiciously
clean real-Vim check exposed the remaining limit: EditorConfig follows the
typed path, so a dotfile opened through its `~` link misses the repo's rules.
Last, every doc that described the old behavior was brought in line,
including a helper that would have contradicted the fixed installer.

### 11. The transferable principles (the part to keep)

1. Watch a new test fail before you trust it to pass, and give it a control
   that must not change.
2. Reproduce the exact reported symptom once, end to end.
3. Switching on a config that has never run is a deployment: audit it
   against the files it will touch.
4. A tool that walks "every file in a folder" must skip editor litter, and
   two walkers that must agree should share one filter.
5. A symlink has two paths, and tools disagree on which one they use.
6. Re-check locks right before you edit; check the owner before you delete.
7. Fix the notes in the same change: grep for claims and line numbers, not
   only file names.

### 12. Mental checklist

- [ ] Does anyone have the file open? `vim -r`, right before the edit.
- [ ] Did the new test fail first, for the right reason? Does it have a control?
- [ ] Did I reproduce the exact symptom once?
- [ ] Switching on a dormant config? Audited against the files?
- [ ] One isolated check in the real environment?
- [ ] Every doc that described the old behavior updated (claims, numbers)?
- [ ] Deleted only what I own (checked the PID)?

### 13. Suggested learning path, and where to go next

1. `:help swap-file`, `:help 'directory'`, `:help :recover`.
2. `:help packages` and `:help :packadd` (what the `!` does).
3. `:help editorconfig`, then the spec at <https://editorconfig.org>.
4. `:help :verbose` and `:help autocmd-use` (the definition-order rule).
5. `man find`: `-name`, `!`, and how `\( … \)` groups the tests.

Try it:

- `vim ~/config_files/scripts/test.sh` and `:verbose setlocal shiftwidth?`;
  then the same in `vim ~/.config/shell/common.sh`. Explain the difference.
- Break a fix on purpose: delete `! -name '*.sw?'` from `install.sh`, run
  `make test`, watch section 3 turn red, undo.
- Stretch: decide what *should* happen for files opened through `~`, write
  that test first (section 5 of `test.sh` shows the pattern), then make it pass.
- See it drawn: ATLAS Plate 8 (the two new startup scripts) and Plate 18
  (the installer).
