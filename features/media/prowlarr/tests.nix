args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.prowlarr feature.environment.systemPackages;
    expected = true;
  };
  test_systemd_services_prowlarr_description = {
    expr = feature.systemd.services.prowlarr.description;
    expected = "Prowlarr Daemon";
  };
  test_systemd_services_prowlarr_wantedBy = {
    expr = builtins.elem "multi-user.target" feature.systemd.services.prowlarr.wantedBy;
    expected = true;
  };
  test_systemd_services_prowlarr_after = {
    expr = builtins.elem "network.target" feature.systemd.services.prowlarr.after;
    expected = true;
  };
  test_systemd_services_prowlarr_serviceConfig_Type = {
    expr = feature.systemd.services.prowlarr.serviceConfig;
    expected = {
      Type = "simple";
      User = "prowlarr";
      Group = "data";
      ExecStart = "${pkgs.prowlarr}/bin/Prowlarr --nobrowser --data /data/prowlarr";
      Restart = "always";
      RestartSec = 5;
    };
  };
  test_users_users_prowlarr_isSystemUser = {
    expr = feature.users.users.prowlarr.isSystemUser;
    expected = true;
  };
  test_users_users_prowlarr_group = {
    expr = feature.users.users.prowlarr.group;
    expected = "data";
  };
}
