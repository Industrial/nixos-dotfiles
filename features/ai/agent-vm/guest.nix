# The agent guest (ADR-0009): a minimal NixOS on microvm.nix and cloud-hypervisor, one per slot.
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
# `agentVm` is passed in by ./default.nix: the slot's number, uid and limits.
{
  lib,
  pkgs,
  agentVm,
  ...
}: let
  s = agentVm;
  proxy = "http://${s.hostIp}:${toString s.proxyPort}";
  rwStore = "/nix/.rw-store";
  proxyEnv = {
    http_proxy = proxy;
    https_proxy = proxy;
    HTTP_PROXY = proxy;
    HTTPS_PROXY = proxy;
    no_proxy = "127.0.0.1,localhost";
    NO_PROXY = "127.0.0.1,localhost";
  };
in {
  networking.hostName = s.name;
  system.stateVersion = "25.05";
  # The host's package set, so guest paths are the host's and no second nixpkgs is evaluated.
  # microvm.nix's `optimize` adds an overlay, which an external package set cannot take; the
  # parts of it that matter here are set below.
  nixpkgs.pkgs = agentVm.hostPkgs;
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
    vsock.cid = s.cid;
    vsock.ssh.enable = true;
    # Relative to the VMM's working directory (the slot's state directory).
    socket = "api.sock";
    storeOnDisk = true;
    storeDiskType = "erofs";
    writableStoreOverlay = rwStore;
    registerWithMachined = false;
    interfaces = [
      {
        type = "tap";
        id = s.tap;
        inherit (s) mac;
      }
    ];
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
        source = s.workDir;
        mountPoint = "/work";
        socket = "work.sock";
      }
    ];
  };

  # No route and no resolver: the proxy is the way out, and it resolves names itself.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.nameservers = lib.mkForce [];
  services.resolved.enable = false;
  systemd.network.networks."10-tap" = {
    matchConfig.MACAddress = s.mac;
    address = ["${s.guestIp}/24"];
    networkConfig.LinkLocalAddressing = "no";
    linkConfig.RequiredForOnline = "routable";
  };
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = lib.mkForce [];
  networking.proxy.default = proxy;
  networking.proxy.noProxy = "127.0.0.1,localhost";

  users.mutableUsers = false;
  # Nobody logs in but the agent, by the session key: no root password, no wheel.
  users.allowNoPasswordLogin = true;
  users.users.agent = {
    isNormalUser = true;
    inherit (s) uid;
    home = "/work/home";
    createHome = false;
    group = "agent";
    shell = pkgs.bashInteractive;
  };
  users.groups.agent.gid = s.uid;
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
      # The key file is on the share, owned by the slot's uid (= agent's), group-writable
      # by the host's operators group, which the guest does not know.
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
    # Not in guest RAM: build directories on the session volume.
    gc.automatic = false;
  };
  systemd.services.nix-daemon.environment = proxyEnv // {TMPDIR = "${rwStore}/tmp";};
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
    after = ["network-online.target" "work.mount"];
    wants = ["network-online.target"];
    unitConfig = {
      ConditionPathExists = ["/work/.session/session.env" "!/work/repo/.git"];
      RequiresMountsFor = "/work";
    };
    environment = proxyEnv // {HOME = "/work/home";};
    path = [pkgs.git];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "agent";
      Group = "agent";
      UMask = "0027";
      EnvironmentFile = "/work/.session/session.env";
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
