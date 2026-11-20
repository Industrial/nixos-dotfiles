# Colocated suite for features/ai/roam-code/package.nix.
# Asserts on the evaluated derivation: identity, pinned release, and the python-set
# override that keeps fastmcp buildable.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  inherit (nixos.evalSystem {modules = [];}) pkgs;
  drv = pkgs.callPackage ./package.nix {};
  fastmcp = lib.findFirst (p: lib.getName p == "fastmcp") null drv.propagatedBuildInputs;
  mcp = lib.findFirst (p: lib.getName p == "mcp") null fastmcp.propagatedBuildInputs;
in
  assay.suite "roam-code-package" {
    namesRoamCode = assay.eq drv.pname "roam-code";
    pinsVersion = assay.eq drv.version "13.0";
    fetchesMatchingSdist = assay.eq drv.src.urls ["mirror://pypi/r/roam_code/roam_code-13.0.tar.gz"];
    pinsPypiHash = assay.eq drv.src.outputHash "sha256-M1QJ0742yaBhpZG1eFwX+s+e0tyo0QTy9P+ltzFsMBU=";

    # nixpkgs ships mcp 2.x, which marks fastmcp-slim 3.x broken. The override pins mcp to the
    # last 1.x release in a python set scoped to this package; dropping it makes the package
    # unbuildable rather than merely older.
    pinsMcpToOneX = assay.eq (lib.getVersion mcp) "1.30.0";
    # Rebuilt against mcp 1.x, one OAuth-proxy storage test asserts a 2.x-era shape.
    relaxesFastmcpCheck = assay.eq fastmcp.doCheck false;

    # fastmcp is an optional extra upstream; it must be forced into the runtime closure or
    # `roam mcp` has no transport.
    injectsFastmcpIntoClosure = assay.eq (builtins.elem "fastmcp" (map lib.getName drv.propagatedBuildInputs)) true;

    exposesRoamAsMainProgram = assay.eq drv.meta.mainProgram "roam";
  }
