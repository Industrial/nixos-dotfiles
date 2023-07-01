{...}: {
  programs.zellij.enable = true;

  #programs.zellij.enableFishIntegration = true;

  programs.zellij.settings = {
    layout_dir = "/home/tom/.dotfiles/features/home/zellij/layouts";
    theme_dir = "/home/tom/.dotfiles/features/home/zellij/themes";
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

    themes = {
      nord = {
        fg = "#D8DEE9";
        bg = "#2E3440";
        black = "#3B4252";
        red = "#BF616A";
        green = "#A3BE8C";
        yellow = "#EBCB8B";
        blue = "#81A1C1";
        magenta = "#B48EAD";
        cyan = "#88C0D0";
        white = "#E5E9F0";
        orange = "#D08770";
      };
    };
  };
}
