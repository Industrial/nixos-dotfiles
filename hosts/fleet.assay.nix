# Assay: fleet-wide invariants, read off each host's full evaluated configuration.
#
# Per-feature suites prove what a module contributes on its own. These prove what a host
# ends up with once every feature, profile and override is merged — which is where a
# port opened by one feature and a service enabled by another actually meet. Hosts are
# built through lib/mk-host.nix, the same entry point flake.nix uses.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  inherit (nixos) lib;
  mkHost = import ../lib/mk-host.nix {inputs = nixos.flakeInputs;};

  hosts = ["drakkar" "huginn" "mimir" "muninn"];
  cfgs = lib.genAttrs hosts (h: (mkHost h).config);
  forAll = f: lib.mapAttrs (_: f) cfgs;
  onAll = value: lib.genAttrs hosts (_: value);

  # Ports reachable from an untrusted interface (anything but tailscale0 / lo). Pinned
  # exactly, so opening one is a deliberate edit here, not a side effect of some feature.
  #   22/tcp    sshd — services.openssh.openFirewall defaults to true
  #   5353/udp  mDNS
  # Note what is NOT here: mimir's NFS (111, 2049, 20048) is opened on tailscale0 only.
  publicTCP = onAll [22];
  publicUDP = onAll [5353];
  # mimir's NFS; drakkar's vcache (features/nix/vcache, fleet.cachePort).
  tailnetTCP =
    onAll {}
    // {
      mimir.tailscale0 = [111 2049 20048];
      drakkar.tailscale0 = [(import ../common/fleet.nix).cachePort];
    };
in
  assay.suite "fleet" {
    firewallOnEverywhere = assay.eq (forAll (c: c.networking.firewall.enable)) (onAll true);
    tailnetTrustedEverywhere =
      assay.eq (forAll (c: builtins.elem "tailscale0" c.networking.firewall.trustedInterfaces)) (onAll true);

    publicTCPPortsArePinned = assay.eq (forAll nixos.publicTCPPorts) publicTCP;
    publicUDPPortsArePinned = assay.eq (forAll nixos.publicUDPPorts) publicUDP;

    # Per-interface rules: only mimir's NFS and drakkar's vcache, and only on the tailnet.
    interfaceTCPRulesArePinned =
      assay.eq
      (forAll (c: lib.filterAttrs (_: v: v != []) (lib.mapAttrs (_: i: i.allowedTCPPorts) c.networking.firewall.interfaces)))
      tailnetTCP;
    noPublicTCPRanges = assay.eq (forAll (c: c.networking.firewall.allowedTCPPortRanges)) (onAll []);

    # Remote access: key-only sshd and the tailnet on every host.
    sshdKeyOnlyEverywhere = assay.eq (forAll (c: c.services.openssh.settings.PasswordAuthentication)) (onAll false);
    sshdNoRootEverywhere = assay.eq (forAll (c: c.services.openssh.settings.PermitRootLogin)) (onAll "no");
    tailscaleEverywhere = assay.eq (forAll (c: c.services.tailscale.enable)) (onAll true);

    # RustDesk: the client everywhere, the signal/relay server on mimir alone.
    rustdeskClientEverywhere = assay.eq (forAll (c: nixos.hasPackage c "rustdesk")) (onAll true);
    rustdeskServerOnlyOnMimir =
      assay.eq (forAll (c: c.services.rustdesk-server.enable)) (onAll false // {mimir = true;});

    # Pull convergence (ADR-0002) on every host, each tracking its own configuration: comin,
    # except where vdeploy took over (the `vdeploy` role, GH-160: drakkar).
    cominEverywhere = assay.eq (forAll (c: c.services.comin.enable)) (onAll true
      // {
        drakkar = false;
        mimir = false;
      });
    vdeployDeploysDrakkar = assay.eq (forAll (c: c.features.nix.vdeploy.mode)) (onAll "observe"
      // {
        drakkar = "deploy";
        mimir = "deploy";
      });
    cominTombstoneOnDrakkar = assay.eq (forAll (c: c.systemd.services.comin.serviceConfig.Restart)) (onAll "always"
      // {
        drakkar = "no";
        mimir = "no";
      });
    cominTracksOwnHost = assay.eq (forAll (c: c.services.comin.hostname)) (lib.genAttrs hosts (h: h));

    hostnamesMatch = assay.eq (forAll (c: c.networking.hostName)) (lib.genAttrs hosts (h: h));
  }
