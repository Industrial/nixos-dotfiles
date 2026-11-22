# vdaemon-proxy switched in and out of a RUNNING system, as comin or
# `nixos-rebuild switch` does on a host, where the fresh boot of ./test.nix never goes.
#
#   nix build .#checks.x86_64-linux.vdaemon-proxy-live-switch-vm
#
# The machine boots without the feature (but with common/nix-daemon-listen.nix, which
# every host carries through the catalog). A slow build is left running, the
# `proxy` specialisation is activated, and an untrusted user's nix-store -q must work
# through the proxy; then the base is activated again and it must work directly. The
# slow build must finish across both switches.
{pkgs}: let
  inherit (pkgs) busybox;
  # The sandbox has no PATH: sleep by its full path, or the build is instant.
  slow = pkgs.writeText "slow.nix" ''
    let bb = builtins.storePath ${busybox}; in
    derivation {
      name = "vdaemon-proxy-slow";
      system = builtins.currentSystem;
      builder = "''${bb}/bin/sh";
      args = ["-c" "''${bb}/bin/sleep 25 && echo survived-the-switches > $out"];
    }
  '';
  # A build that connects THROUGH the proxy and outlasts its restart (12 s, inside the 25 s
  # drain): the restart must not cut it.
  through = pkgs.writeText "through.nix" ''
    let bb = builtins.storePath ${busybox}; in
    derivation {
      name = "vdaemon-proxy-through";
      system = builtins.currentSystem;
      builder = "''${bb}/bin/sh";
      args = ["-c" "''${bb}/bin/sleep 12 && echo drained-not-dropped > $out"];
    }
  '';
in
  pkgs.testers.runNixOSTest {
    name = "vdaemon-proxy-live-switch";

    nodes.machine = {
      imports = [../../../common/nix-daemon-listen.nix];
      nix.settings.experimental-features = ["nix-command"];
      system.extraDependencies = [busybox];
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
      };
      virtualisation.memorySize = 1024;
      specialisation.proxy.configuration.imports = [./default.nix];
    };

    testScript = {nodes, ...}: let
      base = nodes.machine.system.build.toplevel;
    in ''
      def alice(cmd):
          return machine.succeed(f"timeout 60 su - alice -c '{cmd}'")

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("nix-daemon-listen.service")

      with subtest("without the feature, Nix is direct"):
          alice("nix-store -q --hash /run/current-system")
          machine.fail("systemctl is-active vdaemon-proxy.socket")

      # A build in flight across both switches: it must not be killed.
      machine.succeed("su - alice -c 'nohup nix-build --no-out-link ${slow} > /tmp/slow.out 2>&1 &'")
      machine.wait_until_succeeds("pgrep -f 'bin/sleep 25'", timeout=30)

      with subtest("a live switch into the feature hands the socket to the proxy"):
          machine.succeed("${base}/specialisation/proxy/bin/switch-to-configuration test")
          machine.succeed("systemctl is-active vdaemon-proxy.socket nix-daemon-listen.service")
          machine.succeed("test -S /nix/var/nix/daemon-socket-upstream/socket")
          alice("nix-store -q --hash /run/current-system")
          machine.wait_until_succeeds("journalctl -u vdaemon-proxy.service -o cat | grep -F '\"uid\":1000'", timeout=30)

      with subtest("a proxy restart drains: a build connected through it finishes, a new client is queued, the exit is 0"):
          # #224: a vdeploy switch restarts the proxy while builds are connected through it.
          machine.succeed("su - alice -c 'nohup nix-build --no-out-link ${through} > /tmp/through.out 2>&1 &'")
          # [b]: the pattern must not match the waiting shell's own command line.
          machine.wait_until_succeeds("pgrep -f '[b]in/sleep 12'", timeout=30)
          machine.succeed("systemctl restart --no-block vdaemon-proxy.service")
          machine.wait_until_succeeds("journalctl -u vdaemon-proxy.service -o cat | grep -q 'no longer accepting; draining 1 connection'", timeout=30)
          # #211's failure mode: a client that connects while the old proxy drains is queued
          # by the socket and served by the next proxy, not refused.
          alice("nix-store -q --hash /run/current-system")
          machine.wait_until_succeeds("grep -q '^/nix/store/.*-vdaemon-proxy-through$' /tmp/through.out", timeout=120)
          out = machine.succeed("tail -n 1 /tmp/through.out").strip()
          assert machine.succeed(f"cat {out}").strip() == "drained-not-dropped"
          machine.wait_for_unit("vdaemon-proxy.socket")
          # The old proxy ended by its own return, not by the signal: exit 0, no status=143.
          machine.fail("journalctl -u vdaemon-proxy.service -o cat | grep -E 'status=143|code=killed'")
          alice("nix-store -q --hash /run/current-system")

      with subtest("a live switch back out returns the socket to nix-daemon"):
          machine.succeed("${base}/bin/switch-to-configuration test")
          machine.fail("systemctl is-active vdaemon-proxy.socket")
          machine.succeed("systemctl is-active nix-daemon-listen.service")
          alice("nix-store -q --hash /run/current-system")
          # Both rebinds are done and the build is still at it: neither killed it.
          machine.succeed("pgrep -f 'bin/sleep 25'")

      with subtest("the build in flight survived both switches"):
          machine.wait_until_succeeds("grep -q '^/nix/store/.*-vdaemon-proxy-slow$' /tmp/slow.out", timeout=120)
          out = machine.succeed("tail -n 1 /tmp/slow.out").strip()
          assert machine.succeed(f"cat {out}").strip() == "survived-the-switches"
    '';
  }
