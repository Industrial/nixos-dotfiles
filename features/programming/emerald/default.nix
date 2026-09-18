# Emerald programming language (compiler + language server)
{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    inputs.emerald.packages.${pkgs.stdenv.hostPlatform.system}.emerald
  ];
}
