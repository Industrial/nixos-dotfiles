{settings, ...}: {
  system.stateVersion = settings.stateVersion;
  #nix.package = pkgs.nixVersions.stable;
  nix.settings.experimental-features = "nix-command flakes";
  nix.settings.allow-import-from-derivation = true;
}
