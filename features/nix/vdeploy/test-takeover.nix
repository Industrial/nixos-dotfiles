# The take-over's END STATE, switched in and out live (GH-225, brief rule 17).
#
#   nix build .#checks.x86_64-linux.vdeploy-takeover-vm
#
# GH-160's take-over is done: comin applied the generation that retired it on drakkar and
# mimir, and both now run vdeploy in deploy mode with comin.service a TOMBSTONE (inactive,
# Restart=no, no wantedBy, ExecStart=true). GH-225 removes the tombstone, so the generation
# that lands next DROPS comin.service altogether. This test boots in exactly the hosts'
# state before that change and switches into the end state and out of it, with vdeploy
# doing every switch (as on the hosts), checking a non-root user after each one.
#
# Generations are specialisations of the boot generation:
#   base     vdeploy deploy mode, and the tombstone as features/nix/vdeploy defined it until
#            GH-225 (copied here: the hosts' state before this change)
#   retired  the end state: deploy mode, no comin.service at all
#   good     retired, with the web service serving another page
#
# Covered (alice: a store query through the daemon, and the web page, after every switch):
#   1. the boot generation: the tombstone is loaded and dead, vdeploy deploys;
#   2. INTO the end state: `vdeploy-apply retired` (the daemon's own transient unit) switches,
#      health-checked; comin.service is not-found; vdeploy.service is still active;
#   3. vdeploy deploys in the end state: `vdeploy-apply good` switches and writes the system
#      profile;
#   4. a vdeploy restart with no comin unit: the start-up check finds no comin switch in
#      flight and goes straight to deploy mode;
#   5. OUT, back to the tombstone generation (what a deploy of an older commit does): it
#      switches, the tombstone comes back dead, nothing starts comin; then IN again;
#   6. the refusal still holds: an apply while a unit named comin.service is active is
#      refused, with no switch.
{pkgs}: let
  inherit (pkgs) busybox;
  dir = "/var/lib/prometheus-node-exporter-text";
in
  pkgs.testers.runNixOSTest {
    name = "vdeploy-takeover-vm";

    nodes.machine = {
      config,
      lib,
      ...
    }: let
      inherit (config.vmtest) gen;
    in {
      imports = [./default.nix ../vhealth/default.nix];

      options.vmtest.gen = lib.mkOption {
        type = lib.types.enum ["base" "retired" "good"];
        default = "base";
      };

      config = {
        system.switch.enable = true;
        features.nix.vdeploy = {
          mode = "deploy";
          # Nothing to poll here: the applies are driven by the test, through vdeploy-apply.
          url = "/srv/nothing";
          interval = "1h";
          healthWindow = "10s";
          dotfiles.enable = false;
        };

        # The tombstone, verbatim from features/nix/vdeploy before GH-225.
        systemd.services.comin = lib.mkIf (gen == "base") {
          description = "comin, retired by vdeploy (a tombstone: features/nix/vdeploy)";
          restartIfChanged = false;
          wantedBy = lib.mkForce [];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.coreutils}/bin/true";
            Restart = lib.mkForce "no";
          };
        };

        # A service with a probe, so every generation has a health check that means something.
        environment.etc."web/index.html".text = "${gen}\n";
        systemd.services.web = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${busybox}/bin/httpd -f -p 127.0.0.1:8080 -h /etc/web";
        };
        features.nix.vhealth = {
          interval = "5s";
          probes.web = {
            type = "http";
            url = "http://127.0.0.1:8080/index.html";
            bodyContains = gen;
            timeout = 2000;
          };
        };

        nix.settings.experimental-features = ["nix-command"];
        # drakkar's restriction (features/nixos/users): only wheel, and vhealth, may use the
        # Nix daemon. alice is in wheel, like tom.
        nix.settings.allowed-users = ["@wheel"];
        features.nix.vhealth.restrictedNixUsers = true;
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
          retired.configuration.vmtest.gen = "retired";
          good.configuration.vmtest.gen = "good";
        };
      };
    };

    testScript = {nodes, ...}: let
      base = nodes.machine.system.build.toplevel;
    in ''
      import json

      base = "${base}"
      def gen(name):
          return machine.succeed(f"readlink -f {base}/specialisation/{name}").strip()
      retired, good = gen("retired"), gen("good")

      def current():
          return machine.succeed("readlink -f /run/current-system").strip()

      def non_root(page):
          machine.succeed("timeout 60 su - alice -c 'nix-store --store daemon -q --hash /run/current-system'")
          body = machine.succeed("timeout 30 su - alice -c 'curl -sf http://127.0.0.1:8080/index.html'").strip()
          t.assertEqual(body, page)

      def last():
          return json.loads(machine.succeed("cat /var/lib/vdeploy/last.json"))

      def comin(prop):
          return machine.succeed(f"systemctl show comin.service -p {prop} --value").strip()

      def apply(target, prev):
          machine.succeed(f"vdeploy-apply {target}")
          t.assertEqual(current(), target)
          l = last()
          t.assertEqual((l["result"], l["toplevel"], l["prev"]), ("switched", target, prev))
          t.assertTrue(l["health"]["healthy"], l)
          machine.succeed(f"journalctl -o cat | grep -qF 'finished switching to system configuration {target}'")
          t.assertEqual(machine.succeed("readlink -f /nix/var/nix/profiles/system").strip(), target)
          machine.fail("test -e /var/lib/vdeploy/inflight.json")
          machine.succeed("systemctl is-active vdeploy.service")
          machine.fail("systemctl is-active comin.service")

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("vdeploy.service")
      machine.wait_for_unit("web.service")

      with subtest("the boot generation, the hosts' state before GH-225: the tombstone is dead, vdeploy deploys"):
          t.assertEqual(current(), base)
          t.assertEqual((comin("LoadState"), comin("ActiveState")), ("loaded", "inactive"))
          machine.succeed("systemctl cat comin.service | grep -qx 'Restart=no'")
          machine.wait_until_succeeds("journalctl -u vdeploy -o cat | grep -q 'vdeploy deploys this host'", timeout=60)
          machine.wait_until_succeeds("grep -qx 'vdeploy_deploy_mode 1' ${dir}/vdeploy.prom", timeout=120)
          non_root("base")

      with subtest("INTO the end state, switched by vdeploy: comin.service is gone"):
          apply(retired, base)
          t.assertEqual(comin("LoadState"), "not-found")
          # Under drakkar's allowed-users, as the vhealth user: the daemon answered.
          machine.fail("journalctl -u nix-daemon -o cat | grep -q 'is not allowed to connect'")
          non_root("retired")

      with subtest("vdeploy deploys in the end state"):
          apply(good, retired)
          t.assertEqual(comin("LoadState"), "not-found")
          non_root("good")

      with subtest("a vdeploy restart with no comin unit goes straight to deploy mode"):
          t0 = machine.succeed("date +%s").strip()
          machine.sleep(1)
          machine.succeed("systemctl restart vdeploy.service")
          machine.wait_for_unit("vdeploy.service")
          since = f"journalctl -u vdeploy -o cat --since @{t0}"
          machine.wait_until_succeeds(f"{since} | grep -q 'comin.service is not running: vdeploy deploys this host'", timeout=60)
          machine.wait_until_succeeds(f"{since} | grep -q 'deploy mode for machine'", timeout=60)
          machine.fail(f"{since} | grep -q 'still switching'")
          t.assertEqual(comin("LoadState"), "not-found")
          non_root("good")

      with subtest("OUT to the tombstone generation and IN again, both by vdeploy"):
          apply(base, good)
          t.assertEqual((comin("LoadState"), comin("ActiveState")), ("loaded", "inactive"))
          non_root("base")
          apply(good, base)
          t.assertEqual(comin("LoadState"), "not-found")
          non_root("good")

      with subtest("nothing switches while a comin.service is active"):
          machine.succeed("systemd-run --unit comin.service --service-type=simple sleep 600")
          machine.wait_until_succeeds("systemctl is-active comin.service", timeout=30)
          machine.fail(f"vdeploy apply --toplevel {retired} --state-dir /tmp/refused --comin-unit comin.service")
          t.assertEqual(current(), good)
          refused = json.loads(machine.succeed("cat /tmp/refused/last.json"))
          t.assertEqual(refused["result"], "refused")
          t.assertIn("comin.service is active", refused["reason"])
          machine.succeed("systemctl stop comin.service")
          non_root("good")
    '';
  }
