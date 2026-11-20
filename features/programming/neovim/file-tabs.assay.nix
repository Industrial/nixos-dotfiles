# Assay: neovim file tabs (placeholder).
#
# file-tabs.nix only carries a commented-out bufferline setup from the old config; the
# tab line itself is tab-line.nix. Calling the module pins that it contributes nothing,
# so config that lands here later has to come with real claims.
let
  assay = import ../../../common/assay/default.nix;
in
  assay.suite "file-tabs" {
    contributesNothing = assay.eq (import ./file-tabs.nix {}) {};
  }
