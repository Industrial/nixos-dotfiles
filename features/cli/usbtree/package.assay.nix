# Colocated suite for features/cli/usbtree/package.nix.
# Eval-only metadata assertions with stubbed nixpkgs args — no network fetch,
# no build. The fetcher hashes themselves are exercised by real builds.
let
  assay = import ./../../../common/assay/default.nix;
  lib' = {
    licenses = {mit = "MIT";};
    platforms = {linux = "x86_64-linux";};
  };
  rustPlatform' = {
    buildRustPackage = {
      pname,
      version,
      src,
      cargoHash,
      meta ? {},
      ...
    }: {
      isBuildRustPackage = true;
      inherit pname version cargoHash meta src;
      srcRev = src.rev;
    };
  };
  fetchFromGitHub = args@{owner, repo, rev, hash ? null, ...}: {
    inherit owner repo rev;
    inherit (args) hash;
  };
  drv = import ./package.nix {
    inherit fetchFromGitHub;
    lib = lib';
    rustPlatform = rustPlatform';
  };
in
  assay.suite "usbtree-package" {
    isBuildRustPackage = assay.eq drv.isBuildRustPackage true;
    pname = assay.eq drv.pname "usbtree";
    version = assay.eq drv.version "0.1.1";
    fetchedFromUpstream = assay.eq
      (drv.src.owner == "gnomeria" && drv.src.repo == "usbtree"
        && drv.src.rev == "v0.1.1")
      true;
    fetcherPinned = assay.eq
      (builtins.stringLength drv.src.hash > 10
        && builtins.stringLength drv.cargoHash > 10)
      true;
    mainProgram = assay.eq drv.meta.mainProgram "usbtree";
    licenseIsMit = assay.eq drv.meta.license lib'.licenses.mit;
    platformsLinux = assay.eq drv.meta.platforms lib'.platforms.linux;
  }
