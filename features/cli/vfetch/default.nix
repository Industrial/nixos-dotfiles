# vfetch (rust/tools/vfetch): concurrent closure substitution from binary caches, a
# faster `nix copy --from <cache>`. Installed for operators and for vdeploy (#159):
#
#   vfetch <store-path>... --from <cache-url>[,<url>...] [--to <store>] [--jobs N]
#
# It walks the closure's narinfos and fetches the NARs concurrently, verifying every
# signature (nix.conf's trusted-public-keys, plus --trusted-key) and every NAR hash
# as it streams, then imports them over the daemon protocol (AddToStoreNar), which
# checks them again. For a store other than the system one it talks to a
# `nix daemon --stdio --store <to>` child, and `--importer nix-copy` runs
# `nix copy --from file://<staging>`. So the wrapper puts this host's own nix on
# PATH, after anything the caller has.
{
  config,
  pkgs,
  ...
}: let
  vfetch = pkgs.callPackage ../../../rust/tools/vfetch/default.nix {};
  wrapped = pkgs.symlinkJoin {
    name = "vfetch-${vfetch.version}";
    paths = [vfetch];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/vfetch --suffix PATH : ${config.nix.package}/bin
    '';
    inherit (vfetch) meta;
  };
in {
  environment.systemPackages = [wrapped];
}
