# Colocated suite for features/programming/openidea/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "openidea" {
    mentionsSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
    # `npx` must reach the login shell for the Agents panel's ACP adapters.
    provisionsNodejs = assay.eq (builtins.match ".*pkgs\\.nodejs.*" src != null) true;
  }
