# Colocated suite for features/ai/context7/package.nix.
# Asserts on the evaluated derivation: identity, pinned tarball and npm closure, and the
# vendored lockfile the build depends on.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  pkgs = (nixos.evalSystem {modules = [];}).pkgs;
  drv = pkgs.callPackage ./package.nix {};
in
  assay.suite "context7-package" {
    namesContext7Mcp = assay.eq drv.pname "context7-mcp";
    pinsVersion = assay.eq drv.version "2.2.5";
    # The tarball URL embeds the version, so the two must be bumped together.
    tarballMatchesVersion = assay.eq drv.src.url "https://registry.npmjs.org/@upstash/context7-mcp/-/context7-mcp-2.2.5.tgz";
    pinsTarballHash = assay.eq drv.src.outputHash "sha256-+3h/SAIYmPQ140XPrt9+fEjdgVUVBe8V4Y0i4YnGs3U=";
    pinsNpmDepsHash = assay.eq drv.npmDeps.outputHash "sha256-GqvQdJgOAg52aO37WfAoV2fV5eDMXw8Ux1l07OG1mxE=";

    # The published npm tarball has no package-lock.json, so buildNpmPackage needs the
    # generated one copied in. Without this postPatch the build cannot resolve deps at all.
    # postPatch is the generated shell step, so matching its text is matching the artifact.
    vendorsLockfile = assay.eq (builtins.match "cp /nix/store/[^ ]*-package-lock\\.json package-lock\\.json\n" drv.postPatch != null) true;
    lockfileExists = assay.eq (builtins.pathExists ./package-lock.json) true;

    # The tarball unpacks into package/ and already ships a compiled dist/.
    usesPackageSourceRoot = assay.eq drv.sourceRoot "package";
    skipsBuild = assay.eq drv.dontNpmBuild true;

    exposesMcpAsMainProgram = assay.eq drv.meta.mainProgram "context7-mcp";
  }
