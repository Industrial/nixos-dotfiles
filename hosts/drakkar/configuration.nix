{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nixpkgs.config.allowUnfree = true;

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };
    };
  };

  networking = {
    hostName = "drakkar";
    networkmanager = {
      enable = true;
    };
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "nl_NL.UTF-8";
      LC_IDENTIFICATION = "nl_NL.UTF-8";
      LC_MEASUREMENT = "nl_NL.UTF-8";
      LC_MONETARY = "nl_NL.UTF-8";
      LC_NAME = "nl_NL.UTF-8";
      LC_NUMERIC = "nl_NL.UTF-8";
      LC_PAPER = "nl_NL.UTF-8";
      LC_TELEPHONE = "nl_NL.UTF-8";
      LC_TIME = "nl_NL.UTF-8";
    };
  };

  time = {
    timeZone = "Europe/Amsterdam";
  };

  sound = {
    enable = true;
  };

  fonts = {
    fonts = with pkgs; [
      terminus_font
      terminus_font_ttf
      nerdfonts
    ];
  };

  services = {
    printing = {
      enable = true;
      # TODO: Find correct driver.
      #drivers = with pkgs; [ cups-brother-ql-570 ];
    };

    # Sound
    pipewire = {
      enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };

      pulse = {
        enable = true;
      };

      config = {
        pipewire = {
          "context.properties" = {
            #"link.max-buffers" = 64;
            "link.max-buffers" = 16; # version < 3 clients can't handle more than this
            "log.level" = 2; # https://docs.pipewire.org/page_daemon.html
            #"default.clock.rate" = 48000;
            #"default.clock.quantum" = 1024;
            #"default.clock.min-quantum" = 32;
            #"default.clock.max-quantum" = 8192;
          };
        };
      };
    };
  };

  hardware = {
    opengl = {
      enable = true;

      extraPackages = with pkgs; [
        rocm-opencl-icd
        rocm-opencl-runtime
      ];

      driSupport = true;
      driSupport32Bit = true;
    };

    pulseaudio = {
      enable = false;
    };
  };

  security = {
    rtkit = {
      enable = true;
    };
  };

  users = {
    users = {
      tom = {
        isNormalUser = true;
        description = "Tom Wieland";
        shell = pkgs.zsh;
        extraGroups = [
          "wheel"
          "networkmanager"
          "plugdev"
        ];
        packages = [];
      };
    };
  };

  environment = {
    variables = {
      AMD_VULKAN_ICD = "RADV";
    };

    shells = with pkgs; [
      zsh
    ];

    systemPackages = with pkgs; [
      # Sound
      helvum
      pavucontrol

      (wineWowPackages.staging.override {
        wineRelease = "staging";
        gettextSupport = true;
        fontconfigSupport = true;
        alsaSupport = true;
        gtkSupport = true;
        openglSupport = true;
        tlsSupport = true;
        gstreamerSupport = true;
        openclSupport = true;
        udevSupport = true;
        vulkanSupport = true;
        mingwSupport = true;
        pulseaudioSupport = true;
      })
      winetricks

      # NTLM Support for wine
      samba
    ];
  };

  virtualisation = {
    docker = {
      enable = true;
    };
  };

  system = {
    stateVersion = "23.05";
  };
}
