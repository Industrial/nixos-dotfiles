# context7 — up-to-date library documentation MCP server (@upstash/context7-mcp).
# Declared as the `context7` MCP server in features/ai/claude-code/.claude/mcp.json.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
