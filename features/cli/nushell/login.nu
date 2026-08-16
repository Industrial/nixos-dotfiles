# login.nu — runs only for login shells (TTY / session start).
# Fish gets /etc/profile + pam + NixOS environment.sessionVariables via its
# login path; Nu does not. Import a bash login environment once, then re-apply
# Nu-specific overrides (Fish sessionVariables currently typo EDITOR=vnim).

def --env import-posix-login-env [] {
  let blob = (^bash --login -c "env -0" | complete)
  if $blob.exit_code != 0 {
    return
  }

  let skip = [
    "_"
    "SHLVL"
    "OLDPWD"
    "PWD"
    "SHELL"
    "STARSHIP_SHELL"
    "STARSHIP_SESSION_KEY"
    "PROMPT_COMMAND"
    "PROMPT_COMMAND_RIGHT"
    "PROMPT_INDICATOR"
    "PROMPT_INDICATOR_VI_INSERT"
    "PROMPT_INDICATOR_VI_NORMAL"
    "PROMPT_MULTILINE_INDICATOR"
    "FILE_PWD"
    "CURRENT_FILE"
    "LAST_EXIT_CODE"
    "CMD_DURATION_MS"
  ]

  let updates = (
    $blob.stdout
    | split row (char --integer 0)
    | where {|x| ($x | str length) > 0}
    | each {|line|
        let eq = ($line | str index-of "=")
        if $eq == null {
          null
        } else {
          let name = ($line | str substring 0..<$eq)
          let value = ($line | str substring ($eq + 1)..)
          if $name == "PATH" {
            { name: $name, value: ($value | split row ":" | where {|p| ($p | str length) > 0}) }
          } else {
            { name: $name, value: $value }
          }
        }
      }
    | where {|r| $r != null}
    | where {|r| not ($r.name in $skip)}
    | reduce --fold {} {|r, acc| $acc | upsert $r.name $r.value }
  )

  load-env $updates
}

def --env apply-nu-session-overrides [] {
  $env.EDITOR = "nvim"
  $env.GIT_EDITOR = "nvim"
  $env.DIFFPROG = "nvim -d"
  $env.VISUAL = "nvim"
  $env.XDG_CACHE_HOME = $"($env.HOME)/.cache"
  $env.XDG_CONFIG_HOME = $"($env.HOME)/.config"
  $env.XDG_DATA_HOME = $"($env.HOME)/.local/share"
  $env.XDG_STATE_HOME = $"($env.HOME)/.local/state"

  let prefer = [
    $"($env.HOME)/.local/bin"
    $"($env.HOME)/.lmstudio/bin"
    $"($env.HOME)/.dotfiles/scripts"
  ]
  for dir in ($prefer | reverse) {
    if not ($dir in $env.PATH) {
      $env.PATH = ($env.PATH | prepend $dir)
    } else {
      $env.PATH = ($env.PATH | where {|p| $p != $dir} | prepend $dir)
    }
  }
}

import-posix-login-env
apply-nu-session-overrides
