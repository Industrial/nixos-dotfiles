{
  config,
  settings,
  ...
}: {
  # Use swap files.
  programs.nixvim.opts.swapfile = true;

  # Directory to put swap files in.
  programs.nixvim.opts.directory = "${settings.userdir}/.config/nvim/temp";
}
