# vcache's request counters (GH-248), end to end:
#
#   nix build .#checks.x86_64-linux.vcache-metrics-vm
#
# Covered:
#   1. a narinfo hit, narinfo misses and a NAR are counted, flushed within 30 s, and
#      node_exporter serves them (vcache_*), written into its textfile directory as the group's member;
#   2. the counters survive a vcache restart with no scrape error;
#   3. serve latency: 500 narinfo requests timed, printed as LATENCY (the counting is a
#      relaxed atomic add; the crate's test puts a million of them under a second).
{pkgs}: let
  inherit (pkgs) lib;
  settingsFor = hostname: {
    inherit hostname;
    username = "tom";
    userdir = "/home/tom";
    system = "x86_64-linux";
    stateVersion = "24.11";
  };
in
  pkgs.testers.runNixOSTest {
    name = "vcache-metrics-vm";

    nodes.cache = {...}: {
      imports = [./default.nix];
      _module.args.settings = settingsFor "drakkar";
      systemd.services.vcache.environment.HOST = lib.mkForce "127.0.0.1";
      systemd.services.vcache.after = lib.mkForce ["network-online.target"];
      services.prometheus.exporters.node.enable = true;
      nix.settings.experimental-features = ["nix-command"];
      environment.systemPackages = [pkgs.curl pkgs.hello];
      virtualisation.memorySize = 1536;
    };

    testScript = ''
      import time

      def scrape(pattern):
          return cache.succeed(f"curl -sf http://127.0.0.1:9100/metrics | grep -E '{pattern}' || true").strip()

      cache.wait_for_unit("vcache.service")
      cache.wait_for_open_port(5100)
      cache.wait_for_unit("prometheus-node-exporter.service")
      hello = cache.succeed("readlink -f $(command -v hello) | cut -d/ -f1-4").strip()
      part = hello.removeprefix("/nix/store/").split("-")[0]

      with subtest("hits, misses and a NAR are counted, flushed, and served by node_exporter"):
          cache.succeed(f"curl -sf http://127.0.0.1:5100/{part}.narinfo > /dev/null")
          for _ in range(3):
              cache.fail("curl -sf http://127.0.0.1:5100/00000000000000000000000000000000.narinfo")
          cache.succeed(f"curl -sf http://127.0.0.1:5100/nar/{part}.nar > /dev/null")
          cache.wait_until_succeeds("curl -sf http://127.0.0.1:9100/metrics | grep -qF 'vcache_narinfo_requests_total{result=\"hit\"} 1'", timeout=60)
          assert 'vcache_narinfo_requests_total{result="miss"} 3' in scrape("vcache_narinfo_requests_total")
          assert 'vcache_nar_requests_total{result="hit"} 1' in scrape("vcache_nar_requests_total")
          served = float(scrape("^vcache_nar_bytes_served_total").split()[1])
          assert served > 0, served
          assert scrape('node_textfile_scrape_error ') .endswith(" 0"), scrape("node_textfile_scrape_error")

      with subtest("a restart: no scrape error, the published file is 0644"):
          cache.succeed("systemctl restart vcache.service")
          cache.wait_for_open_port(5100)
          cache.succeed("test -e /var/lib/prometheus-node-exporter-text/vcache.prom")
          assert cache.succeed("stat -c %a /var/lib/prometheus-node-exporter-text/vcache.prom").strip() == "644"
          assert scrape('node_textfile_scrape_error ').endswith(" 0"), scrape("node_textfile_scrape_error")

      with subtest("serve latency, with the counting on the path"):
          start = time.monotonic()
          cache.succeed(f"for i in $(seq 500); do curl -sf -o /dev/null http://127.0.0.1:5100/{part}.narinfo; done")
          took = time.monotonic() - start
          print(f"LATENCY 500 narinfo requests in {took:.2f}s: {1000 * took / 500:.2f} ms each (curl's own start included)")
          cache.wait_until_succeeds("curl -sf http://127.0.0.1:9100/metrics | grep -qF 'vcache_narinfo_requests_total{result=\"hit\"} 500'", timeout=60)
    '';
  }
