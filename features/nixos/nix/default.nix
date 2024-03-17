{
  settings,
  pkgs,
  ...
}: {
  system.stateVersion = settings.stateVersion;
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  nix.settings.trusted-users = ["root" "${settings.username}"];
  nix.settings.allow-import-from-derivation = true;
}
