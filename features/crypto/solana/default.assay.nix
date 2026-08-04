# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
    let
      pkgs = { "solana-cli" = "solana-cli"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages
  '';
in
  assay.suite "solana" {
    systemPackages = assay.eq packages ''[ "solana-cli" ]'';
  }
