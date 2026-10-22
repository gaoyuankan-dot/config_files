# Repo tour: the negative controls, then the whole repo top to bottom

Written 2026-10-20 on the WSL machine (Ubuntu 26.04, tmux 3.6). Every result
marked ✅ was measured that day; line numbers match the files as of then.

## Contents

- [Part 1. The negative controls in `scripts/test.sh`](#part-1-the-negative-controls-in-scriptstestsh)
  - [1.1 Plain summary](#11-plain-summary) · [1.2 Analogy](#12-analogy-the-airport-metal-detector) ·
    [1.3 The machinery](#13-the-machinery-check-vs-reject) ·
    [1.4 The five controls](#14-the-five-controls-one-by-one) ·
    [1.5 Validators without a control](#15-validators-that-have-no-control-yet-measured) ·
    [1.6 Three look-alikes](#16-dont-confuse-three-kinds-of-trick-test) ·
    [1.7 Beginner confusions](#17-common-beginner-confusions) ·
    [1.8 Professional upgrade](#18-the-professional-upgrade)
- [Part 2. The repo, top to bottom](#part-2-the-repo-top-to-bottom)
  - [2.1 The whole flow](#21-the-whole-flow-in-one-picture) · [2.2 The map](#22-the-map) ·
    [2.3 Layer by layer](#23-layer-by-layer) · [2.4 Reading order](#24-the-reading-order-i-recommend) ·
    [2.5 Loose ends](#25-loose-ends-found-on-this-tour)
- [Part 3. Wrap-up](#part-3-wrap-up)

---

# Part 1. The negative controls in `scripts/test.sh`

## 1.1 Plain summary

Most checks in `test.sh` feed **your** config to the program that reads it and
expect "no complaints". A **negative control** feeds that same program a
config that is **broken on purpose** and expects a complaint. If the program
stays quiet on the broken one, the "no complaints" on yours meant nothing.

`test.sh` says it in its own header (lines 16-18):

> Each validator also gets a NEGATIVE CONTROL: a deliberately broken input
> that must be rejected. A check that cannot fail proves nothing.

## 1.2 Analogy: the airport metal detector

Every morning, before passengers arrive, security walks a **test piece of
metal** through the detector.

| Airport | `test.sh` |
|---|---|
| Passengers walk through, no beep | your `tmux.conf` → tmux prints no error (`check` passes) |
| The test piece of metal | `set -g no-such-option on`, written to `$TMP/bad.tmux` |
| The detector beeps on the test piece | tmux rejects it → `reject` **passes** |
| No beep on the test piece | `FAIL ... (validator accepted a broken input!)` |

A silent detector with no morning test could just be unplugged. A hundred
quiet passengers prove nothing on their own.

## 1.3 The machinery: `check` vs `reject`

Both helpers live at `scripts/test.sh:66-75`:

```bash
# check NAME CMD...: PASS if CMD exits 0, else FAIL showing its output.
check() {
    local name=$1 out; shift                      # first arg = the label, the rest = the command
    if out=$("$@" 2>&1); then pass "$name"; else fail "$name" "$out"; fi   # exit 0 -> PASS
}
# reject NAME CMD...: the negative control; PASS if CMD FAILS.
reject() {
    local name=$1; shift
    # Output is thrown away: a complaint is the EXPECTED result, not news.
    if "$@" >/dev/null 2>&1; then fail "$name (validator accepted a broken input!)"; else pass "$name"; fi
}
```

They are mirror images. `check` wants exit status 0; `reject` wants
**anything but** 0. Both receive the command as separate words (`"$@"`), so
a path with spaces stays one argument (the SC2086 lesson again).

**Testing the tester** (✅): I fed `reject` a *good* input on purpose to make
sure it can fail too:

```text
PASS gdb runs gdbinit silently
PASS gdb rejects a trailing comment (negative control)
FAIL SANITY: a control fed GOOD input must FAIL (validator accepted a broken input!)
```

That third line is the correct outcome: `reject` can tell good input from bad.

## 1.4 The five controls, one by one

`grep -n 'reject "' scripts/test.sh` finds five calls. All five follow the
same pattern: the broken input is **made fresh in `$TMP`** (a throwaway
folder), never by editing your real files.

### Control 1: `install.sh` refuses to run as root (`test.sh:162-166`)

```bash
if [[ $(id -u) == 0 ]]; then
    reject "refuses to run as root without DOTFILES_ALLOW_ROOT" env -u DOTFILES_ALLOW_ROOT HOME="$TI" ./install.sh --dry-run
else
    info "(the refuse-root check runs only when the tests run as root, e.g. in CI)"
fi
```

- **The bad input:** not a file, a *situation*: running as root with the
  opt-in variable removed (`env -u` deletes it from the environment).
- **What it guards:** `install.sh:42-46`. Under `sudo`, `$HOME` would be
  `/root`, so the links would land in root's home and leave root-owned files
  behind. The test suite itself sets `DOTFILES_ALLOW_ROOT=1` (line 132),
  because CI containers run as root. This control proves the guard still
  works when that variable is **missing**.
- **Why it only runs as root:** as a normal user the guard never triggers,
  so there's nothing to test. On your laptop you see the `info` line; in CI
  (root containers) it runs.

**Thinking:** a negative control doesn't have to be a broken file. Any "this
must be refused" rule (a safety guard, a permission check) can get one.
**Lesson:** a safety guard that nothing tests is just a comment that happens to run.

### Control 2: clang-format rejects a misspelled key (`test.sh:493-495`)

```bash
printf 'BasedOnStyle: LLVM\nIndentWidht: 4\n' > "$TMP/bad.clang-format"    # "Widht", not "Width"
reject "clang-format rejects a misspelled key (negative control)" \
    clang-format --style="file:$TMP/bad.clang-format" --dump-config
```

- **The bad input:** a one-letter typo in a key name.
- **What it proves:** `clang-format --dump-config` (the command the positive
  check at line 488 uses) **exits non-zero on unknown keys**. Without this
  control, "clang-format accepts ~/.clang-format" could mean "clang-format
  ignores whatever it doesn't understand".
- **Why it matters here:** your `.clang-format` (120 lines) was merged from
  four old copies and must work on clang-format 21 and 23 alike (README). A
  key that a newer version renames would
  silently stop working. The weekly CI run catches that only because this
  control proves unknown keys are fatal.

**Lesson:** a typo is the cheapest realistic bad input, so use it first.

### Control 3: clangd flags an unknown key (`test.sh:516-518`)

```bash
mkdir -p "$TMP/badcfg/clangd" && printf 'Diagnostics:\n  Bogus: 1\n' > "$TMP/badcfg/clangd/config.yaml"
reject "clangd flags an unknown key (negative control)" bash -c \
    "cd '$TMP/probe' && XDG_CONFIG_HOME='$TMP/badcfg' clangd --check=bug.c --log=verbose 2>&1 | grep -q 'config warning at' && exit 1 || exit 0"
```

This one has a twist: **clangd does not exit non-zero on a bad config.** It
only writes a log line, `config warning at ...`, and keeps going. So the
test has to turn "a log line appeared" into an exit code:

| Step | Bad config (this control) | Good config |
|---|---|---|
| clangd logs | `config warning at ...` | no warning |
| `grep -q 'config warning at'` | finds it → true | finds nothing → false |
| `&& exit 1 \|\| exit 0` | `exit 1` | `exit 0` |
| `reject` sees | failure → **PASS** | success → **FAIL** "accepted a broken input!" |

`XDG_CONFIG_HOME='$TMP/badcfg'` is how it points clangd at the broken file
without touching your real `~/.config/clangd/config.yaml`: clangd looks for
its config under `$XDG_CONFIG_HOME/clangd/`.

**Thinking:** when a tool reports problems as **text** instead of an exit
code, the test has to read the text, and the control has to prove that the
text really appears.
**Lesson:** "exits 0" and "found no problem" are different claims. Check which
one your tool actually makes.

### Control 4: tmux rejects an unknown option (`test.sh:525-536`)

```bash
# tmux: EXECUTE the file in a throwaway server; -n would only parse it.
tmux_conf_ok() {
    local sock="$SOCKS/conf-$RANDOM" rc; TMUX_SOCKS+=("$sock")   # a private server socket, cleaned up at exit
    tmux -S "$sock" -f /dev/null new-session -d 'sleep 30' || return 2   # start an empty server
    tmux -S "$sock" source-file "$1"; rc=$?                              # RUN the config for real
    tmux -S "$sock" kill-server 2>/dev/null
    return $rc
}
...
printf 'set -g no-such-option on\n' > "$TMP/bad.tmux"
reject "tmux rejects an unknown option (negative control)" tmux_conf_ok "$TMP/bad.tmux"
```

This control has the best story, because **it found a broken test**. The
obvious way to validate a tmux config is `tmux source-file -n` ("parse
only"). Measured ✅:

```text
tmux -n (parse only)  exit=0   <- it ACCEPTED the bad option
tmux    (execute)     exit=1   ("invalid option: no-such-option")
```

`-n` checks *grammar* (quotes, braces) but not whether an option *exists*.
With `-n`, the positive check would have passed on any typo. The negative
control exposed that, and the test switched to executing the file in a
throwaway server.

> **Fixed during this tour:** `home/.config/tmux/tmux.conf:3` still recommended
> `tmux source-file -n` as the way to check the file. The comment now says it
> only parses and points to `make test` (tests ✅ 55/0/0 after the edit).

**Lesson:** a "validate" flag may check much less than its name suggests.
Only a negative control tells you how much.

### Control 5: starship warns on a misspelled key (`test.sh:550-558`)

```bash
# henv (a fresh environment) matters: starship prints a given warning only
# once per STARSHIP_SESSION_KEY, and a key inherited from your own shell
# silently hid the negative control's warning (found 2026-10-19).
err=$(henv STARSHIP_CONFIG="$REPO/home/.config/starship.toml" starship print-config 2>&1 >/dev/null)
...
printf '[os]\nstyel = "bold"\n' > "$TMP/bad.toml"                     # "styel", not "style"
starship_quiet() { [[ -z $(henv STARSHIP_CONFIG="$1" starship print-config 2>&1 >/dev/null) ]]; }
reject "starship warns on a misspelled key (negative control)" starship_quiet "$TMP/bad.toml"
```

- **The bad input:** `styel` instead of `style`.
- **Like clangd**, starship reports bad keys as warning *text* on stderr, so
  `starship_quiet` turns "stderr was empty" into true or false.
  (`2>&1 >/dev/null` keeps stderr and throws away stdout; the order matters.)
- **The story:** on 2026-10-19 this control **failed**. starship prints a
  given warning only once per session, identified by the variable
  `STARSHIP_SESSION_KEY`. The test inherited that variable from your
  interactive shell, which had already seen the warning, so starship stayed
  quiet. The fix was `henv`, which runs every check in a clean environment.
  The positive check had the **same blindness**; only the control revealed it.

**Lesson:** when a negative control fails, suspect the *test environment*
before the tool. Something leaked in from your real session.

## 1.5 Validators that have no control yet (measured)

Not every check has a partner. I fed each remaining validator a broken input
(✅ 2026-10-20):

| Validator | `test.sh` line | Broken input | Result |
|---|---|---|---|
| `bash -n` | 102-104 | `if` without `fi` | exit 2: rejects |
| `zsh -n` | 105-108 | `if` without `fi` | exit 1: rejects |
| `shellcheck` | 119-122 | `rm $1` (unquoted) | exit 1: rejects |
| gdb (judged by **output**) | 541-543 | `set print pretty on  # note` | prints `"on" or "off" expected`: rejects |
| `git config -f` | 548 | `[broken` (unclosed section) | exit 128: rejects |
| TOML (`tomllib`) | 564-565 | unclosed string | exit 1: rejects |
| YAML (`yaml`) | 566-570 | unclosed list | exit 1: rejects |

They all reject bad input **today**. A control would make sure it **stays**
true.

**Which ones deserve a control?** Use the same rule that picked the existing
five. Add one where the tool reports problems **as text, not an exit code**
(clangd, starship, gdb), or where a mode might **only parse** (tmux `-n`). The
exit-code validators above are low risk. **gdb** is the clear gap: its check
depends on "printed nothing", exactly like starship.

**Stretch exercise:** add the gdb control yourself, then compare with this
version (✅ verified to pass on good input and to reject the bad one). It
replaces `test.sh:541-546`:

```bash
if have gdb; then
    # gdb reports a bad gdbinit line as TEXT, so "quiet" is the success signal.
    gdb_quiet() { [[ -z $(gdb -nx -batch -x "$1" 2>&1) ]]; }   # true = gdb printed nothing
    if gdb_quiet home/.config/gdb/gdbinit; then
        pass "gdb runs gdbinit silently"
    else
        fail "gdb complained about gdbinit" "$(gdb -nx -batch -x home/.config/gdb/gdbinit 2>&1)"
    fi
    # Negative control: gdb has NO trailing comments (see the gdbinit header),
    # so this passes "on  # a trailing comment" to `set print pretty`: an error.
    printf 'set print pretty on  # a trailing comment\n' > "$TMP/bad.gdbinit"
    reject "gdb rejects a trailing comment (negative control)" gdb_quiet "$TMP/bad.gdbinit"
else
    skip "gdb (not installed)"
fi
```

This adds one check: offline totals go from 57 to 58, and `--full` from 61 to 62.

## 1.6 Don't confuse: three kinds of "trick" test

`test.sh` uses three techniques that all involve something fake or broken.
They answer different questions:

| Kind | What is fake or broken | Question it answers | Where in `test.sh` |
|---|---|---|---|
| **Negative control** | the **input** (a broken config) | "Can this check fail at all?" | the 5 `reject` calls |
| **Test double** | a **program** (a stand-in) | "Can I test this offline / on any machine?" | stub vim-plug 271-277, fake `xclip` 315-322 |
| **Regression test** | nothing: it replays a **past bug** | "Did an old bug come back?" | eza `ls` 194-199, background 291-298, F8 299-305, clipboard 317-352, F5 411-432 |

One test mixes two kinds: **Shift-Tab** (357-384) is a regression test that
uses a test double, a fake `clang-format` that always fails. That's called
**fault injection**: instead of a broken *input*, you give it a broken
*tool* and check that the vimrc handles the failure (buffer intact, error
explained).

## 1.7 Common beginner confusions

1. **"The check passed, so my config is fine."** Only if the check *can*
   fail. A negative control proves it can.
2. **"`reject` is just `check` with a `!` in front."** Close, but it also
   hides the output (a complaint is expected) and prints a different message.
   More importantly, it passes on *any* failure, including the wrong kind
   (see 1.8).
3. **"Parse-only means validated."** `tmux source-file -n` accepted
   `no-such-option` with exit 0. Parsing checks grammar, not meaning.
4. **"The control breaks my real config."** No. Every broken input is a new
   file in `$TMP`, which the cleanup `trap` deletes (lines 41-51). Your
   `home/` files are never touched. (The LEARN-AND-SYNC §6.8 drill is
   different: there *you* break the real file by hand, then `git restore`.)
5. **"A failing negative control means the tool is broken."** Usually it
   means the *test* is broken. starship was fine; the test environment had
   leaked a session variable.

## 1.8 The professional upgrade

- **A control can pass for the wrong reason.** `reject` is happy with any
  failure. `tmux_conf_ok` returns 2 when the throwaway server can't even
  start, which really happened (the 108-byte socket path limit,
  `test.sh:34-38`). In that case the control would *pass* without tmux ever
  reading the bad file. Two defenses:
  1. **Pairing** (this repo does it): every control shares its harness with
     a positive check. If the harness breaks, the positive check turns red, so
     you still notice.
  2. **Assert the reason** (stricter): check *why* it failed, as Control 3
     does by grepping for `config warning at`. For tmux that would mean
     requiring `invalid option` in the output. The cost is tying the test to
     one tool's wording, which can change between versions.
- **Mutation testing** generalizes this. Tools like `mutmut` (Python) or
  Stryker (JS) make thousands of small automatic edits to your *code* and
  report every edit that no test caught. Negative controls are a hand-made
  version, aimed at configs.
- **Where else this appears:** ELISA tests in biology run "negative control"
  wells (the term comes from lab science). Spam filters are validated with
  known-spam samples. A CI pipeline can be checked with a deliberately
  failing commit on a branch, to make sure CI can turn red at all.

---

# Part 2. The repo, top to bottom

## 2.1 The whole flow in one picture

```text
 a new machine
      │
      ▼
 scripts/bootstrap.sh ───► programs installed (zsh, vim, clangd, tmux, shellcheck …)
      │                     via apt (Ubuntu) or pacman (Arch)
      ▼
 ./install.sh ───────────► ~/.zshrc  →  ~/config_files/home/.zshrc   (symlinks)
      │                     anything in the way → ~/.local/state/dotfiles/backup/<time>/
      ▼
 you edit ~/.zshrc  ═══  you edit the repo file  ───► git commit / git push
      │
      ▼
 scripts/test.sh  (throwaway HOME, your real files untouched)
      ├── same script, on Arch, from WSL ──► scripts/arch-sandbox.sh test --full
      └── same script, on GitHub ─────────► .github/workflows/ci.yml (Ubuntu + Arch)
```

The design idea: **one source of truth (`home/`), one installer, one test
script**, run in three places.

## 2.2 The map

```text
config_files/
├── README.md              front door: what it is, quick start, how it works
├── LICENSE                MIT
├── Makefile               shortcuts: `make` lists them (install, test, arch-test …)
├── .editorconfig          whitespace rules that Vim and VS Code follow (4 spaces; 2 for vim/zsh/yaml/html)
├── .gitattributes         every text file stored with LF endings (CRLF breaks scripts)
├── .gitignore             *.local (per-machine secrets)
├── install.sh             links home/* into ~ ; POSIX sh; --dry-run, --uninstall
├── home/                  a MIRROR of ~ : home/X becomes ~/X
│   ├── .profile .zprofile .zshenv .bash_profile    login environment (PATH, EDITOR …)
│   ├── .zshrc .bashrc .config/shell/common.sh      interactive shells (common.sh = shared)
│   ├── .inputrc                                    readline keys (bash, gdb, python)
│   ├── .vimrc .vim/ftdetect/cpp.vim                Vim as a C IDE (clangd via yegappan/lsp)
│   ├── .clang-format .config/clangd/config.yaml    C/C++ style; clangd + clang-tidy
│   └── .config/{git,tmux,gdb}/ .config/starship.toml   the other tools
├── scripts/
│   ├── bootstrap.sh       install the programs (apt or pacman)
│   ├── test.sh            the proof: 57 offline / 61 --full checks
│   ├── lsp-probe.py       asks clangd for diagnostics like an editor would
│   └── arch-sandbox.sh    rootless Arch Linux, to run test.sh on Arch from WSL
├── templates/             per-PROJECT files, never installed (copy them into a project)
├── .github/workflows/ci.yml   test.sh --full on Ubuntu + Arch: every push + Mondays
├── docs/
│   ├── GUIDE.md           why every decision was made (the long-form "why")
│   ├── LEARN-AND-SYNC.md  your study plan + the two-machine sync loop
│   ├── REPO-TOUR.md       this file
│   ├── ATLAS.html         the same repo as diagrams: every file, every startup flow (traced)
│   ├── SHELL-STARTUP.md   why .zprofile and .bash_profile differ (bash vs zsh login, traced)
│   ├── FIX-NOTES.md       what broke, why, how it was fixed (first: the 3 loose ends of 2.5)
│   └── archive/README.md  index of historical files (they move in at GUIDE §9.5)
└── vimrc                  the long Arch twin (847 lines): NOT installed, to be archived
```

## 2.3 Layer by layer

### Layer 0: the root files (rules for the repo itself)

| File | What | Why |
|---|---|---|
| `README.md` | the front door | someone landing on GitHub learns what, how, and the quick start in one screen |
| `Makefile` | 9 one-line targets (`make` alone lists them) | memorable names (`make test`); the real logic stays in scripts you can run directly |
| `.editorconfig` | whitespace rules | every editor writes the same indentation: Vim through `packadd! editorconfig` (`home/.vimrc` line 7, since 2026-10-21), VS Code through the EditorConfig extension. ⚠ The rules are looked up from the path you open: `vim ~/config_files/home/.zshrc` gets them, `vim ~/.zshrc` (the link) does not |
| `.gitattributes` | `* text=auto eol=lf` | a CRLF shell script fails with `bad interpreter: /bin/sh^M`; WSL makes Windows editors likely |
| `.gitignore` | `*.local` | machine-only secrets (`~/.zshrc.local`, API keys) can never be committed |
| `LICENSE` | MIT | a public repo with no license is legally "all rights reserved" |

### Layer 1: `install.sh` (149 lines), the bridge from repo to `~`

- **What:** for every file under `home/`, makes `~/<same path>` a
  **symlink** to it. Editor litter is skipped: Vim swap files (`*.sw?`)
  and backups (`*~`).
- **Why symlinks, not copies:** editing `~/.zshrc` *is* editing the repo, so
  `git diff` shows your change at once and `git pull` updates the machine.
  Copies drift apart silently.
- **Why POSIX `sh`:** it runs on a fresh machine *before* zsh or bash are
  configured, on Linux and macOS.
- **Safety rules** (each one tested in `test.sh` section 3, lines 128-179):
  `--dry-run` changes nothing; nothing is ever deleted (the old file is
  *moved* to a timestamped backup); a second run does nothing (idempotent);
  `--uninstall` removes only links that point into this repo; it refuses to
  run as root (Control 1); editor litter is never linked.

### Layer 2: `home/`, in the order your machine reads it

Startup files are read in a fixed **order**, so read them in that order.
For a login zsh (what Windows Terminal starts), measured in
LEARN-AND-SYNC.md:349-357:

```text
~/.zshenv     every zsh, even scripts: one line (skip Ubuntu's duplicate compinit)
~/.zprofile   login only: sources /etc/profile and ~/.profile in sh mode
~/.profile    the ENVIRONMENT: exported PATH, EDITOR, LESS … (plain POSIX sh)
~/.zshrc      interactive: history, completion, keys, plugins, prompt (167 lines)
   └─ ~/.config/shell/common.sh   shared with bash: ls/cat/rm wrappers, git, packages, WSL, proxy
```

A login bash takes a parallel path: `~/.bash_profile` → `~/.profile` →
`~/.bashrc` → `common.sh`.

The rule that shapes all of it: **environment** (inherited by child
processes) goes in `.profile`; **interactive conveniences** (aliases,
functions, keys, prompt) go in the rc files. `common.sh` adds one more idea,
"human vs script" (lines 7-9): `[ -t 0 ]` asks "is a human typing?". `rm`
asks for confirmation only then, so scripts and AI agents never hang on a
prompt. `test.sh:200-203` proves it ("agent-safe").

Then the tools, each in its own file:

| File | Read by | Note |
|---|---|---|
| `.vimrc` (382 lines) + `.vim/ftdetect/cpp.vim` | Vim 9 | LSP (clangd) via yegappan/lsp, fzf, clipboard incl. WSL, formatter bridge |
| `.clang-format` | clang-format, clangd | Chromium-based style, merged from 4 old copies |
| `.config/clangd/config.yaml` | clangd | global settings + clang-tidy checks; must be safe for every project |
| `.inputrc` | readline (bash, gdb, python3) | not zsh: zsh has its own line editor |
| `.config/git/{config,ignore}` | git | identity stays in `~/.gitconfig`, which is read after this file and wins |
| `.config/tmux/tmux.conf` | tmux ≥ 3.2 | |
| `.config/gdb/gdbinit` | gdb ≥ 11 | gotcha: no trailing comments |
| `.config/starship.toml` | starship | the 2-line prompt on both machines |

### Layer 3: `scripts/`, the tools that act on the repo

| Script | Job | Run it |
|---|---|---|
| `bootstrap.sh` | install the *programs* the configs need | once per machine, before `install.sh` |
| `test.sh` | prove everything works, in a throwaway HOME | after every edit: `make test` |
| `lsp-probe.py` | talk to clangd like an editor, print diagnostics | by `test.sh:519`, or by hand on a C file |
| `arch-sandbox.sh` | an Arch root filesystem + bubblewrap, no root needed | `make arch-setup` once, then `make arch-test` |

`test.sh` has six sections, matching what can break: 1 Syntax (97), 2 Lint
(118), 3 install.sh (128), 4 Shell startup (174), 5 Vim (232), 6 Config files
(484).

### Layer 4: `templates/`, configs for *projects* rather than for `~`

clangd reads per-project files found by searching upward from the source
file, so these live in a project root, not in `~`. `install.sh` never
touches them:

- `abstract-machine/.clangd` → `~/os-workbench/` (fixes clang-vs-gcc false errors in the NJU labs)
- `cpp-practice/compile_flags.txt` → `~/algo/` (one flag set for a folder of single-file programs)
- `.clang-tidy` → any project that wants the same checks in CI

`templates/README.md` explains how clangd finds your compiler flags. Read it
before your next C project.

### Layer 5: `.github/workflows/ci.yml`, the safety net you don't run

It runs the *same* `scripts/test.sh --full` in `ubuntu:26.04` and
`archlinux:latest` containers on every push and every Monday 03:17 UTC. The
Monday run catches distro updates that break a config even when you changed
nothing. `fail-fast: false` keeps one distro's failure from hiding the other's
result.

### Layer 6: `docs/`, the why

| Doc | Read it when |
|---|---|
| `GUIDE.md` | you wonder *why* something is the way it is (sections 0-14, from "what is a dotfiles repo" to bleeding edge) |
| `LEARN-AND-SYNC.md` | you want the study plan (Phase 0/A/B/C) or the daily pull-edit-test-push loop |
| `REPO-TOUR.md` | you want the map (this file) |
| `ATLAS.html` | you want to *see* it: 21 diagrams of which file runs when, traced on the machine (open it in a browser) |
| `SHELL-STARTUP.md` | you wonder why `~/.zprofile` and `~/.bash_profile` look so different (login startup, traced) |
| `FIX-NOTES.md` | you want the story of a fix: what broke, why, the tests, the lesson (first entry: the 3 loose ends of 2.5) |
| `archive/README.md` | you need history; the files it lists arrive with GUIDE §9.5 |

## 2.4 The reading order I recommend

Follow **dependencies**, not the alphabet:

1. `README.md`: the promise.
2. `install.sh`: how the repo becomes your `~`. Every other file relies on it.
3. `home/.profile` → `.zprofile` → `.zshrc` → `common.sh`: the startup order.
4. `scripts/test.sh` sections 3-4: how those promises are proven.
5. `home/.vimrc` with `test.sh` section 5 side by side: each regression test
   points at a vimrc line that once had a bug.
6. `templates/README.md` + `home/.config/clangd/config.yaml`: the C toolchain.
7. `ci.yml` and `arch-sandbox.sh`: running the same proof elsewhere.
8. `GUIDE.md` whenever a "why?" comes up; it's a reference, not a novel.

LEARN-AND-SYNC Phase A walks the same path with exercises.

## 2.5 Loose ends found on this tour

| Item | Status |
|---|---|
| `tmux.conf:3` recommended `tmux source-file -n` as a check | ✅ **fixed** (see Control 4) |
| `.gitignore` line 6: `/.test-home/` | ✅ **deleted** 2026-10-21 (nothing wrote it: `test.sh` uses `mktemp` in `/tmp`) |
| `.install.sh.swp` in the repo root | ✅ **gone** by 2026-10-21: its Vim session ended. A swap file of a running Vim is normal; check `ps aux \| grep vim` before deleting one |
| root `vimrc` (847 lines) | not live (`~/.vimrc` → `home/.vimrc` ✅); GUIDE §9.5 moves it to `docs/archive/` |
| `docs/archive/` holds only its README | expected until GUIDE §9.5 runs |
| gdb has no negative control | your stretch exercise in 1.5 |
| `install.sh` linked *every* file under `home/` | ✅ **fixed** 2026-10-21: its `find` skips `*.sw?` and `*~`; `test.sh` section 3 plants both in a fake repo (docs/FIX-NOTES.md) |
| `.config/git/ignore:6` said "the vimrc keeps them in ~/.vim" | ✅ **fixed** 2026-10-21: the comment now says swap files sit next to the edited file (for a link, next to its target); GUIDE §1.4 had the same claim, corrected too |
| `.editorconfig` was inert in Vim | ✅ **fixed** 2026-10-21: `silent! packadd! editorconfig` (vimrc line 7), after 4 rules were corrected to match the files; `test.sh` section 5 checks it. Opening a dotfile through its `~` link still skips the rules |

---

# Part 3. Wrap-up

## Pros and cons of this repo's design

| Choice | Pros | Cons |
|---|---|---|
| Symlinks from one `home/` mirror | edits land in git at once; one install script | while a branch is checked out, the whole machine runs it (LEARN-AND-SYNC §6.7) |
| One `test.sh`, run in 3 places | a red CI run reproduces with one local command | Linux only (GNU `find`/`stat`/`date`) |
| A negative control for each text-reporting validator | checks that can't fail are caught | `reject` can pass for the wrong reason (1.8) |
| Plain shell instead of chezmoi/yadm | nothing new to learn; easy to read | no templating for per-machine differences beyond `*.local` |

## How to improve

- **Now:** add the gdb control (1.5).
- **Next:** make the tmux control assert its reason (`invalid option`) so
  it can't pass because the server failed to start.
- **Bleeding edge:** fuzz each config validator with automatically mutated
  copies of your real configs (delete a line, misspell a key) and require
  every mutant to be rejected. That's mutation testing applied to configs.

## The short version

Five `reject` calls in `test.sh` feed each validator a deliberately broken
input, proving the "no complaints" on your real config means something. Two
of them, tmux and starship, earned their place by catching a test that
couldn't fail. The repo around them is a pipeline: `bootstrap.sh` installs
programs, `install.sh` symlinks `home/` into `~`, and one `test.sh` proves
it in a throwaway HOME, locally, on Arch, and in CI.

## The transferable principles (the part to keep)

1. A check that cannot fail proves nothing. Pair every validator with a known-bad input.
2. Know how your tool reports problems: exit code or text. Test the signal it actually gives.
3. "Parse" is not "validate": grammar can be fine while meaning is wrong.
4. When a negative control fails, suspect the test environment first.
5. Keep the broken input synthetic and temporary; never break real files to test.
6. Read a repo in dependency order: what it promises, how it's installed, how it's proven.

## Mental checklist

- Does this check have a known-bad partner?
- Does the tool signal errors by exit code or by text?
- Could the control pass because the *harness* failed?
- Which startup file reads which, in what order?
- Is the file I'm editing the live one (`readlink ~/<file>`)?

## Where to go next

1. Do the gdb stretch exercise (1.5): write it, run `make test`, expect 56 passed.
2. LEARN-AND-SYNC §6.8 drill 1: break `tmux.conf` by hand and watch the net catch it.
3. Read about mutation testing (search "mutation testing introduction"), then
   look at `mutmut` for your Python code.
