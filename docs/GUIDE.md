# Dotfiles from zero: how this repo was rebuilt, and how to do it yourself

*Written 2026-10-19; updated 2026-10-20 after merging the Arch laptop's commit
(section 9 tells that story). Verified on Ubuntu 26.04.1 on WSL2 (kernel 6.18,
Vim 9.1.2141, clangd 21.1.8, zsh 5.9) and Arch Linux (Vim 9.2.1178, clang
23.1.3, zsh 5.9.2) in a rootless sandbox. Every ✅ marks a command that was
actually run; every number was measured, none estimated.*

## Contents

- [0. TL;DR](#0-tldr)
- [1. What a dotfiles repo is (from zero)](#1-what-a-dotfiles-repo-is-from-zero)
- [2. The review: what was wrong, and how each problem was found](#2-the-review-what-was-wrong-and-how-each-problem-was-found)
- [3. LSP from zero: how Vim learned to see your errors](#3-lsp-from-zero-how-vim-learned-to-see-your-errors)
- [4. Your NJU L0 lab with LSP, step by step](#4-your-nju-l0-lab-with-lsp-step-by-step)
- [5. Shells: layout, speed, and the WSL PATH tip](#5-shells-layout-speed-and-the-wsl-path-tip)
- [6. The clang family: who reads which file](#6-the-clang-family-who-reads-which-file)
- [7. The other tools, and the choices inside them](#7-the-other-tools-and-the-choices-inside-them)
- [8. Testing the configs (and testing the tests)](#8-testing-the-configs-and-testing-the-tests)
- [9. Two machines, one repo: the refused pull, the leaked key, and a fresh start](#9-two-machines-one-repo-the-refused-pull-the-leaked-key-and-a-fresh-start)
- [10. Pros and cons, and the alternatives](#10-pros-and-cons-and-the-alternatives)
- [11. How to improve: now vs. bleeding edge](#11-how-to-improve-now-vs-bleeding-edge)
- [12. Expansion: gotchas and edge cases](#12-expansion-gotchas-and-edge-cases)
- [13. Mental checklist](#13-mental-checklist)
- [14. Learning path and where to go next](#14-learning-path-and-where-to-go-next)

---

## 0. TL;DR

| | Before | After |
|---|---|---|
| Vim on WSL | no `~/.vimrc` at all: plain Vim | your concise laptop vimrc + LSP, 23 plugins, clangd errors **~60 ms after you type** |
| LSP | YouCompleteMe (needs cmake + Python + a compile step) | yegappan/lsp: pure Vim9 script, nothing to compile |
| Vim bugs | Shift-Tab could replace the buffer with an error, F5 → E475, `\y` → E121 on every machine, F8 → E492, E185 on a fresh machine, bright gruvbox light on WSL | fixed; each has a test that fails on the old file |
| `.clang-format` | the repo held a retired WebKit-era file | your real Chromium style, checked on clang-format 21 and 23 |
| Deploying | files copied by hand; the WSL copy had drifted from the repo | `install.sh`: symlinks, dry-run, backups, uninstall |
| `ls` for scripts and agents | printed **nothing** (eza read stdin) | correct output; eza only for humans |
| zsh startup (real terminal) | 64.6 ms | 55.1 ms; **31.3 ms** with the optional WSL PATH change |
| clangd on L0 | false errors (`main(const char *)`, `-Werror`, `am.h` not found) | 0 errors on clean code |
| clangd on `~/algo` | 157 and 461 bogus errors per file | 0 (one `compile_flags.txt`) |
| Clipboard in WSL Vim | none | `\y` / `\p` reach Windows, Chinese included |
| Two machines | `git pull` refused (laptop commit vs. uncommitted WSL work) | a fresh, clean history (7 commits), rehearsed end to end |
| Secrets | a Gemini API key in a public commit since June | revoke it; the new history doesn't contain it |
| Tests | none | `scripts/test.sh`: 61 checks; CI on Ubuntu + Arch |

Test results (✅): Ubuntu offline **57/57** and `--full` **61/61** (2026-10-21);
Arch `--full` **59/59** (2026-10-20, before the two newest checks). Adding
shellcheck to the sandbox caught a lint failure the WSL host hid: `common.sh`
sources `/etc/profile.d/proxy.sh`, which exists only there.

What you do next is in [section 9](#9-two-machines-one-repo-the-refused-pull-the-leaked-key-and-a-fresh-start):
revoke the leaked key, back up the old history, build the fresh repo, force-push
it safely (`--force-with-lease`), swap the folders, then re-clone on the laptop.

---

## 1. What a dotfiles repo is (from zero)

### 1.1 Plain-language summary

Programs read their settings from small text files in your home directory
whose names start with a dot (`.zshrc`, `.vimrc`), hence "dotfiles". A
dotfiles repo keeps those files in git, so every machine you use gets the same
setup, every change has a history, and a broken change can be undone.

### 1.2 Analogy: a wardrobe and a mirror

Think of the repo as your **wardrobe** (one real copy of each item, with a
logbook of every alteration: git), and each machine's home directory as a
**room with mirrors**. `install.sh` doesn't copy clothes into the room; it
mounts a mirror at each spot (`~/.zshrc`) that shows the item in the wardrobe
(`~/config_files/home/.zshrc`). Alter the item while looking in the mirror and
you altered the wardrobe's item, so the logbook (`git diff`) sees it. A second
room (the Arch laptop) has its own mirrors onto its own copy of the wardrobe,
and `git pull` brings the alterations over.

The mapping: wardrobe = repo, mirror = symlink, logbook = git history, a
second room = a second machine, carrying alterations between rooms = push/pull.

### 1.3 Worked walkthrough (✅ on this machine)

```sh
$ ls -l ~/.zshrc
lrwxrwxrwx ... /home/ken/.zshrc -> /home/ken/config_files/home/.zshrc
#   ^ "l" = a symbolic link; the arrow shows where it points

$ readlink ~/.zshrc                  # print only the target
/home/ken/config_files/home/.zshrc

# (after your commits in section 9, so the diff is just this edit)
$ echo '# test' >> ~/.zshrc          # edit THROUGH the link...
$ git -C ~/config_files diff --stat  # ...and the repo file changed
 home/.zshrc | 1 +
$ git -C ~/config_files checkout -- home/.zshrc   # undo the test edit
```

What `install.sh` did for each file under `home/` (✅ 19 links, 7 backups):

1. `~/.zshrc` exists and is a regular file, so **move** it to
   `~/.local/state/dotfiles/backup/20261019-044038/.zshrc`. Nothing is deleted.
2. `ln -s ~/config_files/home/.zshrc ~/.zshrc`.
3. On a second run, `~/.zshrc` is already the right link: skip. Safe to repeat.

### 1.4 Common beginner confusions (read these twice)

- **"A symlink is a copy."** No. It is a tiny file that contains a *path*.
  Editing through it edits the target. Deleting the link (`rm ~/.zshrc`)
  deletes only the link; the repo file is untouched.
- **"Then I can just symlink the whole `~/.vim` folder."** Dangerous. Vim
  writes plugins and undo history into `~/.vim`, and they would
  land inside your git repo. `install.sh` links individual **files** for
  exactly this reason; runtime data stays local.
- **"An alias makes a command exist."** Only inside an interactive shell.
  `alias bat=batcat` does nothing for scripts, `fzf --preview 'bat ...'`, or
  Vim's `:!bat`. That is why `install.sh` creates a real file,
  `~/.local/bin/bat -> /usr/bin/batcat` (a "shim").
- **"A private repo is a safe place for API keys."** Repos get made public,
  forked, cloned onto shared machines. Secrets live in `*.local` files that
  git ignores (see `.gitignore`).

### 1.5 The professional upgrade

`install.sh` is 146 lines of POSIX sh you can read in five minutes. The
same layout (`home/` mirrors `~`) also works with **GNU Stow**
(`stow -d ~/config_files -t ~ home`). For many machines with differences (work
vs. personal email, macOS vs. Linux), people move to **chezmoi** (templates,
encrypted secrets) or **Nix home-manager** (fully declarative: packages and
configs together). Section 10 compares them.

---

## 2. The review: what was wrong, and how each problem was found

Each stage: what was looked at, the **Thinking** (why that was the next move,
from the evidence), and the **Lesson** (what transfers to other problems).

### Stage 1: Compare the repo with the machine, not just read the repo

`git status` showed an uncommitted `.zshrc`, untracked `.zshenv`, `.zprofile`,
and the `vimrc` you copied from Arch. Then the home directory:

- `~/.vimrc` **did not exist**: Vim on WSL had been running with no config.
- `~/.zshrc` was a *copy*, and differed from the repo: `rm/cp/mv -i` aliases
  were commented out at home but active in the repo.
- `~/.bashrc` was Ubuntu's default plus one line (`~/.local/bin` in PATH,
  added by the Claude Code installer).

*Thinking:* a config repo can be perfect and still useless if the machine runs
something else. "What's in git" and "what's running" are two facts, so check
both before judging either.

*Lesson:* **drift** (copies slowly diverging) is the default state of
hand-copied configs. Links (one source of truth) remove the possibility.

### Stage 2: `ls -la` printed nothing

In a non-interactive context, `ls -la` returned exit status 0 and **no
output**. `type ls` showed the alias `eza --icons --group-directories-first`.

```sh
$ eza -la </dev/null      # stdin is not a terminal
$                         # nothing!
$ eza -la . </dev/null    # with an explicit path
.rw-r--r-- 2.5k ken ...   # works
```

`eza --help` lists `--stdin`: with no path and a non-terminal stdin, eza reads
file names **from stdin**. Scripts, cron jobs and AI agents all run with a
non-terminal stdin, so they would see an "empty" directory and act on it.

*Thinking:* "no output, success status" is the most dangerous failure shape,
because nothing tells the caller to stop. The fix had to keep your eza look
for humans and give everyone else the real `ls`, hence a function that
checks `[ -t 0 ] && [ -t 1 ]` (stdin and stdout are terminals).

*Lesson:* **never shadow a standard command with an incompatible one** for
non-humans. Flags differ too: `ls -ltr` is an error in eza.

### Stage 3: Why does zsh take 75 ms to start?

Profiling with zsh's built-in profiler:

```sh
zsh -i -c 'zmodload zsh/zprof; source ~/.zshrc; zprof'   # (simplified)
 1)   12 calls  30.48 ms  61.65%  has
 2)    1 call   10.89 ms  22.03%  compinit
```

`has()` is `(( $+commands[$1] ))`: a hash-table lookup that should cost
microseconds, yet it took **2.5 ms per call**. Hypothesis: a lookup for a
*missing* command walks every PATH directory, and 10 of your 21 PATH entries
are Windows folders under `/mnt/c`, where each `stat` crosses to Windows over
the 9P protocol. Test (✅):

| PATH | one missing-command lookup | `zsh -i` startup |
|---|---|---|
| full (21 entries, 10 Windows) | 1.9 ms | 75 ms |
| Linux-only (11 entries) | 0.4 ms | 40 ms |

*Thinking:* the profile said *where* (has), the numbers said it was absurd for
a hash lookup, and the hypothesis predicted a specific experiment: remove the
`/mnt/c` entries and the cost should drop. It did.

*Lesson:* **measure, then explain the anomaly, then test the explanation.**
The fix lives in two places: the shell avoids missing-command lookups (file
tests like `[ -x /usr/bin/pacman ]` instead), and you can optionally stop WSL
from appending the Windows PATH ([section 5](#5-shells-layout-speed-and-the-wsl-path-tip)).

### Stage 4: `.clang-format`: I modernized a retired file

On 2026-10-19 I rewrote the repo's `.clang-format` (keys deprecated years
ago, like `AlignEscapedNewlinesLeft`) and proved the rewrite changed nothing,
by comparing the **effective** configuration on both LLVM versions:

```sh
clang-format --style=file:old.clang-format --dump-config > old.yaml   # what the tool ACTUALLY uses
clang-format --style=file:new.clang-format --dump-config > new.yaml
diff old.yaml new.yaml && echo IDENTICAL      # ✅ on v21.1.8 AND v23.1.3
```

Correct method, wrong file. The laptop commit (2026-10-20) replaced it, and
its header says the repo copy was a *"superseded twin… retired in June
2026"*: the style that really formatted your code on Arch was a curated
**Chromium** style in `~/.clang-format`. clang-format uses the **nearest**
`.clang-format` walking up from the file, so on Arch `~/.clang-format` won
for everything under `$HOME`, and the repo copy formatted nothing at all.

The real file, checked the same way (✅): clang-format 21 and 23 both accept
every key, and every key has the **same effective value**; v23 merely shows
the old spellings in its new structure (`BinPackParameters: BinPack` appears
as `PackParameters: {BinPack: BinPack}`). On 12 real files (L0, klib, xv6,
algo, a C++ lock-free list) the output was byte-identical for 11. The 12th
differs because v23 no longer aligns an assignment that wraps onto a second
line. That is the formatter's *algorithm*, and no option controls it.

One rule from the first attempt still holds for any file that must serve
two versions: v23 renamed `BinPackParameters` to `PackParameters`, and v21
**rejects** the new name, so *write the newest name the OLDEST version
understands.*

*Thinking:* Stage 1 asked "is the machine running what the repo says?". The
same question applies per file, and for clang-format the answer depends on
the lookup rule (nearest file wins), not on what's in git.

*Lesson:* before improving a config, **prove it is the live one**. And a
portable config is necessary but not sufficient: the tool's **version** is
part of the output. Where byte-identical formatting matters (CI checks,
teams), pin the version, e.g. `pipx install clang-format==21.1.8` everywhere.

### Stage 5: clangd on the real L0 sources

`clangd --check=amgame/src/game.c` on a copy of your lab (never the real one:
`make` there would trigger the course tracer, which auto-commits your
in-progress klib work):

```
E [main_arg_wrong] Line 118: first parameter of 'main' (argument count) must be of type 'int'
```

GCC only *warns* about AbstractMachine's `int main(const char *args)`, and
`-Wno-main` silences it; clang calls it an **error** in a hosted program.
Bare-metal code is **freestanding** (no OS underneath), where `main` is an
ordinary function, so `-ffreestanding` for the editor is the *correct*
description, not a hack. Two more findings:

- `am/src/x86/qemu/ioe.c`: clang has `-Winitializer-overrides`, gcc's
  `-Wall` doesn't, and `-Werror` turned it into a red "error". The editor's
  copy of the flags drops `-Werror`, so clang-only warnings stay warnings.
- `klib/src/stdio.c`: `'am.h' file not found`, because clangd looks for
  `compile_commands.json` only in the file's directory **and its parents**,
  and the database was in `amgame/`, a sibling. Writing it to the
  os-workbench root fixed every file at once.

The same method on `~/algo`: no database at all, so clangd guessed flags
(157 and 461 bogus errors in two files). A `compile_flags.txt` mirroring the
Makefile brought it to 0, after one more surprise: **clang's `-Wconversion`
includes `-Wsign-conversion`, g++'s does not** (for C++). Without
`-Wno-sign-conversion` the editor showed 103 warnings `make` never prints.

*Lesson:* **the editor's compiler is not your build's compiler.** When they
disagree, describe the difference in the editor's config (`.clangd`), never
by changing the real build.

### Stage 6: Measuring clang-tidy noise instead of guessing

A global clang-tidy list runs on *every* file you open. I ran clangd with the
candidate checks over 26 real files (L0, AbstractMachine, klib, xv6, algo)
and tallied each finding. Kept: `bugprone-branch-clone` (it found identical
switch branches in your own klib `printf`), `macro-parentheses`,
`switch-missing-default-case`. Removed: `exception-escape` (fired on every
test program's `main`) and `performance-no-int-to-ptr` (kernels must cast
integers to pointers for MMIO and page tables).

*Lesson:* a warning that fires on correct code trains you to ignore the
warning column. **Tune lint rules on real code, with counts.**

### Stage 7: The vimrc: two twins, one chosen, five bugs

You keep two vimrc twins: a long, heavily documented one live in Arch's
`~/.vimrc` (the file you copied to WSL), and a concise one in the repo whose
first line says *"the single concise config, no defensive."* On 2026-10-19 I
merged the long twin. The laptop commit showed that the concise file is your
direction for the repo, so `home/.vimrc` is now **your concise file plus
minimal ports**: 381 lines, one reviewable diff (+71 / −25) against what you
wrote:

- YouCompleteMe → **yegappan/lsp** (your choice): pure Vim9 script, so
  installing is a git clone, with no cmake, Python headers or compile step.
- a **WSL clipboard** backend, and `set signcolumn=yes` so LSP and gitgutter
  signs never shift the text sideways.
- `set background=dark`: gruvbox has a dark and a light palette and follows
  `'background'`, which Vim only *guesses*. Konsole announces a dark terminal
  through `$COLORFGBG`; Windows Terminal announces nothing, so Vim fell back
  to light and WSL showed gruvbox's bright cream palette (✅ reproduced: same
  vimrc, `background=light` without `$COLORFGBG`, `dark` with it).
- **five bugs**, each reproduced first, each now guarded by a test that was
  proven to FAIL on your original file:

| Key | Symptom (✅ reproduced) | Cause |
|---|---|---|
| F5 | `E475: Invalid argument: _gotoid(...)` after every build | a bare `win_gotoid(...)` statement: legacy Vim script reads a line that starts with a name as an **Ex command**, here `:win[size]` with the argument `_gotoid(...)`. Function calls need `call`. |
| `\y` | `E121: Undefined variable: s:clip_write`, on **every** machine | a mapping runs when you PRESS it, outside the script that defined it, so its right-hand side cannot see `s:` variables. Read them inside a function and map `<SID>Copy(...)`, as your long twin did. |
| F8 | `E492: Not an editor command: MarkdownPreview` outside markdown | the plugin loads only for markdown (`'for'`); the key is now mapped only in markdown buffers |
| (start) | `E185: Cannot find color scheme 'gruvbox'` and a "Press ENTER" prompt on a machine without plugins; an uncolored first session | `colorscheme` without `silent!`, and the bootstrap re-sources the vimrc DURING VimEnter, where `au!` deletes the still-pending autocommand |
| Shift-Tab | without clang-format (this WSL box, until bootstrap), the **whole buffer** became `zsh:1: command not found: clang-format`; one `:w` and the source file is gone | a failed `:%!filter` replaces the text with its error output; the long twin's `s:FilterFailed()` (undo + message) was dropped in the rewrite, and is back |

Still true from the first pass: Vim leaves `$MYVIMRC` unset under
`vim -u file`; `has('wsl')` is 0 on WSL (`has()` silently returns 0 for any
name it doesn't know; test `exists('$WSLENV')`); and inside a `\`-continued
expression a `"` starts a *string*, not a comment.

*Thinking:* "no defensive" is a legitimate style: short files are easier to
read and change. But every one of the five bugs was silent until a key was
pressed, which is exactly what defensive habits protect against. The
resolution keeps the file concise and moves the defensiveness **into the
tests**: they press F5, F8, `\y` and `\p` for you on every run.

*Lesson:* **concise code + tests that exercise it** beats both "defensive
everywhere" and "concise and untested".

### Stage 8: The clipboard, byte by byte

Terminal Vim on both distros is built **without** clipboard support (✅
`-clipboard -X11` on Arch too), so `\y` / `\p` pipe text through external
programs: `wl-copy`/`wl-paste` (Wayland), `xclip` (X11), and on WSL, Windows'
own clipboard. Building the WSL backend took three measured fixes:

| Symptom | Cause (✅ measured) | Fix |
|---|---|---|
| text came back with an invisible U+FEFF in front | `iconv -t UTF-16` adds a byte-order mark; `clip.exe` stores it as a character | no BOM |
| every paste grew an extra empty line | PowerShell's console output adds its own newline | `[Console]::Write(...)` |
| a lone `中` came back as `-N` | `clip.exe` *guesses* the encoding; bytes `2D 4E` look like ASCII "-N" | write through PowerShell `Set-Clipboard`, always exact (~200 ms) |

Your real clipboard was saved in memory before every test and restored
byte-for-byte after it (verified each time). The concise vimrc uses
PowerShell for every write: one command instead of an ASCII/non-ASCII split,
at ~170 ms extra per copy.

*Lesson:* for encodings, **test with bytes, test edge cases** (one character,
empty, non-ASCII), and never trust a comment that says how a tool behaves,
including your own.

### Stage 9: Testing the tests

Four checks first "passed" when they should not have:

- `tmux source-file -n` accepted `set -g no-such-option on`: `-n` only
  *parses*; option names are checked at execution. Now the test executes the
  file in a throwaway server.
- The starship check missed a misspelled key: starship prints a warning only
  once per `STARSHIP_SESSION_KEY`, and the key was inherited from the shell I
  ran in. Now every check runs in a clean `env -i` environment.
- `[[ -o zle ]]` is **on** in `zsh -i` even with no terminal. The option
  records the request, not whether a line editor can run. `-t 0` is the real
  test.
- gdb has **no trailing comments**: `set print pretty on  # note` failed with
  `"on" or "off" expected`. (Same class of bug as Vim mappings, which your
  vimrc already documents.)

And three more from the second pass (2026-10-20):

- A run with a long `TMPDIR` hung: tmux sockets lived under it, and a Unix
  socket path may be at most **108 bytes** (it was 128: `File name too
  long`). Sockets now live in a short private dir in `/tmp`.
- My first negative control for the clipboard printed **nothing**: my
  `awk` pattern expected the heredoc at column 0, but it was indented, so the
  "test" was an empty file. A control that produces no output proves nothing
  either; check that it actually ran.
- The vimrc must load offline in tests, but your concise file has no "skip
  the plugin download" switch, and it shouldn't need one. A **test double**
  does it: a stub `plug.vim` whose functions do nothing, plus a fake `xclip`
  that keeps the "clipboard" in a file. The vimrc runs unchanged.

*Lesson:* **a check that cannot fail proves nothing.** Every validator in
`scripts/test.sh` has a *negative control*, and every regression test was
run once against the old, buggy file to see it fail.

### The short version

The repo looked fine, but the machine ran something else: no vimrc, drifted
copies. Comparing the two led to a silent `ls` bug, then profiling turned a
"slow shell" into a measured Windows-PATH effect. Proving the `.clang-format`
rewrite with `--dump-config` on two LLVM versions exposed a key-naming trap,
and running clangd on the real L0 sources exposed three clang-vs-gcc
differences that a `.clangd` file now describes. The vimrc moved to a
dependency-free LSP client, and every claim (clipboard, colorscheme, startup)
was turned into a test. Building those tests found four checks that couldn't
fail, so the tests themselves now have negative controls. Then the laptop's
commit arrived: it showed that I had polished a retired `.clang-format` and the
twin vimrc you don't want in the repo, so both were replaced by your real
files, and the concise vimrc's five silent bugs were fixed with a test each.

### The transferable principles (the part to keep)

1. **Check what is running, not only what is committed.** Drift is the
   default for copied files; one source of truth (links) removes it.
2. **Silent success is the worst failure.** Prefer tools and wrappers that
   fail loudly; treat "exit 0, no output" as suspicious.
3. **Measure, find the anomaly, predict, test.** "2.5 ms for a hash lookup"
   was the clue, and removing `/mnt/c` was the experiment.
4. **Prove refactors by comparing effective output** (`--dump-config`,
   compiled bytes), never by eyeballing source.
5. **The tool in your editor is not the tool in your build.** Describe the
   gap in the editor's config; never bend the real build to please the editor.
6. **Tune warnings on real code, with counts.** Noise destroys attention.
7. **Supporting two versions means writing for the older one.**
8. **Every check needs a negative control**, and tests run in a clean
   environment, never in yours.
9. **Prove which copy is live before improving it.** "Nearest file wins"
   (clang-format), "first file wins" (gdb), and twins on two machines all
   mean the file in front of you may format, configure, or run nothing.
10. **Keep code concise and put the defensiveness in tests** that press the
    keys and run the commands, then show each test failing on the old bug.

---

## 3. LSP from zero: how Vim learned to see your errors

### 3.1 Plain-language summary

A **language server** is a separate program that understands one language
deeply: clangd understands C and C++. The editor sends it your text as you
type; it answers with errors, completions, and where things are defined. The
**Language Server Protocol** (LSP) is the shared format of those messages, so
one server works with Vim, VS Code and every other editor.

### 3.2 Analogy: a compiler expert on a phone call

You (Vim) are on a call with an expert (clangd) who has your project's build
instructions (`compile_commands.json`). Every time you change a line, you read
the change aloud (`didChange`). The expert compiles in their head and calls
back with problems (`publishDiagnostics`). You can also ask "where is
`screen_w` defined?" (`definition`). If the expert has the **wrong build
instructions**, they confidently report problems that don't exist. That is
exactly what happened in Stage 5.

### 3.3 Worked walkthrough: the real messages

`scripts/lsp-probe.py` is a 134-line LSP client with no dependencies. It does
what Vim's plugin does, then prints the result like a compiler would:

```sh
$ cd /tmp/probe && cat bug.c
void set(int *a, int n) {
    if (n > 0) { a[0] = 1; } else { a[0] = 1; }
}
$ ~/config_files/scripts/lsp-probe.py bug.c        # ✅
bug.c:2:5: warning: If with identical then and else branches [bugprone-branch-clone]
bug.c:2:30: info: Else branch starts here
```

The four messages behind that line. Each is JSON preceded by a
`Content-Length: N` header, on clangd's stdin/stdout:

```text
→ initialize            {"processId": 1234, "capabilities": {...}}     "hello, here is what I support"
→ initialized           {}                                              "ready"
→ textDocument/didOpen  {"uri": "file:///tmp/probe/bug.c", "text": "..."}   "here is the file"
← textDocument/publishDiagnostics {"diagnostics": [{"range": ..., "message": "If with identical...",
                                   "code": "bugprone-branch-clone", "severity": 2}]}
```

In Vim the same pipeline measured (✅, `scripts/test.sh --full`, five runs): clangd
ready 0.05 to 0.26 s after opening a file (it varies with machine load); after typing `printff("x");` and an
undeclared variable, **2 errors appeared about 60 ms later**, with clangd's
"did you mean 'printf'?" note.

### 3.4 Common beginner confusions

- **"The LSP compiles my program."** It never produces a binary and never
  runs `make`. It parses in memory to *understand* the code. Your build is
  still `make`.
- **"clangd knows my flags."** Only from `compile_commands.json` (or
  `compile_flags.txt`). Without one it guesses, and guesses produce fake
  errors (157 in one algo file).
- **"clangd searches the whole project for the database."** It searches the
  file's directory and its **parents**, never siblings. Put the database at the
  common root.
- **"No red marks means `make` will succeed."** clang ≠ gcc (Stage 5): some
  warnings exist only in one of them. The editor is a fast first opinion;
  `make` is the verdict.
- **"`clangd --check` shows everything."** It prints only *errors*. For
  warnings and clang-tidy findings, use an LSP client: Vim, or `lsp-probe.py`.
- **"`K` is broken: it shows a man page."** On purpose: `K` = `:Man` (C
  library docs); LSP hover is `<Leader>K`.

### 3.5 The professional upgrade

- `--background-index` builds a persistent index under `.cache/clangd/`, so
  "find references" covers the whole project, not just open files.
- `--query-driver=/usr/bin/*gcc*` lets clangd ask a *cross* compiler
  (`riscv64-linux-gnu-gcc` for xv6) for its built-in include paths. It is an
  allow-list because clangd **executes** that binary; never widen it to `**`.
- Big codebases (Chromium, LLVM) use a remote index server; CMake projects get
  the database for free with `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`.
- Neovim has a built-in LSP client (`vim.lsp`); this vimrc stays on Vim, where
  yegappan/lsp is the closest equivalent.

---

## 4. Your NJU L0 lab with LSP, step by step

All three commands were run on a copy of your lab (✅ 17 database entries,
0 errors on clean sources).

```sh
cd ~/os-workbench
# 1. The editor-only flags (freestanding, no -Werror). Ignored by git: your
#    os-workbench .gitignore already ignores dotfiles (`.*`).
cp ~/config_files/templates/abstract-machine/.clangd .

# 2. Record every compile command. -B rebuilds everything, including the
#    AbstractMachine libraries in sub-makes (MAKEFLAGS passes -B down), so
#    all files appear. --output puts the database at the ROOT, so files in
#    amgame/ AND abstract-machine/ find it. (make also runs the course
#    tracer's auto-commit, exactly like every other make you run.)
cd amgame
bear --output ../compile_commands.json -- make -B ARCH=x86_64-qemu

# 3. Open a file. Errors now appear as you type.
vim src/game.c
```

`compile_commands.json` is ignored in every repo by
`~/.config/git/ignore`: it holds absolute paths of *this* machine.
Regenerate it when you add files or change `ARCH` (`native` uses different
flags).

In Vim: `]d` jumps to the next error, `<Leader>ji` applies clangd's fix
("did you mean printf?"), `F4` lists all errors, `F5` runs the build.

---

## 5. Shells: layout, speed, and the WSL PATH tip

The layout follows your note `~/notes/shell-login-vs-interactive.md` (§7):
**inherited** things (PATH, EDITOR) go in login files, **per-shell** things
(aliases, prompt, keys) in rc files.

| File | Read by | Holds |
|---|---|---|
| `.profile` | sh, bash (via `.bash_profile`), zsh (via `.zprofile`) at login | PATH, EDITOR, LESS, COLORTERM |
| `.bash_profile` | login bash | sources `.profile`, then `.bashrc` |
| `.zprofile` | login zsh | `/etc/profile` (Ubuntu needs it), then `.profile` |
| `.zshenv` | every zsh | one flag: skip Ubuntu's duplicate `compinit` |
| `.bashrc`, `.zshrc` | interactive shells | history, completion, keys, plugins, prompt |
| `.config/shell/common.sh` | both rc files | aliases, the ls/cat/rm wrappers, proxy functions |

**Human-only wrappers.** `rm` asks once (`-I`) and `cp`/`mv` ask before
overwriting, **only when stdin is a terminal**. Without a terminal nobody can
answer: `rm -i` reads end-of-file as "no" and silently deletes nothing, which
breaks scripts and AI agents. ✅ `zsh -i -c 'rm file' </dev/null` deletes without
prompting; at your keyboard you still get the question.

**Speed** (✅, best of 8, real terminal, plugins loaded):

| | zsh startup |
|---|---|
| old config | 64.6 ms |
| new config | 55.1 ms |
| new config, Windows PATH removed | 31.3 ms |

What made the new one faster: `_cached_init` caches the code that
`starship init`, `zoxide init`, `fzf --zsh` and `dircolors` print (about 2 ms
each per shell), keyed by binary path + arguments and refreshed when the binary
changes; `compinit`'s security audit runs once a day instead of every shell;
fewer missing-command lookups.

### The WSL PATH tip (optional, needs sudo)

WSL appends your whole Windows PATH to Linux's. To stop that:

```sh
sudo tee -a /etc/wsl.conf >/dev/null <<'EOF'

[interop]
appendWindowsPath = false
EOF
# then, from PowerShell or cmd on Windows:   wsl --shutdown
# and open a new terminal.
```

`~/.profile` notices (no `/mnt/c` in PATH) and adds back only the folders you
use: `System32` (`clip.exe`, `wsl.exe`), `C:\Windows` (`explorer.exe`),
PowerShell, and VS Code's `code`. Undo: delete those lines and `wsl --shutdown`.

---

## 6. The clang family: who reads which file

| File | Read by | Purpose | Where |
|---|---|---|---|
| `.clang-format` | clang-format, clangd (`:LspFormat`) | code *style* | `~/.clang-format` (fallback for everything under `~`); a project's own file wins |
| `config.yaml` | clangd | diagnostics, clang-tidy list, index, hints | `~/.config/clangd/config.yaml` (all projects) |
| `.clangd` | clangd | per-project flag fixes (`-ffreestanding`) | project root; merged **on top** of config.yaml |
| `.clang-tidy` | clang-tidy CLI, clangd | lint checks | project root (template in `templates/`) |
| `compile_commands.json` | clangd, clang-tidy, IWYU | the exact command per file | generated (`bear -- make -B`), never committed |
| `compile_flags.txt` | clangd | one flag list for every file | folders of single-file programs |

Two facts that surprise people:

- clangd **embeds** clang-format's library: `:LspFormat` formats exactly like
  the `clang-format` binary (same `.clang-format`). Your `Shift-Tab` calls the
  binary; if it is missing or fails, the buffer is restored and a message
  says why (Stage 7).
- Project `.clangd` files are *untrusted* (`trusted=false` in clangd's log), so
  they cannot make clangd run arbitrary commands; your home config is trusted.

---

## 7. The other tools, and the choices inside them

**git** (`~/.config/git/config`; your identity stays in `~/.gitconfig`, which
git reads *after* this file, so it wins).

- `pull.ff = only`: a plain `git pull` never invents a merge commit; it stops
  and asks. I first believed this would break your lab command
  `git pull --no-rebase --no-edit origin L1`, then tested it (✅ git 2.53): an
  explicit `--no-rebase` overrides `pull.ff` (since git 2.34), so the lab
  merge still works, and the plain pull is still protected (exit 128 + hint).
- `merge.conflictStyle = zdiff3`: conflicts also show the common ancestor, so
  you can see what *both* sides changed from.
- `rerere`, `fetch.prune`, `push.autoSetupRemote`, `commit.verbose`: small
  quality-of-life defaults, each commented in the file.

**tmux**: `escape-time 10` (the default 500 ms makes every `Esc` in Vim
lag), true color passthrough, `focus-events` (Vim's autoread),
`set-clipboard on` (copy mode reaches Windows through OSC 52).

**gdb**: history across sessions, pretty structs, no pager, no "are you
sure?", `debuginfod` **on** (your laptop's choice: symbols for system
libraries download on demand, and the startup question disappears), and the
per-project `.gdbinit` allow-list (xv6). One trap, verified on gdb 17.1: gdb
reads only the **first** of `~/.config/gdb/gdbinit` and `~/.gdbinit` that
exists. With both present, `~/.gdbinit` was silently ignored (`confirm` stayed
on). So the laptop's two lines live in the XDG file, and an old `~/.gdbinit`
should be deleted.

**starship**: one file for both machines. On Arch the ribbon is a color emoji
that ignores the style color; on WSL a Nerd Font glyph takes it. A byte-level
check caught that a rewrite had dropped the glyph (U+EDA5); it was restored
byte-for-byte.

**readline** (`.inputrc`): Up/Down search history by prefix in bash, gdb and
python, the bash twin of zsh's history-substring-search.

---

## 8. Testing the configs (and testing the tests)

`scripts/test.sh` builds a throwaway HOME, runs `install.sh` into it, and
checks everything with the program that actually reads each file:

| Section | What it proves |
|---|---|
| 1. Syntax | `sh -n`, `bash -n`, `zsh -n` on every shell file |
| 2. Lint | shellcheck (POSIX rules for `install.sh` and `.profile`) |
| 3. install.sh | dry-run changes nothing; links; backups keep content; idempotent; uninstall; refuses root |
| 4. Shells | 5 startup modes with empty stderr; `ls` works without a terminal; `rm` doesn't prompt agents; a real-terminal zsh via tmux |
| 5. Vim | loads cleanly with plugins stubbed out; F8 only in markdown; `\y`/`\p` round trip through a fake `xclip`; `--full`: installs 23 plugins, applies the colorscheme, F5 builds without errors, typos produce clangd errors |
| 6. Configs | clang-format (21 and 23), clangd (+ clang-tidy really runs), tmux, gdb, git, starship, YAML, TOML, each with a negative control |

Why **tmux** appears in the tests: some behavior only exists with a real
terminal (ZLE, Vim's UI). `tmux new-session -d` gives a real pseudo-terminal
without a screen, and `tmux capture-pane -p` prints what a human would see.

**Test doubles** stand in for things a test can't or shouldn't use: a stub
`plug.vim` (same function names, empty bodies) lets the vimrc load offline,
and a fake `xclip` (a 4-line shell script that keeps the "clipboard" in a
file) lets `\y` / `\p` run end to end on any machine, CI included. The
vimrc itself never knows it's being tested.

**Regression tests** pin down fixed bugs: Shift-Tab with a failing formatter
(a fake `clang-format` that exits 1), F5 (E475), `\y` (E121), F8 (E492) and
the fresh-machine colorscheme each have one. Each was run once against
your original laptop vimrc and **failed** there (✅), the proof that it tests
the bug and not just the happy path.

**The Arch sandbox** (`scripts/arch-sandbox.sh`) needs no root and no Docker.
Arch publishes a "bootstrap" tarball that is a complete root filesystem;
`bwrap` (bubblewrap) starts processes in new Linux **namespaces**: a user
namespace maps your uid to 0 (so pacman believes it is root), and a mount
namespace makes the unpacked tree its `/`. That is the same kernel feature
containers use (your `~/notes/containers-and-kvm-from-zero.md`, §8.8 dissects
this exact sandbox). ✅ From
nothing to a ready sandbox in about 10 minutes through the USTC mirror, then
all 59 checks passing, none skipped (it installs the same tools as CI's Arch job).

**CI** (`.github/workflows/ci.yml`) runs `scripts/test.sh --full` in
`ubuntu:26.04` and `archlinux:latest` containers on every push, and every
Monday, so a distro update that breaks a config (a new clang-format dropping a
key) shows up as a red badge before it surprises you.

---

## 9. Two machines, one repo: the refused pull, the leaked key, and a fresh start

### 9.1 What happened (✅ diagnosed 2026-10-20)

On WSL, all of the 2026-10-19 work was **uncommitted**: three renames staged
by `git mv`, an edited `README.md`, ~20 new files. Meanwhile on the Arch
laptop you committed and pushed `4febb70 laptop arch tmp modification`, which
**modified** `.vimrc`, `.clang-format` and `README.md` and **added** a
`.gdbinit`, three analysis documents and a `vimrc-claude/` folder. Then on
WSL you ran `git pull`:

```text
            4febb70  laptop commit = origin/main  (changed .vimrc, .clang-format, README.md)
           /
6909b3f ──●  main, HEAD on WSL
           \
            (uncommitted) .vimrc → home/.vimrc, .clang-format → home/…, README.md edited, ~20 new files
```

The same three files changed on both sides, and one side wasn't even a
commit yet. Git refused to merge and **changed nothing**.

### 9.2 How to analyze a refused pull (from zero)

**Plain summary.** `git pull` is two commands. `git fetch` downloads the
other side's new commits into `origin/main` and never touches your files.
`git merge origin/main` then combines them into your branch and your files.
When the merge would overwrite something you haven't committed, git stops
before changing anything.

**Analogy: a shared lab notebook.** *Fetch* = photocopying your partner's
new pages into a folder on your desk: harmless, your notebook is untouched.
*Merge* = gluing those pages into your notebook. If you have loose notes lying
on exactly the pages the glue would cover, a careful assistant (git) refuses
to glue until you have filed your notes (committed them).

**Walkthrough: five read-only commands, and what each told us.**

```sh
git status                  # "behind 'origin/main' by 1 commit, and can be fast-forwarded"
                            #   + your staged renames, edited README, untracked files
git log --oneline --graph --all -n 10   # origin/main is ONE commit ahead; main didn't move
git reflog -n 5             # HEAD's last move is the clone: the merge never happened
git show --stat origin/main # what the incoming commit touches: .vimrc, .clang-format, README.md, ...
git diff --stat HEAD        # what YOU touched: the overlap is exactly the problem
```

Then read the other side's content without touching yours, file by file:
`git show origin/main:.vimrc | less`. That is how this guide learned that
the laptop held your **real** clang-format and your **concise** vimrc
(sections 2.4 and 2.7).

**Common beginner confusions (the part to read twice):**

- **"The pull failed, so nothing came down."** The *fetch* half succeeded:
  `origin/main` already holds the laptop commit. Only the *merge* half
  refused.
- **"I lost my work."** A refusal is atomic: nothing changed. `git status`
  still lists every change.
- **"`git reset --hard origin/main` will fix it."** It would **destroy**
  every uncommitted change (the whole restructure) and cannot be undone,
  because uncommitted work isn't in any commit for `git reflog` to find. Never
  "fix" a refused pull with `reset --hard`.
- **"Untracked files are safe."** `reset --hard` leaves them alone, but
  `git clean -fd` deletes them, and no git command can bring them back.
  Commit early.
- **"A conflict means something broke."** A conflict is git asking a
  question it can't answer alone: *both sides changed this, which content is
  right?* You answer with knowledge git doesn't have.

**The professional upgrade:** avoid the situation instead of solving it.
Commit and push before you leave a machine, and `git pull` before you start
on the other. To look before merging: `git fetch`, then
`git log ..origin/main` (what's new) and `git diff ...origin/main` (what it
changes). To preview a merge's conflicts without touching anything:
`git merge-tree --write-tree --name-only HEAD origin/main`.

### 9.3 Handling it: four options

| Option | How | Pros | Cons |
|---|---|---|---|
| Commit, then merge | commit the work on a branch, `git merge origin/main`, resolve | nothing rewritten; every step is a commit | keeps all old history, including what you'd rather not keep |
| Stash, fast-forward, pop | `git stash push -u`; `git merge --ff-only origin/main`; `git stash pop` | linear history | conflicts surface inside `stash pop`; a dropped stash is hard to find |
| Commit, then rebase | commit, then `git rebase origin/main` | linear history | conflicts can repeat at each of 7 commits |
| **Start fresh** (chosen) | build a new history from the tested files, replace GitHub's with one force-push | a clean, readable history; removes the leaked key from the published branch | rewrites published history: every clone (the laptop) must re-clone |

Normally, rewriting published history is the wrong tool: anyone who cloned it
is left with a diverged copy. Here it is justified twice over. The repo is
yours alone (2 machines, 0 forks), and the old history contains a leaked
secret (9.4). The rehearsed merge (commit, merge, answer 3 conflicts) still
works if you ever need it; the analysis above is how you'd find your way.

### 9.4 The leaked key: what to do, in what order

Commit `f5d1d1c` (2026-06-10) added `export GEMINI_API_KEY="..."` to
`.zshrc`; `6909b3f` (2026-09-29) removed the line in a NEW commit. The old
commit still contains it, and the repo is **public** (✅ GitHub API:
`visibility: public`). Bots scan public repositories for keys within
minutes, so the key must be treated as **stolen since June**.

1. **Revoke it first.** Google AI Studio → API keys → delete that key, then
   create a new one. Check the usage page for calls you didn't make.
2. **Store the new one where git can't see it:** `~/.zshrc.local` (sourced
   by `~/.zshrc`, `chmod 600`, never in the repo).
3. **Only then clean history** (9.5). Rewriting history does not "unleak"
   anything: copies already exist. It just stops the dead key from staying
   on display.

**Common beginner confusion:** *"I deleted the line and committed, so the key
is gone."* A commit records a SNAPSHOT; deleting a line adds a new snapshot,
and every old one stays reachable: `git show f5d1d1c:.zshrc` prints it.

### 9.5 Fresh start, step by step (✅ rehearsed)

Every command below was extracted from this document and run verbatim on a
copy of the repo, with a stand-in "GitHub" holding today's state and a
stand-in laptop clone. The new history had 7 commits and **0** occurrences
of the key; the swap kept every `~` symlink working; `make test` passed.
Re-run on 2026-10-21 with the fixed tree (57 checks pass); that run added the
swap-file check (Step 1), `chmod -x` (Step 2), the e-mail check (Step 4), the
publish check (Step 5) and Step 7. Paste the lines into a terminal, not into
a `set -e` script: Step 4's `grep -c` exits with status 1 when it counts 0,
which here is the good outcome.

**Step 0 (browser): revoke the key** (9.4). Do it before anything else.

**Step 1: close every Vim on a repo file, then back up the old history.**
`vim ~/.vimrc` counts: through the link, its swap file is `home/.vimrc.swp`
*inside* the repo. Step 2 copies whole folders and git hides `*.swp`
(ignored), so a live swap file would ride into the new repo and greet you
with Vim's ATTENTION prompt after the swap (✅ happened in the 2026-10-21
rehearsal). A bundle is the whole repository (every commit and branch) in
one file; `git clone` can read it back.

```sh
cd ~/config_files
find . -name '*.sw?'                     # must print nothing
git bundle create ~/config_files-old-history.bundle --all
git bundle verify ~/config_files-old-history.bundle
chmod 600 ~/config_files-old-history.bundle
```

(It contains the leaked key, revoked or not: keep it on your disk only.
To look inside later, `git clone --mirror ~/config_files-old-history.bundle
old-history.git` restores every branch, the laptop commit included; a plain
`git clone` maps only the branches under `refs/heads/`.)

**Step 2: build the fresh repo in a NEW folder.** A new folder can't be
confused by the old index, staged renames or history. Copy exactly the files
that belong in the repo; the archived leftovers come straight out of the old
history with `git archive`.

```sh
mkdir ~/config_files-fresh
cd ~/config_files-fresh
git init -b main
cp -a ~/config_files/LICENSE ~/config_files/README.md ~/config_files/.gitignore \
      ~/config_files/.gitattributes ~/config_files/.editorconfig \
      ~/config_files/install.sh ~/config_files/Makefile ~/config_files/home \
      ~/config_files/scripts ~/config_files/templates ~/config_files/docs \
      ~/config_files/.github .
git -C ~/config_files archive origin/main clang-format-analysis-2026-09-01.md \
    vimrc-analysis-2026-08-31.md vimrc-plugin-analysis-2026-09-01.md vimrc-claude \
    | tar -x -C docs/archive
cp ~/config_files/vimrc docs/archive/vimrc-long-twin.vim
chmod -x docs/archive/vimrc-long-twin.vim   # the source is mode 755; a vimrc is not a program
```

**Step 3: commit in logical steps.** Each commit is one topic, so the log
reads like a table of contents.

```sh
git add LICENSE README.md .gitignore .gitattributes .editorconfig
git commit -m "chore: license, README and repository settings"
git add home/.profile home/.bash_profile home/.bashrc home/.inputrc \
        home/.zshenv home/.zprofile home/.zshrc home/.config/shell
git commit -m "feat(shell): bash and zsh share one setup"
git add home/.vimrc home/.vim
git commit -m "feat(vim): concise vimrc with LSP (yegappan/lsp + clangd)"
git add home/.clang-format home/.config/clangd templates
git commit -m "feat(clang): clang-format style, clangd config, project templates"
git add home/.config/git home/.config/tmux home/.config/gdb home/.config/starship.toml
git commit -m "feat: git, tmux, gdb and starship configs"
git add install.sh Makefile scripts .github
git commit -m "feat: installer, bootstrap, tests, Arch sandbox, CI"
git add docs
git commit -m "docs: from-zero guide and archived analyses"
git status --short
```

The last command must print **nothing**: every file is committed.

**Step 4: check before publishing.**

```sh
git log -p | grep -c -E 'AIza[0-9A-Za-z_-]{35}'
git log --format=%ae | sort -u
git log --oneline
make test
```

Expect `0`, one address ending in `@users.noreply.github.com`, 7 commits,
and no FAIL. The second command lists every author e-mail: the old commits
carry your Gmail address, the new ones the private noreply address from
`~/.gitconfig`, so the fresh start takes Gmail off the published branch
too. The first command counts strings
SHAPED like a Google API key (always `AIza` + 35 characters) in every
commit; on the old history it finds 2 (the line added in `f5d1d1c` and
removed in `6909b3f`). Don't search for the NAME `GEMINI_API_KEY`: this
guide mentions the name, so that count would never be 0 (a trap found by
re-running these steps from the final text). Two SKIPs are normal until `scripts/bootstrap.sh` has installed
clang-format and shellcheck.

**Step 5: publish (the only destructive step).**

```sh
git remote add origin git@github.com:gaoyuankan-dot/config_files.git
git push --force-with-lease=main:4febb7053d669bd7eeb46283dd49093e2cb9d922 -u origin main
git ls-remote origin main && git rev-parse main     # the same hash twice = published
```

`--force` would overwrite GitHub's `main` no matter what. `--force-with-lease=main:<hash>`
overwrites it **only if it is still exactly `4febb70`**, the laptop commit
you saw. If anything was pushed since (from the laptop, say), git refuses
instead of silently destroying it (✅ checked: with GitHub moved on to
another commit, the same lease was `! [rejected] (stale info)` and GitHub
stayed unchanged).

**Step 6: swap the folders.** Your `~/.zshrc`, `~/.vimrc`, ... are symlinks
to the PATH `~/config_files/home/...`, so after the swap they point into the
new repo without being touched.

```sh
cd ~
mv ~/config_files ~/config_files-old && mv ~/config_files-fresh ~/config_files
readlink -e ~/.zshrc ~/.vimrc
cd ~/config_files && git status && git log --oneline -3
```

`readlink -e` must print two paths inside `~/config_files/home/`. Keep
`~/config_files-old` for a few days; when everything works,
`rm -rf ~/config_files-old` (the bundle remains your backup).

A terminal that was already inside `~/config_files` during the `mv` stays
in the OLD folder: a shell's current directory follows the directory, not
its name (✅ checked). Run `cd ~/config_files` there (or open a new tab), and
restart any Claude Code session that works in the repo.

**Step 7 (browser): lock it in.**

1. **Actions** tab: this is the first run of `ci.yml` ever (it was never
   pushed before); both jobs, Ubuntu and Arch, must turn green.
2. **Settings → Advanced Security:** secret scanning and push protection
   on, so GitHub rejects a push that contains a key.
3. **Settings → Rules → Rulesets → New branch ruleset:** target the default
   branch, keep *Restrict deletions* and *Block force pushes*, set it
   *Active*. Step 5 was the one force-push this repo should ever need; from
   now on GitHub refuses the next one, even a plain `--force`.

**What GitHub still remembers:** after a force-push the old commits are
unreachable from any branch, but GitHub may keep serving them by their hash
for a while. With the key revoked that is harmless. To purge them for good,
GitHub Support can remove cached views, or you can delete and recreate the
repository.

### 9.6 On the Arch laptop

The laptop's clone still holds the old history, which no longer shares a
single commit with GitHub's (`git merge-base` finds nothing). A `git pull`
there fails (✅ rehearsed): first with *Need to specify how to reconcile
divergent branches*, and with a strategy chosen, *refusing to merge unrelated
histories*. Re-clone instead:

```sh
cd ~
git -C ~/config_files status            # anything uncommitted? copy it somewhere first
mv ~/config_files ~/config_files-old
git clone git@github.com:gaoyuankan-dot/config_files.git ~/config_files
# no SSH key on the laptop? the repo is public, so HTTPS clones without a login:
#   git clone https://github.com/gaoyuankan-dot/config_files.git ~/config_files
cd ~/config_files
scripts/bootstrap.sh
./install.sh --dry-run                  # read the plan: your live ~/.vimrc etc. get backed up
./install.sh
rm ~/.gdbinit                           # gdb reads ~/.config/gdb/gdbinit now; both lines are in it
make test
```

Then in Vim: `:PlugInstall` (adds yegappan/lsp) and `:PlugClean` (removes
YouCompleteMe).

Give the laptop the same private commit e-mail as WSL (`git config
user.email` on WSL prints it; `git config --global user.email <it>` on the
laptop). Otherwise its next commit puts your Gmail address back on GitHub.

### 9.7 The two-machine rule from now on

1. **Leaving a machine:** `git status`, commit, `git push`.
2. **Arriving at the other:** `git pull` first, then edit.
3. **Secrets never enter the repo:** they live in `*.local` files.
   Before every commit, glance at `git diff --staged`.
4. **Forgot, and a pull refused?** Don't panic, and never `reset --hard`:
   commit your work on a branch, then `git merge origin/main`.

---

## 10. Pros and cons, and the alternatives

**Deploying**

| Option | Pros | Cons |
|---|---|---|
| `install.sh` (chosen) | no dependencies, readable, backups, dry-run | you maintain it (146 lines) |
| GNU Stow | standard, tiny | refuses existing files (no backup); may symlink whole directories ("folding") unless `--no-folding` |
| chezmoi | templates per machine, encrypted secrets, Windows too | files are copies: edit with `chezmoi edit`; more concepts |
| bare git repo in `~` | no links at all | every `git status` sees your whole home; easy to commit the wrong file |
| Nix home-manager | packages + configs declared together, rollbacks | a new language and ecosystem |

**Vim LSP client**

| Option | Pros | Cons |
|---|---|---|
| yegappan/lsp (chosen) | Vim9 script, no runtime deps, fast, maintained by a Vim developer | Vim ≥ 9.0 only; smaller community |
| YouCompleteMe | excellent completion ranking | compile step, Python, cmake, large |
| coc.nvim | VS Code-like, huge extension set | needs Node.js |
| vim-lsp + asyncomplete | works on Vim 8 | three plugins to wire; slower legacy script |
| Neovim + built-in LSP | the most active ecosystem | a different editor; Lua config |

**vimrc style**

| Option | Pros | Cons |
|---|---|---|
| Concise file + tests (chosen) | short, readable, your own words; the tests press the keys | a bug hides until a test (or you) presses that key |
| Long, defensive, documented | every line explains itself; guards on every edge | ~950 lines to maintain; the explanation can drift from the code |

**Wrapping `ls` with eza**: kept for humans (your choice), real `ls` for
everyone else. The purist alternative is new names only (`ll`, `lt`) and
`ls` untouched: zero surprises, at the cost of habit.

---

## 11. How to improve: now vs. bleeding edge

**Now (small, safe):**

- Apply the WSL PATH tip: -24 ms per shell, faster Tab completion of commands.
- `cp templates/cpp-practice/compile_flags.txt ~/algo/`: 0 bogus errors there.
- `sudo apt install wl-clipboard` only if you ever use Linux GUI apps
  through WSLg; Vim doesn't need it.
- `:PlugSnapshot ~/config_files/plug.lock` after a good `:PlugUpdate`, and
  commit it: an exact record of plugin versions you can restore.
- `packadd termdebug`: one line, Vim's built-in gdb front end. Your own
  plugin analysis (`docs/archive/vimrc-plugin-analysis-2026-09-01.md` §9.3)
  ranked it "do this first"; debugging is the one loop that still leaves Vim.
- Pin the formatter where identical output matters (CI, teams):
  `pipx install clang-format==21.1.8` on both machines.

**Bleeding edge:**

- Vim 9.1's native `'autocomplete'` option with the LSP as an omnifunc
  source: one completion system for every buffer, LSP or not.
- Vim 9.1's **clipboard providers** (`:h clipboard-providers`): back the real
  `"+` register with the same external tools, so every `"+y` / `"+p` works,
  not only `\y` / `\p`. (The 2026-10-19 long vimrc did this; the concise one
  keeps your simpler mappings.)
- `pre-commit` hooks running `scripts/test.sh` before each commit.
- Renovate/Dependabot-style plugin updates: CI tests a plugin bump before you
  accept it.
- Nix home-manager or chezmoi once a third machine (or macOS) appears.

---

## 12. Expansion: gotchas and edge cases

- **zsh doesn't word-split** unquoted variables: `for p in $LIST` loops once
  over the whole string; write `${=LIST}`. (Bash does split.)
- **zsh's `=word`** expands to the path of command `word`: `echo ======`
  fails with "not found". Quote it.
- **Aliases expand while a block is parsed**: an alias defined inside the same
  `if` block as a function that uses it is not active yet (shellcheck SC2262).
- **`cmd1 && cmd2; cmd3`** hides `cmd1`'s failure: `cmd3` runs anyway. One
  such chain hid an `rmdir` failure during this work until a later test caught it.
- **`$MYVIMRC` is unset under `vim -u file`**; use `expand('<sfile>:p')`.
- **`:set opt+=x` on a comma list can duplicate** `x` when re-sourced; pair it
  with `opt-=x` first.
- **Ubuntu renames** `bat` → `batcat`, `fd` → `fdfind`; aliases don't help
  scripts, shims do.
- **eza with no path and a non-terminal stdin reads stdin**: empty output.
- **`clangd --check` hides warnings**; `lsp-probe.py` shows them.
- **clang `-Wconversion` ⊃ `-Wsign-conversion`, g++ (C++) doesn't.**
- **A Windows-edited script gets CRLF line ends** ("bad interpreter:
  /bin/sh^M"); `.gitattributes` forces LF.
- **gdb has no trailing comments.** Neither do Vim `:map` lines.
- **A Vim script line that starts with a name is an Ex command.** A bare
  `win_gotoid(id)` runs `:win[size]` (E475); function calls need `call`.
- **A mapping's right-hand side cannot see `s:` variables** (E121): it runs
  when you press it, outside the script. Use a function via `<SID>`.
- **First file wins (gdb) vs nearest file wins (clang-format):** know each
  tool's lookup rule before deciding which copy of a config matters.
- **A Unix socket path may be at most 108 bytes**; a deep `TMPDIR` breaks
  tmux with "File name too long".
- **The formatter's version is part of its output:** the same `.clang-format`
  wrapped one assignment differently on LLVM 21 and 23.
- **Vim guesses `'background'`** from `$COLORFGBG` (Konsole sets it, Windows
  Terminal doesn't) or by asking the terminal; no answer means "light". Set
  it explicitly when a colorscheme has two palettes.
- **Deleting a secret in a new commit doesn't remove it:** every old snapshot
  stays reachable (`git show <old-commit>:file`). Revoke the secret first;
  rewriting history only stops displaying it.
- **`git pull` = `git fetch` + `git merge`.** A refused pull already fetched;
  `--ours`/`--theirs` swap meaning between merge and rebase.
- **`sudo` strips the proxy variables**; pacman needs them, apt has its own
  `Acquire::http::Proxy`.

---

## 13. Mental checklist

- [ ] Is the machine running what the repo says? (`readlink ~/.zshrc`)
- [ ] Did I measure before optimizing, and after?
- [ ] Does each new check have a negative control that fails?
- [ ] Does this config serve two versions? Write for the older one.
- [ ] Editor errors that `make` doesn't show? Fix `.clangd`, not the Makefile.
- [ ] Secrets in a `*.local` file, never in git?
- [ ] Changed a config? `make test` (57 checks, ~10 s) before committing.
- [ ] Leaving this machine? Commit and push. Arriving? `git pull` first.
- [ ] A pull refused? Read-only diagnosis first (`status`, `log --graph --all`,
      `reflog`, `show --stat origin/main`); never `reset --hard` uncommitted work.
- [ ] Which copy of this config is live (nearest wins? first wins?)?
- [ ] Fixed a bug? Add a test, and watch it fail on the old code once.
- [ ] A command that "succeeded" with no output? Verify it did anything.

---

## 14. Learning path and where to go next

1. **Today:** read `install.sh` top to bottom (146 lines of POSIX sh). Then
   `scripts/lsp-probe.py`: it's the shortest path to really understanding LSP.
2. **This week:** the official specs behind the tools:
   [LSP specification](https://microsoft.github.io/language-server-protocol/),
   [clangd configuration](https://clangd.llvm.org/config),
   [clang-format style options](https://clang.llvm.org/docs/ClangFormatStyleOptions.html),
   `:help lsp` (yegappan/lsp) and `:help clipboard-providers` in Vim.
3. **Shell depth:** `man zshoptions` (ZLE, word splitting), `man bash` →
   INVOCATION, and your own `~/notes/shell-login-vs-interactive.md`.
4. **Containers from the inside:** `man bwrap`, `man user_namespaces`, then
   rebuild `scripts/arch-sandbox.sh` with plain `unshare` as an exercise.
5. **Stretch exercise:** add a third CI job for macOS that runs only
   `install.sh` tests and `bash -n` under macOS's bash 3.2. What breaks, and
   why does `install.sh` (POSIX sh) survive while `.bashrc` needs guards?
