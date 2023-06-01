{pkgs, ...}: {
  system.stateVersion = "23.05";
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  nix.settings.trusted-users = ["root" "tom"];
  nix.settings.allow-import-from-derivation = true;
}
