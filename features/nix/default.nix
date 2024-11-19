{settings, ...}: {
  system = {
    stateVersion = settings.stateVersion;
  };

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      allow-import-from-derivation = true;
    };
  };
}
