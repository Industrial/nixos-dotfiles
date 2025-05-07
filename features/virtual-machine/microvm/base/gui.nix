{
  settings,
  pkgs,
  ...
}: {
  system = {
    stateVersion = settings.stateVersion;
  };

  hardware = {
    graphics = {
      enable = true;
    };
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

  environment = {
    sessionVariables = {
      WAYLAND_DISPLAY = "wayland-1";
      DISPLAY = ":0";
      QT_QPA_PLATFORM = "wayland"; # Qt Applications
      GDK_BACKEND = "wayland"; # GTK Applications
      XDG_SESSION_TYPE = "wayland"; # Electron Applications
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
    };
    systemPackages = with pkgs;
      [
        xdg-utils # Required
      ]
      ++ map (
        package:
          lib.attrByPath (lib.splitString "." package) (throw "Package ${package} not found in nixpkgs") pkgs
      ) (
        builtins.filter (package: package != "") (lib.splitString " " packages)
      );
  };

  systemd = {
    user = {
      services = {
        wayland-proxy = {
          enable = true;
          description = "Wayland Proxy";
          serviceConfig = {
            # Environment = "WAYLAND_DISPLAY=wayland-1";
            ExecStart = "${pkgs.wayland-proxy-virtwl}/bin/wayland-proxy-virtwl --virtio-gpu --x-display=0 --xwayland-binary=${pkgs.xwayland}/bin/Xwayland";
            Restart = "on-failure";
            RestartSec = 5;
          };
          wantedBy = ["default.target"];
        };
      };
    };
  };

  microvm = {
    hypervisor = "cloud-hypervisor";
    graphics = {
      enable = true;
    };
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
