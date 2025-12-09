# Crypto Profile
# Cryptocurrency tools
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    ./base.nix

    # Crypto
    ../features/crypto/bisq
    ../features/crypto/monero
  ];
}
