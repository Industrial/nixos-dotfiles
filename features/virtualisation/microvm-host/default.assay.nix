# Colocated suite for features/virtualisation/microvm-host: one VM declared with a stand-in
# runner, and what the host makes of it (users, units, sandboxing, polkit).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  runner =
    pkgs.emptyDirectory.overrideAttrs (_: {
      passthru = {
        tapMultiQueue = true;
        supportsNotifySocket = true;
      };
    })
    // {
      tapMultiQueue = true;
      supportsNotifySocket = true;
    };
  cfg = nixos.eval {
    modules = [
      ./default.nix
      {
        features.virtualisation.microvm-host = {
          operators = ["tom"];
          vms.vm1 = {
            inherit runner;
            uid = 8201;
            tap = {
              name = "tap1";
              address = "10.9.1.1/24";
            };
            shares = [
              {
                tag = "work";
                source = "/srv/vm1";
                socket = "work.sock";
                guestUid = 1000;
              }
            ];
            environment.X = "y";
            memoryMax = "2G";
          };
        };
      }
    ];
  };
  svc = cfg.systemd.services;
  vmm = svc.microvm-vm1.serviceConfig;
  fs = svc.microvm-vm1-fs-work.serviceConfig;
  tap = svc.microvm-vm1-tap.serviceConfig;
in
  assay.suite "virtualisation-microvm-host" {
    ownUser = assay.eq [cfg.users.users.microvm-vm1.uid cfg.users.users.microvm-vm1.isSystemUser vmm.User fs.User] [8201 true "microvm-vm1" "microvm-vm1"];
    operators = assay.eq cfg.users.groups.microvm-operators.members ["tom"];
    stateDirIsGroupPrivate = assay.eq (builtins.elem "d /var/lib/microvm-host/vm1 2770 microvm-vm1 microvm-operators - -" cfg.systemd.tmpfiles.rules) true;
    notifyReadiness = assay.eq vmm.Type "notify";
    vmmSandboxed = assay.eq [vmm.ProtectSystem vmm.ProtectHome vmm.NoNewPrivileges vmm.CapabilityBoundingSet vmm.DevicePolicy vmm.DeviceAllow vmm.IPAddressDeny] ["strict" true true "" "closed" ["/dev/kvm rw" "/dev/net/tun rw"] "any"];
    vmmLimited = assay.eq [vmm.MemoryMax vmm.MemorySwapMax vmm.CPUQuota vmm.TasksMax] ["2G" "0" "400%" 512];
    vmmEnvironment = assay.eq svc.microvm-vm1.environment.X "y";
    neverRestartedBySwitch = assay.eq svc.microvm-vm1.restartIfChanged false;
    virtiofsdUnprivilegedNoNetwork = assay.eq [fs.PrivateNetwork fs.ReadWritePaths fs.RestrictAddressFamilies] [true ["/srv/vm1"] ["AF_UNIX"]];
    virtiofsdSocketActivated = assay.eq cfg.systemd.sockets.microvm-vm1-fs-work.socketConfig.ListenStream "/var/lib/microvm-host/vm1/work.sock";
    virtiofsdMapsTheGuestUid = assay.eq (lib.hasInfix "--translate-uid=map:1000:8201:1" fs.ExecStart) true;
    tapOwnedByTheVm = assay.eq (lib.hasInfix "user microvm-vm1 vnet_hdr multi_queue" (builtins.head tap.ExecStart)) true;
    tapNoForwarding = assay.eq (builtins.any (lib.hasInfix "tap1.forwarding=0") tap.ExecStart) true;
    polkitOnlyTheseUnits = assay.eq (lib.hasInfix ''["microvm-vm1.service"]'' cfg.security.polkit.extraConfig) true;
    networkManagerKeepsOff = assay.eq cfg.networking.networkmanager.unmanaged ["interface-name:tap1"];
  }
