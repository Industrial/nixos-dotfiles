{settings, ...}: {
  system = {
    stateVersion = settings.stateVersion;
  };

  networking = {
    hostName = settings.hostname;
    # useDHCP = false;
    # interfaces = {
    #   eth0 = {
    #     useDHCP = true;
    #   };
    # };
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

  services = {
    getty = {
      autologinUser = settings.username;
    };
  };

  microvm = {
    socket = "control.socket";
    hypervisor = "qemu";
    volumes = [
      {
        mountPoint = "/var";
        image = "var.img";
        size = 256;
      }
    ];
    shares = [
      {
        # use "virtiofs" for MicroVMs that are started by systemd
        proto = "9p";
        tag = "ro-store";
        # a host's /nix/store will be picked up so that no
        # squashfs/erofs will be built for it.
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
  };
}
