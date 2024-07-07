args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.sonarr feature.environment.systemPackages;
    expected = true;
  };
  test_systemd_services_sonarr_description = {
    expr = feature.systemd.services.sonarr.description;
    expected = "Sonarr Daemon";
  };
  test_systemd_services_sonarr_wantedBy = {
    expr = builtins.elem "multi-user.target" feature.systemd.services.sonarr.wantedBy;
    expected = true;
  };
  test_systemd_services_sonarr_after = {
    expr = builtins.elem "network.target" feature.systemd.services.sonarr.after;
    expected = true;
  };
  test_systemd_services_sonarr_serviceConfig_Type = {
    expr = feature.systemd.services.sonarr.serviceConfig;
    expected = {
      Type = "simple";
      User = "sonarr";
      Group = "data";
      ExecStart = "${pkgs.sonarr}/bin/Sonarr --nobrowser --data /data/sonarr";
      Restart = "always";
      RestartSec = 5;
    };
  };
  test_users_users_sonarr_isSystemUser = {
    expr = feature.users.users.sonarr.isSystemUser;
    expected = true;
  };
  test_users_users_sonarr_group = {
    expr = feature.users.users.sonarr.group;
    expected = "data";
  };
}
