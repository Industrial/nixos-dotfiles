{...}: {
  programs = {
    nixvim = {
      plugins = {
        # Commenting plugin. Use `gcc` or `gbc`.
        comment = {
          enable = true;
        };
      };

      keymaps = [
        {
          # Toggle Line Comment in Normal mode.
          mode = "n";
          key = "<C-/>";
          action = "<Plug>(comment_toggle_linewise_current)";
        }
        {
          # Toggle Block Comment in Normal mode.
          mode = "n";
          key = "<C-S-/>";
          action = "<Plug>(comment_toggle_blockwise_current)";
        }
        {
          # Toggle Line Comment in Normal mode.
          mode = "v";
          key = "<C-/>";
          action = "<Plug>(comment_toggle_linewise_visual)";
        }
        {
          # Toggle Block Comment in Normal mode.
          mode = "v";
          key = "<C-S-/>";
          action = "<Plug>(comment_toggle_blockwise_visual)";
        }
      ];

      extraConfigLua = ''
        local comment = require('Comment')
        comment.setup()
      '';
    };
  };

  # # Prevents you from using motions and tells you how to fix your behaviour.
  # # Really gives you a hard time.
  # programs.nixvim.plugins.hardtime.enable = true;
}
