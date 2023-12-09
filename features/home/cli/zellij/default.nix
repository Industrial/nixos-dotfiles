{
  c9config,
  pkgs,
  ...
}: {
  programs.zellij.enable = true;

  # TODO: Describe why I don't want this.
  programs.zellij.enableFishIntegration = false;

  programs.zellij.settings = {
    layout_dir = "${c9config.userdir}/.dotfiles/features/home/cli/zellij/layouts";
    theme_dir = "${c9config.userdir}/.dotfiles/features/home/cli/zellij/themes";
    theme = "stylix";
    default_layout = "system";
    default_mode = "normal";

    default_shell = "fish";
    on_force_close = "detach";
    simplified_ui = false;
    pane_frames = true;
    mouse_mode = true;
    scroll_buffer_size = 10000;
    copy_command = "xclip -selection clipboard";
    copy_clipboard = "system";
    copy_on_select = true;
    scrollback_editor = "$EDITOR";
    mirror_session = true;
    auto_layouts = true;

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
