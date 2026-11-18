# Colocated suite for features/ai/lean-ctx/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "lean-ctx" {
    hasSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
    callsPackageNix = assay.eq (builtins.match ".*callPackage ./package.nix.*" src != null) true;

    # Every lean-ctx build must write the same hook path into the shared
    # ~/.claude, or concurrent repos flip it to their own store path.
    pinsHookBinaryEnv = assay.eq (builtins.match ".*LEAN_CTX_HOOK_BINARY = hookBinary.*" src != null) true;
    hookBinaryIsSystemProfile = assay.eq (builtins.match ".*hookBinary = \"/run/current-system/sw/bin/lean-ctx\".*" src != null) true;
    setsConfigViaUserOneshot = assay.eq (builtins.match ".*lean-ctx config set hook_binary.*" src != null) true;
  }
