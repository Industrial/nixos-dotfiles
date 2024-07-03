args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_services_i2pd_enable = {
    expr = feature.services.i2pd.enable;
    expected = true;
  };
  test_services_i2pd_enableIPv4 = {
    expr = feature.services.i2pd.enableIPv4;
    expected = true;
  };
  test_services_i2pd_enableIPv6 = {
    expr = feature.services.i2pd.enableIPv6;
    expected = true;
  };
  test_services_i2pd_proto_http_enable = {
    expr = feature.services.i2pd.proto.http.enable;
    expected = true;
  };
  test_services_i2pd_proto_http_address = {
    expr = feature.services.i2pd.proto.http.address;
    expected = "127.0.0.1";
  };
  test_services_i2pd_proto_http_name = {
    expr = feature.services.i2pd.proto.http.name;
    expected = "http";
  };
  test_services_i2pd_proto_http_port = {
    expr = feature.services.i2pd.proto.http.port;
    expected = 7070;
  };
  test_services_i2pd_proto_httpProxy_enable = {
    expr = feature.services.i2pd.proto.httpProxy.enable;
    expected = true;
  };
  test_services_i2pd_proto_httpProxy_address = {
    expr = feature.services.i2pd.proto.httpProxy.address;
    expected = "127.0.0.1";
  };
  test_services_i2pd_proto_httpProxy_name = {
    expr = feature.services.i2pd.proto.httpProxy.name;
    expected = "httpproxy";
  };
  test_services_i2pd_proto_httpProxy_port = {
    expr = feature.services.i2pd.proto.httpProxy.port;
    expected = 4444;
  };
  test_services_i2pd_proto_socksProxy_enable = {
    expr = feature.services.i2pd.proto.socksProxy.enable;
    expected = true;
  };
  test_services_i2pd_proto_socksProxy_address = {
    expr = feature.services.i2pd.proto.socksProxy.address;
    expected = "127.0.0.1";
  };
  test_services_i2pd_proto_socksProxy_name = {
    expr = feature.services.i2pd.proto.socksProxy.name;
    expected = "socksproxy";
  };
  test_services_i2pd_proto_socksProxy_port = {
    expr = feature.services.i2pd.proto.socksProxy.port;
    expected = 4447;
  };
  test_services_i2pd_proto_socksProxy_outproxy = {
    expr = feature.services.i2pd.proto.socksProxy.outproxy;
    expected = "127.0.0.1";
  };
  test_services_i2pd_proto_socksProxy_outproxyEnable = {
    expr = feature.services.i2pd.proto.socksProxy.outproxyEnable;
    expected = true;
  };
  test_services_i2pd_proto_socksProxy_outproxyPort = {
    expr = feature.services.i2pd.proto.socksProxy.outproxyPort;
    expected = 4444;
  };
}
