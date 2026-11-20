# DNS: intentionally empty.
#
# This module used to carry a commented-out dnscrypt-proxy2 (Quad9) and systemd-resolved
# setup that no host ran; it is in git history if DNSCrypt is wanted again. Name resolution
# is whatever NetworkManager (features/nixos/networking) and, where enabled, Mullvad
# (features/network/mullvad) configure. features/catalog.nix still lists this file; dropping
# it from there is a follow-up for the catalog owner.
{...}: {}
