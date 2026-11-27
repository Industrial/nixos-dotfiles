# Fleet inventory — the one place that knows which hosts exist and what each does.
#
# Shared features read this instead of naming hosts themselves, so adding a fifth
# host is an edit here (plus hosts/<name>/), not a hunt through features/. It is
# plain data: no pkgs, no config, importable from a module, an assay suite, or
# flake.nix alike. Modules bind it with `let fleet = import .../common/fleet.nix;`
# rather than taking a `fleet` argument, so they evaluate the same under
# lib/mk-host.nix, common/assay/nixos.nix and a bare `import` in a suite.
#
# Fields per host:
#   roles        — tags features select on (see `withRole`). "vdeploy": vdeploy deploys
#                  the host instead of comin (features/nix/vdeploy, GH-160).
#   builder      — present when the host accepts remote nix builds; consumed by
#                  features/fleet/nix-remote-builder-client.nix.
#   operatorKey  — the host's ~/.ssh/id_ed25519.pub, installed fleet-wide by
#                  features/fleet/operator-ssh.nix. null = not yet enrolled.
#   tailscaleIp  — tailnet IPv4, for consumers that need an address rather than a
#                  MagicDNS name (NFS export lists, the vcache listener).
#   cacheKey     — public half of the host's vcache signing key (features/nix/vcache).
#                  The secret half is generated on the host at the service's first
#                  start and never leaves it; the public half is copied here so
#                  clients trust it at eval time. null/absent = the host serves no
#                  cache (yet), and clients leave it out.
#   online       — false for a host that is out of reach for the long term. It keeps
#                  its roles and its own config, but clients stop using it as a
#                  remote builder or cache (`builders`, `binaryCaches`): Nix's build
#                  hook can pick a dead builder and wait out the TCP timeout for a
#                  derivation (GH-252). Absent = true. Bringing a host back is
#                  deleting its `online = false;` line.
#
# Compartment trust facts (GH-421, epic GH-419). What the hardware can attest, read by the
# compartment policy; every host carries all four.
#   trustTier       — "local-hw-attested": a fleet machine with a TPM2 that roots its
#                     own attestation. "local-unattested": no TPM2 (or none verified).
#   cpu             — { vendor ("amd" | "intel"); model; sevSnp; tdx; }. sevSnp/tdx say
#                     whether the CPU can run confidential VMs (AMD SEV-SNP, Intel TDX);
#                     consumer parts cannot, so every host today is false/false.
#   tpm2            — a TPM 2.0 is present (/dev/tpm0, tpm_version_major = 2).
#   attestationRoot — the pinned root of the host's DICE chain, the way operatorKey pins
#                     its ssh key. Decided 2026-11-27: pure DICE chains rooted in each
#                     host's TPM, no fleet CA. null until enrolled.
# Facts were read non-root over ssh on 2026-11-27 (/proc/cpuinfo flags, /dev/tpm0,
# /sys/class/tpm/tpm0/tpm_version_major, kvm_amd's sev_snp parameter). A host that was
# unreachable says so next to its facts.
#
# Host names double as MagicDNS short names on the tailnet.
let
  hosts = {
    drakkar = {
      description = "desktop and gaming station";
      trustTier = "local-hw-attested";
      # Zen 4 desktop part: svm, but no SEV/SEV-SNP (kvm_amd sev_snp = N).
      cpu = {
        vendor = "amd";
        model = "AMD Ryzen 9 7950X";
        sevSnp = false;
        tdx = false;
      };
      tpm2 = true;
      attestationRoot = null;
      # vdeploy: vdeploy deploys this host, health-checked with rollback, and comin is
      # retired (features/nix/vdeploy, GH-160).
      roles = ["desktop" "builder" "nfs-client" "vdeploy"];
      tailscaleIp = "100.69.213.35";
      # Public half of /var/lib/private/vcache/secret-key, logged by vcache-ensure-key
      # (`journalctl -u vcache`). Rotating that key means updating this line.
      cacheKey = "drakkar-vcache-1:WtADMHunhHX0O8Et3619eHQwtbl4EkFEfwrujjaYMv8=";
      operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtviEPSAz5PlJ8K8mFzSQz/Y6WqzqrBA5PzXkhjZ2/y tom@drakkar";
      builder = {
        maxJobs = 8;
        speedFactor = 2;
        supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
      };
    };
    huginn = {
      # Out of reach since 2026-11 (no WiFi, router full): no longer a builder for clients (GH-252).
      online = false;
      description = "tablet (Intel N200)";
      # UNVERIFIED: huginn was unreachable on 2026-11-27 (ssh timed out). The CPU is from
      # hosts/huginn (N200, Alder Lake-N: vmx, no TDX). Its TPM is not checked, so it
      # claims none and stays unattested until probed; the N200's PTT is a likely TPM2.
      trustTier = "local-unattested";
      cpu = {
        vendor = "intel";
        model = "Intel N200";
        sevSnp = false;
        tdx = false;
      };
      tpm2 = false;
      attestationRoot = null;
      roles = ["tablet" "builder" "nfs-client"];
      tailscaleIp = "100.70.136.13";
      operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvaH/4XK0nQr6vo1ZZYpk0SIv0LvtJm6yxWMv7U2/Gb tom@huginn";
      builder = {
        maxJobs = 4;
        speedFactor = 1;
        supportedFeatures = ["kvm" "nixos-test"];
      };
    };
    mimir = {
      description = "always-on file server";
      trustTier = "local-hw-attested";
      # Zen 3 mobile part: svm, no SEV/SEV-SNP (kvm_amd sev_snp = N).
      cpu = {
        vendor = "amd";
        model = "AMD Ryzen 7 5825U";
        sevSnp = false;
        tdx = false;
      };
      tpm2 = true;
      attestationRoot = null;
      # vdeploy: vdeploy deploys this host instead of comin (GH-160), after drakkar's 5
      # clean deploys on 2026-11-22.
      roles = ["server" "monitoring" "nfs-server" "remote-desktop-relay" "vdeploy"];
      # vdeploy waits for main to sit still this long before it starts a plan (GH-221).
      # vdeploy never cancels a plan, so a plan started on a commit that is superseded
      # a minute later is a whole plan of lag. Measured 2026-11-21/22 over 48 h: 20 of
      # 73 gaps between merges on main were under 2 min (agents merging back to back),
      # and comin had each of mimir's generations ready a median 4 min after its merge,
      # because mimir substitutes from drakkar's cache. 2 min collapses those bursts. A
      # longer window (10 min would cover 38 of the 73 gaps) would cost more waiting than
      # a plan takes.
      deployDebounce = "2m";
      tailscaleIp = "100.103.79.41";
      operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHaaBOy2a1WnlGy5B6WwEmVlf7s5VUgVIbsjdGZrsmK+ tom@mimir";
    };
    muninn = {
      # Out of reach since 2026-11 (no WiFi, router full): no longer a builder for clients (GH-252).
      online = false;
      description = "work laptop; monitoring standby when mimir is down";
      trustTier = "local-hw-attested";
      # Comet Lake-H: vmx, no TDX.
      cpu = {
        vendor = "intel";
        model = "Intel Core i7-10750H";
        sevSnp = false;
        tdx = false;
      };
      tpm2 = true;
      attestationRoot = null;
      # Never "nfs-client": a work machine holds no personal files, so it neither
      # mounts mimir's /data nor appears in its export list.
      # vdeploy: vdeploy deploys this host instead of comin (#437), the test host first.
      roles = ["laptop" "work" "builder" "monitoring" "vdeploy"];
      operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAC/xRRyQ1Om1ChkxfeqfK8HjvAgzg1d+bfgU9ALxgYx tom@muninn";
      builder = {
        maxJobs = 4;
        speedFactor = 1;
        supportedFeatures = ["kvm" "nixos-test"];
      };
    };
  };

  # Order is part of the contract: prometheus target order and remote-builder
  # preference follow these lists, so they are explicit rather than attrNames
  # (which is alphabetical).
  order = ["mimir" "drakkar" "huginn" "muninn"];
  builderOrder = ["drakkar" "muninn" "huginn"];
  nfsClientOrder = ["drakkar" "huginn"];

  hasRole = role: name: builtins.elem role hosts.${name}.roles;
  isOnline = name: hosts.${name}.online or true;

  # The builders clients actually use: builderOrder minus the hosts marked offline.
  onlineBuilderOrder = builtins.filter isOnline builderOrder;
  withRole = role: builtins.filter (hasRole role) order;

  # vcache's TCP port, on every serving host's tailnet address.
  cachePort = 5100;

  # A cache host, by the same test as binaryCaches below: a builder with a tailnet
  # address and a published cacheKey.
  isCacheIn = hs: name: let
    h = hs.${name} or {};
  in
    builtins.elem "builder" (h.roles or []) && h ? tailscaleIp && (h.cacheKey or null) != null;

  # Whether `name` pushes its builds to the fleet cache (features/nix/vpush, switched on
  # from profiles/base.nix): every builder-role host that is not a cache itself, as long
  # as some other host is one. Automatic, not opt-in; the rollback is the one option
  # `features.nix.vpush.enable = lib.mkForce false`. A cache never pushes to itself: it
  # IS the cache. Takes the host set, so the rule is testable on another inventory.
  pushesToCacheIn = hs: name: let
    h = hs.${name} or {};
    otherCaches = builtins.filter (n: n != name && isCacheIn hs n) (builtins.attrNames hs);
  in
    builtins.elem "builder" (h.roles or []) && !(isCacheIn hs name) && otherCaches != [];
in {
  inherit hosts order hasRole isOnline withRole cachePort isCacheIn pushesToCacheIn;

  pushesToCache = pushesToCacheIn hosts;

  # The hosts that push their builds to the cache, in fleet order.
  cachePushers = builtins.filter (pushesToCacheIn hosts) order;

  # The fleet's binary caches (features/nix/vcache), in builder preference order:
  # online builder-role hosts with a tailnet address and a published cacheKey.
  binaryCaches =
    map (name: {
      inherit name;
      url = "http://${hosts.${name}.tailscaleIp}:${toString cachePort}";
      publicKey = hosts.${name}.cacheKey;
    })
    (builtins.filter (name: hasRole "builder" name && hosts.${name} ? tailscaleIp && (hosts.${name}.cacheKey or null) != null) onlineBuilderOrder);

  # Alphabetical, like builtins.attrNames.
  names = builtins.attrNames hosts;

  # Remote builders for clients, in preference order; offline hosts are left out.
  builders = map (name: {inherit name;} // hosts.${name}.builder) onlineBuilderOrder;

  nfsClients = builtins.filter (hasRole "nfs-client") nfsClientOrder;

  operatorKeys = builtins.filter (k: k != null) (map (name: hosts.${name}.operatorKey) (builtins.attrNames hosts));
}
