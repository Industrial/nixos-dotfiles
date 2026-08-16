# Nushell Configuration

This Nushell setup mirrors the Fish shell configuration for easy comparison and testing.

## Quick Start

```bash
# From Fish, launch Nushell
nu

# Try some commands
l                           # List files (same as Fish)
g status                    # Git status (same as Fish)
c ~/projects                # Change directory and list
open data.json | get field  # Parse JSON natively
ls | where size > 1MB       # Filter with structured data
```

## Configuration Files

- `default.nix` — NixOS module (package + activation symlinks)
- `env.nu` — session vars (XDG/PATH/direnv) + `source starship.nu`
- `starship.nu` — official `starship init nu` (PROMPT_* via export-env)
- `login.nu` — bash login env import (NixOS/profile vars Nu does not get for free)
- `havamal.nu` — Hávamál random stanza (`havamal` command + startup print)
- `config.nu` — interactive config (aliases, keybinds, vi indicators, Hávamál)

Linked into `~/.config/nushell/` on activate / `bin/update/system`.

## Features Implemented

### ✅ Parity with Fish
- Vi mode (limited compared to Fish)
- Starship prompt integration
- Hávamál random stanza on startup (`havamal` to reprint)
- Direnv hooks
- Custom commands: `l`, `ll`, `g`, `c`, `cl`, `p`
- FZF keybindings: Ctrl-R, Ctrl-T, Alt-C
- Custom keybindings: Ctrl-P/Ctrl-N for history
- XDG environment variables
- PATH modifications

### 🚀 Nushell-Specific Advantages
- Structured data pipelines
- Native format parsing (JSON, YAML, TOML, CSV, XML)
- Type-safe operations
- Table operations: `where`, `select`, `sort-by`, `group-by`

## Installation

Config is linked automatically:

- **On every `nixos-rebuild switch`** via `system.activationScripts.linkNushellConfig`
- **After `bin/update/system`** via `features/cli/nushell/bin/link-files-nixos`

Manual (same as the update helper):

```bash
cd ~/.dotfiles && features/cli/nushell/bin/link-files-nixos
nu
```

First-run Nushell may create stock `~/.config/nushell/*.nu`; activation/`link-files-nixos` backs those up and replaces them with symlinks into this feature.

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
| History search | Ctrl-R (fzf) | Ctrl-R (fzf) |
| Vi mode | `fish_vi_key_bindings` | `$env.config.edit_mode = "vi"` |

## Known Limitations

⚠️ **Compared to Fish:**
- Vi mode is less complete (Reedline limitation)
- Fewer auto-completions available
- FZF requires manual keybinding setup (no native integration)
- Pre-1.0 means occasional breaking changes

## Tips for Fish Users

1. **Think in structured data**: Instead of piping text, you're piping typed data (tables, records, lists)
2. **Explore with `describe`**: Use `ls | describe` to see data types
3. **Check help**: `help commands` or `help <command-name>`
4. **View keybindings**: `keybindings list -e`
5. **Return to Fish**: Just type `exit` or Ctrl-D

## When to Use Nushell vs Fish

**Use Nushell for:**
- Working with JSON, YAML, CSV, APIs
- Data exploration and analysis
- Scripts that manipulate structured data
- Learning functional programming paradigms

**Use Fish for:**
- Daily interactive shell work
- When you need mature vi mode
- When completions are critical
- Traditional Unix text processing
- Stable, no-surprises environment

## Future Migration Path

After Nushell 1.0 is released (TBD 2026-2027), evaluate:
- Vi mode improvements
- Completion system maturity
- FZF integration status
- API stability

Then decide if full migration makes sense.
