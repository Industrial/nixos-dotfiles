# Colocated suite for features/ai/mcp-searxng/package.nix.
# Asserts on the evaluated derivation: identity, pinned tarball and npm closure, vendored
# lockfile.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  pkgs = (nixos.evalSystem {modules = [];}).pkgs;
  drv = pkgs.callPackage ./package.nix {};
in
  assay.suite "mcp-searxng-package" {
    namesMcpSearxng = assay.eq drv.pname "mcp-searxng";
    pinsVersion = assay.eq drv.version "2.1.0";
    tarballMatchesVersion = assay.eq drv.src.url "https://registry.npmjs.org/mcp-searxng/-/mcp-searxng-2.1.0.tgz";
    pinsTarballHash = assay.eq drv.src.outputHash "sha256-H/+Fn9gUIsm79Ze88cvHqPuMbdF4hHYYBFzxt5EgNhw=";
    pinsNpmDepsHash = assay.eq drv.npmDeps.outputHash "sha256-5OtWT99QEYqbDYGLv1OlLKrRiPL9eT7fHNLetFJNXkg=";

    # The tarball ships no lockfile; postPatch (the generated shell step) copies ours in.
    vendorsLockfile = assay.eq (builtins.match "cp /nix/store/[^ ]*-package-lock\\.json package-lock\\.json\n" drv.postPatch != null) true;
    lockfileExists = assay.eq (builtins.pathExists ./package-lock.json) true;

    usesPackageSourceRoot = assay.eq drv.sourceRoot "package";
    skipsBuild = assay.eq drv.dontNpmBuild true;

    exposesMcpAsMainProgram = assay.eq drv.meta.mainProgram "mcp-searxng";
  }
