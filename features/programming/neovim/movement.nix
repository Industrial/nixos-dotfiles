{...}: {
  # make movement keys wrap to the next/previous line
  programs.nixvim.opts.whichwrap = "b,s,h,l,<,>,[,]";
  # Fix backspace behaviour
  programs.nixvim.opts.backspace = "indent,eol,start";
  # keep a certain number of lines visible (center the cursor, document moves
  # under it)
  programs.nixvim.opts.scrolloff = 50;
  # Make the mouse usable everywhere.
  programs.nixvim.opts.mouse = "a";

  # # Comments.
  # nvimComment = require "nvim_comment"
  # nvimComment.setup!
  # # Map <C-_> as well as <C-/> because apparently terminals are terrible.
  # vim.keymap.set "n", "<C-_>", ":CommentToggle<cr>",
  #   noremap: true
  # vim.keymap.set "n", "<C-/>", ":CommentToggle<cr>",
  #   noremap: true
  # vim.keymap.set "v", "<C-_>", ":\"<,\">CommentToggle<cr>",
  #   noremap: true
  # vim.keymap.set "v", "<C-/>", ":\"<,\">CommentToggle<cr>",
  #   noremap: true

  programs.nixvim.plugins.vim-bbye.enable = true;
}
