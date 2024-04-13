{...}: {
  # Shows the context you are in on the top of the buffer.
  programs.nixvim.plugins.barbecue.enable = true;

  # Display a column with signs when necessary.
  programs.nixvim.opts.signcolumn = "auto";

  # Highlight the line the cursor is on.
  programs.nixvim.opts.cursorline = true;

  # Don"t highlight the column the cursor is on.
  programs.nixvim.opts.cursorcolumn = false;

  # Highlights usages of the keyword under the cursor (using TreeSitter / LSP)
  programs.nixvim.plugins.illuminate.enable = true;
}
