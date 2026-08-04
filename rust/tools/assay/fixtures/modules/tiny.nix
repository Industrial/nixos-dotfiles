# Tiny options module for Assay `Claim::Module` documentation.
# Pure Nix data — not executed in Rust unit tests.
{lib, ...}: {
  options = {
    assay.tiny.enable = lib.mkEnableOption "tiny assay fixture";
    assay.tiny.message = lib.mkOption {
      type = lib.types.str;
      default = "hello from tiny";
      description = "Example message merged into config by evalModules.";
    };
  };

  config = {
    assay.tiny.message = "hello from tiny";
  };
}
