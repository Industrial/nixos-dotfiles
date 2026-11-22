# nh wraps nixos-rebuild and home-manager with a nicer CLI. Binary: nh.
# Off the default path (GH-241): features/cli/vswitch is the local rebuild and
# bin/update/system switches through it; nothing calls nh. cli-core keeps it installed as
# the rollback's working tool (with `features.cli.vswitch.enable = lib.mkForce false;`).
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nh
  ];
}
