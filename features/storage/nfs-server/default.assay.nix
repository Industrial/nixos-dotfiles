let
  assay = import ../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "nfs-server" {
    enablesServer = assay.eq (builtins.match ".*services\\.nfs\\.server.*enable = true.*" src != null) true;
    exportsData = assay.eq (builtins.match ".*/data .*" src != null) true;
    tailscaleFirewall = assay.eq (builtins.match ".*tailscale0.*allowedTCPPorts.*" src != null) true;
  }
