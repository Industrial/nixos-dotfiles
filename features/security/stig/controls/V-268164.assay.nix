# Colocated suite: V-268164 — usermod execution audited.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268164.nix {};
in
  assay.suite "stig-V-268164" {
    rules = assay.eq mod.security.audit.rules [
      "-a always,exit -F path=/run/current-system/sw/bin/usermod -F perm=x -F auid>=1000 -F auid!=unset -k privileged-usermod"
    ];
    # A path watch on the NixOS profile path, not the FHS location — on NixOS the latter does
    # not exist and the rule would silently never fire.
    usesNixOSProfilePath = assay.eq (builtins.match ".*/run/current-system/sw/bin/usermod.*" (builtins.head mod.security.audit.rules) != null) true;
  }
