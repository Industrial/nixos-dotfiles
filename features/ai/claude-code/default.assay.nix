# Colocated suite: systemPackages from stubbed pkgs, plus the MCP feature imports
# that make `claude-code` self-sufficient (the servers .claude/mcp.json declares).
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    "claude-code" = "claude-code";
    bash = "bash";
    git = "git";
    jq = "jq";
  };
  mod = import ./default.nix {inherit pkgs;};
  src = builtins.readFile ./default.nix;
in
  assay.suite "claude-code" {
    systemPackages = assay.eq mod.environment.systemPackages ["claude-code" "bash" "git" "jq"];
    importsFiveMcpFeatures = assay.eq (builtins.length mod.imports) 5;
    importsLeanCtx = assay.eq (builtins.match ".*lean-ctx.*" src != null) true;
    importsMaestro = assay.eq (builtins.match ".*maestro.*" src != null) true;
  }
