{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nix-unit
  ];
}
