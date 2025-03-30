{settings, ...}: {
  system = {
    stateVersion = settings.stateVersion;
  };

  networking = {
    hostName = settings.hostname;
  };

  security = {
    sudo = {
      wheelNeedsPassword = false;
    };
  };

  services = {
    getty = {
      autologinUser = settings.username;
    };
  };

  microvm = {
    hypervisor = "cloud-hypervisor";
    volumes = [
      {
        mountPoint = "/var";
        image = "var.img";
        size = 256;
      }
    ];
    shares = [
      {
        mountPoint = "/nix/.ro-store";
        proto = "virtiofs";
        source = "/nix/store";
        tag = "ro-store";
      }
    ];
  };
}
