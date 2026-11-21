# vcache (rust/tools/vcache) as this host's binary cache for the fleet: narinfo + NAR over
# HTTP, read straight from the local store, on the tailnet only. Clients are
# ./client.nix, which reads the serving hosts from common/fleet.nix.
#
# Sandbox: a DynamicUser with ProtectSystem=strict. The only things it reads beyond its
# own closure are /nix/store and /nix/var/nix/db (SQLite, opened read-only); the daemon
# socket is out of reach, so it cannot ask the daemon for anything. The only thing it
# writes is its StateDirectory, which holds the signing key.
#
# Signing key: generated here, at the first start, by `nix key generate-secret` into
# the StateDirectory (/var/lib/private/vcache/secret-key, 0600, owned by the dynamic
# user). It is never in the repo or the store. The public half is written next to it
# and logged on every start; copy it into this host's `cacheKey` in common/fleet.nix,
# which is what makes clients add the cache. Kept apart from
# features.hardening.storeSigning (features/nixos/users) on purpose: that key is the
# daemon's, provisioned out of band and off fleet-wide, and the cache must not need it.
#
# Listener: HOST is this host's tailscaleIp from common/fleet.nix, PORT is
# fleet.cachePort, and only tailscale0 opens the port. Binding the tailnet address
# fails until tailscaled has it, so the unit restarts every 5s without a start limit:
# systemd is the supervisor.
#
# Health probe (run on the host):
#   systemctl is-active vcache \
#     && curl -sf http://<tailscaleIp>:5100/nix-cache-info \
#     && curl -sf http://<tailscaleIp>:5100/$(basename $(readlink -f /run/current-system) | cut -c1-32).narinfo
{
  config,
  pkgs,
  settings,
  ...
}: let
  fleet = import ../../../common/fleet.nix;
  host = fleet.hosts.${settings.hostname} or {};
  bindIp = host.tailscaleIp or null;
  port = fleet.cachePort;

  vcache = pkgs.callPackage ../../../rust/tools/vcache/default.nix {};
  nix = config.nix.package;
  stateDir = "/var/lib/vcache";
  keyName = "${settings.hostname}-vcache-1";

  # First start: a fresh key. Every start: the public half, to a file and the journal.
  ensureKey = pkgs.writeShellScript "vcache-ensure-key" ''
    set -eu
    umask 077
    key="$STATE_DIRECTORY/secret-key"
    if [ ! -s "$key" ]; then
      ${nix}/bin/nix --extra-experimental-features nix-command key generate-secret --key-name ${keyName} > "$key.new"
      mv "$key.new" "$key"
    fi
    ${nix}/bin/nix --extra-experimental-features nix-command key convert-secret-to-public < "$key" > "$STATE_DIRECTORY/public-key"
    echo "vcache: public key $(cat "$STATE_DIRECTORY/public-key")"
  '';
in {
  assertions = [
    {
      assertion = bindIp != null;
      message = "features.nix.vcache: ${settings.hostname} has no tailscaleIp in common/fleet.nix, so vcache has no tailnet address to bind.";
    }
    {
      assertion = builtins.elem "builder" (host.roles or []);
      message = "features.nix.vcache: serving hosts are the builder-role hosts of common/fleet.nix; ${settings.hostname} is not one.";
    }
  ];

  environment.systemPackages = [vcache];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [port];

  systemd.services.vcache = {
    description = "vcache: the fleet binary cache, serving the local Nix store on the tailnet";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target" "tailscaled.service"];
    # Never give up: the bind waits on tailscaled, and a cache that stays down
    # costs clients only their fallback to cache.nixos.org.
    startLimitIntervalSec = 0;

    environment = {
      HOST = toString bindIp;
      PORT = toString port;
      HOME = stateDir;
      VCACHE_STORE_DIR = "/nix/store";
      VCACHE_DB = "/nix/var/nix/db/db.sqlite";
      VCACHE_SIGN_KEY_FILE = "${stateDir}/secret-key";
    };

    serviceConfig = {
      Type = "simple";
      ExecStartPre = ensureKey;
      ExecStart = "${vcache}/bin/vcache";
      Restart = "always";
      RestartSec = "5s";

      DynamicUser = true;
      StateDirectory = "vcache";
      StateDirectoryMode = "0700";
      UMask = "0077";

      ProtectSystem = "strict";
      ReadOnlyPaths = ["/nix/store" "/nix/var/nix/db"];
      InaccessiblePaths = ["-/nix/var/nix/daemon-socket"];
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateUsers = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = [""];
      AmbientCapabilities = [""];
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];
    };
  };
}
