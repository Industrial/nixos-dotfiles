# OmniRoute — local AI gateway for Hermes, OpenCode, and other OpenAI-compatible tools
# https://github.com/diegosouzapw/OmniRoute
#
# API:       http://127.0.0.1:20128/v1
# Dashboard: http://127.0.0.1:20128
#
# First-time setup (after enabling this module):
#   1. Open the dashboard and set an admin password
#   2. Connect free providers (OpenCode Zen, Pollinations, Groq, Gemini, NVIDIA NIM, …)
#   3. Create an endpoint API key for Hermes
#   4. Set OMNIROUTE_API_KEY in ~/.hermes/.env (see auth.json.example)
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.omniroute;
  omniroute = pkgs.callPackage ./package.nix {};
in {
  options = {
    services = {
      omniroute = {
        enable = lib.mkEnableOption "OmniRoute local AI gateway";

        port = lib.mkOption {
          type = lib.types.port;
          default = 20128;
          description = "HTTP port for the OmniRoute API and dashboard.";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "%h/.config/omniroute";
          description = "Directory for OmniRoute state (expanded per user in the user service).";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open the OmniRoute port on the firewall (usually keep false; localhost only).";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Extra arguments passed to the OmniRoute server process.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment = {
      systemPackages = [omniroute];
    };

    networking = {
      firewall = {
        allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
      };
    };

    systemd = {
      user = {
        services = {
          omniroute = {
            description = "OmniRoute AI gateway";
            wantedBy = ["default.target"];
            after = ["network.target"];

            serviceConfig = {
              ExecStart = lib.escapeShellArgs (
                [
                  (lib.getExe omniroute)
                ]
                ++ cfg.extraArgs
              );
              Restart = "on-failure";
              RestartSec = "5s";
              Environment = [
                "PORT=${toString cfg.port}"
                "DATA_DIR=${cfg.dataDir}"
                "APP_LOG_TO_FILE=false"
              ];
            };
          };
        };
      };
    };
  };

  services = {
    omniroute = {
      enable = true;
    };
  };
}
