# Operator SSH for fleet push-deploy (deploy-rs).
#
# Every fleet host is an operator: the same authorizedKeys set is installed on
# all machines so any of them can `bin/fleet deploy` to the others.
#
# Enrolled 2026-08-21 from each host (~/.ssh/id_ed25519.pub); muninn 2026-10-26.
# Client: IdentitiesOnly so only the local fleet key is offered (avoids
# MaxAuthTries exhaustion and does not advertise unrelated agent identities).
#
# Privilege: SSH is key-only; deploy-rs activates as root via passwordless sudo
# for the operator (interactiveSudo = false in flake deploy profile).
#
# Hosts and their pubkeys (operatorKey) live in common/fleet.nix.
{
  lib,
  settings,
  ...
}: let
  fleet = import ../../common/fleet.nix;
  fleetHosts = lib.concatStringsSep " " fleet.names;
  enrolledKeys = fleet.operatorKeys;
in {
  users.users.${settings.username}.openssh.authorizedKeys.keys = enrolledKeys;

  # deploy-rs runs activation through sudo; SSH key already gates who can connect.
  security.sudo.extraRules = [
    {
      users = [settings.username];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  programs.ssh.extraConfig = ''
    Host ${fleetHosts}
      User ${settings.username}
      IdentitiesOnly yes
      IdentityFile ~/.ssh/id_ed25519
      StrictHostKeyChecking accept-new
  '';
}
