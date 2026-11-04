# nvd diffs the packages between two Nix system generations. Binary: nvd.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nvd
  ];
}
