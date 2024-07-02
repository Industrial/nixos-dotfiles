{...}: {
  # services.tor.client.port = 9051;
  # services.tor.client.socksListenAddress = "127.0.0.1";
  services.tor.client.enable = true;
  services.tor.enable = true;
  services.tor.relay.enable = false;
}
