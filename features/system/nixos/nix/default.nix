{
  c9config,
  pkgs,
  ...
}: {
  system.stateVersion = c9config.stateVersion;
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  nix.settings.trusted-users = ["root" "${c9config.username}"];
  nix.settings.allow-import-from-derivation = true;
}
