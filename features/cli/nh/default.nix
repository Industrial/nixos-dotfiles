# nh wraps nixos-rebuild and home-manager with a nicer CLI. Binary: nh.
# Demoted (GH-241): features/cli/vswitch replaced it in cli-core, and bin/update/system
# switches through vswitch. Kept as the rollback: a host that sets
# `features.cli.vswitch.enable = lib.mkForce false;` gets nh back.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nh
  ];
}
