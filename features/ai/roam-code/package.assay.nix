# Colocated suite for features/ai/roam-code/package.nix.
# String-level guards (repo pattern): identity, pinned release, and the python-set override
# that keeps fastmcp buildable.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "roam-code-package" {
    namesRoamCode = assay.eq (has ".*pname = \"roam-code\";.*") true;
    pinsVersion = assay.eq (has ".*version = \"13\\.0\";.*") true;
    pinsPypiHash = assay.eq (has ".*hash = \"sha256-M1QJ0742yaBhpZG1eFwX\\+s\\+e0tyo0QTy9P\\+ltzFsMBU=\";.*") true;

    # nixpkgs ships mcp 2.x, which marks fastmcp-slim 3.x broken. The override pins mcp to the
    # last 1.x release; dropping it makes the package unbuildable rather than merely older.
    pinsMcpToOneX = assay.eq (has ".*version = \"1\\.30\\.0\";.*") true;
    overridesPythonSet = assay.eq (has ".*packageOverrides = pself: psuper:.*") true;
    # Brace-free pattern: Nix's regex engine rejects \{ as invalid.
    relaxesFastmcpCheck = assay.eq (has ".*fastmcp = psuper\\.fastmcp\\.overridePythonAttrs .doCheck = false;..*") true;

    # fastmcp is an optional extra upstream; it must be forced into the runtime closure or
    # `roam mcp` has no transport.
    injectsFastmcpIntoClosure = assay.eq (has ".*propagatedBuildInputs = with python3Packages; .fastmcp.;.*") true;

    exposesRoamAsMainProgram = assay.eq (has ".*mainProgram = \"roam\";.*") true;
  }
