{...}: let
  protocol = "http";
  hostname = "127.0.0.1";
  port = 4020;
in {
  services.cryptpad.enable = true;
  services.cryptpad.configureNginx = false;
  services.cryptpad.settings.httpUnsafeOrigin = "${protocol}://${hostname}:${toString port}";
  services.cryptpad.settings.httpSafeOrigin = "${protocol}://${hostname}:${toString port}";
  services.cryptpad.settings.httpAddress = hostname;
  services.cryptpad.settings.httpPort = port;
  services.cryptpad.settings.adminKeys = ["[tom@127.0.0.1:4020/f5bdoXYd9Jlw0pao6HRYE7jMcLl0Ky3+tvI-OG4kBZI=]"];
}
