# Colocated suite for features/monitoring/textfile-collector.nix — node_exporter's textfile
# directory, shared by vverify and vhealth.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;

  dir = "/var/lib/prometheus-node-exporter-text";
  cfg = nixos.eval {modules = [./textfile-collector.nix];};
  withExporter = nixos.eval {
    modules = [
      ./textfile-collector.nix
      ./textfile-collector.nix
      {services.prometheus.exporters.node.enable = true;}
    ];
  };
in
  assay.suite "textfile-collector" {
    dirCreatedSetgid = assay.eq (builtins.elem "d ${dir} 2775 root prometheus-textfile - -" cfg.systemd.tmpfiles.rules) true;
    writersGroup = assay.eq (cfg.users.groups ? prometheus-textfile) true;
    noExporterNoFlag = assay.eq cfg.services.prometheus.exporters.node.extraFlags [];
    exporterReadsTheDirOnce = assay.eq withExporter.services.prometheus.exporters.node.extraFlags ["--collector.textfile.directory=${dir}"];
    oneRuleWhenImportedTwice = assay.eq (builtins.length (builtins.filter (r: r == "d ${dir} 2775 root prometheus-textfile - -") withExporter.systemd.tmpfiles.rules)) 1;
  }
