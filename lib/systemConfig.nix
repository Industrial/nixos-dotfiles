let
  systemConfig = inputs: systemPath: settingsPath: let
    system = import systemPath;
    settings = import settingsPath;
    pkgs = import inputs.nixpkgs {
      stateVersion = settings.stateVersion;
      system = settings.system;
      hostPlatform = settings.system;
      config = {
        allowUnfree = true;
        allowBroken = false;
      };
    };
    specialArgs = {
      inherit inputs;
      settings = settings;
    };
    commonConfig = {
      system = settings.system;
      pkgs = pkgs;
      specialArgs = specialArgs;
      modules = [
        system
      ];
    };
    systemConfiguration =
      if settings.system == "x86_64-linux"
      then inputs.nixpkgs.lib.nixosSystem commonConfig
      else if settings.system == "aarch64-darwin"
      then inputs.nix-darwin.lib.darwinSystem commonConfig
      else throw "Unsupported system: ${settings.system}";
  in {
    systemConfiguration = systemConfiguration;
  };
in
  systemConfig
