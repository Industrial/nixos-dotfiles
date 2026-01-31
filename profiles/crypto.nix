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
    ../features/crypto/bisq
    ../features/crypto/monero
  ];
}
