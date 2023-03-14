{
  pkgs,
  config,
  ...
}: {
  dconf = {
    settings = {
      # Window Manager
      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
        num-workspaces = 9;
      };
      "org/gnome/mutter" = {
        attach-modal-dialogs = true;
        dynamic-workspaces = false;
        edge-tiling = true;
        focus-change-on-pointer-rest = true;
        workspaces-only-on-primary = false;
      };
      "org/gnome/mutter/keybindings" = {
        toggle-tiled-left = [""];
        toggle-tiled-right = [""];
        toggle-tiled-top = [""];
        toggle-tiled-bottom = [""];
      };
      "org/gnome/shell" = {
        always-show-log-out = true;
        app-picker-layout = "favorites";
        app-picker-mode = "all";
        app-picker-view = "list";
        command-history = [];
        development-tools = true;
        disabled-extensions = ["material-shell@papyelgringo"];
        disable-extension-version-validation = false;
        disable-user-extensions = false;
        enabled-extensions = [];
        favorite-apps = [
          "firefox.desktop"
          "org.gnome.Nautilus.desktop"
          "org.gnome.Console.desktop"
        ];
        last-selected-power-profile = "balanced";
        looking-glass-history = [];
        remember-mount-password = false;
      };
      "org/gnome/shell/app-switcher" = {
        current-workspace-only = true;
      };
      "org/gnome/shell/extensions/apps-menu" = {
        apps-menu-toggle-menu = [""];
      };
      "org/gnome/shell/extensions/auto-move-windows" = {
        application-list = [];
      };
      "org/gnome/shell/extensions/native-window-placement" = {
        use-more-screen = true;
        window-captions-on-top = true;
      };
      "org/gnome/shell/extensions/window-list" = {
        display-all-workspaces = false;
        grouping-mode = "never";
        show-on-all-monitors = true;
      };
      "org/gnome/shell/overrides" = {
        attach-modal-dialogs = true;
        dynamic-workspaces = true;
        edge-tiling = true;
        focus-change-on-pointer-rest = true;
        workspaces-only-on-primary = false;
      };
      "org/gnome/shell/weather" = {
        automatic-location = false;
        locations = [];
      };
      "org/gnome/shell/window-switcher" = {
        app-icon-mode = "both";
        current-workspace-only = true;
      };
      "org/gnome/shell/world-clocks" = {
        locations = [];
      };
      "org/gnome/system/location" = {
        enabled = false;
      };

      # Desktop
      "org/gnome/desktop/background" = {
        color-shading-type = "solid";
        picture-opacity = 100;
        picture-options = "zoom";
        #picture-uri = "file:///home/alex/Pictures/Wallpapers/1.jpg";
        picture-uri = "";
        picture-uri-dark = "";
        primary-color = "#336699";
        secondary-color = "#6699cc";
        show-desktop-icons = false;
      };

      # Keybinds
      "org/gnome/shell/keybindings" = {
        focus-active-notification = [""];
        open-application-menu = [""];
        screenshot = [""];
        screenshot-window = [""];
        shift-overview-down = [""];
        shift-overview-up = [""];
        show-screen-recording-ui = [""];
        show-screenshot-ui = [""];
        switch-to-application-1 = [""];
        switch-to-application-2 = [""];
        switch-to-application-3 = [""];
        switch-to-application-4 = [""];
        switch-to-application-5 = [""];
        switch-to-application-6 = [""];
        switch-to-application-7 = [""];
        switch-to-application-8 = [""];
        switch-to-application-9 = [""];
        toggle-application-view = [""];
        toggle-message-tray = [""];
        toggle-overview = [""];
      };
      "org/gnome/mutter/wayland/keybindings" = {
        restore-shortcuts = [""];
      };
      "org/gnome/desktop/wm/keybindings" = {
        activate-window-menu = [""];
        always-on-top = [""];
        begin-move = [""];
        begin-resize = [""];
        close = ["<Super><Control>q"];
        cycle-group = ["<Super>Tab"];
        cycle-group-backward = ["<Super><Shift>Tab"];
        cycle-panels = [""];
        cycle-panels-backward = [""];
        cycle-windows = [""];
        cycle-windows-backward = [""];
        lower = [""];
        maximize = [""];
        maximize-horizontally = [""];
        maximize-vertically = [""];
        minimize = [""];
        move-to-center = ["<Super><Control>f"];
        move-to-corner-ne = ["<Super><Control>t"];
        move-to-corner-nw = ["<Super><Control>e"];
        move-to-corner-se = ["<Super><Control>b"];
        move-to-corner-sw = ["<Super><Control>c"];
        move-to-monitor-down = [""];
        move-to-monitor-left = [""];
        move-to-monitor-right = [""];
        move-to-monitor-up = [""];
        move-to-side-e = ["<Super><Control>g"];
        move-to-side-n = ["<Super><Control>r"];
        move-to-side-s = ["<Super><Control>v"];
        move-to-side-w = ["<Super><Control>d"];
        move-to-workspace-1 = ["<Super><Control>1"];
        move-to-workspace-10 = [""];
        move-to-workspace-11 = [""];
        move-to-workspace-12 = [""];
        move-to-workspace-2 = ["<Super><Control>2"];
        move-to-workspace-3 = ["<Super><Control>3"];
        move-to-workspace-4 = ["<Super><Control>4"];
        move-to-workspace-5 = ["<Super><Control>5"];
        move-to-workspace-6 = ["<Super><Control>6"];
        move-to-workspace-7 = ["<Super><Control>7"];
        move-to-workspace-8 = ["<Super><Control>8"];
        move-to-workspace-9 = ["<Super><Control>9"];
        move-to-workspace-down = ["<Super><Control>j"];
        move-to-workspace-last = [""];
        move-to-workspace-left = ["<Super><Control>h"];
        move-to-workspace-right = ["<Super><Control>l"];
        move-to-workspace-up = ["<Super><Control>k"];
        panel-run-dialog = [""];
        raise = [""];
        raise-or-lower = [""];
        set-spew-mark = [""];
        show-desktop = [""];
        switch-applications = [""];
        switch-applications-backward = [""];
        switch-group = [""];
        switch-group-backward = [""];
        switch-input-source = [""];
        switch-input-source-backward = [""];
        switch-panels = [""];
        switch-panels-backward = [""];
        switch-to-workspace-1 = ["<Super>1"];
        switch-to-workspace-10 = [""];
        switch-to-workspace-11 = [""];
        switch-to-workspace-12 = [""];
        switch-to-workspace-2 = ["<Super>2"];
        switch-to-workspace-3 = ["<Super>3"];
        switch-to-workspace-4 = ["<Super>4"];
        switch-to-workspace-5 = ["<Super>5"];
        switch-to-workspace-6 = ["<Super>6"];
        switch-to-workspace-7 = ["<Super>7"];
        switch-to-workspace-8 = ["<Super>8"];
        switch-to-workspace-9 = ["<Super>9"];
        switch-to-workspace-down = ["<Super>j"];
        switch-to-workspace-left = ["<Super>h"];
        switch-to-workspace-right = ["<Super>l"];
        switch-to-workspace-up = ["<Super>k"];
        switch-windows = [""];
        switch-windows-backward = [""];
        toggle-above = [""];
        toggle-fullscreen = [""];
        toggle-maximized = ["<Super><Control>m"];
        toggle-on-all-workspaces = [""];
        toggle-shaded = [""];
        unmaximize = [""];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Super><Alt>t";
        command = "gnome-terminal";
        name = "open-terminal";
      };
    };
  };
}
