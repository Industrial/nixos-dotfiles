# Substitute from the fleet's vcache servers (./default.nix) before the public caches.
#
# The servers and their public keys come from common/fleet.nix (`binaryCaches`: the
# builder-role hosts that published a cacheKey), never from host names here. A host
# never lists itself. vcache advertises Priority 30 in nix-cache-info, ahead of
# cache.nixos.org's 40, so a reachable fleet cache is asked first.
#
# Rollback is this one switch: `features.nix.vcache.client.enable = lib.mkForce false;`.
# Short of that, an unreachable cache costs a client one connect-timeout before Nix
# moves on to the next substituter and, in the end, to cache.nixos.org.
{
  config,
  lib,
  settings,
  ...
}: let
  fleet = import ../../../common/fleet.nix;
  cfg = config.features.nix.vcache.client;
  caches = builtins.filter (c: c.name != settings.hostname) cfg.caches;
in {
  options.features.nix.vcache.client.caches = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          description = "The serving host (a common/fleet.nix name).";
        };
        url = lib.mkOption {
          type = lib.types.str;
          description = "The cache's base URL.";
        };
        publicKey = lib.mkOption {
          type = lib.types.str;
          description = "The public half of the host's vcache signing key.";
        };
      };
    });
    default = fleet.binaryCaches;
    defaultText = lib.literalExpression "(import common/fleet.nix).binaryCaches";
    description = "The fleet binary caches to substitute from; this host's own entry is skipped.";
  };

  config = lib.mkIf (caches != []) {
    nix.settings = {
      substituters = map (c: c.url) caches;
      trusted-public-keys = map (c: c.publicKey) caches;
      # A tailnet peer that is offline drops packets rather than refusing them; without
      # a bound, every substitution would wait out curl's 300s default first.
      connect-timeout = lib.mkDefault 5;
    };
  };
}
