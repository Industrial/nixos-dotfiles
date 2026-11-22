# NixOS VM test for features/nixos/etc-overlay (GH-185), the gate: drakkar's own config
# (./node.nix) boots WITHOUT the feature, with state planted the way drakkar has it, then
#
#   1. switches LIVE into the feature (switch-to-configuration, no reboot),
#   2. changes state under the overlay (a new NM connection, a deleted file),
#   3. switches LIVE out again (the rollback: the feature off),
#   4. boots cold INTO the feature (the overlay generation's own VM, on the same disk:
#      the first boot after `switch-to-configuration boot`), changes state again,
#   5. boots cold OUT of it (back to the generation without the feature),
#
# and after every step asserts: the machine-id and every ssh host key unchanged, the
# NetworkManager connections and the planted files (adjtime, security/opasswd,
# wpa_supplicant/imperative.conf, mullvad-vpn/*) present with their content, mode and
# owner, tom's shadow entry unchanged and his password accepted (and a wrong one refused),
# polkit and accounts-daemon running with no 217/USER since the step, and vhealth, run as
# the vhealth user, reporting no probe down that was up before.
#
# Two evaluations of drakkar: the node, and the node extended with the feature on
# (extendModules), whose toplevel is the live switch target and whose VM is the cold boot.
#
#   nix build .#checks.x86_64-linux.etc-overlay-live-switch
{
  pkgs,
  inputs,
}: let
  inherit (inputs.nixpkgs) lib;
  drakkar = import ./node.nix {inherit inputs;};

  # Every piece of state the test follows, one line each, compared as a whole.
  state = pkgs.writeShellScript "gh185-state" ''
    cd /etc
    echo "machine-id $(cat machine-id)"
    for k in ssh/ssh_host_*_key.pub; do echo "$k $(ssh-keygen -lf "$k" | cut -d' ' -f2)"; done
    for f in adjtime security/opasswd wpa_supplicant/imperative.conf mullvad-vpn/*.json NetworkManager/system-connections/*; do
      [ -e "$f" ] && echo "$f $(stat -c '%a %U:%G' "$f") $(sha256sum < "$f" | cut -c1-16)"
    done
    echo "shadow $(grep '^tom:' shadow | cut -d: -f1-2)"
    echo "passwd $(grep '^tom:' passwd)"
  '';

  plant = pkgs.writeShellScript "gh185-plant" ''
    set -e
    cd /etc
    printf '0.000000 1795300000 0.000000\n1795300000\nUTC\n' > adjtime
    mkdir -p security wpa_supplicant mullvad-vpn
    printf 'tom:1000:1:$y$j9T$gh185$old\n' > security/opasswd
    chmod 600 security/opasswd
    printf 'network={\n  ssid="gh185"\n}\n' > wpa_supplicant/imperative.conf
    chmod 664 wpa_supplicant/imperative.conf
    chown nobody:nogroup wpa_supplicant/imperative.conf
    printf '{"gh185":"settings"}\n' > mullvad-vpn/settings.json
    printf '{"gh185":"device"}\n' > mullvad-vpn/device.json
    printf '{"gh185":"history"}\n' > mullvad-vpn/account-history.json
    chmod 600 mullvad-vpn/device.json mullvad-vpn/account-history.json
    echo 'tom:gh185-pw' | chpasswd
  '';

  password = pkgs.writeShellScript "gh185-password" ''
    printf '%s\0' "$1" | /run/wrappers/bin/unix_chkpwd tom nonull
  '';
in
  pkgs.testers.runNixOSTest {
    name = "etc-overlay-live-switch";
    inherit (drakkar) node;

    nodes.machine = {
      config,
      extendModules,
      ...
    }: {
      imports = [drakkar.module];
      options.gh185 = {
        withOverlay = lib.mkOption {
          type = lib.types.raw;
          description = "This node with features.nixos.etc-overlay on.";
        };
        isOverlayVariant = lib.mkEnableOption "the extension of the node with the feature on";
      };
      config = {
        # A test node only gets switch-to-configuration with specialisations
        # (nixos/lib/testing/nixos-test-base.nix); this one switches without any.
        system.switch.enable = true;
        gh185.withOverlay = extendModules {
          modules = [
            {
              features.nixos.etc-overlay.enable = true;
              gh185.isOverlayVariant = true;
            }
          ];
        };
        # The test script's string context is dropped, so the overlay generation (the live
        # switch target) and its VM (the cold boot) reach the VM's store this way. Only from
        # the node itself, or the extension would depend on its own extension.
        system.extraDependencies = lib.optional (!config.gh185.isOverlayVariant) config.gh185.withOverlay.config.system.build.vm;
      };
    };

    testScript = {nodes, ...}: let
      overlay = nodes.machine.gh185.withOverlay.config;
    in ''
      import json
      import time

      overlay_system = "${overlay.system.build.toplevel}"
      overlay_vm = "${overlay.system.build.vm}/bin/run-drakkar-vm"

      def cursor(m):
          return m.succeed("journalctl -n0 --show-cursor --no-pager | sed -n 's/^-- cursor: //p'").strip()

      def etc_fstype(m):
          return m.succeed("findmnt -n -o FSTYPE --mountpoint /etc || echo plain").strip()

      def vhealth(m):
          deadline = time.monotonic() + 90
          while True:
              _, out = m.execute("runuser -u vhealth -- /run/current-system/sw/bin/vhealth check --json")
              try:
                  r = json.loads(out.strip().splitlines()[-1])
                  return r["healthy"], {p["name"]: p["up"] for p in r["probes"]}
              except Exception:
                  if time.monotonic() > deadline:
                      raise Exception(f"vhealth check gave no report:\n{out}")
                  time.sleep(3)

      def healthy(m, label, since, vh_base):
          m.succeed("systemctl start polkit.service accounts-daemon.service")
          m.succeed("systemctl is-active polkit.service accounts-daemon.service")
          window = f"--after-cursor='{since}'" if since else "-b"
          bad = m.succeed(f"journalctl --no-pager -o cat {window} | grep -c 'status=217/USER' || true").strip()
          failed = set(m.succeed("systemctl --failed --no-legend --plain | cut -d' ' -f1").split())
          assert failed <= allowed_failed, f"[{label}] failed units: {sorted(failed - allowed_failed)}"
          assert bad == "0", f"[{label}] {bad} unit(s) exited 217/USER"
          m.succeed("su - tom -c true")
          m.succeed("runuser -u tom -- ${password} gh185-pw")
          m.fail("runuser -u tom -- ${password} wrong-password")
          # Probes settle after a switch: wait for every probe that was up to be up again.
          deadline = time.monotonic() + 120
          while True:
              ok, probes = vhealth(m)
              lost = sorted(n for n, up in vh_base.items() if up and not probes.get(n, False))
              if not lost:
                  break
              if time.monotonic() > deadline:
                  raise Exception(f"[{label}] vhealth probes down that were up: {lost}")
              time.sleep(5)
          print(f"GH185 [{label}] vhealth healthy={ok} probes={probes}")

      def same_state(m, label, expected):
          now = m.succeed("${state}")
          print(f"GH185 [{label}] state:\n{now}")
          assert now == expected, f"[{label}] state changed:\nexpected:\n{expected}\nnow:\n{now}"

      def switch(target, label):
          rc, out = machine.execute(f"{target}/bin/switch-to-configuration test 2>&1")
          print(f"GH185 [{label}] switch rc={rc}\n{out[-4000:]}")
          # rc 4 is a unit that failed to (re)start; vcache has no tailnet in a VM. healthy()
          # checks the failed units against the baseline.
          assert "FAILED to carry" not in out, out

      machine.wait_for_unit("multi-user.target")
      base_system = machine.succeed("readlink -f /run/current-system").strip()

      with subtest("boot without the feature, plant drakkar's state"):
          assert etc_fstype(machine) == "plain"
          machine.wait_for_unit("NetworkManager.service")
          machine.wait_for_file("/etc/ssh/ssh_host_ed25519_key.pub")
          machine.succeed("${plant}")
          machine.succeed("nmcli connection add type ethernet ifname gh185 con-name 'Wired connection 1'")
          machine.wait_for_file("'/etc/NetworkManager/system-connections/Wired connection 1.nmconnection'")
          planted = machine.succeed("${state}")
          print(f"GH185 planted:\n{planted}")
          _, vh_base = vhealth(machine)
          print(f"GH185 vhealth baseline: {vh_base}")
          # What already fails here without the feature (vcache: no tailnet in a VM).
          allowed_failed = set(machine.succeed("systemctl --failed --no-legend --plain | cut -d' ' -f1").split()) | {"vcache.service"}
          print(f"GH185 failed at baseline: {sorted(allowed_failed)}")

      with subtest("live switch INTO the overlay keeps the state"):
          since = cursor(machine)
          switch(overlay_system, "live in")
          assert etc_fstype(machine) == "overlay"
          same_state(machine, "live in", planted)
          healthy(machine, "live in", since, vh_base)
          machine.succeed("test -e /.rw-etc/.seeded")
          # setup-etc.pl's link to its generation's tree is not carried: the overlay mounts
          # the tree itself and has no /etc/static, so a carried one would be stale.
          machine.fail("test -e /etc/static || test -L /etc/static")

      with subtest("change state under the overlay"):
          machine.succeed("nmcli connection add type ethernet ifname gh185b con-name gh185-overlay")
          machine.wait_for_file("/etc/NetworkManager/system-connections/gh185-overlay.nmconnection")
          machine.succeed("rm /etc/mullvad-vpn/account-history.json")
          changed = machine.succeed("${state}")
          assert "gh185-overlay.nmconnection" in changed and "account-history" not in changed, changed

      with subtest("live switch OUT of the overlay keeps the state"):
          since = cursor(machine)
          switch(base_system, "live out")
          assert etc_fstype(machine) == "plain"
          same_state(machine, "live out", changed)
          healthy(machine, "live out", since, vh_base)
          machine.succeed("test -e /.rw-etc/.exited")

      with subtest("cold boot INTO the overlay keeps the state"):
          machine.shutdown()
          # The driver does not track a machine from create_machine: on a failure here it
          # would keep running and hold the build open, so it is killed on the way out.
          cold = create_machine(overlay_vm, name="machine", keep_machine_state=True)
          try:
              cold.start()
              cold.wait_for_unit("multi-user.target")
              assert etc_fstype(cold) == "overlay"
              print(cold.succeed("journalctl -b -o cat --no-pager | grep 'etc-overlay:' || true"))
              cold.succeed("ls -d /.rw-etc.stale-*")
              same_state(cold, "cold in", changed)
              healthy(cold, "cold in", "", vh_base)
              cold.succeed("nmcli connection add type ethernet ifname gh185c con-name gh185-cold")
              cold.wait_for_file("/etc/NetworkManager/system-connections/gh185-cold.nmconnection")
              changed_cold = cold.succeed("${state}")
              cold.shutdown()
          except BaseException:
              cold.crash()
              raise

      with subtest("cold boot OUT of the overlay keeps the state"):
          machine.start()
          machine.wait_for_unit("multi-user.target")
          assert etc_fstype(machine) == "plain"
          same_state(machine, "cold out", changed_cold)
          healthy(machine, "cold out", "", vh_base)
          machine.succeed("test -e /.rw-etc/.exited")
    '';
  }
