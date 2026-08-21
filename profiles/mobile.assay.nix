let
  assay = import ../common/assay/default.nix;
  src = builtins.readFile ./mobile.nix;
in
  assay.suite "mobile-profile" {
    hasNfsClient = assay.eq (builtins.match ".*nfs-client.*" src != null) true;
    noGaming = assay.eq (builtins.match ".*gaming.nix.*" src != null) false;
    noAi = assay.eq (builtins.match ".*profiles/ai.*" src != null) false;
  }
