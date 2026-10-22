# config_files

[![test](https://github.com/gaoyuankan-dot/config_files/actions/workflows/ci.yml/badge.svg)](https://github.com/gaoyuankan-dot/config_files/actions/workflows/ci.yml)

My Unix dotfiles, one repo for two machines: **Arch Linux** (KDE Plasma,
Konsole) and **Ubuntu 26.04 on WSL2** (Windows Terminal). Every change is
tested on both distros, locally and in CI.

- **Vim 9 as a C IDE**: one concise vimrc with clangd through
  [yegappan/lsp](https://github.com/yegappan/lsp). Errors appear as you type
  (~0.1 s), plus completion, go-to-definition, rename. No Python, Node or
  compile step.
- **zsh and bash** that share one set of aliases and functions, start in
  ~55 ms (31 ms with the WSL PATH tip), and behave safely when a script or
  an AI agent drives them.
- **clang tools**: a Chromium-based `.clang-format` (same effective settings
  on clang-format 21 and 23), a global clangd config with measured clang-tidy
  checks, per-project templates.
- **git, tmux, gdb, starship, readline** configs, each validated by the
  program that reads it.

## Quick start on a new machine

```sh
git clone https://github.com/gaoyuankan-dot/config_files.git ~/config_files
cd ~/config_files
scripts/bootstrap.sh      # install the programs (asks for sudo; apt or pacman)
./install.sh --dry-run    # show what would change; changes nothing
./install.sh              # link the files; anything in the way is backed up
exec zsh                  # or open a new terminal
vim                       # the first start installs the vim plugins (~1 min)
```

`make` lists the same steps as shortcuts (`make install`, `make test`, ...).

## How it works

`home/` mirrors your home directory. `install.sh` makes each `~/<path>` a
**symlink** to `home/<path>`, so editing `~/.zshrc` edits the repo, and
`git pull` updates the machine. Nothing is ever deleted: a file in the way is
moved to `~/.local/state/dotfiles/backup/<time>/`. Re-running is safe.
`./install.sh --uninstall` removes only the links.

| In `home/` | What it configures |
|---|---|
| `.profile`, `.bash_profile`, `.zprofile`, `.zshenv` | login environment: PATH, EDITOR, LESS, COLORTERM |
| `.zshrc`, `.bashrc`, `.config/shell/common.sh` | interactive shells; `common.sh` is shared by both |
| `.inputrc` | readline keys for bash, gdb, python |
| `.vimrc`, `.vim/ftdetect/` | Vim: LSP, fzf, git, formatter bridge, clipboard |
| `.clang-format`, `.config/clangd/config.yaml` | C/C++ formatting style; clangd + clang-tidy settings |
| `.config/git/{config,ignore}` | git defaults (identity stays in `~/.gitconfig`) |
| `.config/tmux/tmux.conf`, `.config/gdb/gdbinit`, `.config/starship.toml` | tmux, gdb, prompt |

Machine-only settings go in `*.local` files that are never committed:
`~/.profile.local`, `~/.zshrc.local`, `~/.bashrc.local`,
`~/.config/git/config.local`.

### Tips

1. zsh on Arch reads `/etc/profile` by itself, but zsh on Ubuntu does not, so
   `~/.zprofile` sources it. That is how `/etc/profile.d/*.sh` (the WSL proxy,
   for one) reaches zsh on Ubuntu.
2. gdb reads only the FIRST of `~/.config/gdb/gdbinit` and `~/.gdbinit`. The
   repo installs the first, so delete an old `~/.gdbinit` (its settings are
   merged into the repo file).

## C projects and the language server

clangd must see your real compiler flags. For a Makefile project:

```sh
bear -- make -B                     # writes compile_commands.json (-B: rebuild all)
```

For the NJU OS labs, put the database at the os-workbench root and add the
`.clangd` template (it fixes two clang-vs-gcc false errors):

```sh
cp ~/config_files/templates/abstract-machine/.clangd ~/os-workbench/
cd ~/os-workbench/amgame && bear --output ../compile_commands.json -- make -B ARCH=x86_64-qemu
```

See [templates/README.md](templates/README.md) for the why, and for folders
of single-file programs (`compile_flags.txt`).

Vim keys: `<Leader>jd` definition, `<Leader>jr` references, `[d` / `]d`
previous/next error, `<Leader>K` hover, `<Leader>ji` code action (fix),
`:RR newname` rename, `F4` error list, `F5` build, `Shift-Tab` format,
`<Leader>y` / `<Leader>p` system clipboard (WSL included).

## Testing

```sh
scripts/test.sh              # offline: syntax, lint, install, shells, vim, every config (~10 s)
scripts/test.sh --full       # + install vim plugins and check clangd errors inside vim
scripts/arch-sandbox.sh setup && scripts/arch-sandbox.sh test --full   # same tests on Arch, rootless
```

Everything runs in a throwaway HOME, so your real files are never touched.
CI runs `scripts/test.sh --full` in Ubuntu 26.04 and Arch containers on every
push and weekly.

## Learn more

[docs/GUIDE.md](docs/GUIDE.md) explains every decision from first principles:
what was wrong with the old setup and how each problem was found, how LSP
works, shell startup files, the clang tools, the testing strategy, and the
git workflow used to publish this.
