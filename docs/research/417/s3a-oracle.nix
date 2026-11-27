# The #417 S3a oracle for one host: its evaluated users and groups, normalised, and its
# toplevel .drv path. Run before and after a change to the users/groups subtree. The two
# results must be identical, so the change moves no host (vdeploy deploys drakkar and mimir
# from main, and comin deploys muninn).
#
#   nix eval --json --impure --expr \
#     'import ./docs/research/417/s3a-oracle.nix { flakeRef = "git+file:///…/checkout"; host = "drakkar"; }'
#
# flakeRef is a git+file reference, never path: or a bare directory, which would copy .git
# into the world-readable store (#266). One host per eval: each costs about 25 s and 2.6 GB.
{
  flakeRef,
  host,
}: let
  flake = builtins.getFlake flakeRef; # flake-ref: git-tracked
  # The commit is pinned: system.configurationRevision is the flake's git revision, which
  # nixos-version embeds, so without the pin every commit moves every toplevel. With it, a
  # different toplevel is a real change.
  system = flake.nixosConfigurations.${host}.extendModules {
    modules = [{system.configurationRevision = flake.nixosConfigurations.${host}.pkgs.lib.mkForce "s3a-oracle";}];
  };
  inherit (system.pkgs) lib;

  # JSON-safe and comparable: a package by its .drv path (which pins the derivation, not
  # just its output), a function by a marker, a path by its string.
  normalise = v:
    if lib.isDerivation v
    then {drv = v.drvPath;}
    else if lib.isFunction v
    then "<function>"
    else if builtins.isPath v
    then toString v
    else if builtins.isAttrs v
    then lib.mapAttrs (_: normalise) v
    else if builtins.isList v
    then map normalise v
    else v;
in {
  inherit host;
  toplevel = system.config.system.build.toplevel.drvPath;
  users = normalise system.config.users.users;
  groups = normalise system.config.users.groups;
}
