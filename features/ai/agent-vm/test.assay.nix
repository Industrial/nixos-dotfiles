# Colocated suite for features/ai/agent-vm/test.nix, the VM test of the agent microVMs (#353).
# Evaluates the test's nodes, so the claims are about the machines under test; no VM is
# booted here (`nix build .#checks.x86_64-linux.agent-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  test = import ./test.nix {
    inherit pkgs;
    inputs = nixos.flakeInputs;
  };
  inherit (test.nodes) host;
  on = host.specialisation.agentvm.configuration;
in
  assay.suite "agent-vm-test" {
    named = assay.eq test.name "vm-test-run-agent-vm";
    # Booted WITHOUT the feature, switched into it live by the specialisation.
    bootsWithout = assay.eq [(host.systemd.services ? microvm-agent-1) (on.systemd.services ? microvm-agent-1)] [false true];
    # The real hardening: muninn's STIG profile and the restricted daemon.
    stigTestHost = assay.eq on.security.stig.profile "test-host";
    restrictedDaemon = assay.eq (lib.unique on.nix.settings.allowed-users) ["@wheel" "root"];
    # Two slots, so one slot's user can be shown not to reach the other's state.
    twoSlots = assay.eq (builtins.attrNames on.features.virtualisation.microvm-host.vms) ["agent-1" "agent-2"];
    aliceOperates = assay.eq on.users.groups.agent-vm.members ["alice"];
    # The "fleet" and the "LAN" are private ranges the proxy must refuse; the "web" is public.
    fleetIsTailnetLike = assay.eq (map (a: a.address) test.nodes.fleet.networking.interfaces.eth1.ipv4.addresses) ["100.64.0.5" "192.168.1.5"];
    proxyResolvesThroughTheTestWeb = assay.eq on.features.ai.agent-vm.resolvers ["203.0.113.53"];
  }
