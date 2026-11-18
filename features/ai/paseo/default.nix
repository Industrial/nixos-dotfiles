# Paseo — self-hosted orchestrator for coding agents, with a web UI.
# https://github.com/getpaseo/paseo  ·  Apache-2.0  ·  24.3k stars
#
# A resident daemon runs the first-party agent CLIs (Claude Code, Codex,
# OpenCode, …) as subprocesses and exposes them to a browser, desktop app,
# mobile app and its own CLI. Credentials and source stay on this host; only the
# control surface is remote.
#
# FROM NIXPKGS, which is the whole reason this feature is short. `pkgs.paseo`
# 0.15.4 is a real buildNpmPackage from the upstream tag, with autoPatchelfHook
# and a node-pty rebuilt against the nixpkgs node — so none of the vendored
# generic-linux binary problems that features/ai/cloudcli had to work around
# apply here, and there is no tarball to pin or lockfile to vendor. It ships two
# binaries: `paseo` (CLI) and `paseo-server` (the daemon supervisor that also
# serves the web UI).
#
# REPLACES features/ai/cloudcli, which is commented out in profiles/ai.nix
# rather than deleted. The two occupy exactly the same niche — a browser over
# the coding agents already configured on this host — and running both means two
# daemons watching the same ~/.claude session files and two ports to remember.
# Paseo wins on being packaged in nixpkgs (so no vendored lockfile, no
# hand-written prebuilt-binary guards, no REGENERATE.md), on Apache-2.0 against
# CloudCLI's AGPL, and on binding loopback by default instead of 0.0.0.0.
#
# WHAT PASEO DOES NOT REPLACE: features/ai/claude-code. Paseo drives agent CLIs,
# it does not contain one, so the CLI feature stays and this feature depends on
# it. The same is true of the Zed agent wiring in features/programming/zed —
# that is an editor surface on the same CLI, not a competing web UI.
#
# NO NIXOS MODULE EXISTS for paseo (checked against nixos-unstable: nothing under
# nixos/modules/services for it), so the unit below is hand-written, in the same
# shape features/ai/cloudcli and features/ai/paperclip use.
#
# A USER SERVICE, NOT A SYSTEM ONE, for the same reason as cloudcli: the daemon
# spawns the agent CLIs, which need the subscription login in
# ~/.claude/.credentials.json and write access to the working trees under $HOME.
# A system account would mean copying credentials out of $HOME or handing a
# daemon write access to the operator's repositories. linger brings it up at
# boot rather than at first login.
#
# LOOPBACK, AND HERE THAT IS UPSTREAM'S DEFAULT RATHER THAN A CORRECTION.
# Paseo's DEFAULT_PORT is 6767 and it binds 127.0.0.1 unless told otherwise —
# unlike CloudCLI, whose 0.0.0.0 default this repo had to override. Both are set
# explicitly anyway: a default that moves in a later release would otherwise
# publish a browser that can run shell commands to the LAN, and this fleet has no
# Tailscale and a firewall that opens nothing. Reach it from another device by
# forwarding the port, not by widening the bind:
#
#   ssh -N -L 6767:127.0.0.1:6767 drakkar
{
  pkgs,
  settings,
  ...
}: let
  home = settings.userdir;
  stateDir = "${home}/.paseo";
  port = 6767;
in {
  environment.systemPackages = [pkgs.paseo];

  # Start at boot and survive logout.
  users.users.${settings.username}.linger = true;

  systemd.user.services.paseo = {
    description = "Paseo — coding-agent orchestrator with web UI";
    wantedBy = ["default.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    # PATH IS LOAD-BEARING, AND A NARROW ONE CRASHES THE DAEMON IN A LOOP.
    #
    # A systemd unit gets no login PATH, so every binary paseo shells out to has
    # to be listed here. The first version of this feature carried only the set
    # features/ai/cloudcli needs, and the daemon crash-looped roughly every two
    # minutes — eleven child PIDs in twenty minutes — which presents as the web
    # UI dropping its connection over and over:
    #
    #   "msg":"Uncaught exception — daemon crashing"
    #   "message":"spawn ps ENOENT"
    #   "spawnargs":["-o","pid","--no-headers","--ppid",3209195]
    #
    # The daemon enumerates its own children with `ps`, and an ENOENT there is
    # not handled — it reaches the top level and takes the process down.
    # systemd's own NRestarts stays 0 throughout, because it is the supervisor
    # respawning its child rather than the unit restarting, so the unit looks
    # healthy while the connection keeps dying. The same missing `ps` also broke
    # terminals outright: "Terminal worker cannot read its own process identity".
    #
    # The list below is derived from the spawn call sites in paseo 0.15.4's own
    # source rather than guessed one failure at a time:
    #
    #   git (1284 call sites)  procps/ps (2)  gnutar/tar (3)  which (4)
    #   openssh/ssh (3)        npm (3)        coreutils/mkfifo (1)  bash (1)
    #
    # Deliberately absent: codex, opencode and copilot, which paseo can also
    # drive. This host uses Claude Code; paseo reporting the others as
    # unavailable is correct behaviour rather than a fault, and adding agent CLIs
    # nobody runs would put three more toolchains in the closure. Add them here
    # if that changes.
    #
    # THE SYSTEM PROFILE IS APPENDED BEHIND THAT FLOOR. The agent CLI paseo
    # spawns inherits this PATH, and so do the MCP servers and hooks it starts.
    # With only the list above, every MCP server features/ai/claude-code installs
    # into environment.systemPackages — lean-ctx, roam, maestro, mcp-searxng,
    # uvx, context7-mcp — failed with ENOENT inside paseo sessions, and the
    # id-workflow hooks lost jq, while the same ~/.claude worked from a login
    # shell. Strings in `path` get /bin and /sbin appended, so these two entries
    # put the whole system and per-user profiles on PATH. Then anything the
    # claude-code feature adds shows up here too, with no second list to keep in
    # sync. The explicit packages stay first, as the floor the crash-loop fix
    # relies on.
    path =
      (with pkgs; [
        bashInteractive
        coreutils # mkfifo
        git
        gnutar # extracts the speech model; its absence is a recurring level-50 error
        openssh # ssh, for push
        procps # ps — without this the daemon crash-loops, see above
        ripgrep
        which # how paseo probes for optional binaries
        nodejs_22 # npm
        claude-code
        paseo
      ])
      ++ [
        "/run/current-system/sw"
        "/etc/profiles/per-user/${settings.username}"
      ];

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = home;
      ExecStart = "${pkgs.paseo}/bin/paseo-server";
      Restart = "on-failure";
      RestartSec = "10s";
      # An agent turn can hold the connection open for a long time; do not kill a
      # run mid-tool-call just because the unit is stopping.
      TimeoutStopSec = "60";
    };

    environment = {
      HOME = home;
      PASEO_HOME = stateDir;
      PASEO_HOST = "127.0.0.1";
      PASEO_PORT = toString port;
      # The daemon can run headless; this feature exists for the browser, so say
      # so rather than depending on the default.
      PASEO_WEB_UI_ENABLED = "true";
    };
  };
}
