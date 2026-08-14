# OmniRoute — local AI gateway for Hermes, OpenCode, and other OpenAI-compatible tools
# https://github.com/diegosouzapw/OmniRoute
#
# API:       http://127.0.0.1:20128/v1
# Dashboard: http://127.0.0.1:20128
#
# First-time setup (after enabling this module):
#   1. systemctl --user enable --now omniroute.service
#   2. Open the dashboard and set an admin password
#   3. Connect free providers (OpenCode Zen, Pollinations, Groq, Gemini, NVIDIA NIM, …)
#   4. Create an endpoint API key for Hermes
#   5. Set OMNIROUTE_API_KEY in ~/.hermes/.env (see auth.json.example)
{
  config,
  lib,
  pkgs,
  ...
}: let
  omniroute = pkgs.callPackage ./package.nix {};
in {
  environment.systemPackages = [
    omniroute
  ];

  systemd.user.services.omniroute = {
    description = "OmniRoute AI gateway";
    documentation = ["https://github.com/diegosouzapw/OmniRoute"];
    after = ["network.target"];
    wantedBy = ["default.target"];

    serviceConfig = {
      ExecStart = lib.getExe omniroute;
      Restart = "on-failure";
      RestartSec = "5s";
      # Journald only — file logging can grow unbounded when SQLite is unavailable.
      Environment = [
        "APP_LOG_TO_FILE=false"
        "PORT=20128"
        "NODE_OPTIONS=--max-old-space-size=4096"
      ];
    };
  };
}
