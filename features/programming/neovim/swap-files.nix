{
  config,
  settings,
  ...
}: let
  home = config.users.users.${settings.username}.home;
in {
  # Use swap files.
  programs.nixvim.opts.swapfile = true;

  # Directory to put swap files in.
  programs.nixvim.opts.directory = "${home}/.config/nvim/temp";
}
