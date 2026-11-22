# NixOS VM test for GH-185, the measurement: drakkar's /etc, written by setup-etc.pl
# (stock) or mounted as the upstream `system.etc.overlay` (erofs metadata image + mutable
# overlayfs upper). The node: ./node.nix. The live switch between them, with state
# carried across: ./test-live-switch.nix.
#
# Measured, both variants:
#   - the activation `/etc` step, timed in-band (a wrapper around the `etc` activation
#     snippet writes `gh185-etc-step ns=<n>` to /dev/kmsg, so it lands in the journal,
#     and to /run/gh185-etc-step.log), at boot and for every switch;
#   - the whole `switch-to-configuration test` wall time, base <-> `alt` specialisation
#     (the two differ in one /etc file, so the overlay variant really remounts);
#   - what writes to /etc at runtime: the overlay's upperdir (`/.rw-etc/upper`), or under
#     setup-etc.pl the non-symlink files in /etc that /etc/.clean does not own.
#
#   nix build .#checks.x86_64-linux.etc-overlay-stock   (setup-etc.pl)
#   nix build .#checks.x86_64-linux.etc-overlay-on      (system.etc.overlay, mutable)
{
  pkgs,
  inputs,
  variant ? "stock",
  rounds ? 5,
}: let
  overlay = variant == "on";
  inherit (inputs.nixpkgs) lib;
  drakkar = import ./node.nix {inherit inputs;};

  # Time the `etc` activation snippet itself, whichever implementation it is.
  timing = {
    system.activationScripts.etc.text = lib.mkMerge [
      (lib.mkBefore ''
        _gh185_t0=$(date +%s%N)
      '')
      (lib.mkAfter ''
        _gh185_ns=$(( $(date +%s%N) - _gh185_t0 ))
        echo "gh185-etc-step ns=$_gh185_ns stage1=''${IN_NIXOS_SYSTEMD_STAGE1:-0}" >> /run/gh185-etc-step.log
        echo "<5>gh185-etc-step ns=$_gh185_ns" > /dev/kmsg || true
      '')
    ];
  };

  # Files in /etc that are not symlinks and that /etc/.clean (setup-etc.pl's copies) does
  # not own: what something other than setup-etc.pl wrote.
  statefulEtc = pkgs.writeShellScript "gh185-stateful-etc" ''
    cd /etc
    find . -xdev -mindepth 1 ! -type l ! -type d -printf '%P\n' | sort > /tmp/gh185-files
    sort /etc/.clean > /tmp/gh185-clean
    comm -23 /tmp/gh185-files /tmp/gh185-clean | while read -r f; do stat -c '%F %a %U:%G %n' "$f"; done
  '';
  upperEtc = pkgs.writeShellScript "gh185-upper-etc" ''
    cd /.rw-etc/upper && find . -mindepth 1 -printf '%y %m %u:%g %P\n' | sort
  '';
in
  pkgs.testers.runNixOSTest {
    name = "etc-overlay-${variant}";
    inherit (drakkar) node;

    nodes.machine = {
      imports = [drakkar.module timing];
      system.etc.overlay.enable = overlay;
      specialisation.alt.configuration.environment.etc."gh185-marker".text = "alt\n";
    };

    testScript = ''
      import time

      def etc_steps():
          out = machine.succeed("cat /run/gh185-etc-step.log || true")
          return [int(l.split("ns=")[1].split()[0]) for l in out.splitlines() if "ns=" in l]

      def switch(target):
          before = len(etc_steps())
          t0 = time.monotonic()
          rc, out = machine.execute(f"{target}/bin/switch-to-configuration test 2>&1")
          wall = time.monotonic() - t0
          print(f"GH185 switch to {target} rc={rc}\n{out[-3000:]}")
          return wall, etc_steps()[before:], rc

      machine.wait_for_unit("multi-user.target")

      with subtest("boot: the /etc step and the initrd /etc units"):
          print("GH185 boot etc steps (ns):", etc_steps())
          print(machine.succeed("journalctl -b -o short-monotonic --no-pager | grep -E 'gh185-etc-step|setting up /etc|remounting /etc|sysroot-etc|nixos-etc-metadata|rw-etc|find-etc' || true"))
          print(machine.succeed("findmnt /etc || true"))
          print(machine.succeed("systemd-analyze || true"))
          print("GH185 failed units at boot:\n" + machine.succeed("systemctl --failed --no-legend --plain || true"))

      base = machine.succeed("readlink -f /run/current-system").strip()
      alt = base + "/specialisation/alt"

      with subtest("switch: base <-> alt, ${toString rounds} rounds"):
          walls, steps, rcs = [], [], []
          for i in range(${toString rounds}):
              for target in (alt, base):
                  w, s, rc = switch(target)
                  walls.append(w)
                  steps.extend(s)
                  rcs.append(rc)
          steps_ms = sorted(n / 1e6 for n in steps)
          walls_s = sorted(walls)
          print("GH185 switch rcs:", rcs)
          print("GH185 switch etc step ms:", ["%.1f" % x for x in steps_ms])
          print("GH185 switch wall s:", ["%.2f" % x for x in walls_s])
          print("GH185 median etc step ms: %.1f  median wall s: %.2f" % (steps_ms[len(steps_ms) // 2], walls_s[len(walls_s) // 2]))
          print(machine.succeed("journalctl -b -o short-monotonic --no-pager -k | grep gh185-etc-step | tail -n 20"))

      with subtest("the marker follows the generation"):
          switch(alt)
          machine.succeed("grep -qx alt /etc/gh185-marker")
          switch(base)
          machine.fail("test -e /etc/gh185-marker")

      with subtest("runtime writers to /etc"):
          # Let the desktop and network services settle, then exercise the usual writers.
          machine.sleep(30)
          machine.succeed("echo 'tom:gh185-changed' | chpasswd")
          machine.execute("nmcli connection add type ethernet ifname gh185 con-name gh185")
          print("GH185 failed units after settle:\n" + machine.succeed("systemctl --failed --no-legend --plain || true"))
          print("GH185 ${
        if overlay
        then "overlay upper"
        else "stateful /etc"
      }:\n" + machine.succeed("${
        if overlay
        then upperEtc
        else statefulEtc
      }"))
    '';
  }
