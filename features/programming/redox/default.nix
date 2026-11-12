# Redox programming language (compiler, language server and MCP server).
#
# One derivation carries all three binaries — `redox`, `redox-lsp` and
# `redox-mcp` — because the workspace's eleven crates share almost their whole
# dependency graph, and asking for them separately would compile `redox-ast`,
# `redox-parser` and `redox-emit` three times. The flake exposes
# `packages.redox-lsp` and `packages.redox-mcp` as aliases of that one
# derivation, for a consumer that would rather ask by name.
{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    inputs.redox.packages.${pkgs.stdenv.hostPlatform.system}.redox
  ];
}
