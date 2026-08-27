# mcp-searxng — web search MCP server backed by a SearXNG instance.
# Declared as the `searxng` MCP server in features/ai/claude-code/.claude/mcp.json,
# which points it at the local SearXNG from features/network/searx (port 4001).
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
