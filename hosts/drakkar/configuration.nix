{ config, pkgs, modulesPath, inputs, ... }:

let
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/master.tar.gz";
    sha256 = "sha256:1nxhd86lfpfw24yfvkrrf4hnw0xcmwb495qbxl1dqhgv76ayxa2r";
  };
in
{
  imports = [
    ./hardware-configuration.nix
    (import "${home-manager}/nixos")
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

    initrd = {
      secrets = {
        "/crypto_keyfile.bin" = null;
      };

      luks.devices = {
        "luks-9e4e63a2-fdcb-47fa-bb41-1cff46dfb69c" = {
          device = "/dev/disk/by-uuid/9e4e63a2-fdcb-47fa-bb41-1cff46dfb69c";
          keyFile = "/crypto_keyfile.bin";
        };
      };
    };
  };

  fileSystems."/data" = {
    device = "/dev/sda1";
    fsType = "ext4";
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
    xserver = {
      enable = true;

      layout = "us";
      xkbVariant = "";

      displayManager = {
        gdm = {
          enable = true;
          wayland = true;
        };
      };

      desktopManager = {
        gnome = {
          enable = true;
        };
      };

      videoDrivers = [
        "amdgpu"
      ];
    };

    printing = {
      enable = true;
      # TODO: Find correct driver.
      #drivers = with pkgs; [ cups-brother-ql-570 ];
    };

    pipewire = {
      enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };
    };

    tor = {
      enable = true;
      settings = {
        ExitNodes = "{us},{gb} StrictNodes 1";
      };
    };

    yggdrasil = {
      enable = true;
      persistentKeys = false;
      settings = {
        # Public peers can be found at
        # https://github.com/yggdrasil-network/public-peers
        Peers = [
          "tls://23.137.249.65:443"
          "tls://ygg-nl.incognet.io:8884"
          "tls://94.103.82.150:8080"
        ];
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
        ];
        packages = with pkgs; [];
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
      # GFX Benchmark
      glmark2
      unigine-superposition
      unigine-tropics
      unigine-valley
      unigine-heaven

      (wineWowPackages.staging.override {
        wineRelease = "staging";
        #gettextSupport = true;
        #fontconfigSupport = true;
        #alsaSupport = true;
        #gtkSupport = true;
        #openglSupport = true;
        #tlsSupport = true;
        #gstreamerSupport = true;
        #openclSupport = true;
        #pulseaudioSupport = true;
        #udevSupport = true;
        vulkanSupport = true;
        mingwSupport = true;
      })
      winetricks
      #(winetricks.override {
      #  wine = wineWowPackages.staging;
      #})
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
