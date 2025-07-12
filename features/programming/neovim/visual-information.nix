{...}: {
  programs = {
    nixvim = {
      opts = {
        # Show line numbers.
        number = true;
      };

      plugins = {
        # Shows the context you are in on the top of the buffer.
        barbecue = {
          enable = true;
        };

        # Shows indentation levels with thin vertical lines.
        indent-blankline = {
          enable = true;
        };

        # Highlights usages of the keyword under the cursor (using TreeSitter / LSP)
        illuminate = {
          enable = true;
        };
      };

      opts = {
        # Display a column with signs when necessary.
        signcolumn = "auto:1-9";

        # Highlight the line the cursor is on.
        cursorline = true;
      };
    };
  };

  # # Panel for showing warnings and errors.
  # programs.nixvim.plugins.trouble = {
  #   enable = true;

  #   settings = {
  #     position = "right";
  #   };
  # };

  # # Popup for output messages.
  # programs.nixvim.plugins.noice.enable = true;
}
