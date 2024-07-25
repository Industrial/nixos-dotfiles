{...}: {
  services.vaultwarden.enable = true;
  services.vaultwarden.config.ROCKET_ADDRESS = "127.0.0.1";
  services.vaultwarden.config.ROCKET_PORT = 7000;
  services.vaultwarden.config.DOMAIN = "http://localhost";
  services.vaultwarden.config.SIGNUPS_ALLOWED = false;

  # security.acme.defaults.email = "tom.wieland@gmail.com";
  # security.acme.acceptTerms = true;

  # services.nginx.virtualHosts."vault.local" = {
  #   enableACME = true;
  #   forceSSL = true;
  #   locations."/".proxyPass = "http://${config.services.vaultwarden.config.ROCKET_ADDRESS}:${toString config.services.vaultwarden.config.ROCKET_PORT}";
  # };
}
