# vdeploy's apply transaction against a forced-failing health check (GH-160), on the two
# fleet configurations it deploys:
#
#   nix build .#checks.x86_64-linux.vdeploy-rollback-vm
#
#   drakkar   nix.settings.allowed-users = ["@wheel"], as features/nixos/users sets on every
#             host (profiles/base.nix). The Nix daemon refuses any other user.
#   mimir     the same, plus the STIG base-safe profile (ADR-0004: mimir only): auditd,
#             AppArmor, require-sigs, UMASK 077, sudo with a password, sshd hardening, ...
#
# Each node runs vdeploy in deploy mode with vhealth and a web service with an HTTP probe.
# Generations are specialisations of the boot generation:
#   good     the web page changes; its probe expects the new page
#   broken   adds `liar`, a unit systemd reports active while nothing listens on its port,
#            and a critical TCP probe on that port: unhealthy whatever systemd says
#   stuck    a critical probe on a port nothing serves, to interrupt an apply mid-check
#
# Covered on drakkar's configuration, with a non-root user (alice, in wheel like tom)
# checked after every switch:
#   0. the 2026-11-22 drakkar failure, reproduced: probes run as `nobody` (vdeploy before
#      this fix) are refused by the daemon, so a healthy generation is rolled back and
#      marked bad; and the trap that follows: once that same generation is switched to by
#      root, vdeploy treats the running generation as good (the stale mark is cleared, no
#      switch, no refusal);
#   1. probes as the `vhealth` user pass: vhealth's own daemon reports nix-daemon up;
#   2. a forced-failing health check rolls back: the previous generation runs again, the
#      system profile (the boot default) never moved, the reason names the failing probe,
#      the generation is marked bad, and the metrics count the rollback;
#   3. the bad generation is refused when asked again, with no switch;
#   4. an apply killed in its health window leaves inflight.json; the next apply finishes
#      the decision for it (here: roll back).
# On mimir's configuration: a healthy apply is kept and a broken one rolled back, with the
# same checks, and the ledger stays readable to users under UMASK 077.
{pkgs}: let
  inherit (pkgs) busybox;
  dir = "/var/lib/prometheus-node-exporter-text";

  node = {stig}: {
    config,
    lib,
    ...
  }: let
    inherit (config.vmtest) gen;
  in {
    imports =
      [./default.nix ../vhealth/default.nix]
      ++ lib.optional stig ../../security/stig/profiles/base-safe.nix;

    options.vmtest.gen = lib.mkOption {
      type = lib.types.enum ["base" "good" "broken" "stuck"];
      default = "base";
    };

    config = {
      # qemu-vm turns timesyncd off; base-safe's V-268151 turns it on. The control wins here.
      services.timesyncd.enable = lib.mkIf stig (lib.mkForce true);
      system.switch.enable = true;
      features.nix.vdeploy = {
        mode = "deploy";
        url = "/srv/nothing";
        interval = "1h";
        healthWindow = "10s";
        dotfiles.enable = false;
      };

      # drakkar's and mimir's restriction (features/nixos/users/default.nix). That feature is
      # detected by vhealth; here it is set by hand, so vhealth is told.
      nix.settings.allowed-users = ["@wheel"];
      features.nix.vhealth.restrictedNixUsers = true;

      environment.etc."web/index.html".text = "${
        if gen == "base"
        then "base"
        else "good"
      }\n";
      systemd.services.web = {
        wantedBy = ["multi-user.target"];
        serviceConfig.ExecStart = "${busybox}/bin/httpd -f -p 127.0.0.1:8080 -h /etc/web";
      };
      # The liar: `active (running)` to systemd, and nothing listens on its port.
      systemd.services.liar = lib.mkIf (gen == "broken") {
        wantedBy = ["multi-user.target"];
        serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
      };
      features.nix.vhealth = {
        interval = "5s";
        probes =
          {
            web = {
              type = "http";
              url = "http://127.0.0.1:8080/index.html";
              bodyContains =
                if gen == "base"
                then "base"
                else "good";
              timeout = 2000;
            };
          }
          // lib.optionalAttrs (gen == "broken") {
            dead-port = {
              type = "tcp";
              host = "127.0.0.1";
              port = 8081;
              timeout = 1000;
            };
          }
          // lib.optionalAttrs (gen == "stuck") {
            never-up = {
              type = "tcp";
              host = "127.0.0.1";
              port = 8082;
              timeout = 1000;
            };
          };
      };

      nix.settings.experimental-features = ["nix-command"];
      # In wheel, like tom: the only users the restricted daemon serves.
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
        extraGroups = ["wheel"];
      };
      services.prometheus.exporters.node.enable = true;
      environment.systemPackages = [pkgs.curl pkgs.jq];
      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };

      specialisation = lib.mkIf (gen == "base") {
        good.configuration.vmtest.gen = "good";
        broken.configuration.vmtest.gen = "broken";
        stuck.configuration.vmtest.gen = "stuck";
      };
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "vdeploy-rollback-vm";

    nodes.drakkar = node {stig = false;};
    nodes.mimir = node {stig = true;};

    testScript = {nodes, ...}: let
      nix = nodes.drakkar.nix.package;
      setpriv = "${pkgs.util-linux}/bin/setpriv";
      systemctl = "${nodes.drakkar.systemd.package}/bin/systemctl";
    in ''
      import json

      def gen(m, name):
          base = m.succeed("readlink -f /run/booted-system").strip()
          return m.succeed(f"readlink -f {base}/specialisation/{name}").strip()

      def current(m):
          return m.succeed("readlink -f /run/current-system").strip()

      def profile(m):
          return m.succeed("readlink -f /nix/var/nix/profiles/system").strip()

      def last(m, as_user=False):
          read = "su - alice -c 'cat /var/lib/vdeploy/last.json'" if as_user else "cat /var/lib/vdeploy/last.json"
          return json.loads(m.succeed(read))

      def metric(m, line):
          m.succeed(f"grep -qxF '{line}' ${dir}/vdeploy-apply.prom")

      def non_root(m, page):
          m.succeed("timeout 60 su - alice -c 'nix-store --store daemon -q --hash /run/current-system'")
          body = m.succeed("timeout 30 su - alice -c 'curl -sf http://127.0.0.1:8080/index.html'").strip()
          t.assertEqual(body, page)

      def booted(m):
          m.wait_for_unit("multi-user.target")
          m.wait_for_unit("vdeploy.service")
          m.wait_for_unit("web.service")
          m.wait_until_succeeds("journalctl -u vdeploy -o cat | grep -q 'vdeploy deploys this host'", timeout=60)
          m.fail("systemctl is-active comin.service")
          non_root(m, "base")

      start_all()

      # ---------------------------------------------------------------- drakkar's configuration
      m = drakkar
      booted(m)
      base = current(m)
      good, broken, stuck = gen(m, "good"), gen(m, "broken"), gen(m, "stuck")

      with subtest("drakkar: the old identity, nobody, is refused by the restricted daemon"):
          # vdeploy before this fix: the same transient unit, probes as nobody.
          m.fail(
              f"systemd-run --unit=vdeploy-apply --service-type=exec --collect --wait --quiet "
              f"vdeploy apply --toplevel {good} --state-dir /var/lib/vdeploy --textfile-dir ${dir} "
              f"--health-window 5s --systemctl ${systemctl} --nix-env ${nix}/bin/nix-env "
              f"--nix-store ${nix}/bin/nix-store --health-as nobody --health-group nogroup --setpriv ${setpriv}"
          )
          l = last(m)
          t.assertEqual(l["result"], "rolled-back", l)
          t.assertIn("nix-daemon", l["health"]["failing"], l)
          m.succeed("journalctl -u nix-daemon -o cat | grep -q \"user 'nobody' is not allowed to connect\"")
          t.assertEqual(current(m), base)
          m.succeed(f"test -f /var/lib/vdeploy/bad/$(basename {good})")

      with subtest("drakkar: after a root switch to it, the bad-marked generation is the running one, and kept"):
          # What the user's one root rebuild does: the same generation, switched by hand.
          m.succeed(f"nix-env -p /nix/var/nix/profiles/system --set {good}")
          # (`test`, not `switch`: a VM's GRUB cannot install; the boot entry is not the point.)
          m.succeed(f"{good}/bin/switch-to-configuration test")
          t.assertEqual(current(m), good)
          # vdeploy (as fixed) sees it: already running, the stale mark cleared, nothing switched.
          m.succeed(f"vdeploy-apply {good}")
          l = last(m)
          t.assertEqual(l["result"], "already", l)
          t.assertIn("mark is cleared", l["note"])
          m.fail(f"test -e /var/lib/vdeploy/bad/$(basename {good})")
          t.assertEqual(current(m), good)
          non_root(m, "good")

      with subtest("drakkar: as the vhealth user the restricted daemon answers; vhealth's daemon agrees"):
          m.wait_until_succeeds(
              "grep -qF 'vhealth_probe_up{probe=\"nix-daemon\",kind=\"command\",critical=\"true\"} 1' ${dir}/vhealth.prom",
              timeout=60,
          )
          m.fail("journalctl -u nix-daemon -o cat | grep -q \"user 'vhealth' is not allowed\"")
          # The ledger is readable by users (no root needed to see what vdeploy did).
          t.assertEqual(last(m, as_user=True)["result"], "already")

      with subtest("drakkar: a forced-failing health check rolls back, and the boot default never moves"):
          # The liar is active per systemd; only the probe sees that nothing serves.
          m.fail(f"vdeploy-apply {broken}")
          t.assertEqual(current(m), good)
          t.assertEqual(profile(m), good)
          l = last(m)
          t.assertEqual((l["result"], l["toplevel"], l["prev"]), ("rolled-back", broken, good), l)
          t.assertEqual(l["health"]["failing"], ["dead-port"], l)
          t.assertIn("dead-port", l["reason"])
          m.succeed(f"test -f /var/lib/vdeploy/bad/$(basename {broken})")
          metric(m, 'vdeploy_last_result{result="rolled-back"} 1')
          m.fail("systemctl is-active liar.service")
          m.succeed(f"journalctl -u vdeploy-apply -o cat | grep -qF 'rolled back from {broken} to {good}'")
          non_root(m, "good")

      with subtest("drakkar: the rolled-back generation is refused when asked again, with no switch"):
          m.fail(f"vdeploy-apply {broken}")
          t.assertEqual(current(m), good)
          l = last(m)
          t.assertEqual(l["result"], "refused", l)
          t.assertIn("marked bad", l["reason"])
          non_root(m, "good")

      with subtest("drakkar: an apply killed in its health window is decided by the next one"):
          m.succeed(f"systemd-run --unit=apply-bg --collect vdeploy-apply {stuck}")
          m.wait_until_succeeds("test -e /var/lib/vdeploy/inflight.json", timeout=60)
          m.wait_until_succeeds("pgrep -f 'vhealth check'", timeout=60)
          m.succeed("systemctl kill --signal=SIGKILL vdeploy-apply.service")
          m.wait_until_fails("systemctl is-active vdeploy-apply.service", timeout=30)
          t.assertEqual(current(m), stuck)
          t.assertEqual(profile(m), good)
          inflight = json.loads(m.succeed("cat /var/lib/vdeploy/inflight.json"))
          t.assertEqual((inflight["toplevel"], inflight["prev"]), (stuck, good))
          m.succeed("vdeploy-apply")
          t.assertEqual(current(m), good)
          t.assertEqual(profile(m), good)
          m.fail("test -e /var/lib/vdeploy/inflight.json")
          m.succeed(f"test -f /var/lib/vdeploy/bad/$(basename {stuck})")
          m.succeed(f"journalctl -u vdeploy-apply -o cat | grep -qF 'resuming the interrupted apply of {stuck}'")
          non_root(m, "good")

      with subtest("drakkar: the history holds every outcome"):
          history = [json.loads(l)["result"] for l in m.succeed("cat /var/lib/vdeploy/deploys.jsonl").splitlines()]
          t.assertEqual(history, ["rolled-back", "already", "rolled-back", "refused", "rolled-back"])
          metric(m, "vdeploy_rollbacks_total 3")

      # ---------------------------------------------------------------- mimir's (STIG base-safe)
      m = mimir
      booted(m)
      base = current(m)
      good, broken = gen(m, "good"), gen(m, "broken")

      with subtest("mimir (base-safe): vhealth's nix-daemon probe is up as the vhealth user"):
          m.wait_until_succeeds(
              "grep -qF 'vhealth_probe_up{probe=\"nix-daemon\",kind=\"command\",critical=\"true\"} 1' ${dir}/vhealth.prom",
              timeout=60,
          )

      with subtest("mimir (base-safe): a healthy generation is kept, the boot profile written"):
          m.succeed(f"vdeploy-apply {good}")
          t.assertEqual(current(m), good)
          t.assertEqual(profile(m), good)
          l = last(m, as_user=True)
          t.assertEqual((l["result"], l["prev"]), ("switched", base), l)
          t.assertTrue(l["health"]["healthy"], l)
          t.assertNotIn("nix-daemon", l["health"]["failing"])
          non_root(m, "good")

      with subtest("mimir (base-safe): a forced-failing health check rolls back"):
          m.fail(f"vdeploy-apply {broken}")
          t.assertEqual(current(m), good)
          t.assertEqual(profile(m), good)
          l = last(m, as_user=True)
          t.assertEqual((l["result"], l["health"]["failing"]), ("rolled-back", ["dead-port"]), l)
          # Readable to users even under the profile's UMASK 077 (the units set their own).
          m.succeed("su - alice -c 'cat /var/lib/vdeploy/deploys.jsonl ${dir}/vdeploy-apply.prom' > /dev/null")
          non_root(m, "good")
    '';
  }
