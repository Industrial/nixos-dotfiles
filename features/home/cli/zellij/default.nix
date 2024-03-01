{
  settings,
  pkgs,
  ...
}: {
  programs.zellij.enable = true;

  # TODO: Describe why I don't want this.
  programs.zellij.enableFishIntegration = false;

  programs.zellij.settings = {
    layout_dir = "${settings.userdir}/.dotfiles/features/home/cli/zellij/layouts";
    theme_dir = "${settings.userdir}/.dotfiles/features/home/cli/zellij/themes";

    auto_layouts = true;
    copy_command = "xclip -selection clipboard";
    default_layout = "system";
    default_mode = "normal";
    default_shell = "nu";
    mouse_mode = true;
    on_force_close = "quit";
    scroll_buffer_size = 10000;
    session_serialization = false;
    theme = "stylix";

    ui = {
      pane_frames = {
        rounded_corners = true;
        hide_session_name = false;
      };
    };

    # Not supported correctly, put them in the layout files.
    keybinds = {};
  };

  home.packages = with pkgs; [
    xclip
    xsel
  ];
}
