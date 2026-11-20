# Assay: VS Code with its extension set and language tooling.
#
# Claims read the evaluated config. The extension list is not an option, so an overlay wraps
# vscode-with-extensions.override and keeps the list it was called with on the result; the
# package itself is still built from the real list.
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
            override = args: (prev.vscode-with-extensions.override args) // {recordedExtensions = args.vscodeExtensions;};
          };
      })
    ];
  };
  cfg = nixos.eval {modules = [./default.nix recordExtensions];};
  code = lib.findFirst (p: lib.getName p == "vscode") null cfg.environment.systemPackages;
  ids = map (e: e.vscodeExtUniqueId) code.recordedExtensions;
  has = id: builtins.elem id ids;
in
  assay.suite "vscode" {
    installsVscode = assay.eq (nixos.hasPackage cfg "vscode") true;
    installsTooling = assay.eq (map (nixos.hasPackage cfg) ["biome" "alejandra" "nixd"]) [true true true];

    shipsVimAndTheme = assay.eq (map has ["vscodevim.vim" "tintedtheming.base16-tinted-themes"]) [true true];
    shipsJsToolchainExtensions =
      assay.eq (map has ["biomejs.biome" "dbaeumer.vscode-eslint" "oven.bun-vscode" "vitest.explorer"]) [true true true true];
    shipsNixExtensions = assay.eq (map has ["bbenoist.nix" "kamadorueda.alejandra"]) [true true];
    shipsClaudeDev = assay.eq (has "saoudrizwan.claude-dev") true;
    # rust-analyzer stays out (RAM; see features/programming/helix).
    noRustAnalyzerExtension = assay.eq (has "rust-lang.rust-analyzer") false;
    noDuplicateExtensions = assay.eq (lib.unique ids) ids;
  }
