# Colocated suite for features/cli/fish/havamal.nix — the Hávamál fish plugin derivation.
#
# default.nix sources ${plugin}/share/fish/vendor_conf.d/Hávamál.fish, and
# features/cli/nushell links ${plugin}/share/fish/stanzas. Both paths must be created by this
# derivation's buildPhase rather than left to buildFishPlugin's installPhase finding conf.d/
# upstream, so a rename breaks the build instead of every interactive fish start.
# See docs/adr/0005-shell-strategy.md.
#
# The derivation is instantiated with the same pkgs a host evaluates fish/default.nix with, so
# the store path the fish config sources is checked against this exact derivation.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  system = nixos.evalSystem {modules = [./default.nix];};
  pkgs = system._module.args.pkgs;
  plugin = pkgs.callPackage ./havamal.nix {};

  vendorConf = "share/fish/vendor_conf.d/Hávamál.fish";
in
  assay.suite "havamal" {
    namesThePlugin = assay.eq plugin.pname "Hávamál";
    # The upstream tag is the version: rev = version.
    fetchesTheVersionTag = assay.eq plugin.src.rev plugin.version;
    pinsTheTag = assay.eq plugin.version "v0.3.1";

    installsVendorConfEntry =
      assay.eq (lib.hasInfix "install -m644 $src/conf.d/Hávamál.fish $out/${vendorConf}" plugin.buildPhase) true;
    installsStanzas =
      assay.eq (lib.hasInfix "cp -r $src/stanzas/* $out/share/fish/stanzas/" plugin.buildPhase) true;

    # The path the fish feature sources is this derivation's vendor_conf.d entry.
    fishSourcesTheInstalledEntry = assay.eq (lib.hasInfix (builtins.unsafeDiscardStringContext "source ${plugin}/${vendorConf}")
      system.config.programs.fish.interactiveShellInit)
    true;
  }
