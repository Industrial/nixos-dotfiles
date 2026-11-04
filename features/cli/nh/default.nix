# nh wraps nixos-rebuild and home-manager with a nicer CLI. Binary: nh.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nh
  ];
}
