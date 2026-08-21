# Operator SSH for fleet push-deploy (deploy-rs).
#
# Every fleet host is an operator: the same authorizedKeys set is installed on
# all machines so any of them can `bin/fleet deploy` to the others.
#
# Enrolled 2026-08-21 from each host (~/.ssh/id_ed25519.pub).
# Client: IdentitiesOnly so only the local fleet key is offered (avoids
# MaxAuthTries exhaustion and does not advertise unrelated agent identities).
#
# Privilege: SSH is key-only; deploy-rs activates as root via passwordless sudo
# for the operator (interactiveSudo = false in flake deploy profile).
{
  lib,
  settings,
  ...
}: let
  fleetHosts = "drakkar huginn mimir";

  # One Ed25519 pubkey per operator host. null = not yet enrolled.
  operatorPubKeys = {
    drakkar = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtviEPSAz5PlJ8K8mFzSQz/Y6WqzqrBA5PzXkhjZ2/y tom@drakkar";
    huginn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvaH/4XK0nQr6vo1ZZYpk0SIv0LvtJm6yxWMv7U2/Gb tom@huginn";
    mimir = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHaaBOy2a1WnlGy5B6WwEmVlf7s5VUgVIbsjdGZrsmK+ tom@mimir";
  };

  enrolledKeys =
    lib.filter (k: k != null) (lib.attrValues operatorPubKeys);
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
