# Assay: fleet remote access.
#
# comin itself moved to features/fleet/comin.nix and is enabled there per host
# (ADR-0002). The noCominEnable claim below is still load-bearing: activation
# semantics must not be smuggled into an access module.
let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./remote-access.nix;
in
  assay.suite "remote-access" {
    enablesTailscale = assay.eq (builtins.match ".*services\\.tailscale\\.enable = lib\\.mkForce true.*" src != null) true;
    importsSsh = assay.eq (builtins.match ".*network/ssh.*" src != null) true;
    importsOperatorSsh = assay.eq (builtins.match ".*operator-ssh\\.nix.*" src != null) true;
    noCominEnable = assay.eq (builtins.match ".*services\\.comin\\.enable.*" src != null) false;
  }
