# Colocated suite for features/cli/leaves/package.nix.
# String-level guards (repo pattern): identity and the two hashes a version bump must move.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "leaves-package" {
    namesLeaves = assay.eq (has ".*pname = \"leaves\";.*") true;

    # The `-cross` suffix is part of the upstream tag, not a local marker — the rev is
    # "v${version}", so dropping it would point fetchFromGitHub at a tag that does not exist.
    pinsCrossTaggedVersion = assay.eq (has ".*version = \"0\\.2\\.0-cross\";.*") true;
    revDerivesFromVersion = assay.eq (has ".*rev = \"v.*version.*\";.*") true;

    pinsSrcHash = assay.eq (has ".*hash = \"sha256-JGWGo/JDC3/Sj97ca4CrgD4WaobYUVmbryuIg/AN2kU=\";.*") true;
    # A Rust package needs both hashes; forgetting cargoHash on a bump is the usual slip.
    pinsCargoHash = assay.eq (has ".*cargoHash = \"sha256-W1RWE08HXDhgejWcnUKI6/WTk9CAU6wayrNNl87rvMw=\";.*") true;

    exposesLeavesAsMainProgram = assay.eq (has ".*mainProgram = \"leaves\";.*") true;
  }
