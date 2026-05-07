# Nushell Config File
# Equivalent to Fish's config.fish

# ============================================================================
# Core Configuration
# ============================================================================

# Vi mode (Note: less mature than Fish's vi mode)
$env.config.edit_mode = "vi"

# Remove default greeting (like Fish's empty fish_greeting)
$env.config.show_banner = false

# ============================================================================
# Custom Commands (equivalent to Fish aliases/functions)
# ============================================================================

# l - detailed eza listing (matches Fish version)
def l [...args] {
    eza --colour=always --icons --long --group --header
        --time-style long-iso --git --classify
        --group-directories-first --sort Extension --all
        ...$args
}

# ll - alternative eza listing
def ll [...args] {
    eza --colour=always --icons --long --group --header
        --time-style long-iso --git --classify
        --group-directories-first --sort Name --all
        ...$args
}

# g - git shorthand
alias g = git

# c - cd and list (matches Fish version)
def c [path: string] {
    cd $path
    l
}

# cl - clear and list (matches Fish version)
def cl [] {
    clear
    l
}

# p - go to projects directory
def p [] {
    cd ~/projects
    l
}

# ============================================================================
# FZF Integration (manual keybindings - no native support)
# ============================================================================

# Note: FZF integration requires manual setup in Nushell
# These keybindings provide equivalent functionality to Fish's fzf integration

$env.config.keybindings = [
    # Ctrl-R: FZF history search (matches Fish)
    {
        name: fzf_history
        modifier: control
        keycode: char_r
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: ExecuteHostCommand
            cmd: "commandline edit --replace (history | get command | reverse | uniq | str join (char newline) | fzf --height 40% --reverse --query (commandline))"
        }
    }

    # Ctrl-T: FZF file search (matches Fish)
    {
        name: fzf_file
        modifier: control
        keycode: char_t
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: ExecuteHostCommand
            cmd: "commandline edit --insert (fd --type f --hidden --exclude .git | fzf --height 40% --reverse)"
        }
    }

    # Alt-C: FZF directory navigation (matches Fish)
    {
        name: fzf_cd
        modifier: alt
        keycode: char_c
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: ExecuteHostCommand
            cmd: "let selected = (fd --type d --hidden --exclude .git | fzf --height 40% --reverse); if ($selected | is-not-empty) { cd $selected }"
        }
    }

    # Ctrl-P: Previous history (matches Fish custom binding)
    {
        name: history_previous
        modifier: control
        keycode: char_p
        mode: [emacs, vi_insert]
        event: { send: up }
    }

    # Ctrl-N: Next history (matches Fish custom binding)
    {
        name: history_next
        modifier: control
        keycode: char_n
        mode: [emacs, vi_insert]
        event: { send: down }
    }
]

# ============================================================================
# Starship Prompt Integration
# ============================================================================

# Initialize Starship prompt
# This uses the same starship.toml as Fish for consistency
mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save --force ($nu.data-dir | path join "vendor/autoload/starship.nu")

# Source Starship
source ($nu.data-dir | path join "vendor/autoload/starship.nu")

# ============================================================================
# Completions & Suggestions
# ============================================================================

# Enable completions
$env.config.completions = {
    case_sensitive: false
    quick: true
    partial: true
    algorithm: "prefix"
}

# ============================================================================
# Color & Display Configuration
# ============================================================================

# Use colors (similar to Fish theme)
$env.config.color_config = {
    shape_string: green
    shape_flag: blue
    shape_int: purple
    shape_float: purple
    shape_range: yellow
    shape_internalcall: cyan
    shape_external: cyan
    shape_externalarg: green
    shape_literal: blue
    shape_operator: yellow
    shape_signature: green_bold
    shape_garbage: { fg: white bg: red attr: b}
}

# ============================================================================
# Additional Configuration
# ============================================================================

# Table display settings
$env.config.table = {
    mode: rounded
    index_mode: auto
    show_empty: true
}

# History configuration
$env.config.history = {
    max_size: 100000
    sync_on_enter: true
    file_format: "sqlite"
}

# File size format (human-readable)
$env.config.filesize = {
    metric: false
    format: "auto"
}

# ============================================================================
# Notes for Fish Users
# ============================================================================

# Differences from Fish:
# - Vi mode is less complete than Fish (Reedline limitation)
# - FZF requires manual keybindings (no native --fish integration)
# - Completions are less extensive (community is working on this)
# - Data is structured (lists, tables) instead of text streams
# - Use 'help commands' to see all available commands
# - Use 'keybindings list -e' to see all keybindings
#
# Advantages over Fish:
# - Native JSON/YAML/TOML/CSV parsing: open data.json | get field
# - Table operations: ls | where size > 1MB | sort-by modified
# - Type system: better error messages and data validation
# - Structured pipelines: data preserves structure through pipes
#
# To return to Fish: type 'exit' or Ctrl-D
