# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { python312 = "python312"; uv = "uv"; pipx = "pipx"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "python" {
    systemPackages = assay.eq mod.environment.systemPackages [ "python312" "uv" "pipx" ];
  }
