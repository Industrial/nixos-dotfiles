# Colocated suite for features/ai/roam-code/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "roam-code") null cfg.environment.systemPackages;
  added = lib.subtractLists (nixos.packageNames nixos.baseline) (nixos.packageNames cfg);
in
  assay.suite "roam-code" {
    # The MCP server .claude/mcp.json declares as `roam-code` (`roam mcp`) is on PATH.
    installsRoamCode = assay.eq (nixos.hasPackage cfg "roam-code") true;
    addsOnlyRoamCode = assay.eq added ["roam-code"];
    installsColocatedPackage = assay.eq (lib.getVersion pkg) "13.0";
    exposesRoamBinary = assay.eq pkg.meta.mainProgram "roam";
  }
