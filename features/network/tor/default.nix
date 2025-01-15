{pkgs, ...}: {
  # 127.0.0.1:9150
  environment = {
    systemPackages = with pkgs; [
      arti
    ];
    # TODO: Turned these off, as not all programs work correctly (bunjs, for
    # example). I'll have to set it manually for each program.
    # variables = {
    #   http_proxy = "socks5://127.0.0.1:9150";
    #   https_proxy = "socks5://127.0.0.1:9150";
    #   HTTP_PROXY = "socks5://127.0.0.1:9150";
    #   HTTPS_PROXY = "socks5://127.0.0.1:9150";
    # };
  };
  users = {
    users = {
      arti = {
        isSystemUser = true;
        home = "/home/arti";
        createHome = true;
        group = "arti";
        extraGroups = [];
      };
    };
    groups = {
      arti = {};
    };
  };
  systemd = {
    services = {
      arti = {
        description = "Arti Tor SOCKS Proxy";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "simple";
          User = "arti";
          Group = "arti";
          ExecStart = "${pkgs.arti}/bin/arti -l info proxy";
          Restart = "always";
          RestartSec = 5;
        };
        path = with pkgs; [arti];
      };
    };
  };
}
