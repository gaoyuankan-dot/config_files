# Per-project templates

`install.sh` never touches these: they belong INSIDE a project, so copy one
when a project needs it. clangd searches the source file's directory and every
parent for its inputs, so put them at the project root.

| File | Copy to | What it fixes |
|---|---|---|
| `abstract-machine/.clangd` | `~/os-workbench/` | clang-vs-gcc false errors in the NJU labs (`main(const char *)`, `-Werror`) |
| `cpp-practice/compile_flags.txt` | `~/algo/` (any folder of single-file programs) | clangd can't find `common/*.hpp` and guesses the wrong `-std` |
| `.clang-tidy` | any project root | same clang-tidy checks on the command line / in CI as in the editor |

## How clangd learns your flags (the part that matters)

clangd must compile your file in its head exactly like your build does, or it
reports errors that don't exist. It looks for, in each directory from the
file's own upward:

1. `compile_commands.json`: one exact command per file. Generate it from a
   Makefile with **bear**: `bear -- make -B` (`-B` rebuilds everything, so
   every file appears, including sub-makes). For the NJU labs write it to the
   os-workbench root, so files in `amgame/` AND `abstract-machine/` find it:
   `bear --output ../compile_commands.json -- make -B ARCH=x86_64-qemu`.
2. `compile_flags.txt`: the same flags for every file, one per line. Enough for
   a folder of standalone programs. No comments allowed in it, which is why the
   notes live here:
   - the flags mirror `~/algo/Makefile` (`-std=c++17` and its warnings, `-I.`);
   - `-Wno-sign-conversion`: in **clang**, `-Wconversion` also turns on
     sign-conversion warnings; in **g++** it does not (for C++). Without this
     line the editor showed 103 warnings that `make` never prints.
3. Neither: clangd guesses (no include paths, default standard). Measured on
   `~/algo`: 157 and 461 bogus errors in two files, 0 with the file above.

Check what clangd decided for one file (compile command, errors):
`clangd --check=path/to/file.c`. For warnings and clang-tidy findings too:
`~/config_files/scripts/lsp-probe.py path/to/file.c`.
