# Voltaic programming language (compiler, language server and MCP server).
#
# One derivation carries all three binaries — `voltaic`, `voltaic-lsp` and
# `voltaic-mcp` — because the workspace's crates share almost their whole
# dependency graph, and asking for them separately would compile
# `voltaic-ast`, `voltaic-parser` and `voltaic-emit` three times. The flake
# exposes `packages.voltaic-lsp` and `packages.voltaic-mcp` as aliases of that
# one derivation, for a consumer that would rather ask by name.
#
# **Not from nixpkgs**, and that is now permanent rather than pending: the
# submission was declined by nixpkgs' maintainers, so Voltaic's own flake is
# the only Nix delivery path, and the packaging expression was deleted
# upstream at 0.2.0. A `pkgs.voltaic` here would be a dead end.
{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    inputs.voltaic.packages.${pkgs.stdenv.hostPlatform.system}.voltaic
  ];
}
