# XFCE Window Manager
{pkgs, ...}: {
  programs = {
    gnupg = {
      agent = {
        pinentryPackage = pkgs.pinentry-qt;
      };
    };
  };

  security = {
    pam = {
      services = {
        lightdm = {
          enableGnomeKeyring = true;
        };
      };
    };
  };

  services = {
    gnome = {
      gnome-keyring = {
        enable = true;
      };
    };

    xserver = {
      displayManager = {
        lightdm = {
          enable = true;
        };
      };

      desktopManager = {
        xfce = {
          enable = true;
        };
      };
    };
  };

  environment = {
    systemPackages = with pkgs; [
      wmctrl
      xarchiver
      xfce.exo
      xfce.garcon
      xfce.libxfce4ui
      xfce.libxfce4util
      xfce.mousepad
      xfce.thunar
      xfce.thunar-archive-plugin
      xfce.xfce4-battery-plugin
      xfce.xfce4-icon-theme
      xfce.xfce4-notifyd
      xfce.xfce4-panel
      xfce.xfce4-panel-profiles
      xfce.xfce4-power-manager
      xfce.xfce4-pulseaudio-plugin
      xfce.xfce4-screensaver
      xfce.xfce4-screenshooter
      xfce.xfce4-session
      xfce.xfce4-settings
      xfce.xfce4-taskmanager
      xfce.xfce4-terminal
      xfce.xfce4-volumed-pulse
      xfce.xfce4-whiskermenu-plugin
      xfce.xfconf
      xfce.xfdashboard
      xfce.xfdesktop
      xfce.xfwm4
      xfce.xfwm4-themes
      xorg.xwininfo
    ];
  };
}
