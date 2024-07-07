{settings, ...}: {
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

  #users = {
  #  users = {
  #    test = {
  #      extraGroups = ["wheel"];
  #      isNormalUser = true;
  #    };
  #  };
  #};

  security = {
    sudo = {
      wheelNeedsPassword = false;
    };
  };

  services.getty = {
    autologinUser = settings.username;
  };
}
