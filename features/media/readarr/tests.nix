args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.readarr feature.environment.systemPackages;
    expected = true;
  };
  test_systemd_services_readarr_description = {
    expr = feature.systemd.services.readarr.description;
    expected = "Readarr Daemon";
  };
  test_systemd_services_readarr_wantedBy = {
    expr = builtins.elem "multi-user.target" feature.systemd.services.readarr.wantedBy;
    expected = true;
  };
  test_systemd_services_readarr_after = {
    expr = builtins.elem "network.target" feature.systemd.services.readarr.after;
    expected = true;
  };
  test_systemd_services_readarr_serviceConfig_Type = {
    expr = feature.systemd.services.readarr.serviceConfig;
    expected = {
      Type = "simple";
      User = "readarr";
      Group = "data";
      ExecStart = "${pkgs.readarr}/bin/Readarr --nobrowser --data /data/readarr";
      Restart = "always";
      RestartSec = 5;
    };
  };
  test_users_users_readarr_isSystemUser = {
    expr = feature.users.users.readarr.isSystemUser;
    expected = true;
  };
  test_users_users_readarr_group = {
    expr = feature.users.users.readarr.group;
    expected = "data";
  };
}
