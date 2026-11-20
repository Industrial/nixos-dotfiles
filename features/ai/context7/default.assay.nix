# Colocated suite for features/ai/context7/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;
  cfg = nixos.eval {modules = [./default.nix];};
  server = lib.findFirst (p: lib.getName p == "context7-mcp") null cfg.environment.systemPackages;
  added = lib.subtractLists (nixos.packageNames nixos.baseline) (nixos.packageNames cfg);
in
  assay.suite "context7" {
    # The MCP server .claude/mcp.json declares as `context7` is on the system PATH.
    installsMcpServer = assay.eq (nixos.hasPackage cfg "context7-mcp") true;
    addsOnlyTheServer = assay.eq added ["context7-mcp"];
    # The installed package is the colocated derivation, not something else of that name.
    installsColocatedPackage = assay.eq (lib.getVersion server) "2.2.5";
    exposesContext7McpBinary = assay.eq server.meta.mainProgram "context7-mcp";
  }
