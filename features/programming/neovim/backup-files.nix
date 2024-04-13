{
  config,
  settings,
  ...
}: let
  home = config.users.users.${settings.username}.home;
in {
  programs.nixvim.opts.backup = true;
  programs.nixvim.opts.writebackup = true;
  programs.nixvim.opts.backupdir = "${home}/.config/nvim/backup";
  programs.nixvim.opts.backupcopy = "yes";
}
