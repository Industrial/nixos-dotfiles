# Drakkar — fleet remote builder (Mimir/Huginn offload builds via SSH).
#
# Clients use nix-remote-builder-client.nix. Requires tom in trusted-users
# (features/nixos/users) and fleet operator SSH keys on all hosts.
{...}: {
  nix.settings.system-features = ["nixos-test" "benchmark" "big-parallel" "kvm"];
}
