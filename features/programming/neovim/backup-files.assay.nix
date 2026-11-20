# Assay: neovim backup files.
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module, so they pin what it contributes, not how its source is spelled.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  eval = settings:
    (nixos.eval {
      modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./backup-files.nix];
      inherit settings;
    }).programs.nixvim.opts;
  opts = eval {};
in
  assay.suite "backup-files" {
    keepsBackups = assay.eq opts.backup true;
    backsUpBeforeOverwriting = assay.eq opts.writebackup true;

    # Copy, don't rename: renaming breaks hard links and watchers on the original file.
    copiesRatherThanRenames = assay.eq opts.backupcopy "yes";

    # Follows settings.userdir rather than a hard-coded home. Note: "config", not
    # ".config" as swap-files/undo-files use.
    backupDirFollowsUserdir =
      assay.eq (eval {userdir = "/home/probe";}).backupdir "/home/probe/config/nvim/backup";
  }
