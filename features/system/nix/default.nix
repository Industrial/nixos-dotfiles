{pkgs, ...}: {
  system.stateVersion = "23.05";
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
}
