# One microVM per agent session (ADR-0009, #353, the P0 development tier of #419).
#
# `slots` declared VMs, agent-1 .. agent-N, each on microvm-host (its own uid, sandboxed VMM and
# virtiofsd), each with its own egress proxy. A session is `vagent run --slot N --branch B`:
# see rust/tools/vagent. Per slot n:
#
#   user        agent-vm-n, uid 8100+n; its virtiofsd shows it to the guest as `agent` (1000)
#   state       /var/lib/microvm-host/agent-n: sockets (vsock notify.vsock, api.sock, work.sock),
#               session.img (the guest's overlay store, recreated each session), session/ (the
#               launcher's inputs: authorized_keys, session.env), work/ (the guest's /work)
#   network     tap agvm<n>, host 10.233.<n>.1/24, guest .2; no forwarding; the host firewall
#               admits only the proxy port from it
#   proxy       agent-vm-proxy-n: tinyproxy on 10.233.<n>.1:3128, a default-deny allowlist of
#               host names; its unit may not reach private, tailnet, link-local or loopback
#               addresses, and it resolves through public resolvers, never MagicDNS or the LAN
#   vsock       hybrid (a Unix socket per VM): readiness (Type=notify) and ssh to the guest
#
# Every slot runs the same guest system (./guest.nix); the slot is the host side. Each start
# empties work/ and deletes session.img (as the slot's user), writes the slot's address and
# proxy (net.env) and copies session/
# into work/.session. Nothing else from the host reaches the guest.
#
# Probe (no root): `systemctl status microvm-agent-1`; as the operator, `vagent run --slot 1
# --branch probe --command 'curl -sI https://github.com'`.
#
# Rollback: `features.ai.agent-vm.enable = lib.mkForce false;`.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.ai.agent-vm;
  vagentPkg = pkgs.callPackage ../../../rust/tools/vagent/default.nix {};
  # The host's absolute tools first; the operator's own options after.
  vagent = pkgs.writeShellScriptBin "vagent" ''
    exec ${vagentPkg}/bin/vagent ${lib.escapeShellArgs [
      "--systemctl"
      "${config.systemd.package}/bin/systemctl"
      "--ssh"
      "${pkgs.openssh}/bin/ssh"
      "--ssh-keygen"
      "${pkgs.openssh}/bin/ssh-keygen"
      "--ssh-proxy"
      "${config.systemd.package}/lib/systemd/systemd-ssh-proxy"
      "--git"
      "${pkgs.git}/bin/git"
      "--cp"
      "${pkgs.coreutils}/bin/cp"
    ]} "$@"
  '';

  slotNumbers = lib.range 1 cfg.slots;
  nameOf = n: "agent-${toString n}";
  stateOf = n: "/var/lib/microvm-host/${nameOf n}";

  # What differs per slot. None of it is in the guest system (see ./guest.nix).
  params = n: {
    name = nameOf n;
    uid = cfg.uidBase + n;
    tap = "agvm${toString n}";
    hostIp = "10.233.${toString n}.1";
    guestIp = "10.233.${toString n}.2";
    workDir = "${stateOf n}/work";
  };

  # The agent's uid inside every guest; each slot's virtiofsd maps it to the slot's own.
  guestUid = 1000;

  # One guest system for every slot.
  guest = import "${pkgs.path}/nixos/lib/eval-config.nix" {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs.agentVm = {
      inherit (cfg) memory vcpu volumeSize;
      inherit guestUid;
      packages = cfg.guestPackages;
      hostPkgs = pkgs;
    };
    modules = [inputs.microvm.nixosModules.microvm ./guest.nix] ++ cfg.guestModules;
  };

  # The slot's address and proxy, read by the guest at boot (/work/.session/net.env).
  netEnvOf = n: let
    p = params n;
    proxy = "http://${p.hostIp}:${toString cfg.proxyPort}";
  in
    pkgs.writeText "agent-vm-net-${toString n}.env" ''
      AGENT_GUEST_IP=${p.guestIp}
      http_proxy=${proxy}
      https_proxy=${proxy}
      HTTP_PROXY=${proxy}
      HTTPS_PROXY=${proxy}
      no_proxy=127.0.0.1,localhost
      NO_PROXY=127.0.0.1,localhost
    '';

  # Private, tailnet, link-local, loopback, multicast: never a proxy destination.
  denied = [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "224.0.0.0/4"
    "240.0.0.0/4"
    "::1/128"
    "fc00::/7"
    "fe80::/10"
    "ff00::/8"
  ];

  filterFile = pkgs.writeText "agent-vm-allowlist" (lib.concatMapStrings (h: h + "\n") cfg.allowlist);
  resolvConf = pkgs.writeText "agent-vm-resolv.conf" (lib.concatMapStrings (r: "nameserver ${r}\n") cfg.resolvers);
  hostsFile = pkgs.writeText "agent-vm-hosts" "127.0.0.1 localhost\n";
  nsswitch = pkgs.writeText "agent-vm-nsswitch.conf" "hosts: files dns\n";

  proxyConf = n:
    pkgs.writeText "agent-vm-proxy-${toString n}.conf" ''
      Port ${toString cfg.proxyPort}
      Listen ${(params n).hostIp}
      Allow ${(params n).guestIp}
      Timeout 600
      MaxClients 64
      Syslog On
      LogLevel Connect
      DisableViaHeader Yes
      FilterDefaultDeny Yes
      FilterType ere
      FilterURLs No
      FilterCaseSensitive No
      Filter "${filterFile}"
      ConnectPort 443
    '';
in {
  imports = [../../virtualisation/microvm-host];

  options.features.ai.agent-vm = {
    slots = lib.mkOption {
      type = lib.types.ints.between 1 32;
      default = 3;
      description = "How many sessions may run at once.";
    };
    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users who may start sessions (members of `agent-vm`).";
    };
    uidBase = lib.mkOption {
      type = lib.types.int;
      default = 8100;
      description = "Slot n's user (and the guest's agent) has uid uidBase + n.";
    };
    memory = lib.mkOption {
      type = lib.types.int;
      default = 4096;
      description = "Guest memory per slot, MiB.";
    };
    vcpu = lib.mkOption {
      type = lib.types.int;
      default = 4;
    };
    volumeSize = lib.mkOption {
      type = lib.types.int;
      default = 32768;
      description = "The per-session overlay volume, MiB (sparse).";
    };
    proxyPort = lib.mkOption {
      type = lib.types.port;
      default = 3128;
    };
    allowlist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "POSIX extended regular expressions over host names; everything else is refused.";
      default = [
        "^github\\.com$"
        "^api\\.github\\.com$"
        "^codeload\\.github\\.com$"
        "^(.+\\.)?githubusercontent\\.com$"
        "^cache\\.nixos\\.org$"
        "^nix-community\\.cachix\\.org$"
        "^api\\.anthropic\\.com$"
        "^statsig\\.anthropic\\.com$"
        "^console\\.anthropic\\.com$"
        "^claude\\.ai$"
        "^crates\\.io$"
        "^(index|static)\\.crates\\.io$"
        "^registry\\.npmjs\\.org$"
        "^pypi\\.org$"
        "^files\\.pythonhosted\\.org$"
      ];
    };
    resolvers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Public resolvers the proxies use (Quad9). Never the LAN's or MagicDNS.";
      default = ["9.9.9.9" "149.112.112.112"];
    };
    guestPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [git gh curl jq ripgrep fd claude-code nix-output-monitor];
      description = "What the guest's agent has on PATH.";
    };
    guestModules = lib.mkOption {
      type = lib.types.listOf lib.types.deferredModule;
      default = [];
      description = "Extra NixOS modules for every guest.";
    };
    guest = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      default = guest;
      description = "The evaluated guest system every slot runs (for tests and measurements).";
    };
  };

  config = {
    environment.systemPackages = [vagent];

    features.virtualisation.microvm-host = {
      operatorGroup = "agent-vm";
      inherit (cfg) operators;
      vms = lib.listToAttrs (map (n: let
        p = params n;
        st = stateOf n;
      in
        lib.nameValuePair p.name {
          runner = guest.config.microvm.declaredRunner;
          user = "agent-vm-${toString n}";
          inherit (p) uid;
          tap = {
            name = p.tap;
            address = "${p.hostIp}/24";
          };
          # Read by the guest's runner (`--net tap=$AGENT_TAP`, ./guest.nix).
          environment.AGENT_TAP = p.tap;
          shares = [
            {
              tag = "work";
              source = p.workDir;
              socket = "work.sock";
              inherit guestUid;
            }
          ];
          # A fresh session: empty /work and a new overlay volume; the slot's address and
          # proxy, and the launcher's inputs, copied in (those are absent when the slot is
          # started without vagent: it then boots with no session). `find -delete` never
          # follows the links a guest may have left.
          preStart = [
            "${pkgs.findutils}/bin/find ${p.workDir} -mindepth 1 -delete"
            "${pkgs.coreutils}/bin/rm -f ${st}/session.img"
            "${pkgs.coreutils}/bin/mkdir -p ${p.workDir}/.session ${p.workDir}/home"
            "${pkgs.coreutils}/bin/cp ${netEnvOf n} ${p.workDir}/.session/net.env"
            "-${pkgs.coreutils}/bin/cp --no-dereference ${st}/session/authorized_keys ${st}/session/session.env ${p.workDir}/.session/"
          ];
          memoryMax = "${toString (cfg.memory + 1024)}M";
          cpuQuota = "${toString (cfg.vcpu * 100)}%";
        })
      slotNumbers);
    };

    systemd.tmpfiles.rules = map (n: "d ${stateOf n}/session 2770 agent-vm-${toString n} agent-vm - -") slotNumbers;

    # Only the slot's own proxy, only from its own tap.
    networking.firewall.interfaces = lib.listToAttrs (map (n: lib.nameValuePair (params n).tap {allowedTCPPorts = [cfg.proxyPort];}) slotNumbers);
    # No forwarding to or from any slot, whatever else the host routes.
    networking.firewall.extraCommands = lib.mkIf (!config.networking.nftables.enable) ''
      iptables -w -I FORWARD -i agvm+ -j DROP
      iptables -w -I FORWARD -o agvm+ -j DROP
    '';
    networking.nftables.tables.agent-vm = lib.mkIf config.networking.nftables.enable {
      family = "inet";
      content = ''
        chain forward {
          type filter hook forward priority -10; policy accept;
          iifname "agvm*" drop
          oifname "agvm*" drop
        }
      '';
    };

    systemd.services = lib.listToAttrs (map (n: let
      p = params n;
      unit = "microvm-${p.name}";
    in
      lib.nameValuePair "agent-vm-proxy-${toString n}" {
        description = "agent slot ${toString n}: egress proxy (allowlist)";
        bindsTo = ["${unit}-tap.service"];
        after = ["${unit}-tap.service"];
        requiredBy = ["${unit}.service"];
        before = ["${unit}.service"];
        partOf = ["${unit}.service"];
        serviceConfig = {
          ExecStart = "${pkgs.tinyproxy}/bin/tinyproxy -d -c ${proxyConf n}";
          DynamicUser = true;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictNamespaces = true;
          LockPersonality = true;
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
          SystemCallFilter = ["@system-service"];
          # The guest's own address may talk to it; the public resolvers may answer it; no
          # other private address is reachable, whatever a name resolves to.
          IPAddressAllow = ["${p.guestIp}/32" "${p.hostIp}/32"] ++ cfg.resolvers;
          IPAddressDeny = denied;
          BindReadOnlyPaths = ["${resolvConf}:/etc/resolv.conf" "${hostsFile}:/etc/hosts" "${nsswitch}:/etc/nsswitch.conf"];
          InaccessiblePaths = ["-/run/nscd" "-/var/run/nscd"];
          MemoryMax = "64M";
          TasksMax = 128;
          Restart = "on-failure";
        };
      })
    slotNumbers);
  };
}
