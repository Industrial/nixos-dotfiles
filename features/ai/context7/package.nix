# context7 MCP server — @upstash/context7-mcp — https://github.com/upstash/context7
#
# Provides up-to-date library documentation context to LLMs via MCP.
# Not in nixpkgs; built here from the npm tarball using buildNpmPackage.
#
# The upstream repo is a pnpm monorepo (packages/mcp) with no package-lock.json in the
# published npm tarball. We ship a generated package-lock.json (v3) alongside this
# derivation; regenerate with:
#   npm pack @upstash/context7-mcp@<version>
#   tar xzf *.tgz && cd package
#   npm install --package-lock-only --ignore-scripts
# Then re-run prefetch-npm-deps to update npmDepsHash.
#
# Invocation: context7-mcp   (stdio transport, no args required)
{
  lib,
  buildNpmPackage,
  fetchurl,
}: let
  # Published npm tarball (contains pre-built dist/).
  src = fetchurl {
    url = "https://registry.npmjs.org/@upstash/context7-mcp/-/context7-mcp-2.2.5.tgz";
    hash = "sha256-+3h/SAIYmPQ140XPrt9+fEjdgVUVBe8V4Y0i4YnGs3U=";
  };
in
  buildNpmPackage {
    pname = "context7-mcp";
    version = "2.2.5";

    inherit src;

    # The npm tarball unpacks into a `package/` subdirectory.
    sourceRoot = "package";

    # package-lock.json generated from the npm tarball; required by buildNpmPackage.
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    # SHA-256 of the npm dependency closure; generated with:
    #   prefetch-npm-deps package-lock.json
    npmDepsHash = "sha256-GqvQdJgOAg52aO37WfAoV2fV5eDMXw8Ux1l07OG1mxE=";

    # dist/ is already compiled in the published tarball; skip the build step.
    dontNpmBuild = true;

    meta = {
      description = "MCP server providing up-to-date library documentation context via Context7";
      homepage = "https://github.com/upstash/context7";
      changelog = "https://github.com/upstash/context7/releases/tag/%40upstash%2Fcontext7-mcp%402.2.5";
      license = lib.licenses.mit;
      maintainers = [];
      mainProgram = "context7-mcp";
      platforms = lib.platforms.unix;
    };
  }
