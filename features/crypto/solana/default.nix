# Solana CLI: keygen, RPC, deploy, etc.
# Generate keypair and copy to clipboard: solana-keygen new --no-bip39-passphrase --force --outfile /tmp/solana-keypair-$$.json && cat /tmp/solana-keypair-$$.json | xclip -selection clipboard && rm -f /tmp/solana-keypair-$$.json
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    solana-cli
  ];
}
