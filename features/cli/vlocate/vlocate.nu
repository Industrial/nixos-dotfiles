# vlocate's command-not-found hook (features/cli/vlocate, GH-245): when a command is not
# found, nushell shows this hint under its own error: which store path of the fleet's
# systems ships it, which nixpkgs attributes do (nix-locate), and how to run it once with
# comma. Nothing found, or vlocate missing: no hint, nushell's own message alone.
$env.config.hooks.command_not_found = {|cmd_name|
  try {
    let found = (^vlocate hint $cmd_name | complete)
    if $found.exit_code == 0 { $found.stdout | str trim } else { null }
  } catch {
    null
  }
}
