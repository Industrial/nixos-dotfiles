# SearXNG MCP server — mcp-searxng — https://github.com/ihor-sokoliuk/mcp-searxng
#
# Gives the agent web search via a SearXNG instance. Paired with
# features/network/searx (localhost:4001) on this fleet.
# Not in nixpkgs; built here from the npm tarball using buildNpmPackage.
#
# The published npm tarball ships a pre-built dist/ but no package-lock.json.
# We ship a generated package-lock.json (v3) alongside this derivation;
# regenerate with:
#   npm pack mcp-searxng@<version>
#   tar xzf *.tgz && cd package
#   npm install --package-lock-only --ignore-scripts
# Then re-run prefetch-npm-deps to update npmDepsHash.
#
# Invocation: mcp-searxng   (stdio transport; reads SEARXNG_URL from the env)
{
  lib,
  buildNpmPackage,
  fetchurl,
}: let
  # Published npm tarball (contains pre-built dist/).
  src = fetchurl {
    url = "https://registry.npmjs.org/mcp-searxng/-/mcp-searxng-2.1.0.tgz";
    hash = "sha256-H/+Fn9gUIsm79Ze88cvHqPuMbdF4hHYYBFzxt5EgNhw=";
  };
in
  buildNpmPackage {
    pname = "mcp-searxng";
    version = "2.1.0";

    inherit src;

    # The npm tarball unpacks into a `package/` subdirectory.
    sourceRoot = "package";

    # package-lock.json generated from the npm tarball; required by buildNpmPackage.
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    # SHA-256 of the npm dependency closure; generated with:
    #   prefetch-npm-deps package-lock.json
    npmDepsHash = "sha256-5OtWT99QEYqbDYGLv1OlLKrRiPL9eT7fHNLetFJNXkg=";

    # dist/ is already compiled in the published tarball; skip the build step.
    dontNpmBuild = true;

    meta = {
      description = "MCP server for SearXNG integration";
      homepage = "https://github.com/ihor-sokoliuk/mcp-searxng";
      license = lib.licenses.mit;
      maintainers = [];
      mainProgram = "mcp-searxng";
      platforms = lib.platforms.unix;
    };
  }
