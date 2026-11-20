# Crypto Profile
# Cryptocurrency tools
{
  config,
  lib,
  ...
}: {
  options.profiles.crypto.enable = lib.mkEnableOption "the crypto profile";

  config = lib.mkIf config.profiles.crypto.enable {
    # features.crypto.bisq.enable = true;
    # features.crypto.monero.enable = true;
    # features.crypto.solana.enable = true;
  };
}
