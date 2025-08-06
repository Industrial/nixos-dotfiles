{settings, ...}: {
  imports = [
    ../performance/environment
    ../performance/filesystems
    ../performance/hardware
    ../security/apparmor
    ../security/audit
    ../security/kernel
    ../security/pam
    ./systemd
  ];

  system = {
    stateVersion = settings.stateVersion;
  };

  nix = {
    settings = {
      # Enable parallel builds
      max-jobs = "auto";
      cores = 0;

      # Trusted users for binary cache
      trusted-users = ["root" "@wheel"];

      # Binary cache substituters for faster builds
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://devenv.cachix.org"
      ];

      # Trusted public keys for binary caches
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7BKqP7YhK1i3JvGvscqg5k="
        "devenv.cachix.org-1:w1cLUi8dv3hgsSP+aeo2H8R7ExhwCQrC19yFK+ZZmoc="
      ];

      # Enable experimental features for better performance
      experimental-features = "nix-command flakes";

      # Allow import from derivation for better caching
      allow-import-from-derivation = true;

      # Enable auto-optimise-store for better performance
      auto-optimise-store = true;

      # Set build timeout
      build-timeout = 3600;

      # Enable sandbox for security
      sandbox = true;

      # Set max log size
      max-log-size = 1000000;

      # Enable keep-derivations for better caching
      keep-derivations = true;

      # Enable keep-outputs for better caching
      keep-outputs = true;

      # Set gc-keep-derivations
      gc-keep-derivations = true;

      # Set gc-keep-outputs
      gc-keep-outputs = true;
    };

    # Configure garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
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
