{
  settings,
  pkgs,
  ...
}: {
  system = {
    stateVersion = settings.stateVersion;
  };

  networking = {
    hostName = settings.hostname;
    useDHCP = false;
    interfaces = {
      eth0 = {
        useDHCP = true;
      };
    };
  };

  users = {
    users = {
      test = {
        extraGroups = ["wheel"];
        isNormalUser = true;
      };
    };
  };

  #virtualisation = {
  #  vmVariant = {
  #    virtualisation = {
  #      graphics = false;
  #      host = {
  #        pkgs = pkgs;
  #      };
  #    };
  #  };
  #};

  security = {
    sudo = {
      wheelNeedsPassword = false;
    };
  };

  services.getty = {
    autologinUser = "test";
  };
}