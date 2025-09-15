# GNOME dconf Configuration
# This file contains all the dconf settings for GNOME desktop environment
{
  pkgs,
  lib,
  config,
  ...
}: {
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
          ];

          disabled-extensions = lib.gvariant.mkEmptyArray "as";

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
          picture-uri = "file:///home/tom/.local/share/backgrounds/2024-08-18-19-15-47-wallhaven-m9yymk.jpg";
          picture-uri-dark = "file:///home/tom/.local/share/backgrounds/2024-08-18-19-15-47-wallhaven-m9yymk.jpg";
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
          picture-uri = "file:///home/tom/.local/share/backgrounds/2024-08-18-19-15-47-wallhaven-m9yymk.jpg";
          primary-color = "#2E3440";
          secondary-color = "#3B4252";
        };

        "org/gnome/desktop/sound" = {
          event-sounds = false;
          input-feedback-sounds = false;
          theme-name = "freedesktop";
        };

        "org/gnome/shell/keybindings" = {
          focus-active-notification = lib.gvariant.mkEmptyArray "as";
          open-new-window-application-1 = lib.gvariant.mkEmptyArray "as";
          open-new-window-application-2 = lib.gvariant.mkEmptyArray "as";
          open-new-window-application-3 = lib.gvariant.mkEmptyArray "as";
          open-new-window-application-4 = lib.gvariant.mkEmptyArray "as";
          open-new-window-application-5 = lib.gvariant.mkEmptyArray "as";
          open-new-window-application-6 = lib.gvariant.mkEmptyArray "as";
          open-new-window-application-7 = lib.gvariant.mkEmptyArray "as";
          open-new-window-application-8 = lib.gvariant.mkEmptyArray "as";
          open-new-window-application-9 = lib.gvariant.mkEmptyArray "as";
          screenshot = ["<Shift>Print"];
          screenshot-window = ["<Alt>Print"];
          shift-overview-down = lib.gvariant.mkEmptyArray "as";
          shift-overview-up = lib.gvariant.mkEmptyArray "as";
          show-screen-recording-ui = lib.gvariant.mkEmptyArray "as";
          show-screenshot-ui = ["Print"];
          switch-to-application-1 = lib.gvariant.mkEmptyArray "as";
          switch-to-application-2 = lib.gvariant.mkEmptyArray "as";
          switch-to-application-3 = lib.gvariant.mkEmptyArray "as";
          switch-to-application-4 = lib.gvariant.mkEmptyArray "as";
          switch-to-application-5 = lib.gvariant.mkEmptyArray "as";
          switch-to-application-6 = lib.gvariant.mkEmptyArray "as";
          switch-to-application-7 = lib.gvariant.mkEmptyArray "as";
          switch-to-application-8 = lib.gvariant.mkEmptyArray "as";
          switch-to-application-9 = lib.gvariant.mkEmptyArray "as";
          toggle-application-view = lib.gvariant.mkEmptyArray "as";
          toggle-message-tray = lib.gvariant.mkEmptyArray "as";
          toggle-overview = lib.gvariant.mkEmptyArray "as";
          toggle-quick-settings = lib.gvariant.mkEmptyArray "as";
        };

        "org/gnome/desktop/wm/keybindings" = {
          # Empty array of strings (as) - no keybinding assigned
          activate-window-menu = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          begin-move = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          begin-resize = lib.gvariant.mkEmptyArray "as";
          close = ["<Control><Super>c"];
          # Empty array of strings (as) - no keybinding assigned
          cycle-group = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          cycle-group-backward = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          cycle-panels = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          cycle-panels-backward = lib.gvariant.mkEmptyArray "as";
          cycle-windows = ["<Super>Tab"];
          cycle-windows-backward = ["<Super><Shift>Tab"];
          # Empty array of strings (as) - no keybinding assigned
          maximize = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          # minimize = lib.gvariant.mkEmptyArray "as";
          minimize = lib.gvariant.mkEmptyArray "s";
          move-to-center = ["<Super><Control>f"];
          move-to-corner-ne = ["<Super><Control>t"];
          move-to-corner-nw = ["<Super><Control>e"];
          move-to-corner-se = ["<Super><Control>b"];
          move-to-corner-sw = ["<Super><Control>c"];
          # Empty array of strings (as) - no keybinding assigned
          move-to-monitor-down = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          move-to-monitor-left = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          move-to-monitor-right = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          move-to-monitor-up = lib.gvariant.mkEmptyArray "as";
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
          # Empty array of strings (as) - no keybinding assigned
          move-to-workspace-last = lib.gvariant.mkEmptyArray "as";
          move-to-workspace-left = ["<Super><Control>h"];
          move-to-workspace-right = ["<Super><Control>l"];
          move-to-workspace-up = ["<Super><Control>k"];
          # Empty array of strings (as) - no keybinding assigned
          panel-run-dialog = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-applications = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-applications-backward = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-group = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-group-backward = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-input-source = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-input-source-backward = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-panels = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-panels-backward = lib.gvariant.mkEmptyArray "as";
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
          # Empty array of strings (as) - no keybinding assigned
          switch-to-workspace-last = lib.gvariant.mkEmptyArray "as";
          switch-to-workspace-left = ["<Super>h"];
          switch-to-workspace-right = ["<Super>l"];
          switch-to-workspace-up = ["<Super>k"];
          toggle-maximized = ["<Control><Super>m"];
          # Empty array of strings (as) - no keybinding assigned
          unmaximize = lib.gvariant.mkEmptyArray "as";

          # Additional keybindings to ensure complete source control
          # Empty array of strings (as) - no keybinding assigned
          always-on-top = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          lower = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          maximize-horizontally = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          maximize-vertically = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          move-to-workspace-11 = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          move-to-workspace-12 = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          panel-main-menu = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          raise = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          raise-or-lower = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          set-spew-mark = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          show-desktop = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-to-workspace-11 = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-to-workspace-12 = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-windows = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          switch-windows-backward = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          toggle-above = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          toggle-fullscreen = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          toggle-on-all-workspaces = lib.gvariant.mkEmptyArray "as";
        };

        "org/gnome/mutter/keybindings" = {
          # System defaults - explicitly set to maintain control
          cancel-input-capture = ["<Super><Shift>Escape"];
          rotate-monitor = ["XF86RotateWindows"];
          switch-monitor = ["<Super>p" "XF86Display"];
          # Empty array of strings (as) - no keybinding assigned
          toggle-tiled-left = lib.gvariant.mkEmptyArray "as";
          # Empty array of strings (as) - no keybinding assigned
          toggle-tiled-right = lib.gvariant.mkEmptyArray "as";
        };

        "org/gnome/desktop/wm/preferences" = {
          action-middle-click-titlebar = "lower";
          button-layout = "icon,appmenu:minimize,maximize,close";
          num-workspaces = lib.gvariant.mkInt32 10;
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
      };
    }
  ];
}
