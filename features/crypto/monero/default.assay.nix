# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { "monero-cli" = "monero-cli"; "monero-gui" = "monero-gui"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "monero" {
    systemPackages = assay.eq packages ''[ "monero-cli" "monero-gui" ]'';
  }
