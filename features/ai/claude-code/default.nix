# Claude Code - Agentic coding tool from Anthropic.
#
# System-wide harness. ~/.claude is a symlink to ./.claude (bin/link-files-nixos),
# mirroring how features/ai/hermes-agent owns ~/.hermes. The payload carries the
# settings, the MCP server declarations, the command and skill rosters, and the
# id-workflow plugin marketplace under .claude/harness.
#
# The MCP servers .claude/mcp.json declares are provided by the sibling features
# imported below, so enabling claude-code alone is enough for the harness to work.
{pkgs, ...}: {
  imports = [
    ../context7
    ../lean-ctx
    ../maestro
    ../mcp-searxng
    ../roam-code
  ];

  environment = {
    systemPackages = with pkgs; [
      claude-code

      # id-workflow hooks and the statusline shell out to these.
      bash
      git
      jq
    ];
  };
}
