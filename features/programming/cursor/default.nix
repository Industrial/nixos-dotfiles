{
  inputs,
  pkgs,
  settings,
  ...
}: let
  cursorAgentExe = pkgs.lib.getExe pkgs.cursor-cli;

  # Cursor's shell wrapper hardcodes ~/.local/bin/cursor-agent and auto-installs
  # upstream FHS binaries that fail on NixOS (stub-ld). Install an immutable
  # delegate script at the path Cursor expects so updates cannot replace it.
  cursorAgentLocalWrapper = pkgs.writeShellScript "cursor-agent-local-wrapper" ''
    case "''${1-}" in
      update)
        echo "cursor-agent is managed by NixOS (pkgs.cursor-cli); run nixos-rebuild switch" >&2
        exit 0
        ;;
    esac
    exec ${cursorAgentExe} "$@"
  '';

  # TODO: We need a way to manage the MCP servers. Add the JSON file to the .config/Cursor/mcp.json and link it correctly.
  # Override license for unfree extensions to allow evaluation
  allowUnfreeExtension = drv:
    drv.overrideAttrs (prev: {
      meta =
        (prev.meta or {})
        // {
          license = [];
        };
    });

  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.forVSCodeVersion "1.105.1";
  # # Use an older VSCode version for vscode-lldb to get compatible version (1.11.8)
  # # Version 1.11.8 of vscode-lldb requires an older VSCode version filter
  # extensionsForLldb = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.forVSCodeVersion "1.75.0";

  # Expose ElixirLS launcher scripts where the VS Code extension expects them.
  elixirLsRelease = pkgs.runCommand "elixir-ls-release" {} ''
    mkdir -p $out/bin $out/share/elixir-ls
    ln -s ${pkgs.elixir-ls}/bin/* $out/bin/
    for script in ${pkgs.elixir-ls}/scripts/*; do
      ln -s "$script" $out/share/elixir-ls/$(basename "$script")
    done
  '';

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
      extensions.vscode-marketplace.astral-sh.ty
      extensions.vscode-marketplace.littlefoxteam.vscode-python-test-adapter
      extensions.vscode-marketplace.ms-python.debugpy
      extensions.vscode-marketplace.ms-python.python

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

      ## Nushell
      extensions.vscode-marketplace.thenuprojectcontributors.vscode-nushell-lang

      ## Elixir
      pkgs.vscode-extensions.elixir-lsp.vscode-elixir-ls
      pkgs.vscode-extensions.phoenixframework.phoenix

      ## Git
      (allowUnfreeExtension extensions.vscode-marketplace.mhutchie.git-graph)
      extensions.vscode-marketplace.sugatoray.vscode-git-extension-pack
      # extensions.vscode-marketplace.rust-lang.rust
      extensions.vscode-marketplace.rust-lang.rust-analyzer
      extensions.vscode-marketplace.swellaby.vscode-rust-test-adapter
      # TODO: Marked as broken.
      # extensions.vscode-marketplace.vadimcn.vscode-lldb  # Marked as broken in nixpkgs

      # TOML
      extensions.vscode-marketplace.tamasfe.even-better-toml

      # Astro
      extensions.vscode-marketplace.astro-build.astro-vscode

      # GraphViz
      # pkgs.vscode-extensions.joaompinto.vscode-graphviz
      extensions.vscode-marketplace.efanzh.graphviz-preview

      # Terraform
      extensions.vscode-marketplace.hashicorp.terraform

      # Mermaid
      extensions.vscode-marketplace.mermaidchart.vscode-mermaid-chart
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
      ty
      uv

      # Elixir
      elixir
      elixirLsRelease
    ];
  };

  system.activationScripts.cursorAgentLocalWrapper = {
    text = ''
      local_bin="${settings.userdir}/.local/bin"
      share_agent="${settings.userdir}/.local/share/cursor-agent"

      mkdir -p "$local_bin"

      for name in cursor-agent agent; do
        target="$local_bin/$name"
        chattr -i "$target" 2>/dev/null || true
        rm -f "$target"
        cp ${cursorAgentLocalWrapper} "$target"
        chmod 755 "$target"
        chown ${settings.username}: "$target"
        chattr +i "$target" 2>/dev/null || true
      done

      rm -rf "$share_agent"
    '';
  };
}
