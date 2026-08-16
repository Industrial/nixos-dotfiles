# Nushell Environment Config File
# Loaded before config.nu (and before login.nu for login shells).
# Keep this aligned with features/cli/fish environment.sessionVariables.

# -----------------------------------------------------------------------------
# Editors / XDG (matches Fish sessionVariables; EDITOR fixed to nvim)
# -----------------------------------------------------------------------------
$env.EDITOR = "nvim"
$env.GIT_EDITOR = "nvim"
$env.DIFFPROG = "nvim -d"
$env.VISUAL = "nvim"

$env.XDG_CACHE_HOME = $"($env.HOME)/.cache"
$env.XDG_CONFIG_HOME = $"($env.HOME)/.config"
$env.XDG_DATA_HOME = $"($env.HOME)/.local/share"
$env.XDG_STATE_HOME = $"($env.HOME)/.local/state"

# -----------------------------------------------------------------------------
# PATH — user bins first (Nu keeps PATH as a list)
# -----------------------------------------------------------------------------
def --env prepend-path [dir: string] {
  if $dir in $env.PATH {
    return
  }
  $env.PATH = ($env.PATH | prepend $dir)
}

def --env append-path [dir: string] {
  if $dir in $env.PATH {
    return
  }
  $env.PATH = ($env.PATH | append $dir)
}

prepend-path $"($env.HOME)/.local/bin"
append-path $"($env.HOME)/.lmstudio/bin"
append-path $"($env.HOME)/.dotfiles/scripts"

# -----------------------------------------------------------------------------
# Direnv — update env when PWD changes
# -----------------------------------------------------------------------------
$env.config = ($env.config? | default {} | merge {
  hooks: {
    env_change: {
      PWD: [
        {
          condition: {|_| (which direnv | is-not-empty)}
          code: "direnv export json | from json | default {} | load-env"
        }
      ]
    }
  }
})

# -----------------------------------------------------------------------------
# Starship — official init (export-env), not hand-rolled PROMPT_COMMAND
# -----------------------------------------------------------------------------
source starship.nu
