# Colocated suite: V-268082 — consent banner on console logon.
let
  assay = import ./../../../../common/assay/default.nix;
  banner = import ./../lib/dow-banner.nix;
  mod = import ./V-268082.nix {};
in
  assay.suite "stig-V-268082" {
    usesTheSharedBanner = assay.eq mod.services.getty.helpLine banner.multiline;
    # The opening sentence is what the check greps for.
    opensCorrectly = assay.eq (builtins.match "You are accessing a U.S. Government.*" mod.services.getty.helpLine != null) true;
    isMultiParagraph = assay.eq (builtins.match ".*\n\n.*" mod.services.getty.helpLine != null) true;
    # V1R3 wording, not the pre-rename "Department of Defense".
    usesDoWWording = assay.eq (builtins.match ".*Department of Defense.*" mod.services.getty.helpLine) null;
  }
