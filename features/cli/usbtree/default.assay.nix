let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {
      callPackage = path: args: "usbtree";
    };
  in
    import ./default.nix {inherit pkgs;};
in
  assay.suite "usbtree" {
    systemPackages = assay.eq mod.environment.systemPackages ["usbtree"];
  }
