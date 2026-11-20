# Assay: neovim quickfix (placeholder).
#
# quickfix.nix only carries a commented-out trouble setup from the old config; trouble is
# configured in visual-information.nix. Calling the module pins that it contributes
# nothing, so config that lands here later has to come with real claims.
let
  assay = import ../../../common/assay/default.nix;
in
  assay.suite "quickfix" {
    contributesNothing = assay.eq (import ./quickfix.nix {}) {};
  }
