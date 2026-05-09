# Mullvad VPN — enables `mullvad-daemon`, CLI, and GUI (`pkgs.mullvad-vpn`).
# After rebuild: log in with `mullvad account login` (requires an active Mullvad account).
{pkgs, ...}: {
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };
}
