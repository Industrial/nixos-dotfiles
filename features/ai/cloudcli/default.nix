# CloudCLI — browser front end for the Claude Code sessions already on this host.
#
# WHY THIS AND NOT A CHAT UI. CloudCLI does not keep its own idea of a session. It
# reads ~/.claude — the same projects, history, settings.json, MCP servers and
# permission allowlists the CLI reads — and writes changes back to those files. So
# the sessions this repo's claude-code feature produces appear in the browser with
# no import step, and a setting changed in the UI is a plain diff in the payload
# rather than a divergent copy. That property is the whole reason it is here: this
# host's Claude Code is heavily configured (lean-ctx, roam-code, maestro, context7
# through features/ai/claude-code/.claude/mcp.json, plus the id-workflow plugin's
# mode guards), and a console that wrapped Claude Code in its own session model
# would be fighting all of it.
#
# A USER SERVICE, NOT A SYSTEM ONE, and not negotiable. CloudCLI spawns the agent
# CLI as a child process, which then needs the subscription login from
# ~/.claude/.credentials.json and write access to the working trees under the
# user's home. Running it as a system user would mean either copying credentials
# out of $HOME or giving a daemon account write access to the operator's repos.
# linger is enabled so it comes up at boot rather than at first login, the same
# shape features/ai/paperclip uses.
#
# BOUND TO LOOPBACK, DELIBERATELY. Upstream defaults HOST to 0.0.0.0 (see
# dist-server/server/index.js) which on these hosts would publish a browser that
# can run shell commands and push commits to the LAN. The fleet has no Tailscale
# (features/security/tailscale is enable = false and unimported) and
# features/nixos/networking/firewall.nix opens nothing, so loopback is both the
# safe default and the honest one: drakkar and muninn are desktops and the browser
# is on the machine. For access from another device, forward the port over SSH:
#
#   ssh -N -L 3001:127.0.0.1:3001 drakkar
#
# rather than changing the bind address. First visit asks for a username and
# password, which CloudCLI stores in ~/.cloudcli/auth.db; the JWT signing secret
# is generated into the same database on first run, so there is no secret for this
# module to provision and none is referenced here.
#
# STATE LIVES IN $HOME, NOT THE STORE. DATABASE_PATH and WORKSPACES_ROOT are set
# explicitly even though both match upstream's defaults — a default that moves
# under us would relocate the account database silently, and this is a file worth
# being able to find. Nothing is written into the install directory.
{
  pkgs,
  settings,
  ...
}: let
  cloudcli = pkgs.callPackage ./package.nix {};
  home = settings.userdir;
  stateDir = "${home}/.cloudcli";
  port = 3001;
in {
  environment.systemPackages = [cloudcli];

  # Start at boot and survive logout.
  users.users.${settings.username}.linger = true;

  systemd.user.services.cloudcli = {
    description = "CloudCLI — web UI for coding-agent sessions";
    wantedBy = ["default.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    # The agent CLIs are spawned as children and resolve their own tooling through
    # PATH: git for the repository panel, openssh for push over SSH, ripgrep for
    # search, and a real shell because the built-in terminal spawns one.
    path = with pkgs; [
      bashInteractive
      coreutils
      git
      openssh
      ripgrep
      nodejs_22
      claude-code
      cloudcli
    ];

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = home;
      ExecStart = "${cloudcli}/bin/cloudcli";
      Restart = "on-failure";
      RestartSec = "10s";
      # Agent turns can hold the socket open for a long time; do not kill a run
      # that is mid-tool-call just because the unit is stopping.
      TimeoutStopSec = "60";
    };

    environment = {
      HOME = home;
      HOST = "127.0.0.1";
      SERVER_PORT = toString port;
      DATABASE_PATH = "${stateDir}/auth.db";
      WORKSPACES_ROOT = home;
    };
  };
}
