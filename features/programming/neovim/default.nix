{
  inputs,
  settings,
  pkgs,
  lib,
  ...
}: let
  options = import ./options;
in {
  imports = [
    ./backup-files.nix
    ./buffer-search.nix
    ./buffers.nix
    ./color-scheme.nix
    ./completion.nix
    ./copy-paste.nix
    ./debug-adapter-protocol.nix
    ./diagnostic-signs.nix
    ./file-tabs.nix
    ./file-tree-sidebar.nix
    ./find-modal-dialog.nix
    ./folds.nix
    ./git.nix
    ./keybind-menu.nix
    ./language-support.nix
    ./line-numbers.nix
    ./movement.nix
    ./quickfix.nix
    ./refactoring.nix
    ./saving-files.nix
    ./splits.nix
    ./status-line.nix
    ./swap-files.nix
    ./tab-line.nix
    ./testing.nix
    ./undo-files.nix
    ./visual-information.nix

    ./initialize.nix
  ];

  programs.nixvim.enable = true;

  programs.nixvim.plugins = {
    # - Telescope
    # TODO: https://github.com/nix-community/nixvim/tree/main/plugins/telescope
    # TODO: Map keys correctly. I want keys for file search, buffer search, and git search.
    telescope = {
      enable = true;
    };

    # - UI
    # - Utils
    startify = {
      enable = true;
    };
    auto-session = {
      enable = true;
    };
    autoclose = {
      enable = true;
    };
    endwise = {
      enable = true;
    };
    # TODO: Check out.
    # TODO: https://github.com/folke/flash.nvim
    # flash = {
    #   enable = true;
    # };
    # Give hints for vim motions.
    # hardtime = {
    #   enable = true;
    # };
    illuminate = {
      enable = true;
    };
    # TODO: https://github.com/nix-community/nixvim/blob/main/plugins/utils/nix-develop.nix
    # nix-develop = {
    #   enable = true;
    # };
    # # TODO: https://github.com/nix-community/nixvim/blob/main/plugins/utils/ollama.nix
    # ollama = {
    #   enable = true;
    # };
    # https://github.com/akinsho/toggleterm.nvim
    toggleterm = {
      enable = true;
    };
    # https://github.com/moll/vim-bbye
    vim-bbye = {
      enable = true;
    };
    wilder = {
      enable = true;
    };
  };

  programs.nixvim.globals = {
    # Disable NetRW
    loaded_netrw = 1;
    loaded_netrwPlugin = 1;

    # Set the map leader to space
    mapleader = " ";
  };

  environment.systemPackages = with pkgs; [
    xsel
    xclip
  ];
}
