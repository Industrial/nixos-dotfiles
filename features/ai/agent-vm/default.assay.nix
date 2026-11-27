# Colocated suite for features/ai/agent-vm (ADR-0009, #353): what a slot is made of, and what
# its guest does not get. The runtime half (from inside a guest) is test.nix.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [
      ./default.nix
      {
        features.ai.agent-vm = {
          slots = 2;
          operators = ["tom"];
          guestPackages = [];
        };
      }
    ];
  };
  guest = cfg.features.ai.agent-vm.guests.agent-1.config;
  vm = cfg.features.virtualisation.microvm-host.vms.agent-1;
  vmm = cfg.systemd.services.microvm-agent-1.serviceConfig;
  fs = cfg.systemd.services.microvm-agent-1-fs-work.serviceConfig;
  proxy = cfg.systemd.services.agent-vm-proxy-1.serviceConfig;
  shareSources = map (s: s.source) guest.microvm.shares;
in
  assay.suite "ai-agent-vm" {
    slotsAreDeclared = assay.eq (builtins.attrNames cfg.features.virtualisation.microvm-host.vms) ["agent-1" "agent-2"];

    # The store is this guest's closure on an image, not the host's /nix/store.
    closureOnlyStore = assay.eq [guest.microvm.storeOnDisk guest.microvm.storeDiskType] [true "erofs"];
    noHostStoreShare = assay.eq (builtins.elem "/nix/store" shareSources) false;
    # The one share is the slot's work directory: nothing from any home directory.
    onlyTheWorkShare = assay.eq shareSources ["/var/lib/microvm-host/agent-1/work"];
    noHomeShare = assay.eq (builtins.any (lib.hasPrefix "/home") shareSources) false;
    # No operator key: the only authorized keys are the session's, on the share.
    noOperatorKey = assay.eq [guest.users.users.agent.openssh.authorizedKeys.keys guest.services.openssh.authorizedKeysFiles] [[] ["/work/.session/authorized_keys"]];
    noRootLogin = assay.eq guest.services.openssh.settings.PermitRootLogin "no";
    sshOverVsockOnly = assay.eq [guest.microvm.vsock.ssh.enable guest.services.openssh.openFirewall guest.networking.firewall.allowedTCPPorts] [true false []];
    # No route, no resolver: the proxy is the way out.
    noResolver = assay.eq guest.networking.nameservers [];
    proxyIsTheWayOut = assay.eq guest.networking.proxy.default "http://10.233.1.1:3128";
    cloudHypervisor = assay.eq guest.microvm.hypervisor "cloud-hypervisor";
    ownDaemonNotTheHosts = assay.eq (lib.unique guest.nix.settings.trusted-users) ["root"];

    # Host side: the VMM and virtiofsd as the slot's own user, sandboxed, limited.
    ownUser = assay.eq [vmm.User fs.User cfg.users.users.agent-vm-1.uid] ["agent-vm-1" "agent-vm-1" 8101];
    vmmSandboxed = assay.eq [vmm.ProtectSystem vmm.ProtectHome vmm.NoNewPrivileges vmm.CapabilityBoundingSet vmm.DevicePolicy] ["strict" true true "" "closed"];
    vmmLimited = assay.eq [vmm.MemoryMax vmm.CPUQuota vmm.MemorySwapMax] ["5120M" "400%" "0"];
    virtiofsdNoNetwork = assay.eq [fs.PrivateNetwork fs.ReadWritePaths] [true ["/var/lib/microvm-host/agent-1/work"]];
    tapOwnedBySlot = assay.eq (lib.hasInfix "user agent-vm-1" (builtins.head cfg.systemd.services.microvm-agent-1-tap.serviceConfig.ExecStart)) true;
    operatorsInGroup = assay.eq cfg.users.groups.agent-vm.members ["tom"];
    stateDir = assay.eq vm.stateDir "/var/lib/microvm-host/agent-1";

    # The proxy: no private, tailnet or loopback destination, only the guest as a client.
    proxyDeniesFleet = assay.eq (map (r: builtins.elem r proxy.IPAddressDeny) ["100.64.0.0/10" "192.168.0.0/16" "10.0.0.0/8" "127.0.0.0/8" "fc00::/7"]) [true true true true true];
    proxyAllowsOnlyItsGuest = assay.eq (builtins.head proxy.IPAddressAllow) "10.233.1.2/32";
    proxyResolvesPublicly = assay.eq (lib.hasSuffix ":/etc/resolv.conf" (builtins.head proxy.BindReadOnlyPaths)) true;
    firewallOnlyProxyPort = assay.eq cfg.networking.firewall.interfaces.agvm1.allowedTCPPorts [3128];
  }
