# Colocated suite: V-268136 — PKCS#11 token support installed.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268136.nix {pkgs = {opencryptoki = "opencryptoki-pkg";};};
in
  assay.suite "stig-V-268136" {
    installsOpencryptoki = assay.eq mod.environment.systemPackages ["opencryptoki-pkg"];
    installsExactlyOnePackage = assay.eq (builtins.length mod.environment.systemPackages) 1;
  }
