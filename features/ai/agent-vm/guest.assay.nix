# Colocated suite for features/ai/agent-vm/guest.nix: the guest system every slot runs, read off
# the feature's own evaluation of it.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [
      ./default.nix
      {features.ai.agent-vm.guestPackages = [];}
    ];
  };
  g = cfg.features.ai.agent-vm.guest.config;
in
  assay.suite "ai-agent-vm-guest" {
    # The same CID and no tap in the system: both are the slot's, at run time.
    sharedCid = assay.eq g.microvm.vsock.cid 3;
    tapAtRunTime = assay.eq [g.microvm.interfaces (g.microvm.extraArgsScript != null)] [[] true];
    # The overlay for the guest's own builds is the per-session volume.
    overlayOnTheVolume = assay.eq (map (v: v.mountPoint) g.microvm.volumes) [g.microvm.writableStoreOverlay];
    # The address and proxy come from the host, before the network is wanted.
    addressFromTheHost = assay.eq [g.systemd.services.agent-net.serviceConfig.EnvironmentFile (builtins.elem "network-online.target" g.systemd.services.agent-net.before)] ["/work/.session/net.env" true];
    # The clone is the agent's, in /work, never root's.
    cloneAsAgent = assay.eq [g.systemd.services.agent-session.serviceConfig.User (lib.hasInfix "/work/repo" g.systemd.services.agent-session.serviceConfig.ExecStart)] ["agent" true];
    agentUid = assay.eq g.users.users.agent.uid 1000;
    noRootPassword = assay.eq g.users.users.root.hashedPassword "!";
    noTimeOrDocs = assay.eq [g.services.timesyncd.enable g.documentation.enable] [false false];
  }
