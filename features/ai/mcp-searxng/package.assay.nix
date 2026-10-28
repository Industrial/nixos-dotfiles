# Colocated suite for features/ai/mcp-searxng/package.nix.
# String-level guards (repo pattern): identity, pinned tarball and npm closure, vendored
# lockfile.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "mcp-searxng-package" {
    namesMcpSearxng = assay.eq (has ".*pname = \"mcp-searxng\";.*") true;
    pinsVersion = assay.eq (has ".*version = \"2\\.1\\.0\";.*") true;
    pinsTarballHash = assay.eq (has ".*hash = \"sha256-H/\\+Fn9gUIsm79Ze88cvHqPuMbdF4hHYYBFzxt5EgNhw=\";.*") true;
    pinsNpmDepsHash = assay.eq (has ".*npmDepsHash = \"sha256-5OtWT99QEYqbDYGLv1OlLKrRiPL9eT7fHNLetFJNXkg=\";.*") true;

    # Brace-free pattern: Nix's regex engine rejects \{ as invalid.
    vendorsLockfile = assay.eq (has ".*cp .*package-lock\\.json.* package-lock\\.json.*") true;
    lockfileExists = assay.eq (builtins.pathExists ./package-lock.json) true;

    usesPackageSourceRoot = assay.eq (has ".*sourceRoot = \"package\";.*") true;
    skipsBuild = assay.eq (has ".*dontNpmBuild = true;.*") true;

    exposesMcpAsMainProgram = assay.eq (has ".*mainProgram = \"mcp-searxng\";.*") true;
  }
