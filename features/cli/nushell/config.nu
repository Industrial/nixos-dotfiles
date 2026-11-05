# Nushell Config File
# Interactive configuration: commands, keybindings, completion, session behaviour.
#
# Load order (measured, not assumed):
#
#   env.nu → config.nu → $nu.data-dir/vendor/autoload/00-nixos-env.nu
#                     → .../10-starship.nu → .../20-zoxide.nu
#                     → .../30-carapace.nu → .../40-atuin.nu
#
# The autoload files come from features/cli/shell-init, which generates them at build time
# from the installed binaries. They run AFTER this file, and only on the REPL path: `nu -c`
# and `nu script.nu` never see them. Two rules follow:
#
#   * what the generated files set wins over this file. The prompt (starship), the `cd`
#     alias (zoxide), the external completer (carapace) and the Ctrl-R history search
#     (atuin) are theirs. Setting any of them here is dead weight at best.
#   * nothing in here reaches a non-interactive shell at all: as of Nushell 0.116 neither
#     env.nu nor config.nu is loaded for `nu -c` or `nu script.nu` (`nu -c
#     '$env.config.edit_mode'` answers `emacs`, not the `vi` set below). The
#     `$nu.is-interactive` guards further down are therefore defence in depth, for
#     `nu -i`, an explicit `--config`, and the next version that changes its mind.

# ============================================================================
# Core Configuration
# ============================================================================

# Vi mode and banner settings. No vi-mode prompt indicators are assigned here: starship's
# `character` module owns the vi-mode glyph, and 10-starship.nu installs its own prompt
# closures after this file, so anything set here would be overwritten.
$env.config = ($env.config | merge {
    edit_mode: vi
    show_banner: false
})

# Hávamál — random stanza on interactive start (Fish sources the plugin instead).
# ~3 ms. Skipped for `nu -c`, skipped inside a zellij pane (a multi-pane layout would
# otherwise print one stanza per pane) and skipped entirely when HAVAMAL=0.
source havamal.nu
if $nu.is-interactive and ($env.ZELLIJ? == null) and (($env.HAVAMAL? | default "1") != "0") {
    havamal | print
}

# ============================================================================
# Custom Commands (equivalent to Fish aliases/functions)
# ============================================================================

# l - detailed eza listing (matches Fish version)
def l [...args] {
    eza --colour=always --icons --long --group --header --time-style=long-iso --git --classify --group-directories-first --sort=Extension --all ...$args
}

# ll - alternative eza listing
def ll [...args] {
    eza --colour=always --icons --long --group --header --time-style=long-iso --git --classify --group-directories-first --sort=Name --all ...$args
}

# g - git shorthand
alias g = git

# df / df -h → sys disks; other flags still hit GNU df (^df)
def --wrapped df [...rest] {
    let only_human = ($rest | all {|a| $a in ["-h", "--human-readable"]})
    if ($rest | is-empty) or $only_human {
        sys disks
    } else {
        ^df ...$rest
    }
}

# c - cd and list (matches Fish version). `--env` because a plain `def` scopes the `cd` to
# the command body and leaves the caller where it started.
#
# This takes an exact path through the builtin `cd`, and deliberately does not reach for
# zoxide: 20-zoxide.nu exports its `cd` alias after this file is parsed and Nushell
# resolves aliases at parse time, so a body written here can only ever see the builtin.
# Bare `cd` in the REPL is zoxide's frecency jump; `c` is cd-and-list.
def --env c [path: string] {
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
# Bounded Filesystem Search
# ============================================================================

# `fd --hidden` with no depth limit is unusable from $HOME: it descends .cache (71k
# directories on drakkar), .cargo (42k), .npm (24k), .local (24k) and .bun (15k), for 223k
# directories and 1.7M files — 2.5 s cold, and the fzf bindings below paid that on every
# keypress. Pruned, the same walk is ~140 ms.
const FD_EXCLUDE = [
    --exclude .git
    --exclude .cache
    --exclude .cargo
    --exclude .rustup
    --exclude .npm
    --exclude .bun
    --exclude node_modules
    --exclude .direnv
    --exclude .devenv
    --exclude target
    --exclude result
    --exclude .venv
    --exclude __pycache__
    --exclude .steam
    --exclude Steam
]

# fd with the prune list above. `kind` is fd's --type (f or d), `depth` its --max-depth,
# and the rest arguments are search roots (default: the current directory).
def fd-bounded [kind: string, depth: int, --hidden, ...roots: string] {
    let hidden_flag = (if $hidden { [--hidden] } else { [] })
    fd --type $kind --max-depth $depth ...$hidden_flag ...$FD_EXCLUDE . ...$roots
}

# ============================================================================
# Zellij Sessions
# ============================================================================

# Project roots the sessionizer scans. A root this host does not have drops out rather
# than making fd fail on it.
def sessionizer-roots [] {
    [
        $"($env.HOME)/Code"
        $"($env.HOME)/projects"
        "/data/Code"
    ] | where {|dir| $dir | path exists}
}

# sessionize — pick a project, attach a zellij session named after it.
#
# zoxide's frecency list supplies the directories actually visited; the fd pass (depth 2,
# so <root>/<project> and <root>/<org>/<project>) supplies the ones not visited yet. The
# `try` around zoxide is for a host that has not rebuilt yet, or an installer image where
# it is absent: a missing zoxide costs the frecency half of the list, not the command.
def --env sessionize [] {
    let roots = (sessionizer-roots)
    let scanned = if ($roots | is-empty) { [] } else { fd-bounded d 2 ...$roots | lines }
    let candidates = (
        [$"($env.HOME)/.dotfiles"]
        | append (try { zoxide query -l | lines } catch { [] })
        | append $scanned
        | where {|dir| ($dir | path type) == "dir"}
        | uniq
    )
    # fzf exits 130 when the user aborts with Esc; that is an answer, not a failure.
    let choice = (
        try { $candidates | str join (char newline) | fzf --prompt "session> " } catch { "" }
        | str trim
    )
    if ($choice | is-empty) {
        return
    }
    let name = ($choice | path basename | str replace --all --regex '[^A-Za-z0-9_.-]' "-")
    if ($env.ZELLIJ? != null) {
        # `zellij attach` refuses to nest, so from inside a session the project opens as a
        # new tab of the session already running.
        zellij action new-tab --cwd $choice --name $name
    } else {
        cd $choice
        zellij attach --create $name
    }
}

# ----------------------------------------------------------------------------
# No auto-attach
# ----------------------------------------------------------------------------
#
# A terminal opens a shell, not a multiplexer. This file used to hand an interactive
# shell to `zellij attach --create main` behind a conservative guard; the guard worked,
# and the behaviour was still unwanted — every terminal becoming a zellij pane is a
# decision a terminal should not make for you. Removed 2026-11-05.
#
# zellij is one word away when you want it (`zellij`, or `zellij --layout dev|ops|agents|
# data`), and `sessionize` above (Alt-S) attaches a session named for a project. If you
# ever want the old behaviour back, it belongs in the terminal emulator's own startup
# command, not here — that way it applies to the terminal you chose to set it on rather
# than to every shell on the system, including the ones scripts and agents open.

# ============================================================================
# Keybindings
# ============================================================================

$env.config = ($env.config | merge {
    keybindings: [
    # Ctrl-R is deliberately unbound here. 40-atuin.nu registers atuin's own history
    # search (and atuin_up_arrow) after this file, and atuin owns history now — the fzf
    # shell-out this binding used to carry searched a history nothing writes any more.

    # Tab: IDE-style completion menu — candidates in a bordered box with their
    # descriptions beside them. Nushell ships the menu and binds it to Ctrl-Space; this
    # puts it on Tab, in front of the single-line completion_menu, using the same `until`
    # chain so a second Tab still cycles and a non-menu context still plain-completes.
    {
        name: ide_completion
        modifier: none
        keycode: tab
        mode: [emacs, vi_insert]
        event: {
            until: [
                { send: menu name: ide_completion_menu }
                { send: menunext }
                { edit: complete }
            ]
        }
    }

    # Ctrl-F / Alt-F: accept the history hint (the greyed-out tail of the line) whole, or
    # one word at a time.
    {
        name: accept_history_hint
        modifier: control
        keycode: char_f
        mode: [emacs, vi_insert]
        event: { send: historyhintcomplete }
    }

    {
        name: accept_history_hint_word
        modifier: alt
        keycode: char_f
        mode: [emacs, vi_insert]
        event: { send: historyhintwordcomplete }
    }

    # Ctrl-T: insert a file path. No layout flags here: FZF_DEFAULT_OPTS
    # (features/cli/fzf) already supplies the height, the reversed layout, the border and
    # the preview window, and restating them per binding is how they drift.
    {
        name: fzf_file
        modifier: control
        keycode: char_t
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: ExecuteHostCommand
            cmd: "let picked = (try { fd-bounded f 6 --hidden | fzf } catch { '' } | str trim); if ($picked | is-not-empty) { commandline edit --insert $picked }"
        }
    }

    # Alt-C: jump to a directory.
    {
        name: fzf_cd
        modifier: alt
        keycode: char_c
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: ExecuteHostCommand
            cmd: "let picked = (try { fd-bounded d 6 --hidden | fzf } catch { '' } | str trim); if ($picked | is-not-empty) { cd $picked }"
        }
    }

    # Alt-S: the sessionizer. Alt rather than Ctrl-S, which terminals still eat as XOFF,
    # and Ctrl-F is taken by the history hint above.
    {
        name: zellij_sessionize
        modifier: alt
        keycode: char_s
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: ExecuteHostCommand
            cmd: "sessionize"
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
})

# ============================================================================
# Completions & Suggestions
# ============================================================================

# Field assignments rather than a merge of the whole `completions` record: `merge` is
# shallow, so setting three keys that way would reset max_results, cache_size and
# use_ls_colors to their defaults as a side effect.
$env.config.completions.algorithm = "fuzzy"
$env.config.completions.sort = "smart"
$env.config.completions.case_sensitive = false
$env.config.completions.quick = true
$env.config.completions.partial = true

# External completions stay on, but the completer itself is NOT set here: 30-carapace.nu
# is generated from the installed carapace binary and assigns the external completer field
# itself, after this file runs. A hand-written one would be overwritten every start.
$env.config.completions.external.enable = true

# ============================================================================
# Color & Display Configuration
# ============================================================================

# Use colors (similar to Fish theme)
$env.config = ($env.config | merge {
    color_config: {
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
})

# ============================================================================
# Additional Configuration
# ============================================================================

# Table display and history settings
$env.config = ($env.config | merge {
    table: {
        mode: rounded
        index_mode: auto
        show_empty: true
    }
    history: {
        max_size: 100000
        sync_on_enter: true
        file_format: "sqlite"
        # Per-session up/down history (fish-like); merges into sqlite on exit
        isolation: true
    }
})

# ============================================================================
# Notes for Fish Users
# ============================================================================

# Differences from Fish:
# - Vi mode is less complete than Fish (Reedline limitation)
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
# To return to Fish: type 'fish'
