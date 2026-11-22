# NixOS VM test for GH-185: drakkar's /etc, written by setup-etc.pl (stock) or mounted as
# the upstream `system.etc.overlay` (erofs metadata image + mutable overlayfs upper).
#
# The node is drakkar's own hosts/drakkar/configuration.nix (every profile and feature it
# enables, plus hardware.nix and filesystems.nix) with only disko.nix disabled: its LUKS
# + btrfs layout cannot exist in a VM, and qemu-vm supplies the root filesystem instead.
#
# Measured, both variants:
#   - the activation `/etc` step, timed in-band (a wrapper around the `etc` activation
#     snippet writes `gh185-etc-step ns=<n>` to /dev/kmsg, so it lands in the journal,
#     and to /run/gh185-etc-step.log), at boot and for every switch;
#   - the whole `switch-to-configuration test` wall time, base <-> `alt` specialisation
#     (the two differ in one /etc file, so the overlay variant really remounts);
#   - what writes to /etc at runtime: the overlay's upperdir (`/.rw-etc/upper`), or under
#     setup-etc.pl the non-symlink files in /etc that /etc/.clean does not own.
# Stock only: a live switch into an `overlay` specialisation, to show what the switch from
# setup-etc.pl to the overlay hides (the old /etc's stateful files are not migrated).
#
#   nix build .#checks.x86_64-linux.etc-overlay-stock   (setup-etc.pl)
#   nix build .#checks.x86_64-linux.etc-overlay-on      (system.etc.overlay, mutable)
{
  pkgs,
  inputs,
  overlay ? false,
  rounds ? 5,
}: let
  inherit (inputs.nixpkgs) lib;
  inherit
    (import ../../../common/settings.nix {
      hostname = "drakkar";
      useremail = "tom.wieland@gmail.com";
    })
    settings
    ;
  features = import ../../../lib/features.nix {inherit lib;};

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
  stateSums = pkgs.writeShellScript "gh185-state-sums" ''
    cd /etc
    for f in machine-id ssh/ssh_host_ed25519_key.pub NetworkManager/system-connections/gh185.nmconnection adjtime; do
      printf '%s ' "$f"
      if [ -e "$f" ]; then sha256sum < "$f"; else echo absent; fi
    done
    grep '^tom:' /etc/shadow | cut -c1-24 || echo 'tom: absent from /etc/shadow'
  '';
in
  pkgs.testers.runNixOSTest {
    name = "etc-overlay-${
      if overlay
      then "on"
      else "stock"
    }";

    node = {
      pkgsReadOnly = false;
      specialArgs = {inherit inputs settings;};
    };

    nodes.machine = {...}: {
      imports =
        features.modules
        ++ [
          {system.configurationRevision = "gh-185-test";}
          ../../../hosts/drakkar/configuration.nix
          timing
        ];
      disabledModules = [../../../hosts/drakkar/disko.nix];

      # VM-only adjustments, the minimum for drakkar's config to coexist with qemu-vm.
      services.timesyncd.enable = lib.mkForce false;
      systemd.settings.Manager.DefaultTimeoutStartSec = lib.mkForce 300;

      system.etc.overlay.enable = overlay;

      specialisation =
        {
          alt.configuration.environment.etc."gh185-marker".text = "alt\n";
        }
        // lib.optionalAttrs (!overlay) {
          overlay.configuration.system.etc.overlay.enable = lib.mkForce true;
        };

      virtualisation = {
        cores = 4;
        memorySize = 6144;
        diskSize = 8192;
      };
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
          ${
        if overlay
        then ''
          print("GH185 overlay upper:\n" + machine.succeed("${upperEtc}"))
          print(machine.succeed("findmnt -o TARGET,FSTYPE,OPTIONS /etc"))
        ''
        else ''
          print("GH185 stateful /etc:\n" + machine.succeed("${statefulEtc}"))
        ''
      }

      ${lib.optionalString (!overlay) ''
        with subtest("live switch from setup-etc.pl to the overlay: what the old /etc held"):
            before = machine.succeed("${stateSums}")
            w, s, rc = switch(base + "/specialisation/overlay")
            print("GH185 stock->overlay switch rc=%d wall s: %.2f etc step ms: %s" % (rc, w, [n / 1e6 for n in s]))
            print(machine.succeed("findmnt -o TARGET,FSTYPE,OPTIONS /etc || true"))
            after = machine.succeed("${stateSums}")
            print("GH185 before overlay:\n" + before)
            print("GH185 after overlay:\n" + after)
      ''}
    '';
  }
