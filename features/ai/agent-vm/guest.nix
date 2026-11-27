# The agent guest (ADR-0009): a minimal NixOS on microvm.nix and cloud-hypervisor.
#
#   store      an erofs image of this closure only (microvm.storeOnDisk), read-only, with an
#              overlay on the per-session volume for the guest's own builds
#   network    one tap, a static address, no default route, no DNS; everything leaves through
#              the slot's proxy on the host side of the tap
#   share      /work, the only host directory the guest sees, read-write: the clone (/work/repo),
#              the agent's home (/work/home) and the session's inputs (/work/.session)
#   operator   ssh over vsock only (systemd's ssh generator, vsock::22), with the per-session
#              public key the launcher put in /work/.session/authorized_keys
#   builds     the guest's own nix-daemon on the overlay store; substitutes through the proxy
#
# One guest system serves every slot: a NixOS system evaluated per slot costs the host's own
# evaluation a whole system each (muninn's VM-test checks went over CI's memory budget with
# three). What differs per slot comes in at run time, from the host: the tap (`--net`, from
# the VMM unit's AGENT_TAP), and the address and proxy (/work/.session/net.env, written by the
# VMM unit before boot). The CID is the same in every guest: cloud-hypervisor's vsock is
# hybrid, a Unix socket per VM, so no CID is global. The agent's uid is the same too; the
# slot's virtiofsd maps it to the slot's own host uid.
#
# `agentVm` is passed in by ./default.nix: limits, packages and the host's package set.
{
  lib,
  pkgs,
  agentVm,
  ...
}: let
  s = agentVm;
  rwStore = "/nix/.rw-store";
  netEnv = "/work/.session/net.env";
  # Every guest is alone on its own tap, so one MAC serves them all.
  mac = "02:00:0a:e9:00:02";
  netArgs = pkgs.writeShellScript "agent-vm-net-args" ''
    echo "--net tap=$AGENT_TAP,mac=${mac},num_queues=${toString (2 * s.vcpu)}"
  '';
in {
  networking.hostName = "agent";
  system.stateVersion = "25.05";
  # The host's package set, so guest paths are the host's and no second nixpkgs is evaluated.
  # microvm.nix's `optimize` adds an overlay, which an external package set cannot take; the
  # parts of it that matter here are set below.
  nixpkgs.pkgs = s.hostPkgs;
  microvm.optimize.enable = false;
  boot.kernelParams = ["8250.nr_uarts=1"];
  boot.initrd.systemd.tpm2.enable = false;
  systemd.tpm2.enable = false;
  boot.swraid.enable = false;

  microvm = {
    hypervisor = "cloud-hypervisor";
    inherit (s) vcpu;
    mem = s.memory;
    balloon = true;
    deflateOnOOM = true;
    vsock.cid = 3;
    vsock.ssh.enable = true;
    # Relative to the VMM's working directory (the slot's state directory).
    socket = "api.sock";
    storeOnDisk = true;
    storeDiskType = "erofs";
    writableStoreOverlay = rwStore;
    registerWithMachined = false;
    # The tap is the slot's; the VMM unit names it (microvm-host's `environment`).
    interfaces = [];
    extraArgsScript = "${netArgs}";
    volumes = [
      {
        # Deleted by the host before every session, so each starts empty.
        image = "session.img";
        mountPoint = rwStore;
        size = s.volumeSize;
        fsType = "ext4";
      }
    ];
    shares = [
      {
        proto = "virtiofs";
        tag = "work";
        # Not used by the guest (it mounts by tag); the host's virtiofsd serves the slot's.
        source = "/var/lib/microvm-host/agent/work";
        mountPoint = "/work";
        socket = "work.sock";
      }
    ];
  };

  # No route and no resolver: the proxy is the way out, and it resolves names itself.
  networking.useDHCP = false;
  networking.useNetworkd = false;
  networking.usePredictableInterfaceNames = false;
  networking.nameservers = lib.mkForce [];
  services.resolved.enable = false;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = lib.mkForce [];

  # The slot's address, from the host, before anything wants the network.
  systemd.services.agent-net = {
    description = "agent: the slot's address on eth0";
    wantedBy = ["network-online.target" "multi-user.target"];
    before = ["network-online.target" "agent-session.service" "nix-daemon.service"];
    after = ["work.mount" "sys-subsystem-net-devices-eth0.device"];
    wants = ["sys-subsystem-net-devices-eth0.device"];
    unitConfig.RequiresMountsFor = "/work";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = netEnv;
      ExecStart = [
        "${pkgs.iproute2}/bin/ip link set eth0 up"
        "${pkgs.iproute2}/bin/ip addr add \${AGENT_GUEST_IP}/24 dev eth0"
      ];
    };
  };
  # Every shell (login, and ssh's non-interactive commands) gets the slot's proxy.
  environment.extraInit = ''
    if [ -r ${netEnv} ]; then set -a; . ${netEnv}; set +a; fi
  '';

  users.mutableUsers = false;
  # Nobody logs in but the agent, by the session key: no root password, no wheel.
  users.allowNoPasswordLogin = true;
  users.users.agent = {
    isNormalUser = true;
    uid = s.guestUid;
    home = "/work/home";
    createHome = false;
    group = "agent";
    shell = pkgs.bashInteractive;
  };
  users.groups.agent.gid = s.guestUid;
  users.users.root.hashedPassword = "!";

  # ssh over vsock only: the generator's sshd-vsock socket; the TCP listener is closed by the
  # firewall and bound to loopback.
  services.openssh = {
    enable = true;
    openFirewall = false;
    listenAddresses = [
      {
        addr = "127.0.0.1";
        port = 22;
      }
    ];
    authorizedKeysFiles = lib.mkForce ["/work/.session/authorized_keys"];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = ["agent"];
      # The key file is on the share and written by the host; the guest's ownership checks
      # do not describe who can change it.
      StrictModes = false;
      AcceptEnv = ["TERM"];
    };
  };

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root"];
      allowed-users = ["agent" "root"];
      substituters = ["https://cache.nixos.org" "https://nix-community.cachix.org"];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      sandbox = true;
    };
    gc.automatic = false;
  };
  systemd.services.nix-daemon = {
    after = ["agent-net.service"];
    # Not in guest RAM: build directories on the session volume.
    environment.TMPDIR = "${rwStore}/tmp";
    serviceConfig.EnvironmentFile = "-${netEnv}";
  };
  systemd.tmpfiles.rules = ["d ${rwStore}/tmp 1777 root root - -"];

  environment.systemPackages = s.packages;
  environment.variables = {
    TERM = "xterm-256color";
    # Transcripts and the session's own login stay in /work (ADR-0009, decision 7).
    CLAUDE_CONFIG_DIR = "/work/home/.claude";
  };

  # The session's clone, made in the guest from the base ref (ADR-0009, decision 6). The host
  # writes no repository content: it only names the repository, the base and the branch.
  systemd.services.agent-session = {
    description = "agent session: clone the base ref into /work/repo";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "work.mount" "agent-net.service"];
    wants = ["network-online.target"];
    unitConfig = {
      ConditionPathExists = ["/work/.session/session.env" "!/work/repo/.git"];
      RequiresMountsFor = "/work";
    };
    environment.HOME = "/work/home";
    path = [pkgs.git];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "agent";
      Group = "agent";
      UMask = "0027";
      EnvironmentFile = [netEnv "/work/.session/session.env"];
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /work/home";
      ExecStart = "${pkgs.git}/bin/git clone --filter=blob:none --branch \${AGENT_BASE} \${AGENT_REPO} /work/repo";
      ExecStartPost = [
        "${pkgs.git}/bin/git -C /work/repo switch -c \${AGENT_BRANCH}"
        "${pkgs.git}/bin/git -C /work/repo config user.name \${AGENT_GIT_NAME}"
        "${pkgs.git}/bin/git -C /work/repo config user.email \${AGENT_GIT_EMAIL}"
      ];
    };
  };

  documentation.enable = false;
  services.timesyncd.enable = false;
}
