# nh wraps nixos-rebuild and home-manager with a nicer CLI. Binary: nh.
# Off the default path (GH-241): features/cli/vswitch is the local rebuild and
# bin/update/system switches through it; nothing calls nh. Retired: no profile enables it,
# and vswitch's rollback (`features.cli.vswitch.enable = lib.mkForce false;`) lands on
# nixos-rebuild, not nh. A host may still set `features.cli.nh.enable = true;`.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nh
  ];
}
