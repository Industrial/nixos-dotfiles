# microVM host (ADR-0009, #353): runs microvm.nix runners under cloud-hypervisor, one static
# user per VM, each VMM and each virtiofsd in its own sandboxed systemd unit.
#
# microvm.nix's own host module (`microvm.host`, `microvm.vms`) is deliberately not used: it
# runs every VM as the one user `microvm` and virtiofsd as root under supervisord. Here the
# runner a guest's `config.microvm.declaredRunner` builds is used as it is, and only the units
# around it are ours. Per VM <name>:
#
#   microvm-<name>-tap.service              root oneshot: the tap, owned by the VM's user, with
#                                           the host address; forwarding off on it
#   microvm-<name>-fs-<tag>.socket/.service virtiofsd for one share, socket-activated (`--fd`),
#                                           as the VM's user, no network, caps or home
#   microvm-<name>.service                  the runner (`bin/microvm-run`) as the VM's user,
#                                           Type=notify through the guest's vsock, stopped
#                                           through the API socket (`bin/microvm-shutdown`)
#
# The state directory /var/lib/microvm-host/<name> is <user>:<operatorGroup> 2770: the VMM
# writes its sockets and volumes there (UMask 0007), so the operators' group may reach the
# vsock socket and nobody else may. A VM's user is in no shared group, so one VM's VMM cannot
# open another's state.
#
# Members of `operatorGroup` may start, stop and restart `microvm-<name>.service` through polkit;
# nothing else is granted.
#
# Rollback: switch the feature (or the feature that enables it) off.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.virtualisation.microvm-host;
  stateRoot = "/var/lib/microvm-host";
  ip = "${pkgs.iproute2}/bin/ip";
  sysctl = "${pkgs.procps}/bin/sysctl";

  # The sandbox every unit here shares; each adds its own paths and devices.
  hardened = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectProc = "invisible";
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    LockPersonality = true;
    RemoveIPC = true;
    SystemCallArchitectures = "native";
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
  };

  vmOpts = {name, ...}: {
    options = {
      runner = lib.mkOption {
        type = lib.types.package;
        description = "The guest's `config.microvm.declaredRunner` (microvm.nix, cloud-hypervisor).";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "microvm-${name}";
        description = "The VM's own system user: owns its state, tap and sockets.";
      };
      uid = lib.mkOption {
        type = lib.types.int;
        description = "The user's uid. Fixed, so files the guest writes through virtiofs keep one owner.";
      };
      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "${stateRoot}/${name}";
        readOnly = true;
        description = "The VMM's working directory: sockets, volumes.";
      };
      tap = {
        name = lib.mkOption {
          type = lib.types.str;
          description = "The tap device; must equal the guest's `microvm.interfaces` id.";
        };
        address = lib.mkOption {
          type = lib.types.str;
          example = "10.233.1.1/24";
          description = "The host's address on the tap, with its prefix.";
        };
      };
      shares = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            tag = lib.mkOption {type = lib.types.str;};
            source = lib.mkOption {
              type = lib.types.str;
              description = "Host directory, owned by the VM's user.";
            };
            socket = lib.mkOption {
              type = lib.types.str;
              description = "Socket path relative to stateDir; must equal the guest share's `socket`.";
            };
            guestUid = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "When set, the guest sees the VM user's files as this uid and gid (virtiofsd's --translate-uid/gid), so one guest system can serve VMs with different host users.";
            };
          };
        });
        default = [];
      };
      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment of the VMM unit; the runner's `extraArgsScript` may read it.";
      };
      preStart = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "ExecStartPre command lines, run as the VM's user in stateDir.";
      };
      memoryMax = lib.mkOption {
        type = lib.types.str;
        description = "MemoryMax of the VMM unit (guest memory plus the VMM's own).";
      };
      cpuQuota = lib.mkOption {
        type = lib.types.str;
        default = "400%";
      };
      tasksMax = lib.mkOption {
        type = lib.types.int;
        default = 512;
      };
    };
  };

  perVm = f: lib.mkMerge (lib.mapAttrsToList f cfg.vms);
  unitOf = name: "microvm-${name}";
in {
  options.features.virtualisation.microvm-host = {
    operatorGroup = lib.mkOption {
      type = lib.types.str;
      default = "microvm-operators";
      description = "Group that may start and stop the VMs and reach their vsock sockets.";
    };
    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users added to operatorGroup.";
    };
    vms = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule vmOpts);
      default = {};
      description = "The VMs, by name.";
    };
  };

  # Top-level keys are fixed and only the values are computed from `vms`, so the module system
  # never needs `config` to learn which options this module defines.
  config = {
    boot.kernelModules = ["kvm-intel" "kvm-amd" "tun"];

    users.users = perVm (name: vm: {
      ${vm.user} = {
        isSystemUser = true;
        inherit (vm) uid;
        group = vm.user;
        description = "microVM ${name}";
      };
    });
    users.groups = lib.mkMerge [
      {${cfg.operatorGroup}.members = cfg.operators;}
      (perVm (_: vm: {${vm.user}.gid = vm.uid;}))
    ];

    systemd.tmpfiles.rules = lib.concatLists (lib.mapAttrsToList (_: vm:
      ["d ${vm.stateDir} 2770 ${vm.user} ${cfg.operatorGroup} - -"]
      ++ map (s: "d ${s.source} 2770 ${vm.user} ${cfg.operatorGroup} - -") vm.shares)
    cfg.vms);

    # A VM's own tap is never NetworkManager's business.
    networking.networkmanager.unmanaged = lib.mapAttrsToList (_: vm: "interface-name:${vm.tap.name}") cfg.vms;

    security.polkit.enable = true;
    security.polkit.extraConfig = let
      units = builtins.toJSON (map (n: "${unitOf n}.service") (builtins.attrNames cfg.vms));
    in ''
      // features/virtualisation/microvm-host: operators start and stop their VMs, nothing else.
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.isInGroup("${cfg.operatorGroup}") &&
            ${units}.indexOf(action.lookup("unit")) >= 0) {
          var verb = action.lookup("verb");
          if (verb == "start" || verb == "stop" || verb == "restart") {
            return polkit.Result.YES;
          }
        }
      });
    '';

    systemd.sockets = perVm (name: vm:
      lib.listToAttrs (map (s:
        lib.nameValuePair "${unitOf name}-fs-${s.tag}" {
          description = "microVM ${name}: virtiofs socket ${s.tag}";
          partOf = ["${unitOf name}.service"];
          socketConfig = {
            ListenStream = "${vm.stateDir}/${s.socket}";
            SocketUser = vm.user;
            SocketGroup = vm.user;
            SocketMode = "0600";
            Accept = false;
          };
        })
      vm.shares));

    systemd.services = lib.mkMerge [
      (perVm (name: vm: {
        "${unitOf name}-tap" = {
          description = "microVM ${name}: tap ${vm.tap.name}";
          partOf = ["${unitOf name}.service"];
          after = ["network-pre.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStartPre = "-${ip} link del ${vm.tap.name}";
            ExecStart = [
              ("${ip} tuntap add name ${vm.tap.name} mode tap user ${vm.user} vnet_hdr"
                + lib.optionalString vm.runner.tapMultiQueue " multi_queue")
              "${sysctl} -w net.ipv4.conf.${vm.tap.name}.forwarding=0"
              "${sysctl} -w net.ipv6.conf.${vm.tap.name}.disable_ipv6=1"
              "${ip} addr add ${vm.tap.address} dev ${vm.tap.name}"
              "${ip} link set ${vm.tap.name} up"
            ];
            ExecStop = "${ip} link del ${vm.tap.name}";
          };
        };
      }))

      (perVm (name: vm:
        lib.listToAttrs (map (s:
          lib.nameValuePair "${unitOf name}-fs-${s.tag}" {
            description = "microVM ${name}: virtiofsd for ${s.tag}";
            partOf = ["${unitOf name}.service"];
            requires = ["${unitOf name}-fs-${s.tag}.socket"];
            serviceConfig =
              hardened
              // {
                # Unprivileged, so no namespace sandbox of its own; systemd's is the sandbox,
                # and the share is the only writable path in it.
                ExecStart =
                  lib.escapeShellArgs [
                    "${pkgs.virtiofsd}/bin/virtiofsd"
                    "--fd=3"
                    "--shared-dir=${s.source}"
                    "--sandbox=none"
                    "--cache=auto"
                    "--thread-pool-size=4"
                  ]
                  + lib.optionalString (s.guestUid != null) (" "
                    + lib.escapeShellArgs [
                      "--translate-uid=map:${toString s.guestUid}:${toString vm.uid}:1"
                      "--translate-gid=map:${toString s.guestUid}:${toString vm.uid}:1"
                    ]);
                User = vm.user;
                Group = vm.user;
                UMask = "0027";
                ReadWritePaths = [s.source];
                PrivateNetwork = true;
                PrivateDevices = true;
                RestrictAddressFamilies = ["AF_UNIX"];
                RestrictNamespaces = true;
                # No SystemCallFilter: virtiofsd installs its own seccomp filter (`--seccomp=kill`),
                # sized to what it needs; systemd's @system-service set kills it (SIGSYS).
                TasksMax = 256;
                Restart = "on-failure";
              };
          })
        vm.shares)))

      (perVm (name: vm: {
        ${unitOf name} = let
          deps = ["${unitOf name}-tap.service"] ++ map (s: "${unitOf name}-fs-${s.tag}.socket") vm.shares;
        in {
          description = "microVM ${name} (cloud-hypervisor)";
          requires = deps;
          after = deps ++ ["network.target"] ++ map (s: "${unitOf name}-fs-${s.tag}.service") vm.shares;
          # A switch never restarts a running session; the next start picks up the new runner.
          restartIfChanged = false;
          inherit (vm) environment;
          serviceConfig =
            hardened
            // {
              Type =
                if vm.runner.supportsNotifySocket
                then "notify"
                else "simple";
              NotifyAccess = "all";
              User = vm.user;
              Group = vm.user;
              SupplementaryGroups = ["kvm"];
              UMask = "0007";
              WorkingDirectory = vm.stateDir;
              ReadWritePaths = [vm.stateDir];
              ExecStartPre = vm.preStart;
              ExecStart = "${vm.runner}/bin/microvm-run";
              ExecStop = "${vm.runner}/bin/microvm-shutdown";
              # cloud-hypervisor's hybrid vsock socket is not group-writable as created; the
              # operators' group (the directory's, by setgid) needs write to connect. Run once
              # the guest is ready, when the socket exists.
              ExecStartPost = "${pkgs.coreutils}/bin/chmod 0660 ${vm.stateDir}/notify.vsock";
              TimeoutStartSec = "5min";
              TimeoutStopSec = "1min";
              KillMode = "mixed";
              Restart = "no";
              LimitMEMLOCK = "infinity";
              LimitNOFILE = 65536;
              MemoryMax = vm.memoryMax;
              MemorySwapMax = "0";
              CPUQuota = vm.cpuQuota;
              TasksMax = vm.tasksMax;
              PrivateDevices = false;
              DevicePolicy = "closed";
              DeviceAllow = ["/dev/kvm rw" "/dev/net/tun rw"];
              RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
              RestrictNamespaces = true;
              IPAddressDeny = "any";
            };
        };
      }))
    ];
  };
}
