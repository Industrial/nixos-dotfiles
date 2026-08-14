# Mullvad VPN - enables `mullvad-daemon`, CLI, and GUI (`pkgs.mullvad-vpn`).
# After rebuild: log in with `mullvad account login` (requires an active Mullvad account).
#
# Mullvad on NixOS expects systemd-resolved; without it the daemon can misbehave while
# NetworkManager still shows VPN UI. See https://wiki.nixos.org/wiki/Mullvad_VPN
{
  config,
  lib,
  pkgs,
  ...
}: {
  services = {
    resolved = {
      enable = true;
    };
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
  };

  networking = {
    networkmanager = {
      dns = lib.mkIf config.networking.networkmanager.enable "systemd-resolved";
    };
  };
}
