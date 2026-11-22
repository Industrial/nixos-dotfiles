# vexporter (GH-248) under the STIG base-safe profile (mimir's), which can tighten the
# permissions on /nix/var/nix/db and the gcroots: the lesson of vhealth (#230).
#
#   nix build .#checks.x86_64-linux.vexporter-vm
#
# Covered:
#   1. as the vexporter user, under base-safe, it reads the store database (paths, NAR
#      bytes), the store's file system, the gcroots and the system generations: every
#      such source is up, and the file is readable by a normal user;
#   2. the gcroots walk counts an unreadable directory as unreadable (never fatal) and
#      never walks into a link that leaves /nix/var/nix/gcroots;
#   3. the deploy source from vdeploy-style status.json and plan.json: not on main, with
#      the lag counted from main's head commit time;
#   4. a source that fails (the vdeploy files removed) is 0, and the rest of the file is
#      still written: never blanked; the file is replaced atomically (no temp file left).
{pkgs}: let
  inherit (pkgs) lib;
in
  pkgs.testers.runNixOSTest {
    name = "vexporter-vm";

    nodes.machine = {...}: {
      imports = [./default.nix ../../security/stig/profiles/base-safe.nix];
      services.timesyncd.enable = lib.mkForce true;
      features.monitoring.vexporter.interval = "3s";
      services.prometheus.exporters.node.enable = true;
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
      };
      environment.systemPackages = [pkgs.jq];
      virtualisation.memorySize = 1536;
    };

    testScript = ''
      prom = "/var/lib/prometheus-node-exporter-text/vexporter.prom"

      def value(name):
          line = machine.succeed(f"grep '^{name} ' {prom}").split()
          return float(line[1])

      def up(source):
          return machine.succeed(f"grep -F 'vexporter_source_up{{source=\"{source}\"}}' {prom}").split()[1]

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("vexporter.service")
      # A test VM boots its closure with no system profile; a host has generations. Give it one.
      machine.succeed("nix-env -p /nix/var/nix/profiles/system --set $(readlink -f /run/current-system)")
      machine.wait_until_succeeds(f"grep -qF 'vexporter_source_up{{source=\"generations\"}} 1' {prom}", timeout=60)

      with subtest("under base-safe, as its own user, it reads the DB, the store, the gcroots and the generations"):
          t.assertEqual(machine.succeed("systemctl show -p User --value vexporter").strip(), "vexporter")
          for source in ["store", "fs", "gcroots", "generations"]:
              t.assertEqual(up(source), "1", source)
          t.assertGreater(value("vexporter_store_paths"), 100)
          t.assertGreater(value("vexporter_store_nar_bytes"), 1000000)
          t.assertGreater(value("vexporter_nix_fs_size_bytes"), value("vexporter_nix_fs_free_bytes"))
          t.assertGreaterEqual(value("vexporter_generations"), 1)
          t.assertEqual(value("vexporter_reboot_pending"), 0)
          t.assertEqual(value("vexporter_profile_is_running"), 1)
          # A normal user reads it (node_exporter's own user does too).
          machine.succeed(f"su - alice -c 'cat {prom}' > /dev/null")
          # No vdeploy here: the deploy source is down, and says so.
          t.assertEqual(up("deploy"), "0")

      with subtest("the gcroots walk: an unreadable entry is counted, a link out is never walked"):
          before = value("vexporter_gcroots")
          machine.succeed("install -d -m 0700 -o root /nix/var/nix/gcroots/private-test")
          machine.succeed("ln -s /etc /nix/var/nix/gcroots/link-out-test")
          machine.wait_until_succeeds(f"grep -q '^vexporter_gcroots_unreadable [1-9]' {prom}", timeout=30)
          # The link counts once; /etc's thousands of entries were not walked.
          machine.wait_until_succeeds(f"test $(grep '^vexporter_gcroots ' {prom} | cut -d' ' -f2) = {int(before) + 1}", timeout=30)
          t.assertEqual(up("gcroots"), "1")

      with subtest("the deploy source from vdeploy's files: behind main, the lag from its head commit time"):
          machine.succeed("install -d -m 0755 /var/lib/vdeploy")
          machine.succeed("echo '{\"head\":\"abc\"}' > /var/lib/vdeploy/status.json")
          machine.succeed("echo \"{\\\"commit\\\":\\\"abc\\\",\\\"commitTime\\\":$(( $(date +%s) - 600 ))}\" > /var/lib/vdeploy/plan.json")
          machine.wait_until_succeeds(f"grep -qF 'vexporter_source_up{{source=\"deploy\"}} 1' {prom}", timeout=30)
          t.assertEqual(value("vexporter_on_main"), 0)
          t.assertGreaterEqual(value("vexporter_deploy_lag_seconds"), 600)

      with subtest("a failed source never blanks the file, and the file is replaced atomically"):
          machine.succeed("rm -r /var/lib/vdeploy")
          machine.wait_until_succeeds(f"grep -qF 'vexporter_source_up{{source=\"deploy\"}} 0' {prom}", timeout=30)
          t.assertGreater(value("vexporter_store_paths"), 100)
          machine.fail("ls -a /var/lib/prometheus-node-exporter-text | grep -q '\\.vexporter\\.prom\\.tmp'")
          machine.succeed("systemctl is-active vexporter.service")
    '';
  }
