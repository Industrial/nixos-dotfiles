{
  config,
  settings,
  ...
}: let
  home = config.users.users.${settings.username}.home;
in {
  # Use undo files.
  programs.nixvim.opts.undofile = true;

  # Directory to put undo files in.
  programs.nixvim.opts.undodir = "${home}/.config/nvim/undo";
}
