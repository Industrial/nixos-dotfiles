{
  settings,
  inputs,
  pkgs,
  ...
}: let
  spagoPkgs =
    import (builtins.fetchGit {
      name = "spago-0.20.7";
      url = "https://github.com/NixOS/nixpkgs/";
      ref = "refs/heads/nixpkgs-unstable";
      rev = "d1c3fea7ecbed758168787fe4e4a3157e52bc808";
    }) {
      system = pkgs.system;
    };

  spagoOld = spagoPkgs.haskellPackages.spago;

  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.system};

  userSettings = import ./userSettings.nix;
  keybindings = import ./keybindings.nix;
in {
  programs.vscode = {
    enable = true;
    # package = pkgs.vscodium;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    userSettings = userSettings;
    keybindings = keybindings;
    extensions = with pkgs.vscode-extensions; [
      # Themes
      extensions.vscode-marketplace.zhuangtongfa.material-theme
      extensions.vscode-marketplace.pkief.material-icon-theme
      extensions.vscode-marketplace.tintedtheming.base16-tinted-themes

      # Vim
      extensions.vscode-marketplace.vscodevim.vim
      # asvetliakov.vscode-neovim

      # Visual Feedback
      extensions.vscode-marketplace.usernamehw.errorlens
      extensions.vscode-marketplace.vspacecode.whichkey

      # Completion
      pkgs.vscode-extensions.github.copilot
      pkgs.vscode-extensions.github.copilot-chat

      # File Types
      ## GraphQL
      extensions.vscode-marketplace.graphql.vscode-graphql-syntax
      extensions.vscode-marketplace.graphql.vscode-graphql
      ## Markdown
      extensions.vscode-marketplace.yzhang.markdown-all-in-one
      ## JavaScript / TypeScript
      extensions.vscode-marketplace.dbaeumer.vscode-eslint
      extensions.vscode-marketplace.denoland.vscode-deno
      extensions.vscode-marketplace.ms-vscode.js-debug
      extensions.vscode-marketplace.ms-vscode.js-debug-companion
      ## Python
      extensions.vscode-marketplace.littlefoxteam.vscode-python-test-adapter
      extensions.vscode-marketplace.ms-python.black-formatter
      extensions.vscode-marketplace.ms-python.debugpy
      extensions.vscode-marketplace.ms-python.flake8
      extensions.vscode-marketplace.ms-python.isort
      extensions.vscode-marketplace.ms-python.python
      extensions.vscode-marketplace.ms-python.vscode-pylance
      extensions.vscode-marketplace.tamasfe.even-better-toml
      ## Jupyter
      extensions.vscode-marketplace.ms-toolsai.jupyter
      extensions.vscode-marketplace.ms-toolsai.jupyter-renderers
      ## Nix
      extensions.vscode-marketplace.bbenoist.nix
      extensions.vscode-marketplace.jnoortheen.nix-ide
      extensions.vscode-marketplace.kamadorueda.alejandra
      ## YAML
      extensions.vscode-marketplace.redhat.vscode-yaml
      ## Docker
      extensions.vscode-marketplace.ms-azuretools.vscode-docker
      ## Dotenv
      extensions.vscode-marketplace.mikestead.dotenv
      ## Git
      extensions.vscode-marketplace.mhutchie.git-graph
      extensions.vscode-marketplace.sugatoray.vscode-git-extension-pack
      ## PureScript
      extensions.vscode-marketplace.nwolverson.language-purescript
      extensions.vscode-marketplace.nwolverson.ide-purescript
      ## MoonScript
      extensions.vscode-marketplace.vgalaktionov.moonscript
      ## Haskell
      extensions.vscode-marketplace.haskell.haskell
      extensions.vscode-marketplace.hoovercj.haskell-linter
      extensions.vscode-marketplace.justusadam.language-haskell

      # Testing
      extensions.vscode-marketplace.hbenl.vscode-test-explorer
      extensions.vscode-marketplace.ms-playwright.playwright
      extensions.vscode-marketplace.ms-vscode.test-adapter-converter
      # extensions.vscode-marketplace.vitest.explorer

      # # Remote / SSH
      # extensions.vscode-marketplace.ms-vscode-remote.remote-ssh
      # extensions.vscode-marketplace.ms-vscode-remote.vscode-remote-extensionpack

      # # Text to Speech
      # extensions.vscode-marketplace.ms-vscode.vscode-speech
    ];
  };

  home.packages = with pkgs; [
    # Nix
    # TODO: Try the `nil` language server with the VSCode extension
    alejandra

    # PureScript
    nodePackages.purescript-language-server
    nodePackages.purs-tidy
    purescript
    spagoOld

    # Haskell
    hlint
    haskell-language-server
  ];
}
