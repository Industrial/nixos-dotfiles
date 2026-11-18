# Claude Code - Agentic coding tool from Anthropic.
#
# System-wide harness. ~/.claude is a symlink to ./.claude (bin/link-files-nixos),
# mirroring the layout this repo uses for agent harnesses. The payload carries the
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

      # The interpreter the uvx-launched MCP servers (fetch, git, time in
      # .mcp.json) run on. Without a system python, uv downloads a generic-linux
      # CPython that NixOS cannot exec (stub-ld, exit 127), and the servers die
      # with "Connection closed". .mcp.json pins UV_PYTHON_PREFERENCE=only-system
      # and UV_PYTHON_DOWNLOADS=never so uv picks this one.
      python3
    ];
  };
}
