# Colocated suite for features/cli/fish/havamal.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./havamal.nix;
in
  assay.suite "havamal" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;

    # default.nix sources ${plugin}/share/fish/vendor_conf.d/Hávamál.fish. That path must be
    # created here rather than left to buildFishPlugin's installPhase finding conf.d/ upstream,
    # so a rename breaks the build instead of every interactive fish start.
    # See docs/adr/0005-shell-strategy.md.
    installsVendorConfEntry =
      assay.eq (builtins.match ".*vendor_conf\\.d/Hávamál\\.fish.*" src != null) true;

    installsStanzas = assay.eq (builtins.match ".*share/fish/stanzas.*" src != null) true;
  }
