{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
  };

  outputs = inputs: let
    hostname = "drakkar";
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        allowBroken = false;
      };
    };
  in {
    nixosConfigurations = {
      drakkar = inputs.nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ({...}: {
            imports = [
              ./hardware-configuration.nix
            ];

            # Nix
            system.stateVersion = "23.05";
            nix.package = pkgs.nixFlakes;
            nix.extraOptions = ''
              experimental-features = nix-command flakes
            '';

            # Boot
            boot.loader.systemd-boot.enable = true;
            boot.loader.efi.canTouchEfiVariables = true;
            boot.loader.efi.efiSysMountPoint = "/boot/efi";
            boot.initrd.secrets = {
              "/crypto_keyfile.bin" = null;
            };

            # Time
            time.timeZone = "Europe/Amsterdam";

            # I18N
            i18n.defaultLocale = "en_US.UTF-8";
            i18n.extraLocaleSettings = {
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

            # Console
            console.font = "Lat2-Terminus16";
            console.keyMap = "us";

            # Networking
            networking.hostName = hostname;
            networking.networkmanager.enable = true;

            # Graphics
            hardware.opengl.enable = true;
            hardware.opengl.extraPackages = with pkgs; [
              rocm-opencl-icd
              rocm-opencl-runtime
              rocm-runtime
            ];
            hardware.opengl.driSupport = true;
            hardware.opengl.driSupport32Bit = true;
            environment.variables = {
              AMD_VULKAN_ICD = "RADV";
            };

            # Sound (https://nixos.wiki/wiki/PipeWire)
            sound.enable = false;
            hardware.pulseaudio.enable = false;
            security.rtkit.enable = true;
            services.pipewire.enable = true;
            services.pipewire.alsa.enable = true;
            services.pipewire.alsa.support32Bit = true;
            services.pipewire.pulse.enable = true;

            # Shell
            programs.fish.enable = true;
            users.users.tom.shell = pkgs.fish;

            # Window Manager
            services.xserver.enable = true;
            services.xserver.dpi = 96;
            services.xserver.layout = "us";
            services.xserver.xkbVariant = "";
            services.xserver.displayManager.defaultSession = "xfce";
            services.xserver.desktopManager.xfce.enable = true;
            services.xserver.videoDrivers = ["amdgpu"];

            # Fonts
            fonts.fonts = with pkgs; [
              terminus_font
              terminus_font_ttf
              nerdfonts
            ];

            # Docker
            virtualisation.docker.enable = true;

            # Printing
            services.printing.enable = true;

            # Packages
            environment.systemPackages = with pkgs; [
              # Git (needed for home-manager / flakes)
              git

              # Graphics
              rocminfo

              # Sound
              helvum
              pavucontrol
              pulsemixer

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

              # Node.js + Global Packages
              nodejs-19_x
              # overlay
              #promptr
            ];

            # User
            users.users.tom.isNormalUser = true;
            users.users.tom.home = "/home/tom";
            users.users.tom.description = "Tom Wieland";
            users.users.tom.extraGroups = [
              "audio"
              "networkmanager"
              "plugdev"
              "wheel"
            ];
          })
        ];
      };
    };

    homeConfigurations = {
      "tom@drakkar" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs;
        modules = [
          ./users/tom/home
        ];
      };
    };
  };
}
