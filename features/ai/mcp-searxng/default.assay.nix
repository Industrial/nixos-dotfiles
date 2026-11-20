# Colocated suite for features/ai/mcp-searxng/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "mcp-searxng") null cfg.environment.systemPackages;
  added = lib.subtractLists (nixos.packageNames nixos.baseline) (nixos.packageNames cfg);
in
  assay.suite "mcp-searxng" {
    # The MCP server .claude/mcp.json declares as `searxng` is on the system PATH.
    installsMcpServer = assay.eq (nixos.hasPackage cfg "mcp-searxng") true;
    addsOnlyTheServer = assay.eq added ["mcp-searxng"];
    installsColocatedPackage = assay.eq (lib.getVersion pkg) "2.1.0";
    # The SearXNG instance it talks to is features/network/searx's; this feature runs none.
    runsNoSearxInstance = assay.eq cfg.services.searx.enable false;
  }
