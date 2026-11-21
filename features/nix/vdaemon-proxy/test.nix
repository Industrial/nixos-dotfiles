# The vdaemon-proxy feature in a VM: Nix used as an ordinary (untrusted) user goes
# through the proxy, and the proxy's journal has the ops.
#
#   nix build .#checks.x86_64-linux.vdaemon-proxy-vm
#
# Covered: `nix-build` of a trivial derivation, `nix-store -q --references`, `nix copy
# --to file://`, the daemon still telling a trusted root from an untrusted user (the
# upstream connection carries the client's uid), a killed proxy coming back, and the
# fallback that hands the public socket to nix-daemon directly.
{pkgs}: let
  inherit (pkgs) busybox;
  # A derivation with no inputs but busybox, built in the sandbox.
  expr = pkgs.writeText "trivial.nix" ''
    derivation {
      name = "vdaemon-proxy-trivial";
      system = builtins.currentSystem;
      builder = "''${builtins.storePath ${busybox}}/bin/sh";
      args = ["-c" "echo built-through-the-proxy > $out"];
    }
  '';
in
  pkgs.testers.runNixOSTest {
    name = "vdaemon-proxy";

    nodes.machine = {
      imports = [./default.nix];
      nix.settings.experimental-features = ["nix-command"];
      # The builder's closure, in the VM's store.
      system.extraDependencies = [busybox];
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
      };
      virtualisation.memorySize = 1024;
    };

    testScript = ''
      # nix store info reports on stderr, hence the 2>&1 below.
      def alice(cmd):
          return machine.succeed(f"timeout 60 su - alice -c '{cmd}'")

      def diagnose():
          print(machine.execute("systemctl status --no-pager vdaemon-proxy.socket vdaemon-proxy.service vdaemon-proxy-fallback.service nix-daemon.socket nix-daemon.service; ss -xlp | grep -i nix; ls -la /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket-upstream; journalctl -u vdaemon-proxy-fallback.service --no-pager | tail -n 40")[1])

      def logged(op):
          machine.wait_until_succeeds(
              f"journalctl -u vdaemon-proxy.service -o cat | grep -F '\"op\":\"{op}'", timeout=30
          )

      def ops():
          return int(machine.succeed("journalctl -u vdaemon-proxy.service -o cat | grep -c '\"event\":\"op\"' || true").strip())

      machine.wait_for_unit("sockets.target")
      machine.succeed("systemctl is-active vdaemon-proxy.socket")
      machine.succeed("test -S /nix/var/nix/daemon-socket/socket")
      # The real daemon is out of users' reach.
      machine.succeed("test -S /nix/var/nix/daemon-socket-upstream/socket")
      machine.succeed("test \"$(stat -c %a /nix/var/nix/daemon-socket-upstream)\" = 700")
      machine.fail("su - alice -c 'nix store info --store unix:///nix/var/nix/daemon-socket-upstream/socket'")

      with subtest("nix-store -q --references passes through the proxy"):
          refs = alice("nix-store -q --references /run/current-system")
          assert "/nix/store/" in refs, refs
          machine.succeed("systemctl is-active vdaemon-proxy.service")
          logged("QueryPathInfo")
          machine.succeed("journalctl -u vdaemon-proxy.service -o cat | grep -F '\"uid\":1000'")

      with subtest("nix-build of a trivial derivation"):
          out = alice("nix-build --no-out-link ${expr}").strip()
          assert machine.succeed(f"cat {out}").strip() == "built-through-the-proxy"
          # nix-build asks for BuildPaths, nix build for BuildPathsWithResults.
          logged("BuildPaths")

      with subtest("nix copy --to file://"):
          before = ops()
          alice(f"nix copy --to file:///tmp/c {out}")
          machine.succeed("ls /tmp/c/*.narinfo")
          machine.wait_until_succeeds(f"test $(journalctl -u vdaemon-proxy.service -o cat | grep -c '\"event\":\"op\"') -gt {before}", timeout=30)
          logged("QueryPathInfo")

      with subtest("the daemon still sees who the client is"):
          assert "Trusted: 0" in alice("nix store info 2>&1"), "alice must stay untrusted"
          assert "Trusted: 1" in machine.succeed("nix store info --store daemon 2>&1"), "root must stay trusted"

      with subtest("a killed proxy comes back, and no fallback is taken"):
          machine.succeed("systemctl kill -s KILL vdaemon-proxy.service")
          alice("nix-store -q --hash /run/current-system")
          machine.wait_for_unit("vdaemon-proxy.service")
          machine.succeed("systemctl is-active vdaemon-proxy.socket")
          machine.fail("systemctl is-active vdaemon-proxy-fallback.service")

      with subtest("a proxy that keeps dying hands the socket to nix-daemon"):
          # Past the start limit (10 in 30 s): kill it each time it is back.
          for _ in range(12):
              machine.succeed("systemctl kill -s KILL vdaemon-proxy.service || true")
              machine.succeed("timeout 20 su - alice -c 'nix-store -q --hash /run/current-system' || true")
          machine.wait_until_succeeds("systemctl is-active vdaemon-proxy-fallback.service", timeout=60)
          machine.fail("systemctl is-active vdaemon-proxy.socket")
          try:
              alice("nix-store -q --references /run/current-system")
          except Exception:
              diagnose()
              raise
          assert "Trusted: 0" in alice("nix store info 2>&1")
          # The documented restore.
          machine.succeed("systemctl reset-failed vdaemon-proxy.service vdaemon-proxy.socket && systemctl start vdaemon-proxy.socket")
          machine.wait_until_fails("systemctl is-active vdaemon-proxy-fallback.service", timeout=30)
          machine.succeed("systemctl is-active vdaemon-proxy.socket")
          before = ops()
          alice("nix-store -q --references /run/current-system")
          machine.wait_until_succeeds(f"test $(journalctl -u vdaemon-proxy.service -o cat | grep -c '\"event\":\"op\"') -gt {before}", timeout=30)
    '';
  }
