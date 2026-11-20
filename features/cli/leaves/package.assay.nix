# Colocated suite for features/cli/leaves/package.nix.
# Identity and the two hashes a version bump must move, read off the package as callPackage
# builds it from the pinned nixpkgs.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  leaves = pkgs.callPackage ./package.nix {};
in
  assay.suite "leaves-package" {
    namesLeaves = assay.eq leaves.pname "leaves";

    # The `-cross` suffix is part of the upstream tag, not a local marker — the rev is
    # "v${version}", so dropping it would point fetchFromGitHub at a tag that does not exist.
    pinsCrossTaggedVersion = assay.eq leaves.version "0.2.0-cross";
    revDerivesFromVersion = assay.eq leaves.src.rev "v${leaves.version}";
    fetchesUpstream = assay.eq [leaves.src.owner leaves.src.repo] ["patonw" "leaves"];

    pinsSrcHash = assay.eq leaves.src.outputHash "sha256-JGWGo/JDC3/Sj97ca4CrgD4WaobYUVmbryuIg/AN2kU=";
    # A Rust package needs both hashes; forgetting cargoHash on a bump is the usual slip.
    pinsCargoHash = assay.eq leaves.cargoHash "sha256-W1RWE08HXDhgejWcnUKI6/WTk9CAU6wayrNNl87rvMw=";

    exposesLeavesAsMainProgram = assay.eq leaves.meta.mainProgram "leaves";
  }
