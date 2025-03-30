{...}: {
  # https://github.com/nix-community/nixvim/blob/main/plugins/utils/which-key.nix
  programs = {
    nixvim = {
      plugins = {
        which-key = {
          enable = true;

          settings = {
            plugins = {
              # marks = false;
              registers = true;
              spelling = {
                enabled = true;
              };
              presets = {
                operators = true;
                motions = true;
                textObjects = true;
                windows = true;
                nav = true;
                z = true;
                g = true;
              };
            };

            layout = {
              width = {
                min = 20;
                max = 50;
              };
              height = {
                min = 4;
                max = 25;
              };
              spacing = 3;
              align = "center";
            };

            window = {
              # top = 1;
              # left = 1;
              # right = 1;
              # bottom = 1;
            };
          };
        };
      };

      opts = {
        # This sets the timeout of map leaders to 0, causing which-key to pop up
        # immediately for all possible keybindings.
        timeoutlen = 0;
      };
    };
  };
}
