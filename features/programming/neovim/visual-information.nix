{...}: {
  # Shows the context you are in on the top of the buffer.
  programs.nixvim.plugins.barbecue.enable = true;

  # Shows indentation levels with thin vertical lines.
  programs.nixvim.plugins.indent-blankline.enable = true;

  # Highlights usages of the keyword under the cursor (using TreeSitter / LSP)
  programs.nixvim.plugins.illuminate.enable = true;

  # # Panel for showing warnings and errors.
  # programs.nixvim.plugins.trouble = {
  #   enable = true;

  #   settings = {
  #     position = "right";
  #   };
  # };

  # # Popup for output messages.
  # programs.nixvim.plugins.noice.enable = true;

  # Display a column with signs when necessary.
  programs.nixvim.opts.signcolumn = "auto:1-9";

  # Highlight the line the cursor is on.
  programs.nixvim.opts.cursorline = true;
}
