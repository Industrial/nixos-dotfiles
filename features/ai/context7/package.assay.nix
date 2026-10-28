# Colocated suite for features/ai/context7/package.nix.
# String-level guards (repo pattern): identity, pinned tarball and npm closure, and the
# vendored lockfile the build depends on.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "context7-package" {
    namesContext7Mcp = assay.eq (has ".*pname = \"context7-mcp\";.*") true;
    pinsVersion = assay.eq (has ".*version = \"2\\.2\\.5\";.*") true;
    pinsTarballHash = assay.eq (has ".*hash = \"sha256-\\+3h/SAIYmPQ140XPrt9\\+fEjdgVUVBe8V4Y0i4YnGs3U=\";.*") true;
    pinsNpmDepsHash = assay.eq (has ".*npmDepsHash = \"sha256-GqvQdJgOAg52aO37WfAoV2fV5eDMXw8Ux1l07OG1mxE=\";.*") true;

    # The published npm tarball has no package-lock.json, so buildNpmPackage needs the
    # generated one copied in. Without this postPatch the build cannot resolve deps at all.
    # Brace-free pattern: Nix's regex engine rejects \{ as invalid.
    vendorsLockfile = assay.eq (has ".*cp .*package-lock\\.json.* package-lock\\.json.*") true;
    lockfileExists = assay.eq (builtins.pathExists ./package-lock.json) true;

    # The tarball unpacks into package/ and already ships a compiled dist/.
    usesPackageSourceRoot = assay.eq (has ".*sourceRoot = \"package\";.*") true;
    skipsBuild = assay.eq (has ".*dontNpmBuild = true;.*") true;

    exposesMcpAsMainProgram = assay.eq (has ".*mainProgram = \"context7-mcp\";.*") true;
  }
