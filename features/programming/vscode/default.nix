{
  settings,
  inputs,
  pkgs,
  ...
}: let
  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.system};

  vscodeWithExtensions = pkgs.vscode-with-extensions.override {
    vscodeExtensions = [
      # Themes
      extensions.vscode-marketplace.zhuangtongfa.material-theme
      extensions.vscode-marketplace.pkief.material-icon-theme
      extensions.vscode-marketplace.tintedtheming.base16-tinted-themes

      # Vim
      extensions.vscode-marketplace.vscodevim.vim

      # Visual Feedback
      extensions.vscode-marketplace.usernamehw.errorlens
      extensions.vscode-marketplace.vspacecode.whichkey

      # Completion
      extensions.vscode-marketplace.github.copilot
      extensions.vscode-marketplace-release.github.copilot-chat

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
      ## PlantUML
      extensions.vscode-marketplace.jebbs.plantuml

      # Testing
      extensions.vscode-marketplace.hbenl.vscode-test-explorer
      extensions.vscode-marketplace.ms-playwright.playwright
      extensions.vscode-marketplace.ms-vscode.test-adapter-converter
      # extensions.vscode-marketplace.vitest.explorer

      # # Remote / SSH
      # extensions.vscode-marketplace.ms-vscode-remote.remote-ssh
      # extensions.vscode-marketplace.ms-vscode-remote.vscode-remote-extensionpack

      # # Text to Speech
      extensions.vscode-marketplace.ms-vscode.vscode-speech
    ];
  };
in {
  environment.systemPackages = with pkgs; [
    vscodeWithExtensions

    # Nix
    alejandra
    # nixd
  ];

  system.activationScripts.linkFile = {
    text = ''
      mkdir -p /home/${settings.username}/.config/Code/User
      ln -sf ${pkgs.writeTextFile {
        name = "keybindings.json";
        text = builtins.readFile ./.config/Code/User/keybindings.json;
      }} /home/${settings.username}/.config/Code/User/keybindings.json

      ln -sf ${pkgs.writeTextFile {
        name = "settings.json";
        text = builtins.readFile ./.config/Code/User/settings.json;
      }} /home/${settings.username}/.config/Code/User/settings.json
    '';
  };
}
