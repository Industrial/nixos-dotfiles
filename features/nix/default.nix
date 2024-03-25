{
  settings,
  pkgs,
  ...
}: {
  system.stateVersion = settings.stateVersion;
  nix.package = pkgs.nixFlakes;
  nix.settings.experimental-features = "nix-command flakes";
  nix.settings.allow-import-from-derivation = true;
}
