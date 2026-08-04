# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
    let
      pkgs = { qbittorrent = "qbittorrent"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages
  '';
in
  assay.suite "qbittorrent" {
    systemPackages = assay.eq packages ''[ "qbittorrent" ]'';
  }
