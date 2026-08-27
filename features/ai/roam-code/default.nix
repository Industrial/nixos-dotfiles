# roam-code — AI-native code intelligence MCP server (tree-sitter code graph).
# Declared as the `roam-code` MCP server in features/ai/claude-code/.claude/mcp.json.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
