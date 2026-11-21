# NixOS VM test for features/nix/vverify: the service verifies the VM's store, a store path
# corrupted on disk is reported (JSON and metric), and node_exporter serves the metric.
#
# The VM's /nix/store is an overlay over the host's store (writableStore, the test default),
# so the corruption lands in the VM's tmpfs upper layer and the host store is untouched.
# Two paths are planted in the system closure so the VM's database registers them: one is
# rewritten (corrupt) and one removed (missing).
#
#   nix build .#checks.x86_64-linux.vverify-vm
{pkgs}: let
  victim = pkgs.writeText "vverify-victim" "intact\n";
  gone = pkgs.writeText "vverify-gone" "present\n";
  dir = "/var/lib/prometheus-node-exporter-text";
in
  pkgs.testers.runNixOSTest {
    name = "vverify-vm";

    nodes.machine = {...}: {
      imports = [./default.nix];
      system.extraDependencies = [victim gone];
      services.prometheus.exporters.node.enable = true;
      environment.systemPackages = [pkgs.curl];
      virtualisation = {
        cores = 2;
        memorySize = 1536;
      };
    };

    testScript = ''
      import json

      def metric(name):
          text = machine.succeed("cat ${dir}/vverify.prom")
          for line in text.splitlines():
              if line.startswith(name + " "):
                  return float(line.split()[1])
          raise Exception(f"{name} not in vverify.prom:\n{text}")

      machine.wait_for_unit("vverify.service")

      with subtest("the first pass runs at start and finds the store intact"):
          machine.wait_until_succeeds("grep -q '^vverify_paths_total ' ${dir}/vverify.prom", timeout=900)
          assert metric("vverify_paths_total") > 100, "the VM's closure was not walked"
          assert metric("vverify_paths_corrupt") == 0
          assert metric("vverify_paths_missing") == 0
          assert metric("vverify_last_run_timestamp_seconds") > 0
          machine.succeed("stat -c %a ${dir}/vverify.prom | grep -qx 644")

      with subtest("a restart with a recent pass on record waits for the interval"):
          machine.succeed("systemctl restart vverify")
          machine.wait_until_succeeds("journalctl -u vverify -o cat | grep -q 'first pass in [1-9]'")

      with subtest("a corrupted and a removed path are reported"):
          machine.succeed("systemctl stop vverify")
          machine.succeed("mount -o remount,bind,rw /nix/store || mount -o remount,rw /nix/store")
          machine.succeed("echo corrupted > ${victim}")
          machine.succeed("rm ${gone}")
          # No pass on record: the next start is due now.
          machine.succeed("rm ${dir}/vverify.prom")
          machine.succeed("systemctl start vverify")
          machine.wait_until_succeeds("grep -q '^vverify_paths_total ' ${dir}/vverify.prom", timeout=900)
          assert metric("vverify_paths_corrupt") == 1
          assert metric("vverify_paths_missing") == 1
          report = json.loads(machine.succeed("cat ${dir}/vverify.json"))
          assert [c["path"] for c in report["corrupt"]] == ["${victim}"], report
          assert report["missing"] == ["${gone}"], report

      with subtest("node_exporter serves the textfile metrics"):
          machine.wait_for_open_port(9100)
          machine.succeed("curl -sf http://127.0.0.1:9100/metrics | grep -qx 'vverify_paths_corrupt 1'")

      with subtest("--once exits non-zero on a fault and prints the report"):
          out = machine.fail("vverify --once --jobs 2")
          assert json.loads(out.strip().splitlines()[-1])["corrupt"][0]["path"] == "${victim}"
    '';
  }
