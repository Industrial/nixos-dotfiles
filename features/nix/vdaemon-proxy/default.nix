# vdaemon-proxy (rust/tools/vdaemon-proxy) in front of nix-daemon: every client of the
# daemon socket goes through it, and every worker-protocol op is logged to the journal
# as one JSON line (uid, op, store paths, duration, result). Phase 1 (#157) only
# observes: the policy hook allows everything, and #116's gated trust plugs in there.
#
# Sockets:
#
#   /nix/var/nix/daemon-socket/socket            vdaemon-proxy.socket (0666): what every
#                                                client connects to, as before
#   /nix/var/nix/daemon-socket-upstream/socket   nix-daemon.socket, moved: 0600 in a 0700
#                                                directory, so only root (the proxy) can
#                                                reach the real daemon
#
# The proxy connects upstream with each client's effective uid and gid (per-thread
# setresuid/setresgid, filesystem ids kept at root to reach the private socket), so
# the daemon's SO_PEERCRED, trusted-users and allowed-users see the real client and
# not root. That is why the service runs as root with CAP_SETUID and CAP_SETGID.
#
# A crash must not lock the box out of Nix. Three layers:
#
#   1. Socket activation. systemd owns the public socket. A proxy that dies leaves the
#      socket listening: new clients queue in its backlog and the next one starts the
#      proxy again. Restart=always (100 ms) restarts it at once anyway. Clients that
#      were mid-op see their connection reset, as with a daemon restart.
#   2. A fallback. If the proxy keeps failing (10 starts in 30 s), systemd gives up on
#      it (start-limit-hit, which also fails its socket) and OnFailure= starts
#      vdaemon-proxy-fallback.service. Its ExecCondition= lets it run only on that
#      result: OnFailure= also fires on every single crash, which Restart= undoes.
#      It stops the proxy's socket and runs the real daemon, nix-daemon --daemon, with
#      no socket passed, so nix-daemon binds the public path itself. Clients talk to
#      nix-daemon directly, unlogged, until an operator runs
#      `systemctl reset-failed vdaemon-proxy.service vdaemon-proxy.socket &&
#      systemctl start vdaemon-proxy.socket` (the socket stops the fallback as it
#      starts) or the next `nixos-rebuild switch`.
#   3. Rollback. `features.nix.vdaemon-proxy.enable = lib.mkForce false;` on the host
#      puts nix-daemon.socket back on the public path.
#
# The upstream daemon is socket-activated as before; the proxy's first connect starts it.
#
# Health probe (as a user, not root: root's nix uses the store directly):
#   systemctl is-active vdaemon-proxy.socket \
#     && nix-store -q --hash /run/current-system \
#     && systemctl is-active vdaemon-proxy.service \
#     && journalctl -u vdaemon-proxy --since -1min -o cat | grep -q '"op":"QueryPathInfo"'
{
  config,
  lib,
  pkgs,
  ...
}: let
  proxy = pkgs.callPackage ../../../rust/tools/vdaemon-proxy/default.nix {};
  nix = config.nix.package;
  public = "/nix/var/nix/daemon-socket/socket";
  upstream = "/nix/var/nix/daemon-socket-upstream/socket";
  daemon = config.systemd.services.nix-daemon;
  systemctl = "${config.systemd.package}/bin/systemctl";

  restore = "systemctl reset-failed vdaemon-proxy.service vdaemon-proxy.socket && systemctl start vdaemon-proxy.socket";

  # Exit 0 (run the fallback) only when systemd has given up on the proxy.
  gaveUp = pkgs.writeShellScript "vdaemon-proxy-gave-up" ''
    result=$(${systemctl} show -P Result vdaemon-proxy.service)
    if [ "$result" = start-limit-hit ]; then
      echo "vdaemon-proxy: the proxy keeps failing; serving ${public} from nix-daemon directly" >&2
      echo "vdaemon-proxy: restore with: ${restore}" >&2
      exit 0
    fi
    echo "vdaemon-proxy: failed ($result); systemd restarts it, no fallback" >&2
    exit 1
  '';
in {
  # A live switch moves nix-daemon.socket only if something restarts it; this does,
  # on the way in and (being outside features/, so ungated) on the way back out.
  # ./conformance.nix: the native answers checked against the daemon's (#183), off by default.
  # ./native.nix: read-only ops answered by the proxy itself, per op, off by default.
  imports = [../../../common/nix-daemon-listen.nix ./conformance.nix ./native.nix];

  environment.systemPackages = [proxy];

  # The real daemon's socket, moved somewhere only root can reach. The empty entry
  # resets the ListenStream= of nix's own unit file before the new one is added.
  systemd.sockets.nix-daemon.socketConfig = {
    ListenStream = lib.mkForce ["" upstream];
    SocketMode = "0600";
    DirectoryMode = "0700";
  };

  systemd.sockets.vdaemon-proxy = {
    description = "vdaemon-proxy: the Nix daemon socket, logged";
    wantedBy = ["sockets.target"];
    before = ["multi-user.target"];
    unitConfig.RequiresMountsFor = "/nix/store";
    # Not Conflicts=: that is symmetric, so OnFailure= queueing the fallback would stop
    # this socket even when the fallback then skips. Each side stops the other itself.
    # No RemoveOnStop either: systemd's bind (and nix-daemon's) replaces a stale file,
    # and a stop racing the other's bind would delete the new one.
    socketConfig = {
      ListenStream = public;
      SocketMode = "0666";
      ExecStartPre = "-${systemctl} stop --no-block vdaemon-proxy-fallback.service";
    };
  };

  systemd.services.vdaemon-proxy = {
    description = "vdaemon-proxy: log every nix-daemon worker op";
    requires = ["vdaemon-proxy.socket" "nix-daemon.socket"];
    after = ["vdaemon-proxy.socket" "nix-daemon.socket"];
    environment.VDAEMON_UPSTREAM = upstream;
    startLimitIntervalSec = 30;
    startLimitBurst = 10;
    unitConfig.OnFailure = ["vdaemon-proxy-fallback.service"];
    serviceConfig = {
      ExecStart = lib.getExe proxy;
      Restart = "always";
      RestartSec = "100ms";
      # Root, for the per-connection setresuid/setresgid; nothing else.
      CapabilityBoundingSet = "CAP_SETUID CAP_SETGID";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      # "-": not an error if the directory is not there yet.
      ReadWritePaths = ["-${builtins.dirOf upstream}"];
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = ["AF_UNIX"];
      RestrictNamespaces = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
    };
  };

  # The real daemon on the public path, as nix's own unit runs it but without a
  # socket unit: nix-daemon binds the path itself. NixOS's environment for the daemon
  # (PATH, CA bundle, locale) comes along.
  systemd.services.vdaemon-proxy-fallback = {
    description = "vdaemon-proxy fallback: nix-daemon on the public socket, direct";
    # It is started at every proxy failure and skips most of them, so it must never
    # hit a start limit of its own, least of all at the one failure it is for.
    startLimitIntervalSec = 0;
    inherit (daemon) path;
    environment = builtins.removeAttrs daemon.environment ["PATH"];
    unitConfig.RequiresMountsFor = ["/nix/store" "/nix/var" "/nix/var/nix/db"];
    serviceConfig =
      daemon.serviceConfig
      // {
        ExecCondition = gaveUp;
        # The proxy's socket out of the way (it is failed already; this makes it final).
        ExecStartPre = "-${systemctl} stop vdaemon-proxy.socket";
        ExecStart = "@${nix}/bin/nix-daemon nix-daemon --daemon";
        KillMode = "process";
        LimitNOFILE = 1048576;
        TasksMax = 1048576;
      };
  };
}
