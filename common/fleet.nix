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
#
# Host names double as MagicDNS short names on the tailnet.
let
  hosts = {
    drakkar = {
      description = "desktop and gaming station";
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
      description = "tablet (Intel N200)";
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
      roles = ["server" "monitoring" "nfs-server" "remote-desktop-relay"];
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
      description = "work laptop; monitoring standby when mimir is down";
      # Never "nfs-client": a work machine holds no personal files, so it neither
      # mounts mimir's /data nor appears in its export list.
      roles = ["laptop" "work" "builder" "monitoring"];
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
  inherit hosts order hasRole withRole cachePort isCacheIn pushesToCacheIn;

  pushesToCache = pushesToCacheIn hosts;

  # The hosts that push their builds to the cache, in fleet order.
  cachePushers = builtins.filter (pushesToCacheIn hosts) order;

  # The fleet's binary caches (features/nix/vcache), in builder preference order:
  # builder-role hosts with a tailnet address and a published cacheKey.
  binaryCaches =
    map (name: {
      inherit name;
      url = "http://${hosts.${name}.tailscaleIp}:${toString cachePort}";
      publicKey = hosts.${name}.cacheKey;
    })
    (builtins.filter (name: hasRole "builder" name && hosts.${name} ? tailscaleIp && (hosts.${name}.cacheKey or null) != null) builderOrder);

  # Alphabetical, like builtins.attrNames.
  names = builtins.attrNames hosts;

  builders = map (name: {inherit name;} // hosts.${name}.builder) builderOrder;

  nfsClients = builtins.filter (hasRole "nfs-client") nfsClientOrder;

  operatorKeys = builtins.filter (k: k != null) (map (name: hosts.${name}.operatorKey) (builtins.attrNames hosts));
}
