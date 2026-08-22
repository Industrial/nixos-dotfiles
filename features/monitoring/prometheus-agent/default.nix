# Prometheus agent for monitoring hosts with node exporter
{config, lib, pkgs, ...}: {
  services.prometheus.exporters.node = {
    enable = true;
    port = 9002;  # Keep consistent with existing prometheus config
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
      "tcpstat"
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
      "systemd"
      "tapestats"
      "wifi"
    ];
  };
}
