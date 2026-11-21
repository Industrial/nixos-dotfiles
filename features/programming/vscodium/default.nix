# VSCodium — the MIT-licensed build of VS Code, set up to match
# features/programming/cursor. Both features can stay enabled side by side.
#
# What stays identical, and how:
#   - settings.json / keybindings.json: no copy is kept here. The activation
#     script links ~/.config/VSCodium/User/* to Cursor's files in the repo, so
#     an edit made in either editor shows up in both. Cursor-only keys
#     (`cursor.*`) are unknown settings to VSCodium, which ignores them.
#   - extensions: the same list as cursor/default.nix, in the same order. Keep
#     the two in step; default.assay.nix fails if their marketplace IDs drift.
#
# Differences VSCodium forces on us:
#   - ms-vscode-remote.remote-ssh is licensed only for Microsoft builds and does
#     not run on VSCodium. jeanp413.open-remote-ssh takes its place.
#   - Cursor's mcp.json belongs to Cursor's own AI agent. VSCodium has no agent
#     to read it, so nothing is linked for it.
#   - Extensions are matched against VSCodium's own engine version
#     (pkgs.vscodium.version), not Cursor's 1.105.1 pin, so each one resolves to
#     the newest release compatible with the editor that actually loads it.
{
  inputs,
  pkgs,
  settings,
  ...
}: let
  emeraldVscodeExtension = import ../emerald/vscode-extension.nix {inherit inputs pkgs;};
  voltaicVscodeExtension = import ../voltaic/vscode-extension.nix {inherit inputs pkgs;};

  # Override license for unfree extensions to allow evaluation
  allowUnfreeExtension = drv:
    drv.overrideAttrs (prev: {
      meta =
        (prev.meta or {})
        // {
          license = [];
        };
    });

  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.forVSCodeVersion pkgs.vscodium.version;

  vscodiumWithExtensions = pkgs.vscode-with-extensions.override {
    vscode = pkgs.vscodium;
    vscodeExtensions = [
      # Remote SSH: open-source stand-in for ms-vscode-remote.remote-ssh
      extensions.open-vsx.jeanp413.open-remote-ssh

      # Themes
      extensions.vscode-marketplace.tintedtheming.base16-tinted-themes

      # Vim
      extensions.vscode-marketplace.vscodevim.vim

      # Visual Feedback
      extensions.vscode-marketplace.vspacecode.whichkey
      extensions.vscode-marketplace.yoavbls.pretty-ts-errors

      # Testing
      # This adapter converter is needed for other language test adapter
      # extensions like Test Explorer UI
      extensions.vscode-marketplace.ms-vscode.test-adapter-converter
      extensions.vscode-marketplace.hbenl.vscode-test-explorer

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

      # TOML
      extensions.vscode-marketplace.tamasfe.even-better-toml

      # MoonScript
      extensions.vscode-marketplace.vgalaktionov.moonscript

      # Emerald and Voltaic (built from source — not on any marketplace)
      emeraldVscodeExtension
      voltaicVscodeExtension

      # Mermaid
      extensions.vscode-marketplace.mermaidchart.vscode-mermaid-chart
    ];
  };

  cursorUserDir = "${settings.userdir}/.dotfiles/features/programming/cursor/.config/Cursor/User";
  codiumDir = "${settings.userdir}/.config/VSCodium";
in {
  # Same language tooling as the cursor feature; the shared store paths dedup.
  environment.systemPackages = with pkgs; [
    vscodiumWithExtensions
    alejandra
    nixd
    ty
    uv
  ];

  imports = [../../../lib/vfiles.nix];

  # Linked from the checkout (Cursor's User dir), so a change made in the editor lands in
  # git; the committed copy stands in while the checkout is missing.
  vfiles.files = builtins.listToAttrs (map (file: {
    name = "${codiumDir}/User/${file}";
    value = {
      source = "${cursorUserDir}/${file}";
      fallback = ../cursor/.config/Cursor/User + "/${file}";
      user = settings.username;
    };
  }) ["settings.json" "keybindings.json"]);

  # The pre-vfiles script, kept for the rollback (features.nixos.vfiles off, lib/vfiles.nix).
  vfiles.legacy.linkVscodiumConfig = {
    text = ''
      mkdir -p "${codiumDir}/User"
      for file in settings.json keybindings.json; do
        target="${codiumDir}/User/$file"
        if [ -f "$target" ] && [ ! -L "$target" ]; then
          mv "$target" "$target.backup"
        fi
        ln -sfn "${cursorUserDir}/$file" "$target"
      done
      chown -R ${settings.username}:users "${codiumDir}"
    '';
  };
}
