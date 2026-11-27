# NixOS VM test: logging on to the STIG test host (muninn) under its own configuration.
#
# muninn is a real laptop, and what is merged to main reaches it unattended (ADR-0008). The
# test-host profile puts pam_faillock into its logon stacks (V-268081) and pam_pwquality into
# its password stacks (V-268170). tests/vm/pam.nix proves both controls on a minimal machine;
# this proves them where they are deployed, because the stacks differ: muninn's `login`
# service has an early pam_unix and gnome-keyring in front of pam_unix proper, and its
# graphical logon and lock screen (`gdm-password`) reach `login` as a substack, where
# `[default=die]` ends the substack and not the whole stack.
#
# The node is the host's configuration.nix through ../../../nixos/etc-overlay/node.nix: every
# profile and feature the host enables, with only disko left out. Added for the test: a key
# for the operator (the fleet's enrolled keys have no private half here) and pamtester.
#
# What it asserts, in the order an operator would meet it:
#   1. the operator's password is accepted at a console and through gdm-password;
#   2. two wrong passwords and then the right one leave no tally (a mistyped lock screen
#      does not creep toward a lock);
#   3. three wrong passwords lock the account: the right password is then refused, through
#      gdm-password and at the console;
#   4. THE WAY BACK IN: while locked, the operator logs in over SSH with a key, sudo needs
#      no password, and `sudo faillock --user <operator> --reset` releases the account;
#   5. `passwd` as the operator refuses a weak password and accepts a compliant one.
#
#   nix build .#checks.x86_64-linux.stig-test-host-logon
{
  pkgs,
  inputs,
  hostname ? "muninn",
}: let
  host = import ../../../nixos/etc-overlay/node.nix {inherit inputs hostname;};
  user = host.settings.username;
  sshKeys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;

  # Satisfies the policy under test, so setting it is not itself a finding.
  password = "aB3$fG6&jK9)mN2!qR";
  newPassword = "9vK#mQ2$xLp7!Wz@4Ns";
in
  pkgs.testers.runNixOSTest {
    name = "stig-test-host-logon";
    inherit (host) node;

    nodes.machine = {pkgs, ...}: {
      imports = [host.module];
      users.users.${user}.openssh.authorizedKeys.keys = [sshKeys.snakeOilPublicKey];
      environment.systemPackages = [pkgs.pamtester];
    };

    testScript = {nodes, ...}: let
      cfg = nodes.machine;
    in ''
      ${import ./vm/console.nix}

      USER = "${user}"
      PASSWORD = "${password}"
      key = "/root/operator-key"
      ssh = (
          f"ssh -n -i {key} -o BatchMode=yes -o StrictHostKeyChecking=no "
          f"-o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes {USER}@localhost"
      )


      def pam(service, password):
          """Authenticate through a PAM service, account phase included, as GDM does."""
          return machine.execute(
              f"printf '%s\\n' '{password}' | pamtester {service} {USER} authenticate acct_mgmt 2>&1"
          )


      def pam_accepts(service, password):
          status, out = pam(service, password)
          assert status == 0, f"{service} refused the password:\n{out}"


      def pam_refuses(service, password):
          status, out = pam(service, password)
          assert status != 0, f"{service} accepted the password:\n{out}"


      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("sshd.service")

      with subtest("this is the test host, carrying both controls"):
          assert "${cfg.security.stig.profile}" == "test-host"
          carried = ${builtins.toJSON cfg.security.stig.implemented}
          assert "V-268081" in carried and "V-268170" in carried, carried
          # The graphical logon reaches pam_faillock only through the login service.
          gdm = machine.succeed("cat /etc/pam.d/gdm-password")
          assert re.search(r"(?m)^auth\s+substack\s+login\b", gdm), gdm
          assert re.search(r"(?m)^account\s+include\s+login\b", gdm), gdm
          print(machine.succeed("grep -E '^(auth|account)' /etc/pam.d/login /etc/pam.d/sshd"))
          # SSH takes keys only, and the operator's sudo asks for nothing: the way back in.
          sshd = machine.succeed("sshd -T")
          assert re.search(r"(?mi)^passwordauthentication no\s*$", sshd), sshd
          assert re.search(r"(?mi)^kbdinteractiveauthentication no\s*$", sshd), sshd
          machine.succeed(f"install -m 600 ${sshKeys.snakeOilPrivateKey} {key}")
          # The operator's password, as the operator would have set it on the real machine.
          machine.succeed(f"echo '{USER}:{PASSWORD}' | chpasswd")

      with subtest("the right password is accepted"):
          accepted(2, USER, PASSWORD)
          pam_accepts("gdm-password", PASSWORD)
          pam_accepts("login", PASSWORD)
          assert failures(USER) == 0

      with subtest("two mistakes and a success leave no tally"):
          pam_refuses("gdm-password", "wrong-password-1")
          pam_refuses("gdm-password", "wrong-password-2")
          assert failures(USER) == 2, machine.succeed(f"faillock --user {USER}")
          pam_accepts("gdm-password", PASSWORD)
          assert failures(USER) == 0, machine.succeed(f"faillock --user {USER}")

      with subtest("three wrong passwords lock the account"):
          for attempt in range(1, 4):
              pam_refuses("gdm-password", f"wrong-password-{attempt}")
              assert failures(USER) == attempt, machine.succeed(f"faillock --user {USER}")
          # The right password, refused: at the greeter and lock screen, and at a console.
          pam_refuses("gdm-password", PASSWORD)
          pam_refuses("login", PASSWORD)
          refused(3, USER, PASSWORD)
          print(machine.succeed(f"faillock --user {USER}"))

      with subtest("locked, the operator still gets in over SSH and releases the account"):
          assert machine.succeed(f"{ssh} id -un").strip() == USER
          # The key logon neither needed the lock gone nor removed it.
          assert failures(USER) >= 3, machine.succeed(f"faillock --user {USER}")
          pam_refuses("gdm-password", PASSWORD)
          # Passwordless sudo, as the deployer uses it, and the documented release.
          assert machine.succeed(f"{ssh} sudo -n id -un").strip() == "root"
          machine.succeed(f"{ssh} sudo -n faillock --user {USER} --reset")
          assert failures(USER) == 0
          pam_accepts("gdm-password", PASSWORD)
          accepted(3, USER, PASSWORD)

      with subtest("passwd refuses a weak password and takes a compliant one"):
          before = machine.succeed(f"getent shadow {USER}")
          status, out = machine.execute(
              f"printf '%s\\n' '{PASSWORD}' 'xQ7!pL2@' 'xQ7!pL2@' 'xQ7!pL2@' 'xQ7!pL2@' | su {USER} -c passwd 2>&1"
          )
          print(out)
          assert status != 0 and "BAD PASSWORD" in out, f"passwd took a short password:\n{out}"
          assert machine.succeed(f"getent shadow {USER}") == before
          machine.succeed(
              f"printf '%s\\n' '{PASSWORD}' '${newPassword}' '${newPassword}' | su {USER} -c passwd 2>&1"
          )
          assert machine.succeed(f"getent shadow {USER}") != before
          pam_accepts("gdm-password", "${newPassword}")
          pam_refuses("gdm-password", PASSWORD)
    '';
  }
