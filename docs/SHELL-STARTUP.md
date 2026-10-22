# Login startup: why bash and zsh take different roads to the same place

> Question: why do `~/.zprofile` and `~/.bash_profile` look so different? Why
> does zsh use `emulate sh -c '. /etc/profile'` (and not `emulate -R`), while
> bash sources `~/.profile` and `~/.bashrc` with no emulation at all? Do the two
> shells end up with a different order and a different environment?
>
> Every ✅ below was run on this machine (Ubuntu 26.04 on WSL2, zsh 5.9,
> bash 5.3) on 2026-10-21. The commands are included so you can re-run them.

---

## 0. The answer in five lines

1. **The files differ because the shells' built-in rules differ, not because
   you want different results.** bash reads `/etc/profile` by itself; zsh never
   does. bash never reads `~/.bashrc` in a login shell; zsh reads `~/.zshrc` by
   itself. Each `*_profile` file patches its own shell's gaps.
2. **zsh needs `emulate sh` because `/etc/profile` and `~/.profile` are written
   in POSIX sh**, and native zsh reads some sh code differently. bash already
   reads sh code the sh way, so it needs nothing.
3. **`emulate sh -c` is enough; `-R` is overkill.** Plain mode flips the 81
   options that change how *code* means things. `-R` also resets 96 more
   (history, completion, prompt, and your `xtrace` debugging switch) that
   don't matter here, and it silences `zsh -x` traces.
4. **The order differs a little, the result doesn't.** ✅ Both login shells
   end with an identical `PATH`. The only exported difference is
   `LESSOPEN`/`LESSCLOSE` (bash sets them, zsh doesn't).
5. **One real gotcha found:** Ubuntu's `/etc/profile` changes zsh's prompt to
   `$ `. starship hides this, but zsh has no fallback prompt if starship is
   missing.

---

## 1. Plain-language summary

A login shell is the first shell of a session (a Windows Terminal tab, an ssh
login, a tty). It has two jobs:

- **Environment**: set exported variables (`PATH`, `EDITOR`, `LESS`, ...) once,
  so every program started later inherits them. Lives in `~/.profile`.
- **Interactive comfort**: aliases, history, key bindings, prompt. These are
  *not* inherited, so every interactive shell must set them again. Lives in
  `~/.bashrc` / `~/.zshrc`.

You keep the environment in **one** shared file, `~/.profile`, written in
plain POSIX sh so that sh, bash and zsh can all read it. bash and zsh each need
a small adapter file to reach it, and the two adapters look different
because the two shells differ.

## 2. Analogy: two airports, one hotel

Your hotel (`~/.profile`) is the same for every traveler. Two airlines bring
people there:

- **Airline bash** already includes the city shuttle (`/etc/profile`) in the
  ticket, and its passengers already speak the local language (POSIX sh). But
  it drops them at the hotel lobby and never takes them up to their room
  (`~/.bashrc`). So `~/.bash_profile` says: "walk to the hotel, then go up to
  your room."
- **Airline zsh** never includes the shuttle (`/etc/profile`) on Ubuntu, and
  its passengers speak a dialect (native zsh) in which some local words mean
  something else. But it does take passengers to their room (`~/.zshrc`)
  automatically. So `~/.zprofile` says: "take the shuttle and the hotel
  check-in **with an interpreter** (`emulate sh -c`), then the airline handles
  the room."

The interpreter is hired only for the check-in (`-c` = temporary). `-R` would
be a stricter interpreter who also takes away your notebook (`xtrace`) during
check-in. Nothing goes wrong, but you can't see what happened.

## 3. Worked walkthrough: who reads what, traced

### 3.1 The rules built into each shell

| | login bash | login zsh |
|---|---|---|
| reads `/etc/profile` itself? | **yes**, first | **no** (only when started as `sh`/`ksh`) |
| user login file | first of `~/.bash_profile`, `~/.bash_login`, `~/.profile`, then **stops** | `~/.zprofile` (after `/etc/zsh/zprofile`) |
| reads interactive rc itself in a login shell? | **no**, never `~/.bashrc` | **yes**, `/etc/zsh/zshrc` then `~/.zshrc` |
| always-read file (even scripts) | none (`$BASH_ENV` only if set) | `/etc/zsh/zshenv`, `~/.zshenv` |
| native syntax = POSIX sh? | close enough (word splitting, literal unmatched globs) | **no** (see §3.3) |

Each row explains one line of your adapters:

```sh
# ~/.bash_profile: fills bash's gaps
. "$HOME/.profile"     # bash STOPPED at .bash_profile, so .profile is never read otherwise
. "$HOME/.bashrc"      # bash never reads .bashrc in a login shell, so chain it by hand
# no `. /etc/profile`: bash already read it before this file
# no emulation: bash already reads sh code the sh way
```

```zsh
# ~/.zprofile: fills zsh's gaps
emulate sh -c '. /etc/profile'                          # zsh never reads it (Ubuntu's /etc/zsh/zprofile is empty)
[[ -r ~/.profile ]] && emulate sh -c '. ~/.profile'     # sh-dialect file -> read it in sh mode
# no `. ~/.zshrc`: zsh reads it by itself right after this file
```

### 3.2 The actual order, traced ✅

```sh
# zsh: built-in tracer
zsh -o sourcetrace -l -i -c exit 2>&1 </dev/null | grep -v /usr/share/zsh/functions
# bash: put the current file name into the xtrace prefix
PS4='+@${BASH_SOURCE[0]}@ ' bash -l -i -x -c exit 2>&1 </dev/null | grep -o '^+*@[^@]*@' | uniq
```

```text
login zsh                                   login bash
─────────                                   ──────────
/etc/zsh/zshenv                             /etc/profile
~/.zshenv                                     ├─ /etc/bash.bashrc     ◄─ interactive system rc, EARLY
/etc/zsh/zprofile        (empty on Ubuntu)    │    └─ /etc/profile.d/proxy.sh
~/.zprofile                                   └─ /etc/profile.d/*.sh  (01-locale-fix … vte-2.91)
  ├─ /etc/profile        (in sh mode)       ~/.bash_profile
  │    └─ /etc/profile.d/*.sh                 ├─ ~/.profile
  └─ ~/.profile          (in sh mode)         └─ ~/.bashrc
/etc/zsh/zshrc           ◄─ system rc, LATE         └─ ~/.config/shell/common.sh
~/.zshrc                                    … at exit: ~/.bash_logout
  └─ ~/.config/shell/common.sh
/etc/zsh/zlogin          (empty on Ubuntu)
… at exit: /etc/zsh/zlogout
```

**Thinking:** the user files line up one to one (`.zprofile` ↔
`.bash_profile`, `.profile` in both, `.zshrc` ↔ `.bashrc`). The real order
difference is at the *system* level. Ubuntu's `/etc/profile` starts by
sourcing `/etc/bash.bashrc` when the shell is an interactive bash, so bash's
system rc runs **before** `~/.profile`. zsh's `/etc/zsh/zshrc` runs
**after** it.

**Lesson:** does that matter? Only if a system rc and your `~/.profile` set the
same thing. In both shells **your own rc file runs last**, so your settings win
either way. The rule to remember is "user rc is last", not the exact position
of system files.

### 3.3 Why zsh needs `emulate sh`, and bash doesn't ✅

A 7-line file using the two idioms every `/etc/profile.d` script relies on:

```sh
flags="-a -b"
set -- $flags                                  # POSIX: unquoted $var splits on spaces
echo "  1. word split of \$flags -> $# word(s)"
for f in /no/such/dir/*.sh; do                 # POSIX: unmatched glob stays literal...
    [ -r "$f" ] && echo "sourcing $f"          # ...and this test skips it
done
echo "  2. reached the line AFTER the empty glob"
export DEMO_VAR=set-at-end
```

Sourced four ways:

| shell | 1. words | 2. after the glob? | 3. `DEMO_VAR` |
|---|---|---|---|
| `sh` (dash) | 2 | ✔ | set |
| `bash`, defaults | 2 | ✔ | set |
| `zsh`, native | **1** | **✘** `no matches found` | **unset** |
| `zsh`, `emulate sh -c` | 2 | ✔ | set |

**Thinking:** native zsh made two different mistakes. `SH_WORD_SPLIT` is off,
so `$flags` stayed one word. `NOMATCH` is on, so an empty glob is an *error*,
and that error **abandoned the rest of the sourced file**. Every `export` below
it silently never happened. On a machine where some `/etc/profile.d` script
loops over an empty directory, that would quietly lose part of your
environment.

**Lesson:** bash's default behavior already *is* the sh behavior for these
idioms, so `. ~/.profile` in bash needs no adapter. "Bash doesn't use emulate
to keep its defaults" is backwards: bash doesn't need emulate **because** its
defaults are already sh-like.

### 3.4 `emulate sh -c` vs `emulate -R sh -c` ✅

```zsh
emulate -l  sh   # list options plain `emulate sh` would change   -> 81
emulate -lR sh   # list options `emulate -R sh` would change      -> 177
```

| | plain `emulate sh` | `emulate -R sh` |
|---|---|---|
| what it changes | only options that change **what code means**: `shwordsplit`, `nonomatch`, `ksharrays`, `noequals`, `globsubst`, `posixbuiltins`, `bsdecho`, … | **all** options back to sh defaults, except a few that describe the session (`interactive`, `login`, `zle`, …) |
| extra 96 options `-R` adds | — | history (`banghist`, `sharehistory`), completion (`automenu`), prompt (`promptpercent`), `beep`, `rcs`, … and **`noxtrace`, `noverbose`, `nosourcetrace`** |
| restored after `-c '…'` finishes? | yes | yes |
| `zsh -x` trace of the sourced file | **visible** (1 trace line ✅) | **gone** (0 trace lines ✅) |

**Thinking:** with `-c`, *both* forms are temporary, so the question is only
"what is in effect while `/etc/profile` runs". The extra 96 options control
the line editor, history and prompt. None of them change how sh code is
parsed or expanded, and `/etc/profile` doesn't use any of them. So `-R` buys
nothing here, and costs one thing you will want someday: when you debug a slow
or broken login with `zsh -x -l`, the trace goes silent inside `/etc/profile`.

**Lesson:** pick the smallest tool that fixes the actual risk. The risk is
*sh code meaning something else*, and plain `emulate sh` covers exactly that.
It is also what Arch's own `/etc/zsh/zprofile` uses, so it is the common
idiom. Use `-R` when you need a guaranteed clean slate, e.g. at the top of a
zsh function in a plugin (`emulate -L -R zsh`) that must not be affected by
whatever `setopt`s the user has.

### 3.5 Do the two shells end up with different environments? ✅

Same clean starting environment, then diff what each login shell exports:

```sh
clean() { env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" TERM=xterm-256color \
          WSL_DISTRO_NAME="$WSL_DISTRO_NAME" WT_SESSION=x PATH=/usr/bin:/bin "$@"; }
clean bash -l -i -c env </dev/null 2>/dev/null | sort > /tmp/env.bash
clean zsh  -l -i -c env </dev/null 2>/dev/null | sort > /tmp/env.zsh
diff /tmp/env.bash /tmp/env.zsh
```

```text
< LESSCLOSE=/usr/bin/lesspipe %s %s      bash only (from ~/.bashrc)
< LESSOPEN=| /usr/bin/lesspipe %s        bash only (from ~/.bashrc)
> OLDPWD=…                               zsh bookkeeping
< STARSHIP_SHELL=bash / > zsh            expected, per-shell
PATH                                     identical
```

**Thinking:** different roads, same destination. The one real gap is
`LESSOPEN`, an *exported* variable that `~/.bashrc` sets with
`eval "$(SHELL=/bin/sh lesspipe)"` and `~/.zshrc` doesn't. So `less file.gz`
shows the decompressed text in bash, while zsh's `less` has no preprocessor
and treats it as a binary file.

**Lesson:** an exported variable set in an rc file is a smell. By your own
rule in `~/.profile` (line 5: "things child processes INHERIT"), it belongs
there, where both shells pick it up.

## 4. Common beginner confusions

> **"`emulate sh` turns my zsh into sh for the rest of the session."**
> Only without `-c`. ✅ `emulate sh -c true; emulate` prints `zsh`.
> `emulate sh; emulate` prints `sh`, and your `.zshrc` would then run in sh
> mode. The `-c '…'` form is a bracket: switch, run, switch back.

> **"bash skips `emulate` to keep its default settings."**
> bash has no `emulate`, and it doesn't need one: its defaults already read
> POSIX code the POSIX way (§3.3). The closest bash feature is `set -o posix`,
> which changes small corner cases and is not needed for `~/.profile`.

> **"`-R` is the safer, stricter choice, so it must be better."**
> Stricter than needed. It resets options that have nothing to do with how
> the code is read, including your debug tracing (§3.4).

> **"zsh reads `/etc/profile` because it is a login shell."**
> Only sh-family shells do. zsh reads `/etc/zsh/zprofile`. On Arch that file
> sources `/etc/profile`; on Ubuntu it is empty, which is why your
> `~/.zprofile` does it. (On Arch, `/etc/profile` therefore runs twice, which
> is harmless because it only appends missing `PATH` entries.)

> **"A login bash reads `~/.bashrc`."**
> Never by itself. If `~/.bash_profile` doesn't source it, your aliases and
> prompt are missing in every new terminal tab.

> **"Functions defined inside `emulate sh -c` behave like normal zsh functions."**
> They are *sticky*: they keep sh mode forever. ✅ A function defined inside
> `emulate sh -c` splits `"a b c"` into 3 words when called later from zsh;
> the same function defined natively gives 1. Your `~/.profile` unsets its
> only function (`unset -f path_prepend`), so this never bites you, but any
> function a `/etc/profile.d` script leaves behind runs in sh mode.

## 5. The professional upgrade

- **One environment file, thin adapters.** That's the design you already
  have: `~/.profile` is the single source of truth; `.bash_profile` and
  `.zprofile` are 2-3 line adapters. Practitioners keep adapters dumb so the
  two shells can't drift apart.
- **Idempotent environment code.** `/etc/profile.d/proxy.sh` is sourced 2-3
  times in one startup (from `/etc/bash.bashrc`, the `profile.d` loop, and
  `common.sh`). That is only safe because it is idempotent. Your
  `path_prepend` follows the same rule ("safe to run twice").
- **Silent profiles.** Nothing in a profile may print. `scp`/`rsync` read the
  output stream of a remote non-interactive shell and break on stray text.
- **Measure startup with the tracers above**, not by reading code: zsh's
  `sourcetrace`, bash's `PS4` with `BASH_SOURCE`, and `zsh -x -l` when you
  need line-level detail (one more reason not to use `-R`).

### Pros and cons of the two adapter styles

| | bash style (`.` directly) | zsh style (`emulate sh -c '. …'`) |
|---|---|---|
| pro | shortest possible; no mode switches | protects sh code from zsh dialect; scoped; trace-friendly |
| con | relies on bash's defaults staying sh-compatible (`shopt` changes before it could matter) | sticky emulation for leftover functions; one more concept to learn |
| alternative | `set -o posix; . ~/.profile; set +o posix`: no real gain | `emulate -R sh -c`: hides traces; or rewrite env in zsh syntax (`path=(…)`), which loses the shared file |

## 6. How to improve the current setup (not applied, your call)

1. **Move `lesspipe` from `~/.bashrc` to `~/.profile`.** Makes `less file.gz`
   work in zsh too and keeps "exported = `.profile`" true.
2. **Give zsh a fallback prompt.** `.zshrc:167` is the only prompt setter. If
   starship is ever missing, Ubuntu's `/etc/profile` leaves you with `$ `
   (✅ `PS1` goes from `%m%# ` to `$ `). bash's `.bashrc` already has a
   fallback; zsh could mirror it:
   `_cached_init starship init zsh || PROMPT='%F{green}%n@%m%f:%F{blue}%~%f%# '`
3. **Record the `-R` decision in `.zprofile`'s comment** so future you doesn't
   "upgrade" it: e.g. *"not -R: it also resets xtrace, so `zsh -x -l` would go
   blind inside /etc/profile"*.

## 7. Expansion

- **Non-login shells** (typing `zsh` or `bash` in a tab, VS Code terminals)
  skip all profile files and inherit the environment from their parent. That's
  why both rc files re-add `~/.local/bin`.
- **`sh` itself** (dash) reads `/etc/profile` and `~/.profile` at login, and
  `$ENV` when interactive. When bash or zsh is *started as* `sh`, they copy
  that behavior.
- **`ssh host cmd`** runs a non-login, non-interactive bash that still reads
  `~/.bashrc` (a Debian compile option). That's why your `.bashrc` returns
  immediately unless `$-` contains `i`.
- **macOS**: `/etc/zprofile` runs `path_helper`, which reorders `PATH`. Same
  pattern, different system file.
- Deeper reading: your note `~/notes/shell-login-vs-interactive.md` (the full
  login × interactive matrix), `man zshoptions` → *emulate*, `man bash` →
  *INVOCATION*.

## 8. The short version of the whole story

The two adapter files look different because each one fills a different gap:
bash already reads `/etc/profile` but forgets `~/.bashrc`; zsh forgets
`/etc/profile` but reads `~/.zshrc` by itself. zsh also speaks a dialect, and
a traced experiment showed native zsh losing every line after an empty glob in
a POSIX file. So zsh reads the shared files through `emulate sh -c`. bash,
whose defaults already behave like sh, needs no interpreter. `-R` was measured
to touch 96 extra options that don't affect sh code, and to hide `zsh -x`
traces, so plain `emulate sh` is the better tool. A clean-environment diff
showed both shells end up with an identical `PATH`; the only gap is
`LESSOPEN`, which lives in the wrong file.

## 9. The transferable principles (the part to keep)

1. **Read the shell's built-in rules first; the config files only patch the
   gaps.** Different gaps, different patches, same goal.
2. **Keep one source of truth in the lowest common dialect** (POSIX sh) and
   adapt each consumer to it, not the other way around.
3. **When running code written for another dialect, switch dialect for exactly
   that code, and switch back** (`emulate sh -c`, not bare `emulate sh`).
4. **Choose the smallest change that removes the actual risk.** `-R` fixes
   nothing extra here and costs observability.
5. **Verify the result, not the path.** Two different startup chains are fine
   if a clean-environment diff of their output matches.
6. **Exported → profile; interactive → rc.** A violation (like `LESSOPEN` in
   `.bashrc`) shows up as a difference between shells.

## 10. Mental checklist

- [ ] Can I name, for each shell, which system file it reads by itself?
- [ ] Do I know why `.bash_profile` must source `.bashrc`, and `.zprofile` must not source `.zshrc`?
- [ ] Can I explain what `-c` does to the scope of `emulate`?
- [ ] Can I name two zsh options that break POSIX code (`SH_WORD_SPLIT` off, `NOMATCH` on)?
- [ ] Can I prove an environment difference with `env -i … -l -i -c env` and `diff`?

## 11. Suggested learning path

1. Re-run the two tracers in §3.2, then drop `-l` and see which files vanish.
2. Run `emulate -l sh` yourself and look up five options in `man zshoptions`.
3. Read `/etc/profile` and `/etc/bash.bashrc` on this machine, line by line.
4. Stretch: apply improvement 1 (`lesspipe` → `.profile`) and prove it with the §3.5 diff.
