# vbuild (rust/tools/vbuild) as this host's Nix build hook, in place of the C++
# `nix __build-remote`. Same protocol, same machines (`builders`, which is
# `@/etc/nix/machines` when nix-remote-builder-client.nix generates it from
# common/fleet.nix), same slot lock files under /nix/var/nix/current-load. What
# changes:
#
#   - builders are ranked by live load (an ssh probe of /proc/loadavg, nproc and
#     the running build count, cached 5 s) instead of by local slot counts alone;
#   - a builder that does not answer the probe within 3 s is skipped (and
#     remembered for 30 s), so with every builder offline a build is declined at
#     once and runs locally, where build-remote picks the dead host, waits out
#     the TCP connect timeout, and only then moves on;
#   - the probe's ssh connection is a ControlPersist master that the copies and
#     the remote build reuse.
#
# With no builders configured (a host without nix-remote-builder-client) vbuild
# answers `decline-permanently` on the first request, as build-remote does, and
# Nix stops asking.
#
# Rollback: disable this feature; Nix's default build hook comes back.
#
# Health probe (on the host):
#   nix config show build-hook | grep -q /bin/vbuild \
#     && nix build --no-link --rebuild nixpkgs#hello   # or any cached trivial derivation
{
  config,
  pkgs,
  ...
}: let
  vbuild = pkgs.callPackage ../../rust/tools/vbuild/default.nix {};
in {
  nix.settings.build-hook = "${vbuild}/bin/vbuild --nix ${config.nix.package}/bin/nix --ssh ${config.programs.ssh.package}/bin/ssh";

  environment.systemPackages = [vbuild];
}
