# Operator SSH for fleet push-deploy (deploy-rs).
#
# Every fleet host is an operator: the same authorizedKeys set is installed on
# all machines so any of them can `bin/fleet deploy` to the others.
#
# Add huginn/mimir pubkeys in follow-up commits (from each host:
#   cat ~/.ssh/id_ed25519.pub).
# Client: IdentitiesOnly so only the local fleet key is offered (avoids
# MaxAuthTries exhaustion and does not advertise unrelated agent identities).
{
  lib,
  settings,
  ...
}: let
  fleetHosts = "drakkar huginn mimir";

  # One Ed25519 pubkey per operator host. null = not yet enrolled.
  operatorPubKeys = {
    drakkar = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtviEPSAz5PlJ8K8mFzSQz/Y6WqzqrBA5PzXkhjZ2/y tom@drakkar";
    huginn = null;
    mimir = null;
  };

  enrolledKeys =
    lib.filter (k: k != null) (lib.attrValues operatorPubKeys);
in {
  users.users.${settings.username}.openssh.authorizedKeys.keys = enrolledKeys;

  programs.ssh.extraConfig = ''
    Host ${fleetHosts}
      User ${settings.username}
      IdentitiesOnly yes
      IdentityFile ~/.ssh/id_ed25519
      StrictHostKeyChecking accept-new
  '';
}
