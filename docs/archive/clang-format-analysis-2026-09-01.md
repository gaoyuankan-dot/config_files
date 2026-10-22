# .clang-format and compile_commands.json — analysis (2026-09-01)

Companion to `vimrc-analysis-2026-08-31.md` (the vimrc side) and
`vimrc-plugin-analysis-2026-09-01.md` (the plugin side). Everything below was
probed live on this machine with `clang-format` / `clangd` 22.1.8 (pacman
`clang 22.1.8-1`), not recalled from docs.

---

## 0. The one picture

clang-format is a **copy editor**, not a compiler. A copy editor rearranges
*typography* — line breaks, brace placement, spaces — and never opens the
reference books (your `#include`s) to check what your words *mean*. That is
why its only two inputs are the text and **where the file lives** (to find the
nearest style sheet).

`compile_commands.json` is a book of **recipe cards** — one per translation
unit, recording the exact compiler invocation (compiler, flags, include paths,
defines). The semantic chef — clangd, clang-tidy — must have the recipes to
understand your code. The copy editor never reads recipe cards.

**Direct answer to the compile_commands question: NO.** clang-format does not
read `compile_commands.json`, has no command-line flag for it, and its output
is not influenced by it in any way. (Probe P5 below: zero mentions of
"compile" in `clang-format --help`, while `clangd --help` has
`--compile-commands-dir`.) In your vimrc the two worlds meet in different
halves: Shift-Tab (formatting, syntax-only) and YCM/clangd (completion, goto,
diagnostics — the compile-db consumers). Your own comment in `~/.vimrc:779`
already names this: *"Why SEPARATE from a formatting orchestrator rather than
merged: two CONTRACTS."*

---

## 1. What — the file, the tool, the discovery rule

**What `.clang-format` is:** a YAML file (JSON is a valid subset of YAML, so
either parses) that configures the `clang-format` tool from the LLVM/Clang
project. **Purpose: yes — exactly what you guessed.** It automatically
rewrites C/C++ (and Objective-C; also Java, JavaScript, JSON, Proto, Verilog)
source text to one consistent layout. The checked-in copy is how a *project*
imposes its style on every contributor and every editor.

**The discovery rule (this is the load-bearing part):**

1. When clang-format formats a file, it starts in that file's directory and
   **walks upward**, taking the **nearest** `.clang-format` (legacy name
   `_clang-format` also accepted).
2. If none is found all the way up: it silently falls back to
   `--fallback-style` (default `llvm`).
3. On stdin (how vim pipes buffers), the walk starts from
   **`--assume-filename`**, not from vim's CWD.

That rule is why the same machine can hold several styles and each directory
gets its own — proven in probe P1-P4 below: `~/2026` → your global style,
`~/config_files` → the stale WebKit dump, `xv6-riscv/kernel` → the kernel
style, `/tmp` → LLVM fallback.

**YAML detail worth knowing:** the first line `---` is the YAML
document-start marker, and the `...` at the end of
`config_files/.clang-format:85` is the YAML document-*end* marker — not an
ellipsis, not truncation. Both are optional.

**How the tool decides where to break lines (short version):** it parses the
code into "unwrapped lines" (runs of tokens that *could* share a line), then
chooses breaks by minimizing a weighted penalty sum — that's what the
`Penalty*` keys in your old dump mean (`PenaltyExcessCharacter: 1000000` is
why the column limit behaves as hard). It is optimization, not pattern
matching, which is why legal-but-odd layouts sometimes result. `ColumnLimit: 0`
means "no limit, only structural breaks".

---

## 2. Origin — of the tool, of the file format, of *your* four copies

**The tool.** clang-format was written at Google (Daniel Jasper, Manuel
Klimek) and first shipped in LLVM 3.3 (2013). The motivation was the
realization behind `gofmt` (Go, 2009-2010): style debates end when *the tool*
owns the whitespace — "gofmt's style is no one's favorite, yet gofmt is
everyone's favorite." Chromium and Google adopted clang-format at scale, which
is why `llvm`, `google`, `chromium`, `mozilla`, `webkit`, `gnu`, `microsoft`
exist as built-in presets (`BasedOnStyle`). The file-based config mechanism
(`--style=file`, YAML `.clang-format` searched up the tree) landed about a
release later (clang 3.4 era, 2014); before that you could only pick a preset
by name. So: **origin = LLVM/Clang toolchain, culture = Google/Chromium,
philosophy = gofmt**.

**Your four copies, probed and dated today:**

| Path | What it actually is | Fingerprint (probed) | mtime |
|---|---|---|---|
| `~/.clang-format` (90 lines) | Your **current, curated** global default — `BasedOnStyle: Chromium` with hand-picked overrides; header says "Created: 2024-06-24" | 80-col, cont-indent 8, short-if `WithoutElse` | 2026-06-27 |
| `config_files/.clang-format` (86 lines) | **Stale twin** — an old machine-dumped WebKit style (`# BasedOnStyle: WebKit` at `:2`, `...` at `:85`), full of keys from old clang versions | 76-col, cont-indent 4, short-if `false` | 2026-05-12 |
| `xv6-riscv/.clang-format` (10 lines) | Kernel-C style for the MIT teaching OS; entered your repo history in one commit (`96987ad "add sync syscall"`) — lab-work addition, not upstream-shipped | return type on own line, function brace on next line, 2-space | 2026-06-28 |
| `2020-kimi-2.7/syscall/.clang-format` (71 lines) | Per-project override, also Chromium-based; header notes ".S/.s assembly NOT supported by clang-format" | 80-col, cont-indent 8 | 2026-06-26 |

The story the dates tell: in **May 2026** your dotfiles repo was initialized
carrying the then-current style — an old `WebKit` dump produced years earlier
by an old clang (`clang-format -style=webkit -dump-config > .clang-format`;
the old-key spelling is the giveaway). Around **June 26-27, 2026** you
upgraded to the curated Chromium-based style and deployed it to `~/.clang-format`
(and to the syscall project) — but the repo copy was never refreshed. Same
twins-drift disease as `vimrc-claude/` lagging the working tree.

---

## 3. How — your vimrc's formatter bridge, annotated

The pipeline your Shift-Tab runs (`config_files/.vimrc:57-68`, guarded
version in `~/.vimrc:131-175`):

```vim
" config_files/.vimrc:57-61 — whole-buffer C/C++ formatting
function! s:ClangFormat() abort
  let l:view = winsaveview()          " save cursor + scroll (formatting moves text)
  silent! execute '%!clang-format --assume-filename=' . shellescape(expand('%:p'))
  "                   └─ % = all lines; !cmd filters the range through cmd's
  "                      stdin and REPLACES the range with cmd's stdout.
  "                      --assume-filename=%:p gives clang-format the REAL path
  "                      so the .clang-format walk-up (§1) starts in the right
  "                      directory — stdin by itself has no location.
  call winrestview(l:view)            " put the cursor back where it was
endfunction
```

Mapped per-filetype in `config_files/.vimrc:96-104` (`<S-Tab>` normal+visual
for c,cpp; range variant pipes only `a:firstline,a:lastline`). The home twin
adds the two guards your code-quality bar wants and the repo twin lacks:
`s:MissingTool` (PATH check, `~/.vimrc:132-138`) and `s:FilterFailed`
(`~/.vimrc:143-151`) — on non-zero exit the buffer holds the tool's stderr
(`silent! undo` restores it, `v:shell_error` survives `silent!`), then warns.
The disabled format-on-save idiom is kept as documentation at `~/.vimrc:226-230`.

Key mechan: **nothing in this bridge knows about your build.** The only thing
that flows to clang-format is the buffer text plus one string — the file path.
No compile db, no include paths, no defines.

**Inside the tool, three steps:** lex/parse (syntax only — unknown macros and
non-compiling code are fine), build unwrapped lines, minimize the penalty
function, emit. This is also why clang-format can format a file with missing
headers or half-typed code — a formatter *must* survive broken input;
semantic tools cannot and do not.

---

## 4. Probes (all run today, clang 22.1.8)

Discriminating snippet (signature = 78 cols; body reveals if-handling and
indent):

```c
int probe_function(int aaaaaaaaaaaaaaaaaaaaaaaaa, int bbbbbbbbbbbbbbbbbbbb) {
if (x) return 1;
return 2;
}
```

**P1 — `--assume-filename=/home/ken/2026/probe.c` (also os2026: identical):**
found `~/.clang-format` (curated Chromium). 78-col signature kept, `if (x)
return 1;` kept on one line (`AllowShortIfStatementsOnASingleLine: WithoutElse`,
`~/.clang-format:43`), 4-space body:

```c
int probe_function(int aaaaaaaaaaaaaaaaaaaaaaaaa, int bbbbbbbbbbbbbbbbbbbb) {
    if (x) return 1;
    return 2;
}
```

**P2 — `--assume-filename=/home/ken/config_files/probe.c`:** found the stale
repo dump (WebKit, 76-col at `config_files/.clang-format:37`). Signature
wrapped past the open paren, `if` broken:

```c
int probe_function(int aaaaaaaaaaaaaaaaaaaaaaaaa,
                   int bbbbbbbbbbbbbbbbbbbb) {
    if (x)
        return 1;
    return 2;
}
```

**P3 — `--assume-filename=/home/ken/xv6-riscv/kernel/probe.c`:** the 10-line
kernel file wins (`BreakAfterReturnType: TopLevelDefinitions`, `BraceWrapping:
{AfterFunction: true}`):

```c
int
main(void)
{
  ...
```

**P4 — `--assume-filename=/tmp/probe.c` (no config anywhere):** silent LLVM
fallback — 2-space, 80-col. This is what happens anywhere above the
`~/.clang-format` horizon, or if the file were deleted.

**P5 — the compile-db question, empirically:**

```
clang-format --help | grep -ci compile   → 0
clangd --help | grep -i compile         → --compile-commands-dir=<string>
```

The formatter has no notion of a compilation database; the semantic server is
built around it.

**P6 — `SpaceBeforeAssignmentOperators` IS a valid option** (the comment at
`~/.clang-format:28` claims it was removed):

```
$ printf 'int main(){int a=1;}\n' | clang-format --style='{SpaceBeforeAssignmentOperators: false}' ...
int main() { int a= 1; }          # honored: no space before '='
```

**P7 — clang 22 still parses your 2020-era dump.** The stale repo file is full
of keys that were deprecated or removed from *docs* over the years
(`config_files/.clang-format:15` `AlwaysBreakAfterDefinitionReturnType`,
`:18` `AlwaysBreakTemplateDeclarations`, `:39`
`ConstructorInitializerAllOnOneLineOrOnePerLine`, `:42` `Cpp11BracedListStyle`,
`:78` `SpacesInContainerLiterals`). P2 proves the values are honored (the
76-col wrap *happened*), with zero warnings on stderr. Backward compat in
clang-format config is excellent — but "accepted today" is not "guaranteed
tomorrow", which is the argument for §7-R3.

**Method note (honesty section):** my first read of the two big files
exchanged the home and repo copies — the probes looked "impossibly swapped"
until a labeled one-stream grep (`for f in ...; grep ... "$f"`) showed the
*attribution* was wrong, not clang-format. When file identity matters, one
labeled output stream beats trusting parallel-tool result attribution.

---

## 5. compile_commands.json — what it is, who makes it, who eats it

**What:** the "JSON Compilation Database" (a format *specified by LLVM*, which
is why it is the lingua franca): a JSON array, one entry per translation unit —

```json
{
  "file": "kernel/entry.S",
  "arguments": ["/usr/bin/riscv64-elf-gcc", "-march=rv64gc", "-g", "-c", "-o", "kernel/entry.o", "kernel/entry.S"],
  "directory": "/home/ken/xv6-riscv",
  "output": "kernel/entry.o"
}
```

(Your `xv6-riscv/compile_commands.json` — 52 entries, cross-compiled with
`riscv64-elf-gcc`. Probed: **not** in git, not gitignored, no
`compile_commands` target in the xv6 or abstract-machine Makefiles → a local
artifact you generated with an interceptor/generator tool; the `output` field
is the `compiledb`/`bear` style. It is *not* shipped upstream.)

**Who makes it:**
- **CMake: native** — `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` writes
  `build/compile_commands.json` (people symlink it to the project root).
- **make: needs help** — make has no export format; use `compiledb make`
  (pip) or `bear -- make` (LD_PRELOAD interceptor) once, or hand-write a
  target.

**Who eats it (none of them is clang-format):**
- **clangd** — the engine behind your YCM (`~/.vimrc:759-760`,
  `config_files/.vimrc:270-271`: `/usr/bin/clangd`, `--background-index`,
  `--header-insertion=iwyu`). clangd searches up from each opened file for
  `compile_commands.json`. This is what powers `GoToDefinition`,
  `GoToReferences`, `FixIt`, `RefactorRename` (`RR`, `config_files/.vimrc:205`)
  and diagnostics in xv6 — with the *cross-compiler's* include paths.
- **clang-tidy** — semantic linting; takes the build dir via `-p`.
- **ccls / other libclang tools.**

**Why clang-format deliberately doesn't** (the design reason, not an
oversight): formatting is a purely syntactic transformation — where a brace
goes does not depend on include paths or defines. Requiring a build database
would (a) make the formatter unusable exactly where you need it most —
broken code, missing headers, fresh clones, single files; (b) tie formatting
to build health; (c) slow it down by orders of magnitude. The honest cost of
this choice: clang-format *guesses* on macro-heavy code precisely because it
lacks semantics — that's why config keys like `ForEachMacros`,
`StatementMacros`, `AttributeMacros` exist (your dump has `ForEachMacros` at
`config_files/.clang-format:46`). They are a confession of "we're guessing
without the recipe cards".

---

## 6. Common beginner confusions (the part to keep)

1. **"clang-format uses compile_commands.json."** No — never has. The three
   root-of-repo artifacts belong to three *separate* tools:
   `.clang-format` → clang-format (syntax, no build needed);
   `.clang-tidy` → clang-tidy (semantic lint, needs the compdb);
   `compile_commands.json` → consumed by clangd/clang-tidy/ccls. They sit
   together in the project root and never talk to each other.
2. **`g:c_no_cformat` sounds like "disable clang-format"** — it's a vim
   *syntax* option: don't highlight `%s`-style format specifiers inside C
   strings (`/usr/share/vim/vim92/doc/syntax.txt:1082`). Zero relation to
   clang-format or to `gq`. You set it at `config_files/.vimrc:155`.
3. **"BasedOnStyle pins my style."** No — it references whatever `Chromium`
   means *in the clang-format version you run today*. Presets drift between
   releases; a fully-expanded dump (your old file) is immune to preset drift
   but ages in the other direction (removed keys). Nearest-file-wins means
   per-project overrides (`xv6`, `syscall`) silently change your formatting as
   you `cd` between projects — a feature, but a surprising one.
4. **"--assume-filename is a cosmetic detail."** It is the *only* reason the
   stdin pipeline finds the right config. Without it the walk starts at vim's
   CWD — format a file in one project while vim sits in another and you get
   the wrong stylesheet (or LLVM fallback). Your `~/.vimrc:155-157` comment
   already documents exactly this.
5. **"clang-format needs the code to compile."** No — it parses syntax only;
   it formats broken, header-less, macro-heavy code. Same root cause as #1.
6. **"`...` at the end of my config is a truncation artifact."** It's the
   YAML document-end marker, the bookend of the `---` on line 1. Valid,
   optional, cosmetic.

---

## 7. What I'd change (recommendations, in order)

> **Update 2026-09-01 evening (same day): R1 + R2 applied, and the whole thing
> went one step further — a single combined style** (modern key spellings,
> both clang-22-dead keys dropped, `AlignConsecutiveMacros` borrowed from the
> xv6 file, the `:28` comment corrected) deployed identical to
> `~/.clang-format` and `config_files/.clang-format`. Dump-config diff vs the
> pre-combine home style: exactly one hunk (macro alignment). Pre-combine home
> copy backed up at `~/.clang-format.bak-2026-09-01`. R3 resolved: keep
> `BasedOnStyle`, re-probe after major clang upgrades. R4/R5 not applied.

1. **Refresh the repo twin.** `config_files/.clang-format` is the May-2026
   WebKit dump; `~/.clang-format` is your real, newer style. Anyone (including
   future-you) reading the repo concludes you're a 76-col WebKit person; the
   machine actually formats by 80-col Chromium. Copy `~/.clang-format` over
   the repo copy — same discipline as your `.vimrc` twins.
2. **Fix the wrong comment at `~/.clang-format:28`.**
   `SpaceBeforeAssignmentOperators` is valid (P6). Either restore it as a real
   key (`true` is the effective default you already inherit) or reword the
   comment so it doesn't record a false probe result.
3. **Decide your drift posture.** Keeping `BasedOnStyle: Chromium` means
   re-accepting upstream preset changes every clang upgrade. If you want your
   style frozen, commit a full `clang-format --style=file --dump-config`
   expansion (the strategy your old dump accidentally used); if you want to
   track upstream, keep what you have — but re-run the probe snippets after
   major clang upgrades.
4. **Optional strictness for the S-Tab bridge:** `--fallback-style=none`
   makes clang-format *fail loudly* instead of silently formatting with LLVM
   defaults when no config is found (your `s:FilterFailed` would then surface
   the warning). Trade-off: files opened outside any config tree (e.g.
   `/tmp/x.c`) stop formatting at all.
5. **For make-based course projects:** one `compiledb make` (or `bear -- make`)
   per project gives clangd/YCM real cross-compiler completion — the xv6
   file is the working proof. This is the *only* thing compile_commands.json
   buys you: the semantic half. Formatting needs nothing but the file's path.

---

## 8. Transferable principles

1. Formatting is syntax; understanding is semantics. Tooling that mixes them
   couples your whitespace to your build health — never do that.
2. Config discovery by nearest-ancestor-walk (`git`, `.clang-format`,
   `.ycm_extra_conf.py`, `tags` with `./tags;`) is the unix answer to "one
   tree, many local laws". Know for every tool *where its walk starts*.
3. Checked-in config = project's law; home-dir config = personal default;
   stale copies in version control are worse than none, because they carry
   authority.
4. "Valid in this version" ≠ "guaranteed": re-probe after tool upgrades.
5. When two observations disagree, suspect your bookkeeping before the tool —
   and prefer one labeled, ordered output stream over parallel reports.

---

## 9. Follow-up (same day): the file format itself — YAML — and "fixed vs. regenerated?"

Ken's closing questions, answered by probe (clang 22.1.8; probe configs were
3-line files under `/tmp/yamlprobe/<name>/.clang-format`, dumped with
`printf 'int a;\n' | clang-format --style=file --assume-filename=... --dump-config`).

### 9.1 The format: YAML (JSON also parses)

`.clang-format` content is a **YAML** document ("YAML Ain't Markup Language")
— human-editable `key: value` pairs. clang-format's parser also accepts a
pure-JSON document, because JSON is a valid subset of YAML — **P8c**: a
`.clang-format` holding `{"Language": "Cpp", "BasedOnStyle": "Chromium",
"IndentWidth": 3}` parses cleanly and dumps `IndentWidth: 3`. Nobody writes it
that way, though: JSON has no comments, and a style file you can't annotate
is a style file you can't maintain. The filename itself carries no format
information — it's the clang tool family's dotfile naming convention:
`.clang-format` → clang-format, `.clang-tidy` → clang-tidy, `.clangd` → clangd
(per-project clangd flags); all three are YAML.

### 9.2 How to read the content — tour of the combined config

- `---` (line 1): YAML document-START marker. The old WebKit dump's `...` was
  the matching document-END marker. Cosmetic, conventional, and *not* a
  comment.
- `Language: Cpp` + `BasedOnStyle: Chromium` (:30-31): the two meta keys.
  `BasedOnStyle` loads a preset; every key below OVERLAYS it. Inheritance:
  preset first, your overrides second — only what you set changes.
- Everything else is flat `key: value` grouped under `#` comment banners
  (`# --- Indentation ---`, :33). YAML comments start with `#` — the reason
  YAML (not JSON) won this job.
- Value shapes: integers (`IndentWidth: 4`, :34), enum words (`UseTab: Never`,
  :36), booleans (`AlignTrailingComments: true`, :85), quoted regex
  (`IncludeIsMainRegex: '([-_](test|unittest))?$'`, :101).
- **Scalar shorthand vs. struct form.** Many modern keys are structs
  internally; `--dump-config` prints them nested — probed:
  `AlignTrailingComments: false` dumps as
  `{AlignPPAndNotPP: true, Kind: Never}`, and his `SortIncludes:
  CaseSensitive` (:100) as `{Enabled: true, IgnoreCase: false}`. A one-word
  scalar in the file is shorthand and clang-format expands it. When you want
  to know what the file *really* means, `--dump-config` is the oracle: it
  shows preset + overrides fully resolved.

### 9.3 Probes P8: quoting and boolean words

- **P8a — quoting.** The bare regex `IncludeIsMainRegex:
  ([-_](test|unittest))?$` (no quotes) parses byte-identically to the quoted
  form (dump-diff: none) — parentheses are not YAML indicator characters.
  The quotes in the combined config are belt-and-suspenders; they become
  REQUIRED for values starting with YAML indicators (`*`, `&`, `%`, `[`,
  `{`, ...) or containing `: `. Quote regexes/globs as a habit.
- **P8b — yes/no booleans (the Norway problem, live).** For a plain bool key,
  `AllowShortLoopsOnASingleLine: yes` → dump `true`, and `no` → `false`
  (exit 0 both): clang's YAML accepts YAML-1.1 boolean words. BUT the same
  word on a struct-typed key fails: `AlignTrailingComments: no` →
  `error: not a mapping` (exit 1), while `AlignTrailingComments: false` is
  fine. So `yes`/`no` silently work where harmless and break where
  surprising, with an error message that complains about YAML *structure*,
  not spelling. Rule: spell booleans `true`/`false` only.

### 9.4 Fixed vs. regenerated — opposite in KIND, not just degree

| | `.clang-format` | `compile_commands.json` |
|---|---|---|
| Format | YAML (JSON accepted) | JSON |
| Author | you, a human | the build system (cmake / compiledb / bear) |
| Changes when | you decide to change taste | every build; any file/flag change rewrites it |
| Observed here | ~4 human edits since May 2026 (WebKit dump → June curated Chromium → today's combine) | xv6 copy: 52 entries today, 53 the moment a `.c` file is added |
| In git | yes — that's the point: reviewed policy | no — untracked artifact (xv6's is untracked; upstream doesn't ship it) |
| Read by | clang-format, re-read on EVERY invocation | clangd / YCM / clang-tidy |
| Answers | "how should code LOOK?" | "what command BUILT this file?" |

The unifier: **who holds the pen.** `.clang-format` is a law you write — it
changes at human speed (rare, deliberate, version-controlled).
`compile_commands.json` is a receipt the build prints — it changes at build
speed (constantly, never committed).

Two nuances that keep "relatively fixed" honest:
- **Read often ≠ changes often.** clang-format re-reads and re-parses the
  file on every format, so edits take effect instantly — but the FILE only
  moves when a human moves it.
- **The vocabulary drifts even if the file doesn't.** The keys' meaning lives
  in the clang binary (the two dead keys, §2). A "fixed" file still carries
  one maintenance duty: re-audit with `--dump-config` after major clang
  upgrades (R3).

### 9.5 The other two siblings — and the Makefile boundary (follow-up Q&A)

**Q: does `.clangd` control the compilation like a Makefile? No — the
deletion test proves it.** Delete the Makefile: no binary. Delete `.clangd`:
the binary builds identically; you only lose editor intelligence. The
Makefile *runs* the real build (riscv64-elf-gcc → `.o` files); `.clangd`
patches the *recorded recipe cards* (compile_commands.json) before clangd
replays them in-memory for analysis. Nothing in the `.clang-*` trio can
change how the program builds.

Probe found TWO real `.clangd` files on this machine (correcting this
session's earlier assumption that there were none):

- `~/.clangd` — global overlay, and a YAML showpiece: three documents in one
  file (`---` separators + `If: PathMatch:` conditionals) — global
  `-D_GNU_SOURCE` / `-stdlib=libc++` / module-cache path; then `-std=c++23`
  for .cpp/.cc/.cxx and `-std=c17` for .c.
- `xv6-riscv/.clangd` (106 lines, heavily reasoned) — cross-compile
  adaptation: adds `--target=riscv64-unknown-elf` (clang's spelling of the
  gcc cross build), restores `-std=gnu99` to UNDO the parent `~/.clangd`'s
  c17 (see layering probe below — a MERGE, not a per-key win), appends `-Wno-error`
  (analysis ≠ build), removes gcc-only `-mcmodel=medany`/`-no-pie`/`-nopie`;
  embeds clang-tidy checks under `Diagnostics.ClangTidy` with per-check
  suppression rationales. Its own comment is the boundary statement: *"The
  real gcc build is untouched (it still sees -Werror from the Makefile)."*

**Q: how exactly do the config layers stack? (probe-verified 2026-09-02,
`clangd --check=kernel/proc.c --log=verbose`, clangd 22.1.8)** clangd loads
THREE config layers, in this order: user config `~/.config/clangd/config.yaml`
(the canonical user path — exists here with one key, `UnusedIncludes: None`),
then `~/.clangd` (a legacy/fallback user path — clangd 22 also reads it; 3
fragments), then `xv6-riscv/.clangd`. Closer-to-the-file wins — but only for
SCALAR keys (xv6's `Diagnostics.UnusedIncludes: Strict` beats the user layer's
`None` inside xv6; everywhere else stays `None`). LIST keys MERGE across
layers instead of replacing: the traced final compile command contains BOTH
`-std=c17` (parent) and `-std=gnu99` (project) — the gnu99 "undo" is the
compiler's last-`-std`-wins flag order, not config selection. `Remove:` also
strips across layers (`-stdlib=libc++`, injected by `~/.clangd`, is absent
from xv6's final command). Contrast for `.clang-tidy`: the CLI uses only the
NEAREST `.clang-tidy` file — no cascade at all unless that nearest file says
`InheritParentConfig: true`.

**Q: is the combined `.clang-format` okay? Yes** — re-verified after the
combine: `--dump-config` exit 0, stderr 0 bytes, twins identical. Standing
duty remains R3 (re-dump after major clang upgrades).

**Q: `.clang-tidy`'s role?** Config for clang-tidy, the *semantic* linter —
the meaning-reader to clang-format's typography-fixer. Needs build info
(`-p` compdb dir, or `--` inline flags); check families: `bugprone-*`,
`clang-analyzer-*` (the static analyzer), `cppcoreguidelines-*`,
`modernize-*` (C++), `performance-*`, `readability-*`; supports `--fix` with
fix-its — which, unlike anything clang-format does, can change program
behavior.

Probed findings, clang-tidy 22.1.8:

- **No default check set**: `clang-tidy --list-checks` without `--checks`
  prints "No checks enabled." — and a run with zero checks is a hard error
  ("Error: no checks enabled"). Checks must come from `--checks=` or a
  `.clang-tidy` file; persistently answering "which checks?" is that file's
  whole job.
- **Demo, one file** (`int main(void){int x; return x == 0;}`): clang-format
  beautifies it and says NOTHING (formatting is syntax-blind); clang-tidy
  `--checks='clang-analyzer-*,clang-diagnostic-uninitialized'` +
  `-- -x c -Wall` → `warning: variable 'x' is uninitialized when used here`
  plus a fix-it (`= 0`).
- **Catch-all `--checks='*'`** adds the style-nagger families:
  `readability-identifier-length` fired on the 1-char `x` — exactly what
  `xv6-riscv/.clangd`'s own comment predicted ("readability-* as a glob …
  pulls in ~80 identifier-length warnings per file").

No `.clang-tidy` file exists here — the check selection lives in
`xv6-riscv/.clangd`'s `Diagnostics.ClangTidy` instead (that drives
clangd-EMBEDDED tidy diagnostics in the editor; a standalone `.clang-tidy`
matters when running the clang-tidy CLI, which does NOT read `.clangd` —
so xv6's gcc-only flags would need `--extra-arg` handling there).

Kitchen cast, final: Makefile = the chef who runs the kitchen;
compile_commands.json = the recorded recipe cards; clang-format = copy
editor (typography); clang-tidy = line editor (meaning, autocorrect);
clangd + `.clangd` = inspector + briefing sheet. Update-frequency tie-in
(§9.4): the Makefile and the three `.clang-*` laws are all human-authored;
only compile_commands.json is a machine-regenerated receipt.

## 10. Where to go next

- `clang-format --help` / the docs: <https://clang.llvm.org/docs/ClangFormat.html>
- Interactive option playground: <https://clangformat.com> (edit a config,
  watch live output)
- `git-clang-format` — format only *changed* lines; the standard way to adopt
  a style on a legacy codebase without a giant churn commit
- `:h formatprg` / `:h 'equalprg` — vim's native `gq`/`=` bridge, the
  mechanism your S-Tab replaces with something stronger (winsaveview,
  range handling, guards)
- `.editorconfig` — the cross-editor, cross-language cousin (indentation
  only); pairs well with clang-format, and is the right home for rules on
  files clang-format can't parse (your syscall file's header comment already
  says this for `.S`/`.s`)