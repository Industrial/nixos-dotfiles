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

- `default.nix` - NixOS module (installs Nushell package)
- `env.nu` - Environment variables (equivalent to Fish env setup)
- `config.nu` - Main configuration (equivalent to Fish config.fish)

These files should be symlinked to `~/.config/nushell/` for Nushell to use them.

## Features Implemented

### ✅ Parity with Fish
- Vi mode (limited compared to Fish)
- Starship prompt integration
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

After rebuilding NixOS with the Nushell feature enabled:

```bash
# Symlink config files (one-time setup)
ln -sf ~/.dotfiles/features/cli/nushell/env.nu ~/.config/nushell/env.nu
ln -sf ~/.dotfiles/features/cli/nushell/config.nu ~/.config/nushell/config.nu

# Launch Nushell
nu
```

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
