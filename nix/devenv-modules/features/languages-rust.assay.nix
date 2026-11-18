let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./languages-rust.nix {};
  on = h.feature ./languages-rust.nix {local.features.languages-rust.enable = true;};
  custom = h.feature ./languages-rust.nix {
    local.features.languages-rust = {
      enable = true;
      channel = "stable";
      version = "1.88.0";
    };
  };
in
  assay.suite "languages-rust" {
    disabled = assay.eq off.languages.rust.enable false;
    enabled = assay.eq on.languages.rust.enable true;
    defaultChannel = assay.eq on.languages.rust.channel "nightly";
    defaultVersion = assay.eq on.languages.rust.version "latest";
    components = assay.eq on.languages.rust.components [
      "cargo"
      "clippy"
      "rust-analyzer"
      "rustc"
      "rustfmt"
      "llvm-tools"
    ];
    targetsEmpty = assay.eq on.languages.rust.targets [];
    customChannel = assay.eq custom.languages.rust.channel "stable";
    customVersion = assay.eq custom.languages.rust.version "1.88.0";
  }
