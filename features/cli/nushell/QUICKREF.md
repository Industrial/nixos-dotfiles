# Nushell Quick Reference

A side-by-side comparison for Fish users.

## Launching Nushell

```bash
# From Fish
nu              # Launch Nushell
exec nu         # Replace Fish session with Nushell
exit            # Return to Fish (or Ctrl-D)
```

## Common Commands (Same as Fish)

```nushell
l               # Detailed file listing (eza)
ll              # Alternative listing
g status        # Git status
c ~/projects    # cd + list
cl              # Clear + list
p               # Go to projects directory
```

## Nushell-Specific Superpowers

### JSON/YAML/TOML Parsing
```nushell
open package.json | get version
open config.yaml | get database.host
http get https://api.github.com/users/octocat | get name
```

### Table Operations
```nushell
ls | where size > 1MB                    # Filter by size
ls | sort-by modified | reverse          # Sort newest first
ls | where type == file | length         # Count files
ls | group-by type | transpose key count # Group and count
```

### CSV/Data Processing
```nushell
open data.csv | where status == "active"
open data.csv | select name email | to json
open log.txt | lines | where $it =~ "ERROR"
```

### Working with Structured Data
```nushell
ls | select name size | first 10              # Select columns
ps | where cpu > 50 | sort-by cpu             # Process table
sys | get host.hostname                        # System info
$env | transpose key value | where key =~ PATH # Environment vars
```

## Keybindings (Same as Fish)

| Key | Action |
|-----|--------|
| `Ctrl-R` | FZF history search |
| `Ctrl-T` | FZF file search |
| `Alt-C` | FZF directory navigation |
| `Ctrl-P` | Previous history |
| `Ctrl-N` | Next history |
| `Ctrl-D` | Exit Nushell |

## Vi Mode

```nushell
# Vi mode is enabled by default (like Fish)
# Press ESC to enter normal mode
# h/j/k/l for movement
# i/a for insert mode

# Note: Vi mode in Nushell is less complete than Fish
```

## Data Types

```nushell
42                  # int
3.14                # float
"hello"             # string
true                # bool
[1 2 3]            # list
{name: "Tom"}      # record
2023-01-15         # date
10MB               # filesize
```

## Useful Commands

### Inspection
```nushell
help commands           # List all commands
help <command>          # Command help
describe                # Show type of value
keybindings list -e     # Show keybindings
$env | table -e         # Show environment
```

### Navigation
```nushell
cd ~/projects           # Change directory
cd -                    # Previous directory
dirs                    # Directory stack
```

### Data Transformation
```nushell
ls | to json            # Convert to JSON
ls | to csv             # Convert to CSV
open file.json | to yaml # Convert formats
```

### Filtering & Selection
```nushell
where <condition>       # Filter rows
select col1 col2        # Select columns
first 10                # First N items
last 5                  # Last N items
skip 2                  # Skip N items
```

### Aggregation
```nushell
length                  # Count items
sum                     # Sum values
average                 # Average
max                     # Maximum
min                     # Minimum
group-by <column>       # Group rows
```

## Common Patterns

### Find large files
```nushell
ls **/* | where size > 100MB | sort-by size | reverse
```

### Git status with size
```nushell
ls | select name size modified | where modified > 2024-01-01
```

### Process monitoring
```nushell
ps | where cpu > 10 | sort-by cpu | reverse | first 10
```

### Parse JSON API
```nushell
http get https://api.github.com/repos/nushell/nushell
| select name stargazers_count open_issues
```

### Count file types
```nushell
ls | group-by type | transpose type count | sort-by count
```

## Differences from Fish

### Text vs Structured Data
```bash
# Fish (text-based)
ls -la | grep pdf | wc -l

# Nushell (structured)
ls | where name =~ pdf | length
```

### Pipes Preserve Structure
```nushell
# Each command knows the data structure
ls | where size > 1MB | sort-by modified | select name size
```

### Native Format Support
```nushell
# No need for jq, yq, etc.
open config.json | get database.host
open data.yaml | get services | where enabled
```

## When Nushell Shines

✅ Working with JSON/YAML/CSV/TOML  
✅ Data exploration and analysis  
✅ API responses and structured logs  
✅ Complex filtering and transformations  
✅ Type-safe scripting  

## When to Use Fish Instead

✅ Daily interactive shell work  
✅ Complex vi mode editing  
✅ Relying on extensive completions  
✅ Traditional Unix text processing  
✅ Stable, production scripts  

## Getting Help

```nushell
help commands           # List all commands
help <command>          # Specific command help
help --find <keyword>   # Search help
$nu.config-path        # Show config file location
$nu.env-path           # Show env file location
```

## Resources

- Official Book: https://www.nushell.sh/book/
- Cookbook: https://www.nushell.sh/cookbook/
- Community Scripts: https://github.com/nushell/nu_scripts
- Discord: https://discord.gg/NtAbbGn
