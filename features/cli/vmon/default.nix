# vmon watches a Nix build: a live tree of builds and downloads from
# `--log-format internal-json`, a plain mode for logs, a failure summary with
# the failing derivation's last log lines, and build durations as a textfile
# (rust/tools/vmon). It replaces nix-output-monitor: bin/dev, bin/update and
# bin/fleet build through it. Binary: vmon.
#
#   nix build … --log-format internal-json -v 2>&1 | vmon
#   vmon -- nix build …
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ../../../rust/tools/vmon/default.nix {})
  ];
}
