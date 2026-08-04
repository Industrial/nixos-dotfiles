# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { "monero-cli" = "monero-cli"; "monero-gui" = "monero-gui"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "monero" {
    systemPackages = assay.eq mod.environment.systemPackages [ "monero-cli" "monero-gui" ];
  }
