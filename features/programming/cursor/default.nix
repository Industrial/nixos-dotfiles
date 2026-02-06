{
  inputs,
  pkgs,
  ...
}: let
  # TODO: We need a way to manage the MCP servers. Add the JSON file to the .config/Cursor/mcp.json and link it correctly.
  # Override the license of the pylance extension
  resetLicense = drv:
    drv.overrideAttrs (prev: {
      meta =
        prev.meta
        // {
          license = [];
        };
    });

  # Override license for unfree extensions to allow evaluation
  allowUnfreeExtension = drv:
    drv.overrideAttrs (prev: {
      meta =
        (prev.meta or {})
        // {
          license = [];
        };
    });

  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.system}.forVSCodeVersion "1.105.1";
  # # Use an older VSCode version for vscode-lldb to get compatible version (1.11.8)
  # # Version 1.11.8 of vscode-lldb requires an older VSCode version filter
  # extensionsForLldb = inputs.nix-vscode-extensions.extensions.${pkgs.system}.forVSCodeVersion "1.75.0";

  cursorWithExtensions = pkgs.vscode-with-extensions.override {
    vscode = pkgs.code-cursor;
    vscodeExtensions = [
      pkgs.vscode-extensions.ms-vscode-remote.remote-ssh

      # extensions.vscode-marketplace.anysphere.remote-ssh

      # AI
      extensions.vscode-marketplace.thundercompute.thunder-compute

      # Themes
      extensions.vscode-marketplace.tintedtheming.base16-tinted-themes

      # Vim
      extensions.vscode-marketplace.vscodevim.vim

      # Visual Feedback
      extensions.vscode-marketplace.randomfractalsinc.vscode-data-preview
      # TODO: Not available?
      # extensions.vscode-marketplace.usernamehw.errorlens
      extensions.vscode-marketplace.vspacecode.whichkey
      extensions.vscode-marketplace.yoavbls.pretty-ts-errors

      # Testing
      # This adapter converter is needed for other language test adapter
      # extensions like Test Explorer UI
      extensions.vscode-marketplace.ms-vscode.test-adapter-converter
      extensions.vscode-marketplace.hbenl.vscode-test-explorer

      # File Types
      ## JavaScript / TypeScript
      extensions.vscode-marketplace.biomejs.biome
      extensions.vscode-marketplace.oven.bun-vscode
      # extensions.vscode-marketplace.vitest.explorer

      ## Python
      extensions.vscode-marketplace.charliermarsh.ruff
      extensions.vscode-marketplace.ms-python.mypy-type-checker
      extensions.vscode-marketplace.littlefoxteam.vscode-python-test-adapter
      extensions.vscode-marketplace.ms-python.debugpy
      extensions.vscode-marketplace.ms-python.python
      # TODO: What was wrong with this?
      # (resetLicense extensions.vscode-marketplace.ms-python.vscode-pylance)

      ## Jupyter
      extensions.vscode-marketplace.ms-toolsai.jupyter
      extensions.vscode-marketplace.ms-toolsai.jupyter-renderers

      ## Nix
      extensions.vscode-marketplace.bbenoist.nix
      # TODO: What was wrong with this?
      #extensions.vscode-marketplace.jnoortheen.nix-ide
      extensions.vscode-marketplace.kamadorueda.alejandra

      ## YAML
      extensions.vscode-marketplace.redhat.vscode-yaml

      ## Docker
      extensions.vscode-marketplace.ms-azuretools.vscode-docker

      ## Dotenv
      extensions.vscode-marketplace.mikestead.dotenv

      ## Git
      (allowUnfreeExtension extensions.vscode-marketplace.mhutchie.git-graph)
      extensions.vscode-marketplace.sugatoray.vscode-git-extension-pack
      # TODO: What was wrong with this?
      # extensions.vscode-marketplace.github.vscode-github-actions

      # Rust
      # extensions.vscode-marketplace.rust-lang.rust
      extensions.vscode-marketplace.rust-lang.rust-analyzer
      extensions.vscode-marketplace.swellaby.vscode-rust-test-adapter
      # TODO: Marked as broken.
      # extensions.vscode-marketplace.vadimcn.vscode-lldb  # Marked as broken in nixpkgs

      # TOML
      extensions.vscode-marketplace.tamasfe.even-better-toml
    ];
  };
in {
  environment = {
    systemPackages = with pkgs; [
      cursorWithExtensions
      cursor-cli

      # TypeScript
      biome

      # Nix
      alejandra
      nixd

      # Rust
      rustfmt

      # Python
      uv
    ];
  };
}
