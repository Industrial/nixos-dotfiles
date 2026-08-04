# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
    let
      pkgs = { docker = "docker"; "docker-compose" = "docker-compose"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages
  '';
in
  assay.suite "docker-compose" {
    systemPackages = assay.eq packages ''[ "docker" "docker-compose" ]'';
  }
