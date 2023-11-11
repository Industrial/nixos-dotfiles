# TODO: c9config username
{pkgs, ...}: {
  system.stateVersion = "22.11";
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  nix.settings.trusted-users = ["root" "tom"];
  nix.settings.allow-import-from-derivation = true;
}
