# vfetch serve (rust/tools/vfetch): a binary cache on localhost that Nix asks first,
# so every substitution on this host (`nix build`, nixos-rebuild, deploys) fetches
# through vfetch. It fans each narinfo request out to all the other substituters at
# once (nix.conf's `substituters` and `extra-substituters`, read at start, without
# itself), takes the first answer signed by a key nix.conf trusts, and relays the NAR
# from that cache as it streams. Nix still checks the signatures and the NAR hash, and
# does the import.
#
# Ordering: Nix asks substituters lowest priority first, and `Priority: 1` in vfetch
# serve's nix-cache-info puts it ahead of every cache that advertises one: the fleet's
# vcache (30), cache.nixos.org (40), cachix (41). (A cache with no Priority line sorts
# at 0, ahead of it; none of this host's do.) The other substituters stay in the list, so if vfetch
# serve is down or answers 404/502, Nix moves on to them by itself.
#
# Rollback is this one switch: `features.nix.vfetch.enable = lib.mkForce false;` takes
# the localhost entry out of nix.conf and stops the service, and Nix substitutes
# directly again.
#
# Health probe (run on the host):
#   systemctl is-active vfetch-serve && curl -sf http://127.0.0.1:5101/nix-cache-info
{
  config,
  lib,
  pkgs,
  ...
}: let
  vfetch = pkgs.callPackage ../../../rust/tools/vfetch/default.nix {};
  listen = "127.0.0.1:5101";
in {
  nix.settings.substituters = lib.mkBefore ["http://${listen}"];

  systemd.services.vfetch-serve = {
    description = "vfetch serve: the localhost substituter that fans out to the binary caches";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    # The upstreams and trusted keys are nix.conf's: a change there restarts it.
    restartTriggers = [config.environment.etc."nix/nix.conf".source];
    serviceConfig = {
      ExecStart = "${vfetch}/bin/vfetch serve --listen ${listen}";
      Restart = "always";
      RestartSec = "2s";
      # Reads /etc/nix/nix.conf and talks HTTP; nothing else.
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
    };
  };
}
