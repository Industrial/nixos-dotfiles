# Nushell Environment Config File
# This file is loaded before config.nu
# Use for environment variables and PATH modifications

# XDG Base Directory Specification
$env.EDITOR = "nvim"
$env.GIT_EDITOR = "nvim"
$env.DIFFPROG = "nvim -d"
$env.XDG_CACHE_HOME = $"($env.HOME)/.cache"
$env.XDG_CONFIG_HOME = $"($env.HOME)/.config"
$env.XDG_DATA_HOME = $"($env.HOME)/.local/share"
$env.XDG_STATE_HOME = $"($env.HOME)/.local/state"

# Add local bin to PATH
$env.PATH = ($env.PATH | split row (char esep) | prepend $"($env.HOME)/.local/bin")

# Add LM Studio CLI to PATH
$env.PATH = ($env.PATH | split row (char esep) | append $"($env.HOME)/.lmstudio/bin")

# Direnv integration
# Uses env_change hook for efficiency (only updates on directory change)
$env.config = {
    hooks: {
        env_change: {
            PWD: [
                {
                    condition: {|before, after| (which direnv | is-not-empty) }
                    code: "direnv export json | from json | default {} | load-env"
                }
            ]
        }
    }
}
