# Fleet inventory — the one place that knows which hosts exist and what each does.
#
# The DATA is generated (GH-417 S2): the source of truth is the Voltaic inventory in
# rust/tools/vfleet/src/inventory.vlt, typed by rust/tools/vfleet/src/model.vlt. vfleet
# checks the cross-host invariants (unique tailnet addresses and ports, builders that
# exist, operator- and cache-key format, the trust facts) and writes ./fleet.json, which
# this file reads. To change a host: edit inventory.vlt, run `bin/fleet-data`, commit
# both. Editing fleet.json by hand fails vfleet's drift test (bin/ci/cargo-standalone
# test vfleet). Field meanings are documented in inventory.vlt.
#
# This file keeps the derived helpers (withRole, builders, binaryCaches, ...), so
# consumers are unchanged. Shared features read this instead of naming hosts
# themselves. It is plain data: no pkgs, no config, importable from a module, an assay
# suite, or flake.nix alike. Modules bind it with `let fleet = import .../common/fleet.nix;`
# rather than taking a `fleet` argument, so they evaluate the same under
# lib/mk-host.nix, common/assay/nixos.nix and a bare `import` in a suite.
#
# Per host (JSON names): description, roles, operatorKey (null = not enrolled),
# tailscaleIp?, cacheKey?, builder? { maxJobs, speedFactor, supportedFeatures },
# online? (absent = true), deployDebounce?, and the compartment trust facts (GH-421)
# trustTier, cpu { vendor, model, sevSnp, tdx }, tpm2, attestationRoot (null until
# a DICE root is pinned). `?` = left out when absent.
#
# Host names double as MagicDNS short names on the tailnet.
let
  data = builtins.fromJSON (builtins.readFile ./fleet.json);
  inherit (data) hosts;

  # Order is part of the contract: prometheus target order and remote-builder
  # preference follow these lists, so they are explicit rather than attrNames
  # (which is alphabetical).
  inherit (data) order builderOrder nfsClientOrder;

  hasRole = role: name: builtins.elem role hosts.${name}.roles;
  isOnline = name: hosts.${name}.online or true;

  # The builders clients actually use: builderOrder minus the hosts marked offline.
  onlineBuilderOrder = builtins.filter isOnline builderOrder;
  withRole = role: builtins.filter (hasRole role) order;

  # vcache's TCP port, on every serving host's tailnet address.
  inherit (data) cachePort;

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
