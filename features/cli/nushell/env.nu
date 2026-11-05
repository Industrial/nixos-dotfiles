# Nushell Environment Config File
# Loaded before config.nu, which is loaded before $nu.data-dir/vendor/autoload.
#
# The autoload files only run on the REPL path, so `nu -c '...'` and `nu script.nu`
# never see 00-nixos-env.nu.
#
# An earlier revision of this comment called the assignments below "the non-interactive
# floor". That was wrong, and measurement disproved it: as of Nushell 0.116 `nu -c` and
# `nu script.nu` do not load THIS file either — `nu -c 'which prepend-path | is-not-empty'`
# answers false. The real non-interactive floor is the inherited process environment,
# which NixOS populates through /etc/set-environment and pam_env.
#
# What these assignments actually buy is an interactive shell that bypassed pam_env
# (a nested shell, a terminal started from a session that never read it). They are a
# belt-and-braces duplicate of the authoritative declaration, which is
# features/cli/shell-init's environment.sessionVariables.

# -----------------------------------------------------------------------------
# Editors / XDG (matches environment.sessionVariables; EDITOR fixed to nvim)
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
# Rootless Docker — same contract as virtualisation.docker.rootless.setSocketVariable
# (environment.extraInit only reaches POSIX shells; fish has its own glue in
# /etc/fish/nixos-env-preinit.fish). Without this, nu terminals fall back to
# /var/run/docker.sock — the rootful daemon we deliberately disabled.
# -----------------------------------------------------------------------------
if ("DOCKER_HOST" not-in $env) and ($env.XDG_RUNTIME_DIR? != null) {
  $env.DOCKER_HOST = $"unix://($env.XDG_RUNTIME_DIR)/docker.sock"
}

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
# Starship is NOT sourced here. features/cli/shell-init generates `starship init
# nu` at build time into $nu.data-dir/vendor/autoload/10-starship.nu, which Nushell
# sources on its own. The committed starship.nu this line used to source was a copy
# of that output and drifted from the installed binary.
# -----------------------------------------------------------------------------
