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

  nixpkgs = {
    hostPlatform = settings.hostPlatform;
    config = {
      allowUnfree = true;
      allowBroken = false;
    };
  };

  documentation = {
    nixos = {
      enable = false;
    };
  };
}
