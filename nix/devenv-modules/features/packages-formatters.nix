{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.local.features.packages-formatters;
in {
  options.local.features.packages-formatters.enable = lib.mkEnableOption "formatters and linters (treefmt, alejandra, biome, …)";

  config = lib.mkIf cfg.enable {
    packages = with pkgs; [
      actionlint
      alejandra
      beautysh
      biome
      deadnix
      # rustfmt comes from languages.rust (rust-overlay); nixpkgs rustfmt shadows it
      taplo
      treefmt
      vulnix
      yamlfmt
    ];
  };
}
