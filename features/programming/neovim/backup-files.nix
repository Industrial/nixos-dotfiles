{
  config,
  settings,
  ...
}: {
  programs.nixvim.opts.backup = true;
  programs.nixvim.opts.writebackup = true;
  programs.nixvim.opts.backupdir = "${settings.userdir}/config/nvim/backup";
  programs.nixvim.opts.backupcopy = "yes";
}
