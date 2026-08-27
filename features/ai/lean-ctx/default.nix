# lean-ctx — context engineering layer for agents.
# Declared as the `lean-ctx` MCP server in features/ai/claude-code/.claude/mcp.json.
{pkgs, ...}: {
  environment = {
    systemPackages = [
      (pkgs.callPackage ./package.nix {})
    ];
    variables.LEAN_CTX_COMPRESS = "1";
  };
}
