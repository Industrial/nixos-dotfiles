let
  assay = import ../common/assay/default.nix;
  src = builtins.readFile ./server.nix;
in
  assay.suite "server-profile" {
    hasNfsServer = assay.eq (builtins.match ".*nfs-server.*" src != null) true;
    noGaming = assay.eq (builtins.match ".*gaming.nix.*" src != null) false;
    noAi = assay.eq (builtins.match ".*profiles/ai.*" src != null) false;
  }
