{
  inputs,
  pkgs,
  ...
}: let
  version = "1.92.0";
  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.system};
  archive_fmt =
    if pkgs.stdenv.isDarwin
    then "zip"
    else "tar.gz";
  throwSystem = throw "Unsupported system: ${pkgs.system}";
  plat =
    {
      x86_64-linux = "linux-x64";
      x86_64-darwin = "darwin";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
      armv7l-linux = "linux-armhf";
    }
    .${pkgs.system}
    or throwSystem;
  sha256 =
    {
      x86_64-linux = "sha256-n9q14COlOmnEzLDF7ZkHwu3Y76lOb/fG9fqxTXZYPg0=";
      x86_64-darwin = "sha256-dTR+dG9Zf9v02uLs5SLBUcFgRTJjhPOpVpM1d6FlFQY=";
      aarch64-linux = "sha256-n9q14COlOmnEzLDF7ZkHwu3Y76lOb/fG9fqxTXZYPg0=";
      aarch64-darwin = "sha256-dTR+dG9Zf9v02uLs5SLBUcFgRTJjhPOpVpM1d6FlFQY=";
      armv7l-linux = "sha256-n9q14COlOmnEzLDF7ZkHwu3Y76lOb/fG9fqxTXZYPg0=";
    }
    .${pkgs.system}
    or throwSystem;
  vscodePatched = pkgs.vscode.overrideAttrs {
    version = version;
    src = pkgs.fetchurl {
      inherit sha256;
      name = "VSCode_${version}_${plat}.${archive_fmt}";
      url = "https://update.code.visualstudio.com/${version}/${plat}/stable";
    };
  };
  vscodeWithExtensions = pkgs.vscode-with-extensions.override {
    vscode = vscodePatched;
    vscodeExtensions = [
      # Themes
      extensions.vscode-marketplace.tintedtheming.base16-tinted-themes

      # Vim
      extensions.vscode-marketplace.vscodevim.vim

      # Visual Feedback
      extensions.vscode-marketplace.usernamehw.errorlens
      extensions.vscode-marketplace.vspacecode.whichkey
      extensions.vscode-marketplace.yoavbls.pretty-ts-errors

      # Completion
      # extensions.vscode-marketplace-release.github.copilot-chat
      # extensions.vscode-marketplace.github.copilot
      extensions.vscode-marketplace.supermaven.supermaven

      # File Types
      ## GraphQL
      extensions.vscode-marketplace.graphql.vscode-graphql-syntax
      extensions.vscode-marketplace.graphql.vscode-graphql
      ## Markdown
      extensions.vscode-marketplace.yzhang.markdown-all-in-one
      ## JavaScript / TypeScript
      extensions.vscode-marketplace.dbaeumer.vscode-eslint
      # extensions.vscode-marketplace.denoland.vscode-deno
      # extensions.vscode-marketplace.ms-vscode.js-debug
      # extensions.vscode-marketplace.ms-vscode.js-debug-companion
      extensions.vscode-marketplace.oven.bun-vscode
      extensions.vscode-marketplace.vitest.explorer
      # ## Python
      # extensions.vscode-marketplace.littlefoxteam.vscode-python-test-adapter
      # extensions.vscode-marketplace.ms-python.black-formatter
      # extensions.vscode-marketplace.ms-python.debugpy
      # extensions.vscode-marketplace.ms-python.flake8
      # extensions.vscode-marketplace.ms-python.isort
      # extensions.vscode-marketplace.ms-python.python
      # extensions.vscode-marketplace.ms-python.vscode-pylance
      # extensions.vscode-marketplace.tamasfe.even-better-toml
      # ## Jupyter
      # extensions.vscode-marketplace.ms-toolsai.jupyter
      # extensions.vscode-marketplace.ms-toolsai.jupyter-renderers
      ## Nix
      extensions.vscode-marketplace.bbenoist.nix
      extensions.vscode-marketplace.jnoortheen.nix-ide
      extensions.vscode-marketplace.kamadorueda.alejandra
      ## YAML
      extensions.vscode-marketplace.redhat.vscode-yaml
      # ## Docker
      # extensions.vscode-marketplace.ms-azuretools.vscode-docker
      ## Dotenv
      extensions.vscode-marketplace.mikestead.dotenv
      ## Git
      extensions.vscode-marketplace.mhutchie.git-graph
      extensions.vscode-marketplace.sugatoray.vscode-git-extension-pack
      ## PlantUML
      extensions.vscode-marketplace.jebbs.plantuml
      ## AutoHotkey
      # extensions.vscode-marketplace.mark-wiemer.vscode-autohotkey-plus-plus
      extensions.vscode-marketplace.thqby.vscode-autohotkey2-lsp
      ## EdgeDB
      extensions.vscode-marketplace.magicstack.edgedb
      # ## Erlang
      # extensions.vscode-marketplace.pgourlain.erlang
      # ## Haskell
      extensions.vscode-marketplace.haskell.haskell
      extensions.vscode-marketplace.hoovercj.haskell-linter
      extensions.vscode-marketplace.justusadam.language-haskell
      extensions.vscode-marketplace.phoityne.phoityne-vscode

      # # Testing
      # extensions.vscode-marketplace.hbenl.vscode-test-explorer
      # extensions.vscode-marketplace.ms-playwright.playwright
      # extensions.vscode-marketplace.ms-vscode.test-adapter-converter
    ];
  };
in {
  environment.systemPackages = [
    vscodeWithExtensions

    # Nix
    pkgs.alejandra
    pkgs.nixd

    # Haskell
    pkgs.ghc
    pkgs.haskell-language-server
    pkgs.hlint
  ];
}
