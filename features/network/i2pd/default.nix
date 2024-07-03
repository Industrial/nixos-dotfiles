{...}: {
  services = {
    i2pd = {
      enable = true;
      enableIPv4 = true;
      enableIPv6 = true;
      proto = {
        http = {
          enable = true;
          address = "127.0.0.1";
          name = "http";
          port = 7070;
        };
        httpProxy = {
          enable = true;
          address = "127.0.0.1";
          name = "httpproxy";
          port = 4444;
        };
        socksProxy = {
          enable = true;
          address = "127.0.0.1";
          name = "socksproxy";
          port = 4447;
          outproxy = "127.0.0.1";
          outproxyEnable = true;
          outproxyPort = 4444;
        };
      };
    };
  };
}
