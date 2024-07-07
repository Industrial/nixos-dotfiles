args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.lidarr feature.environment.systemPackages;
    expected = true;
  };
  test_systemd_services_lidarr_description = {
    expr = feature.systemd.services.lidarr.description;
    expected = "Lidarr Daemon";
  };
  test_systemd_services_lidarr_wantedBy = {
    expr = builtins.elem "multi-user.target" feature.systemd.services.lidarr.wantedBy;
    expected = true;
  };
  test_systemd_services_lidarr_after = {
    expr = builtins.elem "network.target" feature.systemd.services.lidarr.after;
    expected = true;
  };
  test_systemd_services_lidarr_serviceConfig_Type = {
    expr = feature.systemd.services.lidarr.serviceConfig;
    expected = {
      Type = "simple";
      User = "lidarr";
      Group = "data";
      ExecStart = "${pkgs.lidarr}/bin/Lidarr --nobrowser --data /data/lidarr";
      Restart = "always";
      RestartSec = 5;
    };
  };
  test_users_users_lidarr_isSystemUser = {
    expr = feature.users.users.lidarr.isSystemUser;
    expected = true;
  };
  test_users_users_lidarr_group = {
    expr = feature.users.users.lidarr.group;
    expected = "data";
  };
}
