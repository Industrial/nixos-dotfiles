# maestro — local-first agent harness for the spec-to-ship loop.
# Declared as the `maestro` MCP server in features/ai/claude-code/.claude/mcp.json.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
