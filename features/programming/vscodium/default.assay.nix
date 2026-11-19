# Colocated suite for features/programming/vscodium/default.nix
#
# VSCodium mirrors the cursor feature. These claims catch the two lists of
# extensions drifting apart, and the settings link pointing anywhere but
# Cursor's files.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  cursorSrc = builtins.readFile ./../cursor/default.nix;

  # Marketplace IDs on uncommented lines, in order of appearance.
  marketplaceIds = text: let
    lines = builtins.filter builtins.isString (builtins.split "\n" text);
    hit = l: builtins.match " *\\(?(allowUnfreeExtension )?extensions\\.vscode-marketplace\\.([A-Za-z0-9.-]+).*" l;
  in
    map (m: builtins.elemAt m 1) (builtins.filter (m: m != null) (map hit lines));
in
  assay.suite "vscodium" {
    sameMarketplaceExtensionsAsCursor = assay.eq (marketplaceIds src) (marketplaceIds cursorSrc);
    usesVscodium = assay.eq (builtins.match ".*vscode = pkgs\\.vscodium;.*" src != null) true;
    linksCursorSettings = assay.eq (builtins.match ".*features/programming/cursor/\\.config/Cursor/User.*" src != null) true;
    noMicrosoftRemoteSsh = assay.eq (builtins.match ".*\n *pkgs\\.vscode-extensions\\.ms-vscode-remote.*" src != null) false;
  }
