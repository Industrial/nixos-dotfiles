# Assay: neovim folds (placeholder).
#
# folds.nix only carries a commented-out fold setup from the old config. Calling the
# module pins that it contributes nothing, so config that lands here later has to come
# with real claims.
let
  assay = import ../../../common/assay/default.nix;
in
  assay.suite "folds" {
    contributesNothing = assay.eq (import ./folds.nix {}) {};
  }
