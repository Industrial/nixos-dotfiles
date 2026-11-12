# Emerald programming language (compiler + language server)
{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    # nixpkgs' cargoUseSystemLibs setup hook exports ZSTD_SYS_USE_PKG_CONFIG,
    # but the emerald flake's package carries no system zstd, so zstd-sys
    # panics on its pkg-config probe. Opt out so the vendored C sources build.
    # The override lives here rather than in features/nixos' overlay list
    # because this package comes from a flake input, not from nixpkgs.
    # Drop once the emerald flake handles it upstream.
    (inputs.emerald.packages.${pkgs.stdenv.hostPlatform.system}.emerald.overrideAttrs
      (_: {
        dontCargoUseSystemLibs = true;
      }))
  ];
}
