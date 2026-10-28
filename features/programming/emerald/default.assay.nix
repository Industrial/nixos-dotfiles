# Colocated suite: emerald compiler + language server from the flake input.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    inputs.emerald.packages."x86_64-linux".emerald = "emerald-pkg";
    pkgs.stdenv.hostPlatform.system = "x86_64-linux";
  };
in
  assay.suite "emerald" {
    installsOnePackage = assay.eq (builtins.length mod.environment.systemPackages) 1;

    # Selected per host platform from the flake input, not hardcoded to one system.
    selectsPackageForHostPlatform = assay.eq mod.environment.systemPackages ["emerald-pkg"];
  }
