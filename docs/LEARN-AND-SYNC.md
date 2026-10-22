# Learn this repo from zero, then keep two machines in sync

*Written 2026-10-20 for a junior programmer (you, Ken). Companion to
[GUIDE.md](GUIDE.md): GUIDE explains **why** every config is the way it is;
this file is the **study plan** and the **daily routine**. Every ✅ marks a
command that was run on the WSL machine on 2026-10-20 and printed what is
shown. Practice labs run in throwaway folders and never touch your real files.*

## Contents

- [0. TL;DR: the plan on one screen](#0-tldr-the-plan-on-one-screen)
- [1. Where you are right now (snapshot, 2026-10-20)](#1-where-you-are-right-now-snapshot-2026-10-20)
- [2. The idea from zero: what, why, how](#2-the-idea-from-zero-what-why-how)
- [3. Phase 0: make it safe to explore (10 min)](#3-phase-0-make-it-safe-to-explore-10-min)
- [4. Phase A: learn the repo, one layer at a time](#4-phase-a-learn-the-repo-one-layer-at-a-time)
- [5. Phase B: finish the move (one time)](#5-phase-b-finish-the-move-one-time)
- [6. Phase C: the everyday update-and-sync loop](#6-phase-c-the-everyday-update-and-sync-loop)
- [7. Common beginner confusions (read these twice)](#7-common-beginner-confusions-read-these-twice)
- [8. Pros and cons: ways to learn, ways to sync](#8-pros-and-cons-ways-to-learn-ways-to-sync)
- [9. How to improve: now vs. bleeding edge](#9-how-to-improve-now-vs-bleeding-edge)
- [10. Expansion: gotchas and edge cases](#10-expansion-gotchas-and-edge-cases)
- [11. The short version of the whole story](#11-the-short-version-of-the-whole-story)
- [12. The transferable principles (the part to keep)](#12-the-transferable-principles-the-part-to-keep)
- [13. Mental checklist](#13-mental-checklist)
- [14. Suggested learning path and where to go next](#14-suggested-learning-path-and-where-to-go-next)

---

## 0. TL;DR: the plan on one screen

| Phase | What you do | Time | Done when |
|---|---|---|---|
| **0. Safety** | one backup archive; clear stale Vim swap files | 10 min | you could lose the folder and still have your work |
| **A. Learn** | 8 read-only stages: map → one file end to end → installer → shells → Vim → other tools → tests → history | 4–6 sessions of ~45 min | you can answer every "Check yourself" question |
| **B. Finish the move** | revoke the leaked key, then GUIDE §9.5 (fresh history) and §9.6 (laptop re-clone) | 1 evening | `dots_status` says 0 uncommitted, 0 ahead, 0 behind, links OK, on **both** machines |
| **C. Daily loop** | pull → edit → test → review → commit → push, on every change | minutes | habit |

The one rule that prevents most trouble: **leaving a machine → commit and
push; arriving → pull before you edit.**

---

## 1. Where you are right now (snapshot, 2026-10-20)

This section describes a one-time situation. After Phase B, it is history,
and you can delete it.

| Fact | Value (✅ checked) | What it means |
|---|---|---|
| Your local `main` | `6909b3f` | the last commit made on this machine |
| GitHub's `main` | `4febb70` "laptop arch tmp modification" (`git ls-remote origin`) | the laptop pushed one commit you don't have |
| Working tree | 3 staged renames, 1 modified file, ~20 **untracked** files | the whole 2026-10-19 rebuild exists **only on this disk**: no commit holds it |
| Symlinks | `./install.sh --dry-run` → `0 linked, 17 already in place` | `~` already runs the files in this folder |
| Tests | `make test` → `57 passed, 0 failed, 0 skipped` (2026-10-21) | every check runs: clang-format and shellcheck are installed |
| Stray files | `.swp`, `.swo`, `scripts/.test.sh.swp` (✅ gone by 2026-10-21) | Vim swap files left behind by Vim sessions that died (their processes are gone) |
| Stray file | `vimrc` (847 lines, repo root) | your long Arch twin; GUIDE §9.5 Step 2 archives it as `docs/archive/vimrc-long-twin.vim` |

**Do not run these until Phase B is done**, because your work is uncommitted:

| Command | Why it's dangerous *right now* |
|---|---|
| `git pull` | refuses anyway (GUIDE §9.1), and tempts you into the next two |
| `git reset --hard`, `git checkout -- <file>`, `git restore <file>` | overwrite uncommitted edits with an older version; no undo exists for work that was never committed |
| `git clean -fd` | deletes untracked files, i.e. most of the rebuild |
| `git add -A` / `git add .` | stages everything, including files you didn't mean to commit |

Everything in Phase A is read-only, so it is safe today.

---

## 2. The idea from zero: what, why, how

### 2.1 Plain-language summary

**What.** This repo is the single real copy of your settings files. Every
machine *points at* that copy instead of keeping its own, and git carries
changes between machines through GitHub.

**Why.** Copies drift apart. You fix something on the laptop, forget it on
WSL, and a month later the two behave differently and you don't know why
(GUIDE §2 Stage 1 found exactly that). One copy plus git means one truth,
plus a history of every change, plus an undo.

**How.** `install.sh` turns each `~/<file>` into a **symlink** (a pointer) to
`~/config_files/home/<file>`. Edit either path and you edit the same bytes.
`git commit` records the change; `git push` uploads it; `git pull` on the
other machine downloads it into *its* copy, which its own symlinks already
point at.

### 2.2 Analogy: a shared recipe binder in two kitchens

You cook in two kitchens (WSL and the Arch laptop). Each kitchen has **one
binder** of recipes (the repo folder). Stuck on the fridge, the stove and
the oven are **sticky notes that say "see binder, page 12"** (symlinks):
the appliances read the binder through them, so there is no second copy to
go stale. A **photocopy service** in the middle (GitHub) holds the master
binder.

- Changing a recipe = editing a binder page (`vim ~/.zshrc`).
- Writing the change into the binder's logbook = `git commit`.
- Sending your new pages to the copy service = `git push`.
- Picking up the latest pages in the other kitchen = `git pull`.
- A **new** appliance needs a **new** sticky note = `./install.sh` (a pull
  alone can't stick notes on things).
- Both kitchens edited the same recipe = a **conflict**: the copy service
  can't know which version is right, so it asks you.
- A cook who is already mid-dish keeps using the version they read at the
  start = a running shell keeps its old settings until you restart it
  (`exec zsh`).

### 2.3 Worked walkthrough: a symlink, by hand (✅, throwaway folder)

Paste this into a terminal. It builds a tiny "repo" and "home" in a
temporary folder, so nothing real is touched.

```sh
lab=$(mktemp -d)                       # a private throwaway folder
mkdir "$lab/repo" "$lab/home"
echo 'alias a=1' > "$lab/repo/rc"      # the ONE real file
ln -s "$lab/repo/rc" "$lab/home/rc"    # home/rc = a pointer to repo/rc

echo 'alias b=2' >> "$lab/home/rc"     # write THROUGH the pointer...
cat "$lab/repo/rc"                     # ...and the real file has both lines
#   alias a=1
#   alias b=2

sed -i 's/b=2/b=3/' "$lab/home/rc"     # TRAP: GNU sed -i writes a NEW file and
ls -l "$lab/home/rc"                   # renames it over the pointer:
#   -rw-r--r-- ... home/rc             # "-" = a regular file now, not a link ("l")
grep b= "$lab/repo/rc"                 # the real file never changed
#   alias b=2

rm -r "$lab"                           # clean up
```

Trace what happened: the first `echo >>` opened `home/rc`; the kernel
followed the pointer and appended to `repo/rc`. `sed -i` instead wrote a
temporary file and *renamed* it onto `home/rc`, replacing the pointer
itself. The repo never saw the edit, and that machine silently drifted.
Fix: `sed -i --follow-symlinks` (✅ keeps the link). Vim keeps links when it
saves (✅ checked with your vimrc), so normal editing is safe.

### 2.4 Common beginner confusion

**"Learning a repo means reading every file, in order, before touching
anything."** That is how people burn out on a 1,125-line GUIDE. A repo is a
*system*: you learn it the way you learn a city. First the map (which
neighborhoods exist), then one route walked end to end (one file from the
repo to the running program), then one neighborhood at a time, each time
**asking the running program** what it actually loaded instead of trusting
what a file says. You'll know 80% of the repo after the first three
stages of Phase A.

### 2.5 The professional upgrade

Practitioners onboard to a new codebase with the same three moves: **(1)
map** (tree, README, build entry points), **(2) trace one request** end to
end through the system (here: one config file from git to the program),
**(3) run the tests and break something on purpose** to see what the
safety net catches. And they sync with small, frequent, reviewed commits,
never with "sync everything automatically", because a config that is broken
on one machine should stop at a test, not spread to the other.

---

## 3. Phase 0: make it safe to explore (10 min)

**Step 1: one backup archive of the whole folder** (work tree + `.git`):

```sh
cd ~
f=$HOME/config_files-backup-$(date +%Y%m%d).tar.gz   # today's date in the name
tar -czf "$f" config_files     # everything, untracked files included
chmod 600 "$f"                 # private: it holds the OLD history too
tar -tzf "$f" | wc -l          # it opens, and isn't empty
```

Why this and not only GUIDE §9.5's `git bundle`: a bundle stores
**commits**, and your rebuild isn't committed yet, so a bundle wouldn't
contain it. Re-run this step on the day you do Phase B: an older archive
misses your latest edits (the one from 2026-10-20 missed 27 changed files
by 2026-10-21). Delete the archives once Phase B is done and both machines
pass `make test`.

**Step 2: the stale Vim swap files.** (✅ By 2026-10-21 these three were
gone; keep the method for the next one.) A swap file is Vim's crash-recovery
copy of unsaved edits. The Vim processes that wrote these three are gone, so
each one is either leftover unsaved work or junk:

```sh
cd ~/config_files
vim -r .swp            # shows the recovered text; :q! if there's nothing you need
vim -r .swo
vim -r scripts/.test.sh.swp
rm .swp .swo scripts/.test.sh.swp   # once you've decided nothing in them matters
```

(Git ignores `*.swp` through `~/.config/git/ignore`, and `install.sh` never
links them, so they wouldn't be committed or installed, but GUIDE §9.5 Step 2 copies `scripts/` whole, and a stray file
copied into the new repo is clutter.)

---

## 4. Phase A: learn the repo, one layer at a time

Each stage: **Goal**, **Do** (read-only commands), **Check yourself**
(answers folded underneath), then **Thinking** (why this stage comes now)
and **Lesson** (what transfers to any other repo).

### A1. The map (15 min)

**Goal:** know which files exist and which zone each belongs to, before
reading any of them.

```sh
cd ~/config_files
git status                                             # committed vs changed vs untracked
find . -path ./.git -prune -o -type f -print | sort    # every file, minus git's own database
less README.md
```

| Zone | Files | Job |
|---|---|---|
| **the product** | `home/` (17 files) | the configs themselves; `home/` mirrors `~` path for path |
| **deploy** | `install.sh`, `Makefile` | put links in `~`; `make` = shortcuts for the scripts |
| **safety net** | `scripts/test.sh`, `.github/workflows/ci.yml` | prove every config loads in the program that reads it, on Ubuntu and Arch |
| **helpers** | `scripts/bootstrap.sh`, `scripts/arch-sandbox.sh`, `scripts/lsp-probe.py` | install the programs; a rootless Arch for testing; a tiny LSP client for learning |
| **knowledge** | `docs/GUIDE.md`, `docs/archive/`, this file | why things are the way they are |
| **copy-by-hand** | `templates/` | per-project files (`.clangd`, `compile_flags.txt`) you copy *into a project*; never installed |
| **repo settings** | `.gitignore`, `.gitattributes`, `.editorconfig`, `LICENSE` | git and editor behavior for the repo itself |

**Check yourself**

1. Does `install.sh` link `templates/.clang-tidy` into `~`?
2. Which file would you open to find out *why* `pull.ff = only` is set?

<details><summary>Answers</summary>

1. No. It links only what is under `home/` (`cd "$SRC" && find ...`, with
   `SRC=$REPO/home`). Templates are copied into projects by hand.
2. `home/.config/git/config` (the setting and its comment), then GUIDE §7.

</details>

*Thinking:* before reading any file you need to know which files are the
**product** and which are **machinery**, or you'll spend an hour on the
CI YAML believing it's a config you use.

*Lesson:* **start every new repo with the map:** file tree + README +
`git status`. Ten minutes that make every later hour faster.

### A2. One file, end to end (15 min)

**Goal:** see that "the repo file" and "the file the program reads" are the
same bytes.

```sh
ls -l ~/.zshrc ~/.vimrc      # "l" at the start + "->" = symlink
readlink ~/.vimrc            # ✅ /home/ken/config_files/home/.vimrc
```

Then ask **Vim itself** where a setting came from. In Vim:

```vim
:verbose nmap <F5>
"   n  <F5>  * :call <SNR>1_ToggleBuild()<CR>
"           Last set from ~/.vimrc line 289          (✅)
:scriptnames        " every script Vim loaded, in load order
```

Vim says `~/.vimrc line 289`; git calls the same file `home/.vimrc`.
`grep -n F5 home/.vimrc` shows line 289. One file, two names.

Then run the symlink walkthrough from [§2.3](#23-worked-walkthrough-a-symlink-by-hand--throwaway-folder),
including the `sed -i` trap.

**Check yourself**

1. You run `rm ~/.zshrc`. What happens to `home/.zshrc`?
2. Why does `install.sh` link individual **files**, not the whole `~/.vim`
   folder?

<details><summary>Answers</summary>

1. Nothing. `rm` removed the pointer only. `./install.sh` puts it back.
2. Vim writes plugins and undo history into `~/.vim`. A linked
   folder would put all that runtime data inside your git repo (GUIDE §1.4).

</details>

*Thinking:* every later stage assumes this one fact. If you don't believe
in your gut that editing `~/.zshrc` edits the repo, the whole sync story
feels like magic.

*Lesson:* **trace one thing end to end before studying the parts.** And
**ask the program** (`:verbose`, `:scriptnames`) rather than trusting the
file: the program is the ground truth.

### A3. The installer (30 min)

**Goal:** understand exactly what `install.sh` does to a machine, so you
never fear running it.

Read `install.sh` top to bottom (146 lines of POSIX sh) with these five
questions open, then answer them:

1. `~/.zshrc` is already the right link. What happens?
2. `~/.zshrc` is a regular file. What happens to it?
3. Why does it refuse to run as root?
4. Why does it write the file list to a temp file instead of `find | while read`?
5. What does `--uninstall` remove, and what does it keep?

Then watch it think without changing anything:

```sh
./install.sh --dry-run
#   (dry-run: nothing was changed)
#   Done: 0 linked, 17 already in place, 0 backed up.        (✅)
sh -x ./install.sh --dry-run 2>&1 | less    # -x prints every line as it runs
```

<details><summary>Answers</summary>

1. Kept: `kept=$((kept + 1))`, nothing touched. That's why re-running is safe.
2. Moved (never deleted) to `~/.local/state/dotfiles/backup/<timestamp>/`,
   then the link is created.
3. Under `sudo`, `$HOME` may be `/root`: it would link root's home and leave
   root-owned files behind.
4. In `find | while read`, the loop runs in a **subshell** (a child
   process). The counters it increments die with the child, so the summary
   would always say 0.
5. Only links whose target is exactly a repo file, plus the `bat`/`fd`
   shims. Backups stay; it prints where they are.

</details>

*Thinking:* the installer is the only script that **changes your home
directory**. Knowing its rules (skip, back up, never delete) turns it from
scary into boring, which is what you want from a deploy tool.

*Lesson:* **read the code that changes state before the code that only
reads.** Then use its dry-run mode, every time.

### A4. Shell startup: which file runs when (30 min)

**Goal:** know where to put a new setting. zsh has its own built-in
tracer, `sourcetrace`, that prints every file as it's read:

```sh
zsh -o sourcetrace -lic exit 2>&1 | grep -F "+$HOME/" | cut -d: -f1 | uniq
#   -l login shell, -i interactive, -c exit: start up fully, then quit
# ✅ output (your files only, in order):
#   +/home/ken/.zshenv
#   +/home/ken/.zprofile
#   +/home/ken/.profile
#   +/home/ken/.zshrc
#   +/home/ken/.cache/zsh/init/_usr_bin_dircolors_-b.zsh      <- cached init code (GUIDE §5)
#   +/home/ken/.cache/zsh/zcompdump-5.9
#   +/home/ken/.config/shell/common.sh
#   +/home/ken/.cache/zsh/init/_usr_bin_zoxide_init_zsh.zsh
#   +/home/ken/.cache/zsh/init/_usr_bin_starship_init_zsh.zsh
```

Drop `-l` and run it again: `.zprofile` and `.profile` disappear. That's
the login/interactive split from GUIDE §5 and your note
`~/notes/shell-login-vs-interactive.md`, seen live.

**Check yourself:** where does each of these go?

1. a new folder for `PATH`
2. an alias you want in both bash and zsh
3. a personal API token
4. a zsh-only key binding

<details><summary>Answers</summary>

1. `home/.profile`: inherited by every child process, read at login.
2. `home/.config/shell/common.sh`: sourced by both `.bashrc` and `.zshrc`.
3. `~/.zshrc.local` (`chmod 600`). **Never** the repo: `.gitignore` ignores
   `*.local` for exactly this.
4. `home/.zshrc`.

</details>

*Thinking:* "where do I put it?" is the question you'll ask most often in
Phase C. The tracer answers it from evidence instead of from memory.

*Lesson:* **most tools can tell you what they load:** `zsh -o sourcetrace`,
`bash -x`, Vim's `:scriptnames`, `strace -e openat` as a last resort.

### A5. Vim (two sittings of ~45 min)

**Goal:** read `home/.vimrc` (382 lines) and be able to explain any line.

How to read it: top to bottom, and for every option you don't know, ask
Vim's built-in manual. Put the cursor on an option name and type
`:help 'signcolumn'` (options have quotes), `:help :nnoremap` (commands
have a colon), `:help <Leader>`.

Tools that show what Vim actually did:

| Command | Answers |
|---|---|
| `:verbose set background?` | the value, and which file + line set it |
| `:verbose nmap <F5>` | what a key does, and where it was mapped |
| `:scriptnames` | every script loaded, in order |
| `:messages` | errors you missed at startup |

Then try the keys from the README on a small C file: `<Leader>jd`, `]d`,
`<Leader>K`, `F4`, `F5`, `Shift-Tab`. Read GUIDE §3 (LSP from zero) and
§2 Stage 7 (the five bugs, and why each now has a test).

*Thinking:* the vimrc is the biggest file you'll change most often. Reading
it once with `:help` beside you is cheaper than a hundred small mysteries
later.

*Lesson:* **learn the tool's introspection commands before its config
language.** `:verbose` answers "why does it do that?" in one line.

### A6. The other configs: ask the program, not the file (30 min)

**Goal:** for each tool, one command that prints what the tool **really
uses**. Two of them have lookup traps (GUIDE §2 Stage 4 and §7): clang-format
uses the **nearest** `.clang-format`; gdb reads only the **first** gdbinit
it finds.

| Config | Ask the program (✅ = run here) |
|---|---|
| git | `git config --show-origin --get-regexp '^(pull\|merge)\.'` ✅ → `file:/home/ken/.config/git/config  pull.ff only` |
| gdb | `gdb -batch -ex 'show confirm'` ✅ → `Whether to confirm potentially dangerous operations is off.` |
| tmux | `tmux -L learn -f ~/.config/tmux/tmux.conf start-server \; show -g escape-time \; kill-server` ✅ → `escape-time 10` (a private server, so your sessions aren't touched) |
| clang-format | `clang-format --dump-config` (after `scripts/bootstrap.sh` installs it) |
| clangd | `clangd --check=some/file.c` (errors only; warnings: `scripts/lsp-probe.py`) |

*Thinking:* a config file is a *request*; the program decides what it
honors. The repo once polished a `.clang-format` that formatted nothing,
because a nearer file won.

*Lesson:* **prove a config is the live one before you improve it.**

### A7. The safety net: the tests (30 min)

**Goal:** know what `make test` proves, and find the code behind any line
of its output.

```sh
make test            # ✅ 57 passed, 0 failed, 0 skipped  (~10 s, throwaway HOME)
grep -n '^section' scripts/test.sh
#   97:section "1. Syntax"      118:section "2. Lint"      128:section "3. install.sh"
#   187:section "4. Shell startup ..."   245:section "5. Vim"   530:section "6. Config files ..."
grep -n 'gdb runs gdbinit silently' scripts/test.sh    # pick ANY output line; find its code
```

Read the small helpers at the top (`check`, `skip`, `section`) first:
everything else is built from them. Then GUIDE §8 (why tmux appears in a
test suite, what a test double is).

*Thinking:* the tests are your permission to change things without fear.
You can't trust a net you've never looked at.

*Lesson:* **read a test suite's helpers first, then map output lines back
to code with grep.** That's how you read any unfamiliar test suite.

### A8. History and the story (30 min)

**Goal:** see both machines' lines of history and read a file as it is on
GitHub without touching yours.

```sh
git log --oneline --graph --all -n 10     # your main and origin/main, side by side
git show --stat origin/main               # what the laptop commit changed
git show origin/main:README.md | less     # a file AS IT IS on GitHub; your copy untouched
```

Now read GUIDE.md in this order, which follows the layers you just learned:
§1 → §5 → §7 → §6 → §3–4 → §8 → **§9** (two machines) → §2 (the
investigation story, best read last, once you know every part) → §10–14.

*Thinking:* GUIDE is a story told in the order things were *discovered*.
That's the best order to tell it and the worst order to learn it.

*Lesson:* **`git show <ref>:<path>` reads any version of any file, risk-free.**
Use it whenever you want to know "what does the other side have?".

---

## 5. Phase B: finish the move (one time)

The full commands are in GUIDE §9.5 and §9.6, rehearsed there end to end.
Don't retype them from memory; follow the text. This is the checklist
around them.

**B0. Revoke the leaked key first** (GUIDE §9.4). Nothing else in this
phase matters until that is done: the history cleanup only hides a key, it
can't take it back from anyone who already copied it.

**B1. Preflight (read-only, 1 minute):**

```sh
git -C ~/config_files ls-remote origin main
#   4febb7053d669bd7eeb46283dd49093e2cb9d922  refs/heads/main     (✅ on 2026-10-20)
```

If it prints a **different** hash, the laptop has pushed again. Stop: that
new commit must be folded into the fresh history first (the safety lease in
§9.5 Step 5 would refuse the push anyway).

**B2. Phase 0 done today?** A backup archive from *today* (re-run Phase 0
Step 1 if yours is older), no swap files. This file
lives in `docs/`, so §9.5 Step 2 copies it and Step 3 commits it with the
other docs.

**B3. Run GUIDE §9.5 Steps 1–7**, top to bottom (close every Vim first:
Step 1 checks). After each step, compare your screen with its "Expect" line
before moving on.

**B4. Verify on WSL:** `make test` (no FAIL). Then paste the `dots_status`
function from [§6.2](#62-worked-example-your-first-change-end-to-end)
straight into your terminal (that defines it for this shell only; §6.2 makes
it permanent) and run it: expect `0 file(s)`, `0 ahead, 0 behind`,
`links : all OK`.

**B5. The laptop: re-clone** (GUIDE §9.6). A `git pull` cannot work there:
the new history shares no commit with the old one. Then `make test` there
too.

*Thinking:* this is the only phase with an irreversible step (the
force-push). Everything before it is preparation that makes it boring:
key revoked, backup made, remote confirmed unchanged, commands rehearsed.

*Lesson:* **before an irreversible step, check the one fact it depends
on** (here: GitHub is still at `4febb70`) and have a backup that doesn't
depend on the thing you're changing.

---

## 6. Phase C: the everyday update-and-sync loop

### 6.1 The loop

```text
  arrive ──► git pull ──► edit ──► make test ──► git diff ──► git commit ──► git push ──► leave
    ▲                                                                                     │
    └─────────────────────────────── the other machine ◄─────────────────────────────────┘
```

- **One topic per commit**, written like the fresh history:
  `feat(shell): ...`, `fix(vim): ...`, `docs: ...`, `chore: ...`.
- **`git diff` before every commit**: you are the last check for secrets and
  for stray debug lines.
- **Commit even small things.** A commit is a save point; uncommitted work is
  the only work git can't give back.

### 6.2 Worked example: your first change, end to end

Your first real change: add a read-only "where am I?" command, `dots_status`,
to the shared shell file. It answers the three questions of the loop: is
anything uncommitted, am I ahead of or behind GitHub, does every `~` link
still point into the repo. (✅ tested in sh, bash and zsh, and against a
fake HOME with missing links, a non-repo folder, and two diverged clones.)

**Step 1: arrive.**

```sh
cd ~/config_files && git pull       # "Already up to date." or a fast-forward
```

**Step 2: edit.** Open `home/.config/shell/common.sh` (or `~/.config/shell/common.sh`:
same file) and paste this at the end:

```sh
# dots_status: a READ-ONLY "where am I?" report for the dotfiles repo.
# It answers the three questions you ask before leaving or after arriving
# at a machine: (1) is anything uncommitted? (2) am I ahead of / behind
# GitHub? (3) does every ~/<file> still link into the repo?
# It never changes a file; the only network action is `git fetch`, which
# updates origin/main (the downloaded copy) and never touches your work.
#
# The body is ( ... ) instead of { ... }: it runs in a SUBSHELL, so its
# variables and `cd` can't leak into your interactive shell. That keeps
# it POSIX (no `local`) and safe in sh, bash and zsh alike.
dots_status() (
    repo=${DOTFILES_REPO:-$HOME/config_files}

    # Fail loudly if the folder is missing or isn't a git repository.
    git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        printf 'dots_status: %s is not a git repository\n' "$repo" >&2
        exit 1
    }
    repo=$(cd -- "$repo" && pwd -P)    # real path: install.sh links use it too

    # (1) Uncommitted work. --porcelain is the stable, script-friendly format:
    # one line per changed or untracked file, nothing else.
    changes=$(git -C "$repo" status --porcelain | wc -l | tr -d ' ')
    printf 'uncommitted : %s file(s)%s\n' "$changes" \
        "$( [ "$changes" -gt 0 ] && echo '  -> review with: git status' )"

    # (2) Ahead/behind. fetch first, or origin/main is only as fresh as your
    # last fetch. A failed fetch (offline) is reported, not fatal.
    if ! git -C "$repo" fetch --quiet 2>/dev/null; then
        echo 'remote      : fetch failed (offline?), numbers below may be stale'
    fi
    if git -C "$repo" rev-parse --verify --quiet '@{upstream}' >/dev/null; then
        # "A...B" with --left-right --count prints "<only in A><TAB><only in B>".
        # Split it with parameter expansion, not an unquoted $(...): that
        # works the same in sh, bash and zsh, and shellcheck accepts it.
        counts=$(git -C "$repo" rev-list --left-right --count 'HEAD...@{upstream}')
        ahead=${counts%%[[:space:]]*}     # cut from the first blank to the end
        behind=${counts##*[[:space:]]}    # cut up to the last blank
        printf 'vs GitHub   : %s ahead, %s behind\n' "$ahead" "$behind"
        if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
            echo '              DIVERGED: do not pull blindly (see LEARN-AND-SYNC.md, C4)'
        fi
    else
        echo 'vs GitHub   : no upstream branch set (git push -u origin main sets it)'
    fi

    # (3) Links. For every file under home/ (minus the editor litter that
    # install.sh skips: *.sw?, *~), ~/<same path> must be a symlink whose
    # target is exactly that repo file. Collect the problems as text:
    # a counter inside `find | while` would die with the pipe's subshell.
    problems=$(cd "$repo/home" && find . \( -type f -o -type l \) ! -name '*.sw?' ! -name '*~' | sed 's|^\./||' |
        while IFS= read -r rel; do
            [ "$(readlink "$HOME/$rel" 2>/dev/null)" = "$repo/home/$rel" ] ||
                printf '              not linked: ~/%s\n' "$rel"
        done)
    if [ -z "$problems" ]; then
        echo 'links       : all OK'
    else
        echo 'links       : PROBLEMS  -> run ./install.sh --dry-run to see the fix'
        printf '%s\n' "$problems"
    fi
)
```

**Step 3: try it.** A running shell read `common.sh` when it started, so
start a fresh one:

```sh
exec zsh            # replace this shell with a new one (same terminal)
dots_status
# expected after Phase B, with this one edit not yet committed:
#   uncommitted : 1 file(s)  -> review with: git status
#   vs GitHub   : 0 ahead, 0 behind
#   links       : all OK
```

(✅ Today, before Phase B, it prints `22 file(s)` and `0 ahead, 1 behind`:
exactly the §1 snapshot.)

**Step 4: test.** `make test`: no FAIL. `bash -n` and `zsh -n` check the
syntax of `common.sh` here; CI also runs shellcheck on it (that's why the
function splits `counts` with `${...%%...}` instead of an unquoted `$(...)`,
which shellcheck flags as SC2046).

**Step 5: review.** `git diff`: exactly the lines you added, nothing else.

**Step 6: commit and push.**

```sh
git add home/.config/shell/common.sh       # name the file; don't `git add .`
git commit -m "feat(shell): dots_status, a read-only sync report"
git push                                   # CI runs on GitHub; watch the badge
```

**Step 7: the other machine.**

```sh
cd ~/config_files && git pull     # fast-forward: the laptop's common.sh now has it
exec zsh && dots_status           # no install.sh needed: the link already existed
```

### 6.3 "I pulled. What else do I have to do?"

| What the pull changed | What to do | Why |
|---|---|---|
| an existing file under `home/` | restart the program that reads it (below) | the link already points at the new content, but running programs read config only at startup |
| `.zshrc`, `.bashrc`, `common.sh` | `exec zsh`, or a new terminal | same reason |
| `.profile`, `.zprofile` | `exec zsh -l` (a login shell re-reads them) | they run only at login |
| `.vimrc` | restart Vim; plugin list changed → `:PlugInstall`, `:PlugClean` | same reason |
| `tmux.conf` | `tmux source-file ~/.config/tmux/tmux.conf` | the tmux server lives across terminals |
| git, gdb, clang-format configs | nothing | read fresh on every run |
| a **new** file under `home/` | `./install.sh --dry-run`, then `./install.sh` | the link doesn't exist yet: a pull can't create it |
| a file **renamed or deleted** under `home/` | `./install.sh` for the new name; remove the old, now dangling, link: `find ~ -maxdepth 3 -xtype l` lists them (GNU find) | `install.sh` only adds links, never guesses which old ones to remove |
| `scripts/bootstrap.sh` | re-run it | it installs programs; a pull only moves files |

### 6.4 When the two machines disagree (C4)

**Look first, all read-only:** `dots_status`, or `git status` +
`git fetch` + `git log --oneline --graph --all -n 10`. Then find your case:

| Case | What you see | Do |
|---|---|---|
| 1. Behind only | `0 ahead, 2 behind` | `git pull`: a fast-forward, nothing to decide |
| 2. Ahead only | `1 ahead, 0 behind` | `git push` |
| 3. Uncommitted work + new commits upstream | `uncommitted: N` and `behind` > 0 | commit your work first (`git add <file>`, `git commit`), then it's case 1 or 4 |
| 4. Diverged | `1 ahead, 1 behind` | `git pull --rebase` (below) |
| 5. Push rejected | `! [rejected] ... (fetch first)` | the other machine pushed: that's case 4 |

**Case 4, step by step.** A plain `git pull` stops, on purpose: your
`pull.ff = only` refuses to invent a merge (✅ `hint: Diverging branches
can't be fast-forwarded`). `git pull --rebase` downloads the other
machine's commits, then **replays** yours on top, so history stays one
straight line (✅ works with `pull.ff = only`).

If both machines changed the same lines, the replay stops with a conflict:

```text
CONFLICT (content): Merge conflict in common.sh
error: could not apply 9a227e5... wsl: ll shows sizes
```

The file then holds both versions plus the original (your git config uses
`zdiff3`, which adds the middle part):

```text
<<<<<<< HEAD                                  <- during a rebase, HEAD = THE OTHER MACHINE's version
alias ll="ls -la"
||||||| parent of 9a227e5 (wsl: ll shows sizes)   <- what the line was before either change
alias ll="ls -l"
=======
alias ll="ls -lh"                             <- YOUR commit being replayed
>>>>>>> 9a227e5 (wsl: ll shows sizes)
```

Resolve it: edit the file to what it **should** say (maybe a mix, here
`alias ll="ls -lah"`), delete the three marker lines, then:

```sh
git add common.sh          # "this file is resolved"
git rebase --continue      # finish the replay (it opens the editor for the message; save and quit)
make test                  # the merged result is new code: test it
git push
```

Panic button at any point: `git rebase --abort` puts everything back
exactly as it was before the pull.

**Never** "fix" a disagreement with `git reset --hard` (destroys
uncommitted work) or `git push --force` (destroys the other machine's
commits). After Phase B there is no reason to use either.

### 6.5 Adding a config the repo doesn't have yet (✅ tested with a fake HOME)

Example: you start using `bat` and want `~/.config/bat/config` on both
machines.

```sh
cd ~/config_files
mkdir -p home/.config/bat
cp ~/.config/bat/config home/.config/bat/config   # COPY, don't move: install.sh backs up the original
./install.sh --dry-run
#   backup  ~/.config/bat/config  ->  ~/.local/state/dotfiles/backup/<time>/.config/bat/config
#   link    ~/.config/bat/config
./install.sh
ls -l ~/.config/bat/config                        # now "l ... -> .../config_files/home/.config/bat/config"
git add home/.config/bat/config
git commit -m "feat: bat config"
git push
# on the other machine: git pull && ./install.sh
```

Before adopting a file, read it: no secrets, no machine-specific absolute
paths. And if the program can validate its config, add a check (with a
negative control) to `scripts/test.sh` section 6.

### 6.6 Machine-only settings: the `*.local` files

Some settings belong to **one** machine (a WSL-only alias, a work proxy)
or must never be public (tokens). They go in files that the repo's configs
read **if they exist**, and that `.gitignore` ignores (`*.local`):

| File | Read by |
|---|---|
| `~/.profile.local` | `home/.profile` (login: PATH, environment) |
| `~/.zshrc.local` | `home/.zshrc` |
| `~/.bashrc.local` | `home/.bashrc` |
| `~/.config/git/config.local` | `home/.config/git/config` (`[include]`) |

Rule of thumb: **both machines want it → repo. One machine, or secret →
`.local`.** Small OS differences can also live in the shared file behind a
test, like the vimrc's WSL clipboard (`exists('$WSLENV')`).

### 6.7 Experiments on a branch

```sh
git switch -c try/new-prompt         # a side road; main is untouched
# ... edit, make test, live with it for a day ...
git switch main && git merge try/new-prompt && git branch -d try/new-prompt   # keep it
git switch main && git branch -D try/new-prompt                               # or drop it
```

The catch: your `~` links point at the **folder**, not at a branch. While
`try/new-prompt` is checked out, every new shell and Vim on this machine
runs the experiment. That's useful (you test it for real), but switch back
to `main` before you `git pull` or leave the machine.

### 6.8 Practice drills (after Phase B only: then `git restore` is a safe undo)

1. **Break a config, watch the net catch it:**

   ```sh
   echo 'set -g no-such-option on' >> home/.config/tmux/tmux.conf
   make test
   #   FAIL tmux 3.6 runs tmux.conf without errors
   #   54 passed, 1 failed, 0 skipped               (✅ measured on a copy of the repo)
   git restore home/.config/tmux/tmux.conf          # back to the committed version
   ```

2. **Simulate drift:** `rm ~/.inputrc` (removes only the link), run
   `dots_status` (it reports `not linked: ~/.inputrc`), then `./install.sh`.

3. **Rehearse a conflict with nothing at stake.** This script builds a fake
   GitHub and two fake machines in a temp folder and makes them edit the same
   line. Save it as `~/conflict-lab.sh`, run `sh ~/conflict-lab.sh`, follow
   what it prints, and resolve the conflict with the steps in §6.4 (✅ run
   end to end: conflict, resolve, `rebase --continue`, push):

   ```sh
   #!/bin/sh
   # rehearse-conflict.sh: build a REAL merge conflict between two fake
   # machines, inside a throwaway folder, so you can practice resolving one
   # with nothing at stake. Nothing outside that folder is touched.
   #
   #   github.git  a bare repo standing in for GitHub (no working files)
   #   wsl/        clone #1: this machine
   #   laptop/     clone #2: the Arch laptop
   #
   # Both machines change the SAME line differently; the laptop pushes first.
   set -eu

   lab=$(mktemp -d "${TMPDIR:-/tmp}/conflict-lab.XXXXXX")
   cd "$lab"

   git init -q --bare -b main github.git
   git clone -q github.git wsl 2>/dev/null     # silence "you cloned an empty repository"

   cd wsl
   printf 'alias ll="ls -l"\n' > common.sh
   git add common.sh
   git commit -qm "base: ll alias"
   git push -q -u origin main                  # -u: remember origin/main as upstream

   cd .. && git clone -q github.git laptop
   cd laptop
   printf 'alias ll="ls -la"\n' > common.sh    # laptop: show dotfiles too
   git commit -qam "laptop: ll shows dotfiles"
   git push -q                                 # the laptop wins the race to GitHub

   cd ../wsl
   printf 'alias ll="ls -lh"\n' > common.sh    # wsl: human-readable sizes
   git commit -qam "wsl: ll shows sizes"       # committed, but NOT pulled first

   printf 'Lab ready. Now type:\n  cd %s/wsl\n  git pull --rebase\n' "$lab"
   printf 'When finished:  rm -rf %s\n' "$lab"
   ```

   Run it twice more and try the other exits: `git rebase --abort`, and
   `git pull --no-rebase` (a merge commit instead of a replay). Compare the
   three `git log --oneline --graph` results.

4. **Look before you merge:** `git fetch`, then `git log ..origin/main`
   (commits you don't have) and `git diff ...origin/main` (what they change).

---

## 7. Common beginner confusions (read these twice)

| Belief | Reality | See it yourself |
|---|---|---|
| "`~/.zshrc` and `home/.zshrc` are two files I keep in sync." | One file, two names. | §2.3; `readlink ~/.zshrc` |
| "`git pull` updates my running shell." | It updates files. Programs that are already running keep what they read at startup. | edit `common.sh`, `alias` in the old shell vs. after `exec zsh` |
| "`git pull` installs a new config file." | Only `install.sh` creates links. A new file arrives in `home/`, and nothing in `~` points at it yet. | §6.5; `dots_status` |
| "`git push` uploads my changes." | It uploads **commits**. Uncommitted edits stay on this disk, invisible to the other machine and to GitHub. | `git status` after a push |
| "Untracked files are safe in git." | Untracked = git has **never** stored them. Today that's most of the rebuild. | §1 snapshot |
| "During a rebase, `HEAD` / `ours` is my version." | During a rebase it's the **other** side: git is replaying *your* commit onto *theirs*. (In a merge, it's the opposite.) | §6.4's markers; drill 3 |
| "A refused pull means nothing came down." | The fetch half worked: `origin/main` already holds the other side's commits. | `git log ..origin/main` |
| "All tests pass, so it works on the laptop." | They passed **here**. CI covers clean Ubuntu and Arch; run `make test` on the laptop too after big changes. | GUIDE §8 |
| "Any editor is fine for symlinked files." | Tools that save by writing a new file and renaming it (GNU `sed -i`, some editors' "atomic save") replace the link with a copy. Vim keeps the link. | §2.3 |
| "I must understand everything before I change anything." | Learn one vertical slice (A1–A3), then change small things with the tests as your net. | Phase C, drill 1 |

---

## 8. Pros and cons: ways to learn, ways to sync

**Ways to learn a repo**

| Approach | Pros | Cons |
|---|---|---|
| Read GUIDE.md cover to cover | complete, every decision explained | told in discovery order; easy to drown before seeing the shape |
| Read every file alphabetically | nothing missed | no idea what matters; `.editorconfig` gets the same time as `install.sh` |
| **Map → trace → layers → break it (this plan)** | each stage builds on the last; every claim checked against the running program | slower to "finish"; needs a terminal, not just a reader |
| Just start changing things | fast feedback | with uncommitted work and no understanding of the net, a mistake can't be undone |

**Ways to sync two machines**

| Approach | Pros | Cons |
|---|---|---|
| **Manual pull/commit/push (chosen)** | you review every change; conflicts surface while you're there | relies on habit (the §0 rule) |
| Auto-sync (a timer running `git pull`/`push`) | no habit needed | pulls a broken config mid-session; a conflict goes unnoticed for days; auto-commits with no message |
| A synced folder (Syncthing, Dropbox) for the repo | effortless | can corrupt `.git` when both sides write; "conflict copy" files instead of real conflicts; no review step |
| chezmoi / yadm | per-machine templates, encrypted secrets | new concepts; chezmoi applies copies, so you edit through its command (GUIDE §10) |

---

## 9. How to improve: now vs. bleeding edge

**Now (small, safe):**

- Do §6.2: `dots_status` in `common.sh` is both your first practice commit
  and a daily tool.
- A local **pre-push hook**, so tests run before anything leaves the machine:

  ```sh
  # .git/hooks/ is never committed or pushed: run this once per clone.
  printf '#!/bin/sh\n# run the offline tests before every git push; a FAIL blocks the push\nexec make -C "$(git rev-parse --show-toplevel)" test\n' > .git/hooks/pre-push
  chmod +x .git/hooks/pre-push
  # skip it once, deliberately:  git push --no-verify
  ```

- ✅ Done (2026-10-20): clang-format and shellcheck are installed on WSL, so
  `make test` skips nothing (55/55), like CI.
- **Change git settings by editing `home/.config/git/config`, not with
  `git config --global`.** Because `~/.gitconfig` exists (it holds your
  name and email), `--global` writes *there*, and that file isn't in the
  repo, so the setting never reaches the other machine. Check where a
  setting lives with `git config --show-origin <name>`.

**Bleeding edge:**

- **Secret scanning before every commit** (`gitleaks`, or the
  `pre-commit` framework running gitleaks + shellcheck), so a token is
  stopped before it ever reaches a commit, not cleaned up months later.
- **Jujutsu (`jj`)**, a git-compatible version control tool where every
  edit is automatically a commit, conflicts can be committed and resolved
  later, and `jj undo` reverts any operation, including a bad rebase.
  Friendlier for exactly the mistakes this file warns about; works on top
  of the same GitHub repo.
- **Branch protection** on GitHub (require the CI check before `main`
  moves): overkill for one person, standard on teams.
- **chezmoi or Nix home-manager** once a third machine (or macOS) appears.

---

## 10. Expansion: gotchas and edge cases

- **The global git ignore lives in `~`.** With a different `HOME` (the test
  suite's throwaway home, `sudo`), `*.swp` is no longer ignored: ✅ a run
  with a fake HOME counted 24 changed files instead of 22.
- **`git stash` skips untracked files** unless you add `-u`.
- **`git add .` adds every untracked file** below you. Name files, or use
  `git add -p` to review hunk by hunk.
- **A renamed file under `home/` leaves a dangling link** in `~` on every
  machine. `find ~ -maxdepth 3 -xtype l` (GNU find; macOS's find lacks
  `-xtype`) lists links whose target is gone.
- **Branches change the live config** (§6.7): the links follow the folder.
- **Windows editors and line endings:** editing through `\\wsl$` from
  Windows is fine; `.gitattributes` stores LF and `.editorconfig` tells the
  editor (GUIDE §12: a CRLF script fails with `bad interpreter`).
- **After the fresh start, an old clone can't pull** ("refusing to merge
  unrelated histories"): re-clone it (GUIDE §9.6).
- **`rerere` is on** (your git config): git remembers how you resolved a
  conflict and replays the resolution next time. You'll see `Recorded
  preimage` in drill 3; that's this feature, not an error.
- **Push from one machine at a time.** If both push within a minute, the
  second gets "fetch first": that's case 5, not a bug.

---

## 11. The short version of the whole story

Your repo is one real copy of your settings, linked into `~` on each
machine and carried between them by git. You learn it by layers: first
the map, then one file traced from git to the running program, then the
installer that makes the links, then each tool, always asking the program
what it really loaded, then the tests that prove it all works. Today the
rebuild is still uncommitted while the laptop has pushed a commit, so the
one-time Phase B (revoke the key, publish a fresh history, re-clone the
laptop) comes before any experiment that edits files. After that, syncing
is a short loop (pull, edit, test, review, commit, push) plus three
recoveries: `install.sh` for new files, `exec zsh` for running programs,
and `git pull --rebase` for diverged machines.

## 12. The transferable principles (the part to keep)

1. **Map before you read, trace before you study.** Tree + README +
   `git status`, then one path end to end. Details stick once they have a
   place to go.
2. **Ask the running program, not the file.** `:verbose`, `sourcetrace`,
   `--show-origin`, `--dump-config`: the program is the ground truth.
3. **Know which commands are read-only.** `status`, `log`, `fetch`,
   `show`, `diff`, `--dry-run` can't hurt you. Learn with those; act with the
   others only when you know what they destroy.
4. **Uncommitted work is the only work git can't give back.** Commit early,
   even if it's ugly; you can tidy commits later, not resurrect files.
5. **Before an irreversible step, check the fact it depends on and have an
   independent backup.**
6. **A pointer is not a copy.** Anything that replaces the pointer (`sed -i`,
   a `mv` onto it) silently forks the config.
7. **Restart what you reconfigured.** Files change instantly; running
   programs don't.
8. **Let the test suite be your permission to change things,** and prove it
   catches a failure by breaking something on purpose.
9. **Look, then integrate.** `fetch` + `log ..origin/main` before `pull`;
   `--rebase` for small personal histories; `--abort` is always there.
10. **Secrets never enter the repo:** `*.local` files, and `git diff` before
    every commit.

---

## 13. Mental checklist

- [ ] Arriving at a machine: `git pull` (or `dots_status`) **before** editing?
- [ ] Is the file I'm editing the live one? (`readlink`, `:verbose`, nearest/first-file rules)
- [ ] Changed a config: restarted the program that reads it?
- [ ] Added a file under `home/`: ran `./install.sh` here, and on the other machine?
- [ ] `make test`: no FAIL?
- [ ] `git diff` read line by line: no secrets, no debug leftovers?
- [ ] Commit names files (`git add <path>`), one topic, a clear message?
- [ ] Leaving: `git push` done, `dots_status` says `0 ahead, 0 behind`?
- [ ] Pull refused or diverged: read-only look first; `--rebase`, never `reset --hard`?
- [ ] Machine-only or secret: in a `*.local` file?

---

## 14. Suggested learning path and where to go next

1. **This week:** Phase 0, Phase A stages A1–A4. Then Phase B.
2. **Next week:** A5–A8, then §6.2 (your first commit) and drills 1–3.
3. **Git, properly:** [Pro Git](https://git-scm.com/book/en/v2) chapters 2
   (basics), 3 (branching; 3.6 is rebasing) and 7.7 (reset demystified).
   Then [Learn Git Branching](https://learngitbranching.js.org/), an
   interactive visual game for rebase and merge.
4. **Shell:** `man zshoptions` (look up `SOURCE_TRACE`), `man bash` →
   INVOCATION, your `~/notes/shell-login-vs-interactive.md`.
5. **Vim:** `:help usr_41` (writing Vim script), `:help :verbose`,
   `:help 'backupcopy'` (why Vim keeps your links).
6. **Stretch exercise:** extend `dots_status` to also list dangling links
   in `~` that point into the repo (left behind by a rename, §6.3). Write
   the test first in `scripts/test.sh` section 3, watch it fail, then make
   it pass.
