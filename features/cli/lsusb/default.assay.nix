# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
    let
      pkgs = { usbutils = "usbutils"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages
  '';
in
  assay.suite "lsusb" {
    systemPackages = assay.eq packages ''[ "usbutils" ]'';
  }
