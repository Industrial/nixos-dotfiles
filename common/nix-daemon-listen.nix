# Keep nix-daemon.socket bound where its unit says, across live switches. On every
# host, whether or not features.nix.vdaemon-proxy is on.
#
# NixOS's switch-to-configuration does not restart nix-daemon.socket when the socket's
# ListenStream changes. nix-daemon.service is `stopIfChanged = false`, so its socket is
# never cycled; systemd reloads the unit text but keeps the old listening fd. So when
# vdaemon-proxy takes over (the daemon's socket moves to
# /nix/var/nix/daemon-socket-upstream/socket), the daemon stays on the old path and the
# proxy has nothing to connect to. When it is rolled back, the daemon stays on the
# private path and the public one is a dead file. Either way, non-root Nix breaks until
# someone restarts the socket by hand (#157, the live switch on drakkar).
#
# nix-daemon-listen.service runs at boot and at every switch that changes the path (the
# path is in its environment, so the unit text changes with it). It asks the daemon for
# its version on the configured path. If nothing answers, it rebinds:
#
#   systemctl stop nix-daemon.service      KillMode=process: only the accepting process
#                                          stops. Running builds and client sessions
#                                          are its children and carry on.
#   systemctl restart nix-daemon.socket    the configured path, bound afresh
#   systemctl start nix-daemon.service     accepting on it again
#
# It sits outside features/ on purpose: lib/features.nix gates a feature's body behind
# its switch, but passes non-feature imports through, and the rollback is exactly the
# case where the feature is off. features/nix/vdaemon-proxy imports it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  public = "/nix/var/nix/daemon-socket/socket";
  configured = lib.toList (config.systemd.sockets.nix-daemon.socketConfig.ListenStream or []);
  listens = lib.filter (s: s != "") configured;
  expected =
    if listens == []
    then public
    else lib.last listens;
  nix = config.nix.package;
  systemctl = "${config.systemd.package}/bin/systemctl";

  answers = ''timeout 30 ${nix}/bin/nix --extra-experimental-features nix-command store info --store "unix://$NIX_DAEMON_LISTEN" >/dev/null 2>&1'';

  rebind = pkgs.writeShellScript "nix-daemon-listen" ''
    if ${answers}; then
      echo "nix-daemon-listen: the daemon answers on $NIX_DAEMON_LISTEN"
      exit 0
    fi
    echo "nix-daemon-listen: nothing answers on $NIX_DAEMON_LISTEN; rebinding nix-daemon.socket there" >&2
    ${systemctl} stop nix-daemon.service
    ${systemctl} restart nix-daemon.socket
    ${systemctl} start nix-daemon.service
    if ${answers}; then
      echo "nix-daemon-listen: the daemon answers on $NIX_DAEMON_LISTEN again"
      exit 0
    fi
    echo "nix-daemon-listen: still nothing on $NIX_DAEMON_LISTEN after the rebind" >&2
    exit 1
  '';
in {
  config = lib.mkIf config.nix.enable {
    systemd.services.nix-daemon-listen = {
      description = "Keep nix-daemon.socket bound at its configured path";
      wantedBy = ["multi-user.target"];
      after = ["nix-daemon.socket"];
      # The path is part of the unit, so a switch that moves it restarts this unit.
      environment.NIX_DAEMON_LISTEN = expected;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = rebind;
      };
    };
  };
}
