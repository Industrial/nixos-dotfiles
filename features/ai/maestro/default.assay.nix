# Colocated suite for features/ai/maestro/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "maestro") null cfg.environment.systemPackages;
  added = lib.subtractLists (nixos.packageNames nixos.baseline) (nixos.packageNames cfg);
in
  assay.suite "maestro" {
    # The MCP server .claude/mcp.json declares as `maestro` is on the system PATH.
    installsMaestro = assay.eq (nixos.hasPackage cfg "maestro") true;
    addsOnlyMaestro = assay.eq added ["maestro"];
    installsColocatedPackage = assay.eq (lib.getVersion pkg) "0.106.1";
  }
