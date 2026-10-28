# Colocated suite: V-268084 — consent banner on the graphical greeter.
let
  assay = import ./../../../../common/assay/default.nix;
  banner = import ./../lib/dow-banner.nix;
  mod = import ./V-268084.nix {};
in
  assay.suite "stig-V-268084" {
    usesTheSharedBanner = assay.eq mod.services.displayManager.gdm.banner banner.singleLine;

    # Canonical path, not the fix text's services.xserver.displayManager.gdm.banner, which is
    # a renamed option.
    doesNotUseRenamedPath = assay.eq (mod.services ? xserver) false;

    # The greeter option takes a single string; a block with blank lines would render wrong.
    isSingleBlock = assay.eq (builtins.match ".*\n\n.*" mod.services.displayManager.gdm.banner) null;
    stillCarriesEveryParagraph = assay.eq (builtins.length (builtins.filter builtins.isString (builtins.split "\n" mod.services.displayManager.gdm.banner))) 7;
    usesDoWWording = assay.eq (builtins.match ".*Department of Defense.*" mod.services.displayManager.gdm.banner) null;
  }
