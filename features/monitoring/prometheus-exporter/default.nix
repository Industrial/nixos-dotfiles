# Node exporter agent for fleet-wide host monitoring (single source of truth
# for services.prometheus.exporters.node)
{
  config,
  settings ? {},
  ...
}: let
  fleet = import ../../../common/fleet.nix;
  # This host's tailnet address from common/fleet.nix (where prometheus scrapes it), or
  # loopback on a host without one.
  ip = (fleet.hosts.${settings.hostname or ""} or {}).tailscaleIp or "127.0.0.1";
in {
  imports = [../../../common/vhealth-probes.nix];

  # vhealth (features/nix/vhealth): the exporter answers with its own build info.
  features.nix.vhealth.probes.node-exporter = {
    type = "http";
    url = "http://${ip}:${toString config.services.prometheus.exporters.node.port}/metrics";
    bodyContains = "node_exporter_build_info";
    description = "node_exporter serves /metrics on the address prometheus scrapes";
  };

  services.prometheus.exporters.node = {
    enable = true;
    port = 9002; # Keep consistent with existing prometheus config
    enabledCollectors = [
      "systemd"
      "tcpstat"
      "diskstats"
      "filesystem"
      "loadavg"
      "meminfo"
      "netdev"
      "processes"
      "cpu"
      "conntrack"
      "entropy"
      "filefd"
      "infiniband"
      "interrupts"
      "ksmd"
      "logind"
      "mdadm"
      "meminfo_numa"
      "mountstats"
      "nfs"
      "nfsd"
      "pressure"
      "rapl"
      "schedstat"
      "sockstat"
      "softnet"
      "stat"
      "time"
      "thermal_zone"
      "udp_queues"
      "uname"
      "vmstat"
      "xfs"
      "zfs"
    ];
    disabledCollectors = [
      "bonding"
      "hwmon"
      "ipvs"
      "powersupplyclass"
      "runit"
      "supervisord"
      "tapestats"
      "wifi"
    ];
  };
}
