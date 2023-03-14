{pkgs, ...}: {
  config = {
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
    };

    environment = {
      gnome = {
        excludePackages =
          (with pkgs; [
            gnome-photos
            gnome-tour
          ])
          ++ (with pkgs.gnome; [
            #cheese # webcam tool
            gnome-music
            gedit # text editor
            epiphany # web browser
            geary # email reader
            gnome-characters
            tali # poker game
            iagno # go game
            hitori # sudoku game
            atomix # puzzle game
            yelp # Help view
            gnome-contacts
            gnome-initial-setup
          ]);
      };

      # TODO: GNOME Extensions
      systemPackages = with pkgs; [
        #gnomeExtensions.
        gnome.gnome-tweaks
        gnome.gnome-terminal
        gnome.dconf-editor
        gnome.vinagre
        gnome.seahorse
        gnome.nautilus
        gnome.gnome-system-monitor
        gnome.gnome-shell
        gnome.gnome-shell-extensions
        gnome.gnome-screenshot
        gnome.gnome-remote-desktop
        gnome.gnome-disk-utility
        gnome.gnome-control-center
      ];
    };

    programs = {
      dconf = {
        enable = true;
      };
    };
  };
}
