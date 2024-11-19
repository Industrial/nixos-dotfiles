{
  inputs,
  pkgs,
  ...
}: let
  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.system}.forVSCodeVersion "1.92.0";
  vscodeWithExtensions = pkgs.vscode-with-extensions.override {
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
      # extensions.vscode-marketplace.continue.continue
      extensions.vscode-marketplace.saoudrizwan.claude-dev
      extensions.vscode-marketplace.supermaven.supermaven

      # Testing
      # This adapter converter is needed for other language test adapter
      # extensions like Test Explorer UI
      #extensions.vscode-marketplace.ms-vscode.test-adapter-converter
      extensions.vscode-marketplace.hbenl.vscode-test-explorer

      # File Types
      ## GraphQL
      extensions.vscode-marketplace.graphql.vscode-graphql-syntax
      extensions.vscode-marketplace.graphql.vscode-graphql
      ## Markdown
      extensions.vscode-marketplace.yzhang.markdown-all-in-one
      extensions.vscode-marketplace.geeklearningio.graphviz-markdown-preview
      ## JavaScript / TypeScript
      extensions.vscode-marketplace.dbaeumer.vscode-eslint
      extensions.vscode-marketplace.biomejs.biome
      # extensions.vscode-marketplace.denoland.vscode-deno
      extensions.vscode-marketplace.oven.bun-vscode
      extensions.vscode-marketplace.vitest.explorer
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
      #extensions.vscode-marketplace.ms-toolsai.jupyter-renderers
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
      extensions.vscode-marketplace.donjayamanne.githistory
      extensions.vscode-marketplace.eamodio.gitlens
      extensions.vscode-marketplace.mhutchie.git-graph
      extensions.vscode-marketplace.sugatoray.vscode-git-extension-pack
      ## PlantUML
      extensions.vscode-marketplace.jebbs.plantuml
      ## AutoHotkey
      extensions.vscode-marketplace.thqby.vscode-autohotkey2-lsp
      ## EdgeDB
      extensions.vscode-marketplace.magicstack.edgedb
      ## Haskell
      extensions.vscode-marketplace.haskell.haskell
      extensions.vscode-marketplace.hoovercj.haskell-linter
      extensions.vscode-marketplace.justusadam.language-haskell
      extensions.vscode-marketplace.phoityne.phoityne-vscode
      # PureScript
      extensions.vscode-marketplace.mvakula.vscode-purty
      extensions.vscode-marketplace.nwolverson.ide-purescript
      extensions.vscode-marketplace.nwolverson.language-purescript
      # Rust
      extensions.vscode-marketplace.zhangyue.rust-mod-generator
      extensions.vscode-marketplace.dustypomerleau.rust-syntax
      extensions.vscode-marketplace.lorenzopirro.rust-flash-snippets
      extensions.vscode-marketplace.rust-lang.rust-analyzer
      extensions.vscode-marketplace.swellaby.vscode-rust-test-adapter
      # TOML
      extensions.vscode-marketplace.tamasfe.even-better-toml
    ];
  };
in {
  environment.systemPackages = [
    vscodeWithExtensions

    # TypeScript
    pkgs.biome

    # Nix
    pkgs.alejandra
    pkgs.nixd

    # Haskell
    #pkgs.ghc
    pkgs.haskell-language-server
    pkgs.hlint

    # PureScript
    pkgs.nodePackages.purescript-psa
    pkgs.nodePackages.purs-tidy
    pkgs.nodePackages.purty

    # Rust
    pkgs.rustfmt
    pkgs.leptosfmt
  ];
}
