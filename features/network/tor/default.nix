# Tor - The Onion Router
# Enables Tor service and provides the Tor Browser.
{
  config,
  lib,
  pkgs,
  ...
}: {
  services.tor = {
    enable = true;
    client.enable = true;
  };

  environment.systemPackages = with pkgs; [
    tor-browser
  ];
}
