# NixOS VM test for features/nix/vhealth: a service that systemd reports `active` while its
# port is closed is reported down; every probe type passes or fails as it should; the
# daemon exports vhealth_probe_up through node_exporter; and a settle window waits for a
# late service instead of failing at once.
#
#   nix build .#checks.x86_64-linux.vhealth-vm
{pkgs}: let
  dir = "/var/lib/prometheus-node-exporter-text";
  stamp = "/run/vhealth-stamp";
  liarPort = 8081;
in
  pkgs.testers.runNixOSTest {
    name = "vhealth-vm";

    nodes.machine = {...}: {
      imports = [./default.nix];

      services.prometheus.exporters.node.enable = true;

      # The liar: `active (running)` to systemd, and nothing listens on its port.
      systemd.services.liar = {
        description = "active per systemd, serving nothing";
        wantedBy = ["multi-user.target"];
        serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
      };

      # A file written at boot, for the freshness probe.
      systemd.tmpfiles.rules = ["f ${stamp} 0644 root root - fresh"];

      features.nix.vhealth = {
        interval = "2s";
        probes = {
          liar = {
            type = "tcp";
            host = "127.0.0.1";
            port = liarPort;
            timeout = 1000;
          };
          node-exporter = {
            type = "http";
            url = "http://127.0.0.1:9100/metrics";
            bodyContains = "node_exporter_build_info";
          };
          nix-daemon-socket = {
            type = "unix";
            path = "/nix/var/nix/daemon-socket/socket";
          };
          true-command = {
            type = "command";
            argv = ["${pkgs.coreutils}/bin/true"];
          };
          stamp = {
            type = "file";
            path = stamp;
            maxAge = 3600;
          };
          # Sleeps far past its timeout: down, and the check does not wait for it.
          slow = {
            type = "command";
            argv = ["${pkgs.coreutils}/bin/sleep" "120"];
            timeout = 500;
            critical = false;
          };
        };
      };

      environment.systemPackages = [pkgs.curl];
    };

    testScript = ''
      import json
      import time

      def report(args):
          status, out = machine.execute(f"vhealth check --json {args}")
          return status, json.loads(out.strip().splitlines()[-1])

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("liar.service")
      machine.wait_for_unit("vhealth.service")
      machine.wait_for_open_port(9100)

      with subtest("systemd reports the liar active"):
          assert machine.succeed("systemctl is-active liar").strip() == "active"

      with subtest("vhealth reports the liar down, and the host unhealthy"):
          status, r = report("")
          probes = {p["name"]: p for p in r["probes"]}
          assert status == 1, (status, r)
          assert r["healthy"] is False, r
          assert r["failing"] == ["liar"], r
          assert probes["liar"]["up"] is False, probes["liar"]
          assert "127.0.0.1:${toString liarPort}" in probes["liar"]["detail"], probes["liar"]
          # nix-daemon-socket (unix): the socket accepts; nix-daemon (the built-in command probe,
          # as vhealth's non-root user in the service, as root here): the daemon answers.
          for name in ["node-exporter", "nix-daemon-socket", "nix-daemon", "true-command", "stamp"]:
              assert probes[name]["up"] is True, probes[name]

      with subtest("a probe past its timeout is down, and is not waited for"):
          started = time.monotonic()
          status, r = report("--probe slow --probe true-command")
          elapsed = time.monotonic() - started
          probes = {p["name"]: p for p in r["probes"]}
          # slow is not critical: down, but the host is healthy.
          assert status == 0, (status, r)
          assert probes["slow"]["up"] is False and probes["slow"]["detail"] == "timed out after 500ms", probes["slow"]
          assert elapsed < 30, elapsed

      with subtest("the daemon exports vhealth_probe_up through node_exporter"):
          machine.wait_until_succeeds("grep -qx 'vhealth_probe_up{probe=\"liar\",kind=\"tcp\",critical=\"true\"} 0' ${dir}/vhealth.prom", timeout=60)
          machine.succeed("grep -qx 'vhealth_probe_up{probe=\"node-exporter\",kind=\"http\",critical=\"true\"} 1' ${dir}/vhealth.prom")
          machine.succeed("stat -c %a ${dir}/vhealth.prom | grep -qx 644")
          machine.succeed("curl -sf http://127.0.0.1:9100/metrics | grep -qx 'vhealth_healthy 0'")
          machine.succeed("curl -sf http://127.0.0.1:9100/metrics | grep -q '^vhealth_probe_up{.*probe=\"liar\".*} 0$'")

      with subtest("a settle window waits for a service that comes up late"):
          machine.succeed("systemd-run --unit late-listener --on-active=4 ${pkgs.socat}/bin/socat TCP-LISTEN:${toString liarPort},bind=127.0.0.1,reuseaddr,fork /dev/null")
          machine.fail("vhealth check --probe liar")
          started = time.monotonic()
          machine.succeed("vhealth check --probe liar --wait 60 --every 1")
          assert time.monotonic() - started >= 2, "the settle window passed before the listener started"

      with subtest("the daemon sees the recovery"):
          machine.wait_until_succeeds("grep -qx 'vhealth_healthy 1' ${dir}/vhealth.prom", timeout=60)
          status, r = report("")
          assert status == 0 and r["healthy"] is True and r["down"] == ["slow"], (status, r)
    '';
  }
