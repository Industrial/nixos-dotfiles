# vdeploy's wake (GH-246), switched into and out of a running, hardened system:
#
#   nix build .#checks.x86_64-linux.vdeploy-wake-vm
#
#   target    deploy mode, the STIG base-safe profile (mimir's), the restricted daemon
#             (allowed-users = @wheel, as on every host), vhealth, interval 1h: only a wake
#             makes it poll during the test. It boots WITHOUT wake support; the `wake`
#             specialisation adds it (live), and switching back to the boot generation
#             takes it away again. alice is the operator (group vdeploy-wake), bob a normal
#             user who is not.
#   operator  ssh as alice with the operator key: what `fleet deploy` does.
#
# The "fleet repository" is /srv/origin, a flake with no inputs whose toplevel is a link to
# the target's `good` specialisation (the path is written in by the test script), so the
# plan, the apply, the health check and `--wait` all see a real generation.
#
# Covered:
#   1. no wake support: `vdeploy wake` says so (69) and vdeploy is untouched;
#   2. switched in live: the FIFO is root:vdeploy-wake 0620; bob is refused (77);
#   3. the operator's `ssh target vdeploy wake --wait` makes it poll main at once, plan it,
#      switch to it health-checked, and say so; status.json, plan.json and last.json are
#      readable by alice;
#   4. a burst of wakes is at most one extra poll each way, never one per write;
#   5. wakes during a restart never kill vdeploy (no signal exists to do it);
#   6. the FIFO deleted while vdeploy runs: vdeploy stays up and says so; recreated,
#      wakes work again;
#   7. switched out live: no wake support, vdeploy up, the interval poll as before;
#   and after every step, the daemon answers alice and the web page is the generation's.
{pkgs}: let
  inherit (pkgs) busybox;
  keys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
  lock = pkgs.writeText "flake.lock" ''{"nodes":{"root":{}},"root":"root","version":7}'';

  target = {
    config,
    lib,
    ...
  }: let
    inherit (config.vmtest) gen;
  in {
    imports = [./default.nix ../vhealth/default.nix ../../security/stig/profiles/base-safe.nix];

    options.vmtest.gen = lib.mkOption {
      type = lib.types.enum ["base" "wake" "good"];
      default = "base";
    };

    config = {
      services.timesyncd.enable = lib.mkForce true;
      system.switch.enable = true;
      # The VM's disk takes no GRUB; the boot default is the profile, which is what counts.
      boot.loader.grub.enable = false;

      features.nix.vdeploy = {
        mode = "deploy";
        url = "/srv/origin";
        interval = "1h";
        healthWindow = "10s";
        dotfiles.enable = false;
        wake.enable = gen != "base";
        wake.operators = ["alice"];
      };
      nix.settings.allowed-users = ["@wheel"];
      features.nix.vhealth.restrictedNixUsers = true;

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

      nix.settings = {
        substituters = lib.mkForce [];
        experimental-features = ["nix-command" "flakes"];
        # The origin's toplevel links to a store path named without string context.
        sandbox = false;
      };
      system.extraDependencies = [busybox];
      programs.git = {
        enable = true;
        config.safe.directory = "*";
      };

      services.openssh.enable = true;
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keys = [keys.snakeOilEd25519PublicKey];
      };
      users.users.bob = {
        isNormalUser = true;
        uid = 1001;
      };
      environment.systemPackages = [pkgs.curl pkgs.jq];
      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };

      specialisation = lib.mkIf (gen == "base") {
        wake.configuration.vmtest.gen = "wake";
        good.configuration.vmtest.gen = "good";
      };
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "vdeploy-wake-vm";

    nodes.target = target;
    nodes.operator = {...}: {
      environment.etc."operator-key" = {
        source = keys.snakeOilEd25519PrivateKey;
        mode = "0600";
      };
    };

    testScript = {nodes, ...}: let
      base = nodes.target.system.build.toplevel;
    in ''
      import json

      prom = "/var/lib/prometheus-node-exporter-text/vdeploy.prom"

      def as_user(user, cmd):
          return f"su - {user} -c {json.dumps(cmd)}"

      def current():
          return target.succeed("readlink -f /run/current-system").strip()

      def polls():
          # The first poll after a (re)start retries a failing fetch (10 s, 20 s) before it writes.
          target.wait_until_succeeds(f"grep -q '^vdeploy_polls_total ' {prom}", timeout=120)
          line = target.succeed(f"grep '^vdeploy_polls_total ' {prom}").split()
          return int(line[1])

      def non_root(page):
          target.succeed(as_user("alice", "timeout 60 nix-store --store daemon -q --hash /run/current-system"))
          body = target.succeed(as_user("alice", "timeout 30 curl -sf http://127.0.0.1:8080/index.html")).strip()
          t.assertEqual(body, page)

      def ssh_wake(args=""):
          return operator.execute(
              "ssh -i /etc/operator-key -o StrictHostKeyChecking=no -o BatchMode=yes "
              f"alice@target vdeploy wake {args} 2>&1"
          )

      start_all()
      target.wait_for_unit("multi-user.target")
      target.wait_for_unit("vdeploy.service")
      target.wait_for_unit("sshd.service")
      operator.wait_for_unit("multi-user.target")
      non_root("base")
      good = target.succeed("readlink -f ${base}/specialisation/good").strip()
      wake_gen = target.succeed("readlink -f ${base}/specialisation/wake").strip()

      with subtest("no wake support yet: vdeploy wake says so, vdeploy untouched"):
          status, out = target.execute(as_user("alice", "vdeploy wake 2>&1"))
          t.assertEqual(status, 69, out)
          target.succeed("systemctl is-active vdeploy.service")

      with subtest("switched in live: the FIFO is the operators', and bob is refused"):
          target.succeed(f"{wake_gen}/bin/switch-to-configuration test")
          target.wait_until_succeeds("journalctl -u vdeploy -o cat | grep -q 'and on a wake (/run/vdeploy/wake)'", timeout=60)
          t.assertEqual(target.succeed("stat -c '%F %U:%G %a' /run/vdeploy/wake").strip(), "fifo root:vdeploy-wake 620")
          t.assertIn("alice", target.succeed("getent group vdeploy-wake"))
          status, out = target.execute(as_user("bob", "vdeploy wake 2>&1"))
          t.assertEqual(status, 77, out)
          non_root("wake")

      # The origin: main's toplevel is the `good` generation.
      target.succeed("mkdir -p /srv/origin && git -C /srv/origin init -q -b main")
      target.succeed(
          "cat > /srv/origin/flake.nix <<EOF\n"
          "{ outputs = {self}: { nixosConfigurations.target.config.system.build.toplevel = derivation {\n"
          "    name = \"vdeploy-wake-system\"; system = \"x86_64-linux\";\n"
          "    builder = \"${busybox}/bin/sh\";\n"
          f"    args = [\"-c\" \"${busybox}/bin/ln -s {good} \\$out\"]; }}; }}; }}\n"
          "EOF"
      )
      target.succeed("cp ${lock} /srv/origin/flake.lock")
      target.succeed("git -C /srv/origin add -A && git -C /srv/origin -c user.name=t -c user.email=t@t commit -q -m main")
      with subtest("the operator's wake --wait: polled now, planned, switched, health-checked"):
          before = polls()
          status, out = ssh_wake("--wait --timeout 300")
          t.assertEqual(status, 0, out)
          t.assertIn("switched to main", out)
          t.assertEqual(current(), good)
          t.assertGreater(polls(), before)
          # What --wait read, alice reads too: status.json, plan.json, last.json.
          for f in ["status.json", "plan.json", "last.json"]:
              target.succeed(as_user("alice", f"jq -e . /var/lib/vdeploy/{f} > /dev/null"))
          non_root("good")

      with subtest("a burst of wakes is not a poll per write"):
          before = polls()
          target.succeed(as_user("alice", "for i in {1..20}; do vdeploy wake >/dev/null; done"))
          target.sleep(5)
          t.assertLessEqual(polls() - before, 10)
          status, out = ssh_wake("--wait --timeout 120")
          t.assertEqual(status, 0, out)
          t.assertTrue("switched to main" in out or "nothing to switch" in out, out)

      with subtest("wakes during a restart never kill vdeploy"):
          target.succeed(as_user("alice", "(for i in {1..50}; do vdeploy wake >/dev/null 2>&1; sleep 0.1; done) >/dev/null 2>&1 &") + " ; sleep 1; systemctl restart vdeploy.service; sleep 6")
          target.wait_for_unit("vdeploy.service")
          target.fail("journalctl -u vdeploy -o cat | grep -E 'code=killed|status=.*/USR1'")
          t.assertEqual(target.succeed("systemctl show -p Result --value vdeploy.service").strip(), "success")

      with subtest("the FIFO deleted while vdeploy runs: still up, said, and back once recreated"):
          target.succeed("rm /run/vdeploy/wake")
          target.wait_until_succeeds("journalctl -u vdeploy -o cat | grep -q 'polling on the interval only until it is back'", timeout=200)
          target.succeed("systemctl is-active vdeploy.service")
          status, _ = target.execute(as_user("alice", "vdeploy wake"))
          t.assertEqual(status, 69)
          target.succeed("systemd-tmpfiles --create")
          target.wait_until_succeeds("journalctl -u vdeploy -o cat | grep -q 'the FIFO is back'", timeout=200)
          before = polls()
          status, out = ssh_wake("--wait --timeout 120")
          t.assertEqual(status, 0, out)
          t.assertGreater(polls(), before)
          non_root("good")

      with subtest("switched out live: no wake support, vdeploy up, the interval poll as before"):
          target.succeed("${base}/bin/switch-to-configuration test")
          target.wait_until_succeeds("journalctl -u vdeploy -o cat | grep -q 'deploy mode for'", timeout=60)
          target.succeed("systemctl is-active vdeploy.service")
          status, out = target.execute(as_user("alice", "vdeploy wake 2>&1"))
          # The FIFO left in /run belongs to a group that no longer exists: nobody may write it
          # (77); with it gone or unread, 69 or 75. Never delivered either way.
          t.assertIn(status, [69, 75, 77], out)
          t.assertNotIn("--wake-fifo", target.succeed("systemctl show -p ExecStart --value vdeploy.service"))
          non_root("base")
    '';
  }
