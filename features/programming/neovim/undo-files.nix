{
  config,
  settings,
  ...
}: {
  # Use undo files.
  programs.nixvim.opts.undofile = true;

  # Directory to put undo files in.
  programs.nixvim.opts.undodir = "${settings.userdir}/.config/nvim/undo";
}
