args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.radarr feature.environment.systemPackages;
    expected = true;
  };
  test_systemd_services_radarr_description = {
    expr = feature.systemd.services.radarr.description;
    expected = "Radarr Daemon";
  };
  test_systemd_services_radarr_wantedBy = {
    expr = builtins.elem "multi-user.target" feature.systemd.services.radarr.wantedBy;
    expected = true;
  };
  test_systemd_services_radarr_after = {
    expr = builtins.elem "network.target" feature.systemd.services.radarr.after;
    expected = true;
  };
  test_systemd_services_radarr_serviceConfig_Type = {
    expr = feature.systemd.services.radarr.serviceConfig;
    expected = {
      Type = "simple";
      User = "radarr";
      Group = "data";
      ExecStart = "${pkgs.radarr}/bin/Radarr --nobrowser --data /data/radarr";
      Restart = "always";
      RestartSec = 5;
    };
  };
  test_users_users_radarr_isSystemUser = {
    expr = feature.users.users.radarr.isSystemUser;
    expected = true;
  };
  test_users_users_radarr_group = {
    expr = feature.users.users.radarr.group;
    expected = "data";
  };
}
