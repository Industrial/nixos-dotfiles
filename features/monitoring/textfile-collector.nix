# node_exporter's textfile collector directory, shared by the features that write
# `*.prom` files into it (features/nix/vverify, features/nix/vhealth). Each imports this
# file, so it is a dependency feature (`features.monitoring.textfile-collector`) that
# switches on with any of them, and is evaluated once however many do.
#
# The fleet's exporter (./prometheus-exporter) has no textfile directory configured; this
# adds one: the directory below, created by tmpfiles (root:prometheus-textfile, setgid,
# 2775), and `--collector.textfile.directory` on the exporter where the exporter runs. The
# textfile collector itself is one of node_exporter's defaults; it only needs the
# directory. A writer joins the `prometheus-textfile` group (SupplementaryGroups) and
# writes 0644 files (UMask 0022) so the exporter's own user can read them.
#
# Moved here from features/nix/vverify (GH-180) so a second writer does not add the
# tmpfiles rule and the exporter flag a second time.
{
  config,
  lib,
  ...
}: let
  dir = "/var/lib/prometheus-node-exporter-text";
  group = "prometheus-textfile";
in {
  users.groups.${group} = {};

  systemd.tmpfiles.rules = ["d ${dir} 2775 root ${group} - -"];

  services.prometheus.exporters.node.extraFlags =
    lib.mkIf config.services.prometheus.exporters.node.enable
    ["--collector.textfile.directory=${dir}"];
}
