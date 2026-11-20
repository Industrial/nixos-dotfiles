# Assay: Cursor with its extension set, cursor-cli, and the immutable cursor-agent shim.
#
# Claims read the evaluated config. The extension list is not an option, so the suite records
# it with an overlay that wraps vscode-with-extensions.override and keeps the list it was
# called with on the result -- the real package is still built from the real list. The
# activation script and the shim it installs are generated text, matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  recordExtensions = {
    nixpkgs.overlays = [
      (final: prev: {
        vscode-with-extensions =
          prev.vscode-with-extensions
          // {
            override = args:
              (prev.vscode-with-extensions.override args)
              // {
                recordedEditor = args.vscode;
                recordedExtensions = args.vscodeExtensions;
              };
          };
      })
    ];
  };
  user = nixos.defaultSettings.username;
  home = nixos.defaultSettings.userdir;
  cfg = nixos.eval {modules = [./default.nix recordExtensions];};
  cursor = lib.findFirst (p: lib.getName p == "cursor") null cfg.environment.systemPackages;
  extensionIds = map (e: e.vscodeExtUniqueId) cursor.recordedExtensions;
  activation = cfg.system.activationScripts.cursorAgentLocalWrapper.text;
  activationHas = needle: lib.hasInfix needle activation;
  # The shim is a store script the activation copies into place; read it back (IFD is fine
  # in a suite) so the claims are about what actually lands in ~/.local/bin.
  shimPath = builtins.head (builtins.match ".*cp (/nix/store/[^ ]+-cursor-agent-local-wrapper) .*" activation);
  # builtins.match drops string context, and a store path without context is never built, so
  # readFile only worked where the file was already in the store (never on a fresh CI
  # runner). Re-attach the context of the derivation that produces the matched path.
  realised = path:
    builtins.appendContext path (lib.filterAttrs
      (drv: _: lib.hasSuffix "-${builtins.substring 33 (-1) (baseNameOf path)}.drv" drv)
      (builtins.getContext activation));
  shim = builtins.readFile (realised shimPath);
in
  assay.suite "cursor" {
    installsCursor = assay.eq (nixos.hasPackage cfg "cursor") true;
    # The editor inside the wrapper is nixpkgs' code-cursor, the same derivation.
    wrapsCodeCursor = assay.eq cursor.recordedEditor.drvPath (nixos.evalSystem {modules = [];}).pkgs.code-cursor.drvPath;
    installsCursorCli = assay.eq (nixos.hasPackage cfg "cursor-cli") true;
    installsNixTooling = assay.eq (map (nixos.hasPackage cfg) ["alejandra" "nixd"]) [true true];
    installsPythonTooling = assay.eq (map (nixos.hasPackage cfg) ["ty" "uv"]) [true true];

    # Built from source in this repo's flake inputs; on no marketplace.
    shipsEmeraldAndVoltaic =
      assay.eq (map (id: builtins.elem id extensionIds) ["emerald-lang.emerald-lang" "voltaic-lang.voltaic"]) [true true];
    # Microsoft's Remote-SSH, which runs on Cursor (VSCodium has to swap it out).
    shipsMicrosoftRemoteSsh = assay.eq (builtins.elem "ms-vscode-remote.remote-ssh" extensionIds) true;
    shipsVimAndTheme =
      assay.eq (map (id: builtins.elem id extensionIds) ["vscodevim.vim" "tintedtheming.base16-tinted-themes"]) [true true];
    # rust-analyzer stays out (RAM; see features/programming/helix).
    noRustAnalyzerExtension = assay.eq (builtins.elem "rust-lang.rust-analyzer" extensionIds) false;
    noDuplicateExtensions = assay.eq (lib.unique extensionIds) extensionIds;

    # Cursor's own wrapper hard-codes ~/.local/bin/cursor-agent and auto-installs FHS binaries
    # that hit stub-ld; a NixOS-managed shim takes both names, made immutable so an update
    # cannot replace it.
    shimInstalledUnderBothNames = assay.eq (activationHas "for name in cursor-agent agent; do") true;
    shimTargetsLocalBin = assay.eq (activationHas ''local_bin="${home}/.local/bin"'') true;
    shimMadeImmutable = assay.eq (activationHas ''chattr +i "$target"'') true;
    shimOwnedByOperator = assay.eq (activationHas "chown ${user}: \"$target\"") true;
    removesUpstreamAgentInstall = assay.eq (activationHas ''rm -rf "$share_agent"'') true;
    shimExecsNixpkgsCursorCli = assay.eq (builtins.match ".*exec /nix/store/[^ ]+-cursor-cli-[^ ]+/bin/[a-z-]+ \"\\$@\".*" shim != null) true;
    shimRefusesSelfUpdate = assay.eq (lib.hasInfix "managed by NixOS (pkgs.cursor-cli)" shim) true;
  }
