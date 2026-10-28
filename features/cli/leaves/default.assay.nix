# Colocated suite: leaves is installed from the colocated package derivation.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    pkgs = {callPackage = path: args: "local-pkg:${builtins.baseNameOf (toString path)}";};
  };
in
  assay.suite "leaves" {
    installsOnePackage = assay.eq (builtins.length mod.environment.systemPackages) 1;

    # Built from ./package.nix rather than pulled from nixpkgs — leaves is not packaged there.
    buildsFromColocatedDerivation = assay.eq mod.environment.systemPackages ["local-pkg:package.nix"];
  }
