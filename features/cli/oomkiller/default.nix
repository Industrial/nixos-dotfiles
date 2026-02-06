{
  pkgs,
  inputs,
  settings,
  lib,
  ...
}: let
  oomkillerPkg = pkgs.callPackage inputs.oomkiller-src {};
in {
  environment = {
    systemPackages = with pkgs; [
      oomkillerPkg
    ];
  };

  systemd = {
    services = {
      oomkiller = {
        description = "OOM Killer Daemon - Monitors system memory and kills highest memory-consuming process when threshold exceeded";
        wantedBy = ["multi-user.target"];
        after = ["basic.target"];

        serviceConfig = {
          Type = "simple";
          User = "${settings.username}";
          ExecStart = "${oomkillerPkg}/bin/oomkiller";
          Restart = "always";
          RestartSec = "5s";
        };
      };
    };
  };
}
