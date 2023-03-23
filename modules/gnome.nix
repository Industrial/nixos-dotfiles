{pkgs, ...}: {
  config = {
    services = {
      xserver = {
        enable = true;

        dpi = 96;

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
    };

    environment = {
      gnome = {
        excludePackages =
          (with pkgs; [
            gnome-photos
            gnome-tour
          ])
          ++ (with pkgs.gnome; [
            atomix # puzzle game
            epiphany # web browser
            geary # email reader
            gedit # text editor
            gnome-characters
            gnome-contacts
            gnome-initial-setup
            gnome-music
            hitori # sudoku game
            iagno # go game
            tali # poker game
            yelp # Help view
          ]);
      };

      systemPackages = with pkgs; [
        gnome.dconf-editor
        gnome.gnome-control-center
        gnome.gnome-disk-utility
        gnome.gnome-remote-desktop
        gnome.gnome-screenshot
        gnome.gnome-shell
        gnome.gnome-shell-extensions
        gnome.gnome-system-monitor
        gnome.gnome-terminal
        gnome.gnome-tweaks
        gnome.nautilus
        gnome.seahorse
        #gnome.vinagre
        gnomeExtensions.applications-menu
        gnomeExtensions.dash-to-panel
        gnomeExtensions.gtile
        gnomeExtensions.openweather
        gnomeExtensions.places-status-indicator
        gnomeExtensions.removable-drive-menu
        gnomeExtensions.sound-output-device-chooser
        gnomeExtensions.tray-icons-reloaded
        gnomeExtensions.user-themes
        gnomeExtensions.vitals
      ];
    };

    programs = {
      dconf = {
        enable = true;
      };
    };
  };
}
