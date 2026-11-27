# vswitch, the local rebuild (GH-241), switching a real system as a non-root user:
#
#   nix build .#checks.x86_64-linux.vswitch-vm
#
# The node is drakkar-like: nix.settings.allowed-users = ["@wheel"] (features/nixos/users on
# every host), vhealth with its probes, and alice in wheel like tom. It also carries the real
# STIG base-safe profile, as mimir does (#241; vdeploy-rollback-vm's mimir node imports it the
# same way): auditd, AppArmor, require-sigs, UMASK 077, and V-268156's
# `security.sudo.wheelNeedsPassword = true`. vswitch is run by alice; only the activation is
# elevated, by the real sudo asking alice's password on a terminal (askpw below answers it and
# counts the prompts), in vdeploy's transient unit. The generations are specialisations of the boot generation, handed over with
# --toplevel (the VM has no flake to build from; the build step is covered by the crate's
# tests):
#   good     the web page changes; its probe expects the new page
#   broken   adds `liar`, a unit systemd reports active while nothing listens on its port, and
#            a critical TCP probe on that port: unhealthy whatever systemd says
#
# Covered, with the non-root user checked after every step (the daemon answers alice, the
# web page is the generation's):
#   1. a vhealth failure rolls back: switch to broken exits non-zero, the previous generation
#      runs again, the boot default never moved, and broken is marked bad in vdeploy's ledger;
#   2. the bad generation is refused when asked again, with no switch;
#   3. a healthy switch is kept: running and boot default both move;
#   4. switching to the generation that runs is a no-op that needs no root;
#   5. test activates without touching the boot default; boot moves only the boot default;
#   6. the activation ran in the vdeploy-apply unit, and as alice nothing was asked of sudo
#      for build-only verbs (vswitch build --toplevel needs no root at all).
{pkgs}: let
  inherit (pkgs) busybox;

  # alice's password. Not a secret: the test VM's alone.
  password = "gh241-pw";

  # askpw "<shell command>": runs it on a fresh pseudo-terminal, as a person at a console
  # would, and answers each sudo password prompt with alice's password. Output and exit
  # status are the command's; the last line, on stdout, is `askpw: prompts=<n>`.
  askpw = pkgs.writeScriptBin "askpw" ''
    #!${pkgs.python3}/bin/python3
    import os, pty, sys
    pid, fd = pty.fork()
    if pid == 0:
        os.execv("/bin/sh", ["/bin/sh", "-c", sys.argv[1]])
    seen, prompts = b"", 0
    while True:
        try:
            data = os.read(fd, 4096)
        except OSError:
            break
        if not data:
            break
        sys.stdout.buffer.write(data)
        sys.stdout.flush()
        seen = (seen + data)[-256:]
        if b"password for" in seen.lower():
            os.write(fd, b"${password}\n")
            prompts += 1
            seen = b""
    _, status = os.waitpid(pid, 0)
    print(f"askpw: prompts={prompts}", flush=True)
    sys.exit(os.waitstatus_to_exitcode(status))
  '';

  node = {
    config,
    lib,
    ...
  }: let
    inherit (config.vmtest) gen;
  in {
    imports = [
      ./default.nix
      ../../nix/vhealth/default.nix
      # The real hardening, not a stand-in (#241): mimir's profile.
      ../../security/stig/profiles/base-safe.nix
    ];

    options.vmtest.gen = lib.mkOption {
      type = lib.types.enum ["base" "good" "broken"];
      default = "base";
    };

    config = {
      # qemu-vm turns timesyncd off; base-safe's V-268151 turns it on. The control wins here,
      # as in vdeploy-rollback-vm.
      services.timesyncd.enable = lib.mkForce true;
      system.switch.enable = true;
      # The test VM's disk is ext2 without room for GRUB's core image, so a real
      # `switch-to-configuration boot` cannot install GRUB there and fails (as it should;
      # vswitch reports it). The boot default is the system profile, which is what these
      # subtests check; the boot entries are not the point, so no boot loader is installed.
      boot.loader.grub.enable = false;

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
          };
      };

      nix.settings.experimental-features = ["nix-command"];
      # In wheel, like tom: the only users the restricted daemon serves, and sudo's. sudo asks
      # for this password (V-268156); nothing here turns that off.
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
        extraGroups = ["wheel"];
        inherit password;
      };
      environment.systemPackages = [pkgs.curl askpw];
      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };

      specialisation = lib.mkIf (gen == "base") {
        good.configuration.vmtest.gen = "good";
        broken.configuration.vmtest.gen = "broken";
      };
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "vswitch-vm";

    nodes.machine = node;

    testScript = ''
      import json

      def gen(name):
          base = machine.succeed("readlink -f /run/booted-system").strip()
          return machine.succeed(f"readlink -f {base}/specialisation/{name}").strip()

      def current():
          return machine.succeed("readlink -f /run/current-system").strip()

      def profile():
          return machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()

      def last():
          return json.loads(machine.succeed("cat /var/lib/vdeploy/last.json"))

      def alice(cmd):
          return f"su - alice -c {json.dumps(cmd)}"

      # alice at a terminal: sudo asks her password (STIG V-268156) and askpw types it.
      def alice_tty(cmd):
          return alice(f"askpw {json.dumps(cmd)}")

      def prompts(out):
          return int(out.strip().splitlines()[-1].removeprefix("askpw: prompts="))

      def non_root(page):
          machine.succeed(alice("timeout 60 nix-store --store daemon -q --hash /run/current-system"))
          body = machine.succeed(alice("timeout 30 curl -sf http://127.0.0.1:8080/index.html")).strip()
          t.assertEqual(body, page)

      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("web.service")
      non_root("base")
      base = current()
      good, broken = gen("good"), gen("broken")
      # A test VM boots its closure with no system profile at all (as a fresh install has
      # none): vswitch reads that as "no boot default", not as an error.
      boot_default = profile()

      def marks():
          return machine.succeed("ls /var/lib/vdeploy/bad 2>/dev/null || true").split()

      with subtest("the STIG base-safe profile is in force on the node"):
          machine.succeed("systemctl is-active auditd.service")
          machine.succeed("grep -qx 'require-sigs = true' /etc/nix/nix.conf")

      with subtest("build needs no root: it only resolves and diffs, and sudo is never asked"):
          out = machine.succeed(alice_tty(f"vswitch build --toplevel {good} 2>&1"))
          t.assertIn(f"built {good}", out)
          t.assertEqual(prompts(out), 0, out)
          t.assertEqual((current(), profile()), (base, boot_default))

      with subtest("without alice's password, sudo refuses and nothing is activated"):
          # No terminal, so sudo cannot ask: the STIG's password requirement is what stops it.
          status, out = machine.execute(alice(f"timeout 60 vswitch test --toplevel {good} 2>&1"))
          t.assertNotEqual(status, 0, out)
          t.assertEqual((current(), profile()), (base, boot_default))
          t.assertEqual(marks(), [])

      with subtest("a vhealth failure rolls back, the boot default never moves, and it is marked bad"):
          status, out = machine.execute(alice_tty(f"vswitch switch --toplevel {broken} --health-window 10s 2>&1"))
          t.assertEqual(status, 1, out)
          t.assertEqual(prompts(out), 1, out)
          # `systemd-run --pipe`: the apply's own words reach the operator's terminal.
          t.assertIn(f"rolled back from {broken} to {base}", out)
          t.assertEqual(current(), base)
          t.assertEqual(profile(), boot_default)
          l = last()
          t.assertEqual((l["result"], l["toplevel"], l["prev"]), ("rolled-back", broken, base), l)
          t.assertEqual(l["health"]["failing"], ["dead-port"], l)
          machine.succeed(f"test -f /var/lib/vdeploy/bad/$(basename {broken})")
          machine.fail("systemctl is-active liar.service")
          non_root("base")

      with subtest("the rolled-back generation is refused when asked again, with no switch"):
          machine.fail(alice_tty(f"vswitch switch --toplevel {broken} --health-window 10s"))
          t.assertEqual(current(), base)
          t.assertEqual(last()["result"], "refused")
          non_root("base")

      with subtest("a healthy switch is kept: running and boot default both move"):
          out = machine.succeed(alice_tty(f"vswitch switch --toplevel {good} --health-window 30s 2>&1"))
          t.assertEqual(prompts(out), 1, out)
          t.assertEqual(current(), good)
          t.assertEqual(profile(), good)
          l = last()
          t.assertEqual((l["result"], l["prev"]), ("switched", base), l)
          t.assertTrue(l["health"]["healthy"], l)
          # vdiff's report of the running system against the new one was printed first.
          t.assertIn("Closure size:", out)
          non_root("good")

      with subtest("while vdeploy is mid-apply, vswitch stops at once, says why, and touches nothing"):
          # A stand-in for vdeploy's apply: the same transient unit name, still running.
          machine.succeed("systemd-run --unit=vdeploy-apply --service-type=exec --collect sleep 300")
          machine.wait_until_succeeds("systemctl is-active vdeploy-apply.service", timeout=30)
          before = marks()
          for verb in ["switch", "test", "boot"]:
              # `timeout`: a hang is a failure too; --elevate false: it must not get as far as sudo.
              status, out = machine.execute(alice(f"timeout 60 vswitch {verb} --toplevel {base} --elevate /run/current-system/sw/bin/false 2>&1"))
              t.assertEqual(status, 1, out)
              t.assertIn("vdeploy-apply.service is running", out)
              t.assertEqual((current(), profile()), (good, good))
          # The other's switch is not rolled back or stopped, and no mark was written.
          machine.succeed("systemctl is-active vdeploy-apply.service")
          t.assertEqual(marks(), before)
          # A start that raced past the check is refused by systemd itself, at once.
          machine.fail("timeout 30 systemd-run --unit=vdeploy-apply --wait --quiet true")
          machine.succeed("systemctl stop vdeploy-apply.service")
          non_root("good")

      with subtest("switching to the running generation is a no-op"):
          out = machine.succeed(alice(f"vswitch switch --toplevel {good} --elevate /run/current-system/sw/bin/false 2>&1"))
          t.assertIn("nothing to switch", out)
          t.assertEqual(current(), good)

      with subtest("test activates without touching the boot default"):
          machine.succeed(alice_tty(f"vswitch test --toplevel {base}"))
          t.assertEqual((current(), profile()), (base, good))
          non_root("base")

      with subtest("boot moves only the boot default"):
          machine.succeed(alice_tty(f"vswitch boot --toplevel {base}"))
          t.assertEqual((current(), profile()), (base, base))
          non_root("base")

      with subtest("only switch marks a generation bad; test and boot never write the ledger"):
          t.assertEqual(marks(), [broken.removeprefix("/nix/store/")])

      with subtest("every activation ran in vdeploy's unit"):
          machine.succeed("journalctl -o cat | grep -qF 'vswitch switch: '")
          machine.succeed("journalctl -o cat | grep -qF 'vswitch test: '")
          machine.succeed("journalctl -o cat | grep -qF 'vswitch boot: '")
    '';
  }
