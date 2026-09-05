{
  lib,
  settings,
  ...
}: {
  system = {
    stateVersion = settings.stateVersion;
  };

  nix = {
    settings = {
      # Enable parallel builds
      max-jobs = "auto";
      cores = 0;

      # Binary cache substituters for faster builds
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://devenv.cachix.org"
      ];

      # Trusted public keys for binary caches
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        # https://nix-community.org/cache/
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        # https://devenv.sh/binary-caching/
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      ];

      # Enable experimental features for better performance
      experimental-features = ["nix-command" "flakes"];

      # Allow import from derivation for better caching
      allow-import-from-derivation = true;

      # Enable auto-optimise-store for better performance
      auto-optimise-store = true;

      # Set build timeout
      build-timeout = 3600;

      # Set build directory outside temporary file system to accomodate big
      # builds.
      build-dir = "/var/temproot";

      # Enable sandbox for security
      sandbox = true;

      # # Set max log size
      # max-log-size = 1000000;

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
      # Allow insecure packages (required for some gaming applications)
      permittedInsecurePackages = [
        "mbedtls-2.28.10"
      ];
    };
    overlays = [
      # Disable openldap tests (flaky syncreplication test)
      (final: prev: {
        openldap = prev.openldap.overrideAttrs (old: {
          doCheck = false;
        });
      })
      # pipx 1.14.0 check phase fails on pytest parametrize in test_inject.py
      (final: prev: let
        disablePipxCheck = pkg:
          pkg.overridePythonAttrs (old: {
            doCheck = false;
          });
      in {
        pipx = disablePipxCheck prev.pipx;
        python314Packages = prev.python314Packages.override {
          overrides = self: super: {
            pipx = disablePipxCheck super.pipx;
          };
        };
      })
    ];
  };

  # # Disable package doc outputs globally to avoid pulling fragile doc builds
  # # (e.g. python docs via sphinx/docutils) into system-path.
  # # Disable package doc outputs globally to avoid pulling fragile doc builds
  # # (e.g. python docs via sphinx/docutils) into system-path.
  # documentation = {
  #   doc = {
  #     enable = false;
  #   };
  #   man = {
  #     enable = false;
  #     generateCaches = false;
  #     man-db = {
  #       enable = false;
  #     };
  #   };
  # };

  # Cap journal size so a runaway user unit cannot fill /var/log/journal and
  # break dbus-broker reload during nixos-rebuild switch.
  services.journald.settings.Journal = {
    SystemMaxUse = "1G";
    RuntimeMaxUse = "256M";
    MaxFileSec = "1week";
  };
}
