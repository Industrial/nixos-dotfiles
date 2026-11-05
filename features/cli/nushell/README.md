# Nushell Configuration

This Nushell setup mirrors the Fish shell configuration for easy comparison and testing.

## Quick Start

Nushell is the default login shell. Fish remains available (`fish`) for fallback.

```bash
# Try some commands
l                           # List files (same as Fish)
g status                    # Git status (same as Fish)
c ~/.dotfiles               # Change directory and list (exact path)
cd dotfiles                 # Frecency jump (zoxide owns bare `cd`)
open data.json | get field  # Parse JSON natively
ls | where size > 1MB       # Filter with structured data
```

## Load order

Measured, not assumed:

```
env.nu → config.nu → $nu.data-dir/vendor/autoload/00-nixos-env.nu
                  → 10-starship.nu → 20-zoxide.nu → 30-carapace.nu → 40-atuin.nu
```

Two things follow from it:

1. **The autoload files run _after_ `config.nu`**, so whatever they set wins. The prompt
   (starship), the `cd` alias (zoxide), the external completer (carapace) and the Ctrl-R
   history search (atuin) belong to them; `config.nu` deliberately sets none of those.
2. **They run only on the REPL path.** `nu -c '…'` and `nu script.nu` never source them —
   and as of Nushell 0.116 those two do not source `env.nu` or `config.nu` either
   (`nu -c '$env.config.edit_mode'` answers `emacs`, not the `vi` this feature sets).

## Configuration Files

Hand-written, linked into `~/.config/nushell/` by activation:

- `default.nix` — NixOS module (package + login shell + the activation symlinks)
- `env.nu` — session vars (editors/XDG/PATH), rootless-docker socket, direnv hook
- `config.nu` — interactive config: commands, keybindings, completions, zellij sessions,
  Hávamál
- `havamal.nu` — the `havamal` command (stanzas are linked in from the Fish plugin)
- `default.assay.nix` — the colocated suite

Generated, never committed — see `features/cli/shell-init`:

- `00-nixos-env.nu` — `environment.sessionVariables` as Nu assignments
- `10-starship.nu`, `20-zoxide.nu`, `30-carapace.nu`, `40-atuin.nu` — each tool's own
  `init` output, produced at build time from the store path the host installs

`starship.nu`, `login.nu` and `bin/link-files-nixos` are **gone**. The first two were
committed copies of generated output (and a `bash --login` round-trip on every shell
start); the third was a second, divergent writer of the same symlinks.

## Features Implemented

### ✅ Parity with Fish

- Vi mode (limited compared to Fish)
- Starship prompt — generated, not committed (`10-starship.nu`)
- Hávamál random stanza on interactive start (`havamal` to reprint)
- Direnv hooks (`env.nu`)
- Custom commands: `l`, `ll`, `g`, `c`, `cl`, `p`, `df`
- XDG environment variables and PATH modifications
- Fuzzy completions with smart sorting, carapace as the external completer

### Keybindings

| Key | Does | Owned by |
|-----|------|----------|
| Tab | IDE completion menu (bordered, with descriptions) | `config.nu` |
| Ctrl-Space | the same menu, Nushell's own binding | Nushell default |
| Ctrl-F / Alt-F | accept the history hint, whole / by word | `config.nu` |
| Ctrl-T | insert a file path (fd → fzf, depth-bounded) | `config.nu` |
| Alt-C | jump to a directory (fd → fzf, depth-bounded) | `config.nu` |
| Alt-S | **sessionizer** — project → zellij session | `config.nu` |
| Ctrl-P / Ctrl-N | previous / next history line | `config.nu` |
| Ctrl-R, ↑ | history search / history up | atuin (`40-atuin.nu`) |

`FZF_DEFAULT_OPTS` in `features/cli/fzf` supplies the height, layout, border and preview
for all of the fzf bindings; none of them restate those flags.

### Sessions

- **`sessionize`** (Alt-S) offers `zoxide query -l` plus a depth-2 `fd` scan of `~/Code`,
  `~/projects` and `/data/Code`, and attaches `zellij attach --create <basename>`. Run
  from inside a session it opens a new tab instead, because `zellij attach` will not nest.
- **Auto-attach**: an interactive shell on a terminal attaches the `main` session. The
  guard is `zellij-should-attach`, and it refuses when the shell is non-interactive,
  already in a zellij pane or tmux, not on a tty and not over SSH, an agent or
  editor-embedded shell (`CLAUDECODE`, `CURSOR_TRACE_ID`, `NVIM`, `INSIDE_EMACS`,
  `TERM_PROGRAM=vscode|cursor`), on a dumb terminal, or when zellij is not installed.
  A failed attach falls through to the REPL rather than leaving a terminal with no shell.

### Env guards

| Variable | Effect |
|----------|--------|
| `HAVAMAL=0` | no stanza on start (also skipped inside a zellij pane) |
| `ZELLIJ_AUTO_ATTACH=0` | no auto-attach — what a startup benchmark wants |

To check the auto-attach guard without attaching anything:

```bash
nu --config ~/.config/nushell/config.nu -c 'zellij-should-attach true {|| true}'
```

### 🚀 Nushell-Specific Advantages

- Structured data pipelines
- Native format parsing (JSON, YAML, TOML, CSV, XML)
- Type-safe operations
- Table operations: `where`, `select`, `sort-by`, `group-by`

## Installation

Nothing to run by hand. `nixos-rebuild switch` (or `bin/update/system`, which calls it)
does both halves:

- `system.activationScripts.linkNushellConfig` in this feature's `default.nix` symlinks
  `env.nu`, `config.nu` and `havamal.nu` into `~/.config/nushell/`, and links the Hávamál
  stanzas next to them
- `system.activationScripts.nushellVendorAutoload` in `features/cli/shell-init` points
  `~/.local/share/nushell/vendor/autoload` at the generated store directory

The symlinks mean an edit to `config.nu` in this checkout is live in the next shell, with
no rebuild. The generated autoload files are not editable that way, by design: change the
generator, not its output.

First-run Nushell may create stock `~/.config/nushell/*.nu`; activation moves those aside
as `*.backup` and replaces them with the symlinks.

There is no `bin/link-files-nixos` and no `setup.sh` any more — activation is the single
writer, and the suite asserts both are absent.

## Usage Patterns

### Data Processing Examples

```nushell
# Parse JSON from API
http get https://api.github.com/repos/nushell/nushell | get stargazers_count

# Filter and sort files
ls | where size > 1MB | sort-by modified | reverse

# Work with CSV
open data.csv | where status == "active" | select name email | to json

# Parse logs
open /var/log/syslog | lines | where $it =~ "ERROR" | length

# Group and count
ls | group-by type | transpose key count | sort-by count
```

### Fish vs Nushell Equivalents

| Task | Fish | Nushell |
|------|------|---------|
| List files | `l` | `l` (same) |
| Git status | `g status` | `g status` (same) |
| Parse JSON | `cat file.json \| jq '.field'` | `open file.json \| get field` |
| Filter by size | `ls -lh \| grep ...` | `ls \| where size > 1MB` |
| History search | Ctrl-R (fzf) | Ctrl-R (atuin, via `40-atuin.nu`) |
| Vi mode | `fish_vi_key_bindings` | `$env.config.edit_mode = "vi"` |

## Known Limitations

⚠️ **Compared to Fish:**

- Vi mode is less complete (Reedline limitation)
- Pre-1.0 means occasional breaking changes
- `c` and `p` take exact paths through the builtin `cd`. Only a bare `cd` is zoxide's
  frecency jump: Nushell resolves aliases at parse time and `20-zoxide.nu` is parsed
  after `config.nu`, so a command body written here can only see the builtin.
- `fd`-backed pickers are depth-bounded and prune the big caches (`.cache`, `.cargo`,
  `.npm`, `.bun`, `.rustup`, `node_modules`, …), so a file more than 6 levels deep or
  inside one of those will not show up in Ctrl-T / Alt-C

## Tips for Fish Users

1. **Think in structured data**: Instead of piping text, you're piping typed data (tables, records, lists)
2. **Explore with `describe`**: Use `ls | describe` to see data types
3. **Check help**: `help commands` or `help <command-name>`
4. **View keybindings**: `keybindings list -e`
5. **Return to Fish**: type `fish`. `exit` ends the shell, which closes the terminal — or detaches the zellij session hosting it.

## When to Use Nushell vs Fish

**Use Nushell (default login shell) for:**
- Daily interactive shell work
- Working with JSON, YAML, CSV, APIs
- Data exploration and analysis
- Scripts that manipulate structured data

**Use Fish for:**
- Mature vi mode / richer completions
- Traditional Unix text processing
- Stable fallback when Nushell behavior surprises you

## Fallback

Type `fish` (or set the user shell back temporarily) if you need the previous default.
