# TODO: Copilot Chat: https://github.com/nix-community/nixvim/issues/1425
{
  pkgs,
  inputs,
  settings,
  ...
}: let
  nixvim' = inputs.nixvim.legacyPackages."${settings.system}";
  nvim = nixvim'.makeNixvim {};
  neovimModule = (
    if pkgs.stdenv.isDarwin
    then inputs.nixvim.nixDarwinModules.nixvim
    else inputs.nixvim.nixosModules.nixvim
  );
in {
  imports = [
    inputs.nixvim.nixosModules.nixvim
    # neovimModule
    ./backup-files.nix
    ./buffer-search.nix
    ./buffers.nix
    ./color-scheme.nix
    ./commenting.nix
    ./copy-paste.nix
    ./debug-adapter-protocol.nix
    ./diagnostic-signs.nix
    ./editing.nix
    ./file-tabs.nix
    ./file-tree-sidebar.nix
    ./folds.nix
    ./git.nix
    ./indentation.nix
    ./initialize.nix
    ./keybind-menu.nix
    ./language-support.nix
    ./line-numbers.nix
    ./movement.nix
    ./quickfix.nix
    ./refactoring.nix
    ./saving-files.nix
    ./searching.nix
    ./splits.nix
    ./status-line.nix
    ./swap-files.nix
    ./tab-line.nix
    ./terminal.nix
    ./testing.nix
    ./undo-files.nix
    ./visual-information.nix
    ./wildmenu.nix
  ];

  programs = {
    nixvim = {
      enable = true;
      globals = {
        # Disable NetRW
        loaded_netrw = 1;
        loaded_netrwPlugin = 1;
        # Set the map leader to space
        mapleader = " ";
      };
    };
  };

  environment = {
    systemPackages = with pkgs; [
      nvim
      xsel
      xclip
    ];
  };
}
