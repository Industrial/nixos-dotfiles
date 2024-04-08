{
  settings,
  pkgs,
  ...
}: {
  services.i2pd.enable = true;
  services.i2pd.enableIPv4 = true;
  services.i2pd.enableIPv6 = true;
  # services.i2pd.ifname = "";
  # services.i2pd.ifname4 = "";
  # services.i2pd.ifname6 = "";

  services.i2pd.proto.socksProxy.enable = true;
  services.i2pd.proto.socksProxy.address = "127.0.0.1";
  services.i2pd.proto.socksProxy.name = "socksproxy";
  services.i2pd.proto.socksProxy.port = 4447;
  services.i2pd.proto.socksProxy.outproxy = "127.0.0.1";
  services.i2pd.proto.socksProxy.outproxyEnable = true;
  services.i2pd.proto.socksProxy.outproxyPort = 4444;

  services.i2pd.proto.httpProxy.enable = true;
  services.i2pd.proto.httpProxy.address = "127.0.0.1";
  services.i2pd.proto.httpProxy.name = "httpproxy";
  services.i2pd.proto.httpProxy.port = 4444;

  services.i2pd.proto.http.enable = true;
  services.i2pd.proto.http.address = "127.0.0.1";
  services.i2pd.proto.http.name = "http";
  services.i2pd.proto.http.port = 7070;

  # services.i2pd = {
  #   # ifname = "vm-i2pd-ex";
  #   # proto = {
  #   #   # httpProxy = {
  #   #   #   enable = true;
  #   #   # };
  #   #   socksProxy = {
  #   #     enable = true;
  #   #     address = "127.0.0.1";
  #   #   };
  #   # };
  #   # # app = {
  #   # #   enable = true;
  #   # #   httpProxy = "vm-i2pd-in";
  #   # #   socksProxy = "vm-i2pd-ex";
  #   # # };
  # };
}
