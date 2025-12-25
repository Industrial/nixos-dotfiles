# GNOME dconf Configuration
# This file contains all the dconf settings for GNOME desktop environment
{
  pkgs,
  lib,
  config,
  ...
}: let
  wallpaper = "file:///home/tom/.local/share/backgrounds/2024-08-18-19-15-47-wallhaven-p9oe19.jpg";
in {
  # Advanced GNOME Configuration via dconf
  programs.dconf.profiles.user.databases = [
    {
      # Prevents overriding.
      lockAll = true;

      settings = {
        "system/locale" = {
          region = "en_US.UTF-8";
        };

        "org/gnome/shell" = {
          allow-extension-installation = true;

          last-selected-power-profile = "performance";
          # welcome-dialog-last-shown-version = "46.2";
          remember-mount-password = false;
          disable-user-extensions = false;

          enabled-extensions = [
            # Visual Enhancements
            pkgs.gnomeExtensions.just-perfection.extensionUuid
            pkgs.gnomeExtensions.user-themes.extensionUuid

            # Productivity Powerhouses
            pkgs.gnomeExtensions.clipboard-indicator.extensionUuid
            pkgs.gnomeExtensions.gsconnect.extensionUuid
            pkgs.gnomeExtensions.quick-settings-tweaker.extensionUuid

            # Media & Entertainment
            pkgs.gnomeExtensions.sound-output-device-chooser.extensionUuid
            pkgs.gnomeExtensions.spotify-tray.extensionUuid

            # Advanced Features
            pkgs.gnomeExtensions.night-theme-switcher.extensionUuid

            # Keep your existing extensions
            pkgs.gnomeExtensions.tiling-shell.extensionUuid
            pkgs.gnomeExtensions.vitals.extensionUuid
            pkgs.gnomeExtensions.wifi-qrcode.extensionUuid
            pkgs.gnomeExtensions.media-controls.extensionUuid
            pkgs.gnomeExtensions.notification-banner-reloaded.extensionUuid
            pkgs.gnomeExtensions.another-window-session-manager.extensionUuid

            # Workspace Management
            pkgs.gnomeExtensions.auto-move-windows.extensionUuid
          ];

          disabled-extensions = lib.gvariant.mkEmptyArray "s";

          favorite-apps = [
            "librewolf.desktop"
            "chromium-browser.desktop"
            "code.desktop"
            "obsidian.desktop"
            "spotify.desktop"
            "discord.desktop"
            "org.gnome.Nautilus.desktop"
            "alacritty.desktop"
          ];
        };

        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-timeout = lib.gvariant.mkInt32 0;
          sleep-inactive-battery-timeout = lib.gvariant.mkInt32 1200;
          power-button-action = "suspend";
          lid-close-suspend-with-external-monitor = false;
        };

        "org/gnome/desktop/interface" = {
          accent-color = "orange";
          clock-format = "24h";
          clock-show-date = true;
          clock-show-seconds = true;
          clock-show-weekday = true;
          color-scheme = "prefer-dark";
          cursor-blink = true;
          cursor-blink-time = lib.gvariant.mkInt32 1200;
          cursor-size = lib.gvariant.mkInt32 24;
          cursor-theme = "Bibata-Modern-Classic";
          document-font-name = "Inter 11";
          enable-animations = true;
          enable-hot-corners = true;
          font-antialiasing = "grayscale";
          font-hinting = "slight";
          font-name = "Inter 11";
          font-rendering = "automatic";
          font-rgba-order = "rgb";
          gtk-color-palette = "black:white:gray50:red:purple:blue:light blue:green:yellow:orange:lavender:brown:goldenrod4:dodger blue:pink:light green:gray10:gray30:gray75:gray90";
          gtk-color-scheme = "";
          gtk-enable-primary-paste = true;
          gtk-im-module = "";
          gtk-im-preedit-style = "callback";
          gtk-im-status-style = "callback";
          gtk-key-theme = "";
          gtk-theme = "Nordic";
          icon-theme = "Papirus-Dark";
          locate-pointer = false;
          menubar-accel = "F10";
          menubar-detachable = false;
          menus-have-tearoff = false;
          monospace-font-name = "JetBrains Mono 11";
          overlay-scrolling = true;
          scaling-factor = lib.gvariant.mkInt32 0;
          show-battery-percentage = true;
          text-scaling-factor = lib.gvariant.mkInt32 1;
          toolbar-detachable = false;
          toolbar-icons-size = "large";
          toolbar-style = "both-horiz";
          toolkit-accessibility = false;
        };

        "org/gnome/desktop/privacy" = {
          old-files-age = lib.gvariant.mkInt32 30;
          recent-files-max-age = lib.gvariant.mkInt32 30;
          remove-old-temp-files = true;
          remove-old-trash-files = true;
        };

        "org/gnome/desktop/search-providers" = {
          sort-order = [
            "org.gnome.Contacts.desktop"
            "org.gnome.Documents.desktop"
            "org.gnome.Nautilus.desktop"
          ];
          disable-external = false;
        };

        "org/gnome/desktop/background" = {
          color-shading-type = "solid";
          picture-options = "zoom";
          picture-uri = wallpaper;
          picture-uri-dark = wallpaper;
          primary-color = "#2E3440";
          secondary-color = "#3B4252";
        };

        "org/gnome/desktop/calendar" = {
          show-weekdate = true;
        };

        "org/gnome/desktop/datetime" = {
          automatic-timezone = true;
        };

        "org/gnome/desktop/input-sources" = {
          sources = ["xkb" "us"];
          xkb-options = ["terminate:ctrl_alt_bksp"];
        };

        "org/gnome/desktop/peripherals/mouse" = {
          double-click = lib.gvariant.mkInt32 400;
          drag-threshold = lib.gvariant.mkInt32 8;
          natural-scroll = false;
          speed = 0.10000000000000001;
        };

        "org/gnome/desktop/peripherals/touchpad" = {
          two-finger-scrolling-enabled = true;
        };

        "org/gnome/desktop/screensaver" = {
          color-shading-type = "solid";
          lock-enabled = true;
          picture-options = "zoom";
          picture-uri = wallpaper;
          primary-color = "#2E3440";
          secondary-color = "#3B4252";
        };

        "org/gnome/desktop/sound" = {
          event-sounds = false;
          input-feedback-sounds = false;
          theme-name = "freedesktop";
        };

        "org/gnome/shell/keybindings" = {
          focus-active-notification = lib.gvariant.mkEmptyArray "s";
          open-new-window-application-1 = lib.gvariant.mkEmptyArray "s";
          open-new-window-application-2 = lib.gvariant.mkEmptyArray "s";
          open-new-window-application-3 = lib.gvariant.mkEmptyArray "s";
          open-new-window-application-4 = lib.gvariant.mkEmptyArray "s";
          open-new-window-application-5 = lib.gvariant.mkEmptyArray "s";
          open-new-window-application-6 = lib.gvariant.mkEmptyArray "s";
          open-new-window-application-7 = lib.gvariant.mkEmptyArray "s";
          open-new-window-application-8 = lib.gvariant.mkEmptyArray "s";
          open-new-window-application-9 = lib.gvariant.mkEmptyArray "s";
          screenshot = ["<Shift>Print"];
          screenshot-window = ["<Alt>Print"];
          shift-overview-down = lib.gvariant.mkEmptyArray "s";
          shift-overview-up = lib.gvariant.mkEmptyArray "s";
          show-screen-recording-ui = lib.gvariant.mkEmptyArray "s";
          show-screenshot-ui = ["Print"];
          switch-to-application-1 = lib.gvariant.mkEmptyArray "s";
          switch-to-application-2 = lib.gvariant.mkEmptyArray "s";
          switch-to-application-3 = lib.gvariant.mkEmptyArray "s";
          switch-to-application-4 = lib.gvariant.mkEmptyArray "s";
          switch-to-application-5 = lib.gvariant.mkEmptyArray "s";
          switch-to-application-6 = lib.gvariant.mkEmptyArray "s";
          switch-to-application-7 = lib.gvariant.mkEmptyArray "s";
          switch-to-application-8 = lib.gvariant.mkEmptyArray "s";
          switch-to-application-9 = lib.gvariant.mkEmptyArray "s";
          toggle-application-view = lib.gvariant.mkEmptyArray "s";
          toggle-message-tray = lib.gvariant.mkEmptyArray "s";
          toggle-overview = lib.gvariant.mkEmptyArray "s";
          toggle-quick-settings = lib.gvariant.mkEmptyArray "s";
        };

        "org/gnome/desktop/wm/keybindings" = {
          activate-window-menu = lib.gvariant.mkEmptyArray "s";
          begin-move = lib.gvariant.mkEmptyArray "s";
          begin-resize = lib.gvariant.mkEmptyArray "s";
          close = ["<Control><Super>c"];
          cycle-group = lib.gvariant.mkEmptyArray "s";
          cycle-group-backward = lib.gvariant.mkEmptyArray "s";
          cycle-panels = lib.gvariant.mkEmptyArray "s";
          cycle-panels-backward = lib.gvariant.mkEmptyArray "s";
          cycle-windows = ["<Super>Tab"];
          cycle-windows-backward = ["<Super><Shift>Tab"];
          maximize = lib.gvariant.mkEmptyArray "s";
          minimize = lib.gvariant.mkEmptyArray "s";
          move-to-center = ["<Super><Control>f"];
          move-to-corner-ne = ["<Super><Control>t"];
          move-to-corner-nw = ["<Super><Control>e"];
          move-to-corner-se = ["<Super><Control>b"];
          move-to-corner-sw = ["<Super><Control>c"];
          move-to-monitor-down = lib.gvariant.mkEmptyArray "s";
          move-to-monitor-left = lib.gvariant.mkEmptyArray "s";
          move-to-monitor-right = lib.gvariant.mkEmptyArray "s";
          move-to-monitor-up = lib.gvariant.mkEmptyArray "s";
          move-to-side-e = ["<Super><Control>g"];
          move-to-side-n = ["<Super><Control>r"];
          move-to-side-s = ["<Super><Control>v"];
          move-to-side-w = ["<Super><Control>d"];
          move-to-workspace-1 = ["<Super><Control>1"];
          move-to-workspace-10 = ["<Super><Control>0"];
          move-to-workspace-2 = ["<Super><Control>2"];
          move-to-workspace-3 = ["<Super><Control>3"];
          move-to-workspace-4 = ["<Super><Control>4"];
          move-to-workspace-5 = ["<Super><Control>5"];
          move-to-workspace-6 = ["<Super><Control>6"];
          move-to-workspace-7 = ["<Super><Control>7"];
          move-to-workspace-8 = ["<Super><Control>8"];
          move-to-workspace-9 = ["<Super><Control>9"];
          move-to-workspace-down = ["<Super><Control>j"];
          move-to-workspace-last = lib.gvariant.mkEmptyArray "s";
          move-to-workspace-left = ["<Super><Control>h"];
          move-to-workspace-right = ["<Super><Control>l"];
          move-to-workspace-up = ["<Super><Control>k"];
          panel-run-dialog = lib.gvariant.mkEmptyArray "s";
          switch-applications = lib.gvariant.mkEmptyArray "s";
          switch-applications-backward = lib.gvariant.mkEmptyArray "s";
          switch-group = lib.gvariant.mkEmptyArray "s";
          switch-group-backward = lib.gvariant.mkEmptyArray "s";
          switch-input-source = lib.gvariant.mkEmptyArray "s";
          switch-input-source-backward = lib.gvariant.mkEmptyArray "s";
          switch-panels = lib.gvariant.mkEmptyArray "s";
          switch-panels-backward = lib.gvariant.mkEmptyArray "s";
          switch-to-workspace-1 = ["<Super>1"];
          switch-to-workspace-10 = ["<Super>0"];
          switch-to-workspace-2 = ["<Super>2"];
          switch-to-workspace-3 = ["<Super>3"];
          switch-to-workspace-4 = ["<Super>4"];
          switch-to-workspace-5 = ["<Super>5"];
          switch-to-workspace-6 = ["<Super>6"];
          switch-to-workspace-7 = ["<Super>7"];
          switch-to-workspace-8 = ["<Super>8"];
          switch-to-workspace-9 = ["<Super>9"];
          switch-to-workspace-down = ["<Super>j"];
          switch-to-workspace-last = lib.gvariant.mkEmptyArray "s";
          switch-to-workspace-left = ["<Super>h"];
          switch-to-workspace-right = ["<Super>l"];
          switch-to-workspace-up = ["<Super>k"];
          toggle-maximized = ["<Control><Super>m"];
          unmaximize = lib.gvariant.mkEmptyArray "s";

          # Additional keybindings to ensure complete source control
          always-on-top = lib.gvariant.mkEmptyArray "s";
          lower = lib.gvariant.mkEmptyArray "s";
          maximize-horizontally = lib.gvariant.mkEmptyArray "s";
          maximize-vertically = lib.gvariant.mkEmptyArray "s";
          move-to-workspace-11 = lib.gvariant.mkEmptyArray "s";
          move-to-workspace-12 = lib.gvariant.mkEmptyArray "s";
          panel-main-menu = lib.gvariant.mkEmptyArray "s";
          raise = lib.gvariant.mkEmptyArray "s";
          raise-or-lower = lib.gvariant.mkEmptyArray "s";
          set-spew-mark = lib.gvariant.mkEmptyArray "s";
          show-desktop = lib.gvariant.mkEmptyArray "s";
          switch-to-workspace-11 = lib.gvariant.mkEmptyArray "s";
          switch-to-workspace-12 = lib.gvariant.mkEmptyArray "s";
          switch-windows = lib.gvariant.mkEmptyArray "s";
          switch-windows-backward = lib.gvariant.mkEmptyArray "s";
          toggle-above = lib.gvariant.mkEmptyArray "s";
          toggle-fullscreen = lib.gvariant.mkEmptyArray "s";
          toggle-on-all-workspaces = lib.gvariant.mkEmptyArray "s";
        };

        "org/gnome/mutter/keybindings" = {
          # System defaults - explicitly set to maintain control
          cancel-input-capture = ["<Super><Shift>Escape"];
          rotate-monitor = ["XF86RotateWindows"];
          switch-monitor = ["<Super>p" "XF86Display"];
          toggle-tiled-left = lib.gvariant.mkEmptyArray "s";
          toggle-tiled-right = lib.gvariant.mkEmptyArray "s";
        };

        "org/gnome/desktop/wm/preferences" = {
          action-middle-click-titlebar = "lower";
          button-layout = "icon,appmenu:minimize,maximize,close";
          num-workspaces = lib.gvariant.mkInt32 10;
          # Workspace names (1-based): ["www", "dev", "cmd", "git", "doc", "mda", "gtd", "net", "oth", "rnd"]
          # Workspace indices for auto-move-windows (0-based): 0=www, 1=dev, 2=cmd, 3=git, 4=doc, 5=mda, 6=gtd, 7=net, 8=oth, 9=rnd
          workspace-names = ["www" "dev" "cmd" "git" "doc" "mda" "gtd" "net" "oth" "rnd"];
        };

        "org/gnome/gnome-screenshot" = {
          delay = lib.gvariant.mkInt32 0;
          include-pointer = false;
          last-save-directory = "file:///home/tom/Pictures";
        };

        "org/gnome/nautilus/compression" = {
          default-compression-format = "7z";
        };

        "org/gnome/nautilus/icon-view" = {
          default-zoom-level = "extra-large";
        };

        "org/gnome/nautilus/preferences" = {
          default-folder-viewer = "list-view";
          migrated-gtk-settings = true;
          search-filter-time-type = "last_modified";
        };

        "org/gnome/settings-daemon/plugins/media-keys" = {
          mic-mute = ["XF86AudioMicMute"];
          next = ["XF86AudioNext"];
          pause = ["XF86AudioPause"];
          play = ["XF86AudioPlay"];
          playback-forward = ["XF86AudioForward"];
          playback-rewind = ["XF86AudioRewind"];
          previous = ["XF86AudioPrev"];
          screen-brightness-down = ["XF86MonBrightnessDown"];
          screen-brightness-up = ["XF86MonBrightnessUp"];
          stop = ["XF86AudioStop"];
          touchpad-toggle = ["XF86TouchpadToggle"];
          volume-down-static = ["XF86AudioLowerVolume"];
          volume-mute = ["XF86AudioMute"];
          volume-step = lib.gvariant.mkInt32 5;
          volume-up-static = ["XF86AudioRaiseVolume"];
        };

        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";
        };

        # Auto Move Windows Extension Configuration
        # Maps applications to workspaces (0-based index for extension)
        # Workspace mapping: 0=www, 1=dev, 2=cmd, 3=git, 4=doc, 5=mda, 6=gtd, 7=net, 8=oth, 9=rnd
        # Note: Workspace names are 1-based in GNOME UI, but extension uses 0-based indices
        "org/gnome/shell/extensions/auto-move-windows" = {
          # Application list format: ['desktop-file', workspace-index]
          # Applications will automatically move to assigned workspaces on launch
          # Desktop files must match exactly (check /usr/share/applications/ or ~/.local/share/applications/)
          application-list = [
            "['librewolf.desktop', 0]" # Librewolf → workspace 1 (www) - index 0
            "['cursor.desktop', 1]" # Cursor → workspace 2 (dev) - index 1
            "['obsidian.desktop', 3]" # Obsidian → workspace 4 (git) - index 3
            "['spotify.desktop', 5]" # Spotify → workspace 6 (mda) - index 5
            "['discord.desktop', 7]" # Discord → workspace 8 (oth) - index 7
            "['discord.desktop', 7]" # Discord → workspace 8 (oth) - index 7
          ];
        };
      };
    }
  ];
}
