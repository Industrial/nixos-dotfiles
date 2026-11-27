# Muninn system configuration (work laptop)
# Acts as monitoring standby when mimir is down.
# No personal files here: it does not mount mimir's NFS (see filesystems.nix).
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix
  ];

  profiles.ai.enable = true;
  profiles.base.enable = true;
  profiles.communication.enable = true;
  # profiles.creative.enable = true;
  profiles.desktop.enable = true;
  profiles.development.enable = true;
  # profiles.gaming.enable = true;

  # vdeploy (Voltaic) deploys muninn (#437): the `vdeploy` role in common/fleet.nix puts it
  # in deploy mode; every switch is health-checked with vhealth and rolled back when
  # unhealthy. comin is gone. Rollback: `fleet deploy muninn --legacy` (deploy-rs).
  features.nix.vdeploy.enable = true;
  features.fleet.nix-remote-builder-server.enable = true;
  features.fleet.remote-access.enable = true;
  features.monitoring.grafana.enable = true;
  features.monitoring.homepage-dashboard.enable = true;
  features.monitoring.prometheus-exporter.enable = true;
  # vhealth (Voltaic, #437): the probes muninn's features declare (nix-daemon as the vhealth
  # user, sshd, node_exporter, ...), checked every minute into node_exporter; `vhealth
  # check`. vdeploy's deploy mode decides keep or roll back with it. Rollback: delete this line.
  features.nix.vhealth.enable = true;
  features.monitoring.prometheus.enable = true;
  features.nixos.graphics.amd.enable = true;

  # Anduril NixOS STIG V1R3, test-host. muninn is the fleet's STIG test host (ADR-0008): it
  # accounts for all 103 controls. The profile switches on base-safe's 68, configures 15
  # more, and excludes the rest in writing; the list and each reason are in
  # features/security/stig/profiles/test-host.nix. No other host enables it.
  #
  # Like mimir, two controls need a REBOOT, not just a switch: V-268092 (audit=1) and
  # V-268093 (audit_backlog_limit=65536) are kernel command line parameters. The report
  # renders them "Configured (pending reboot)" until muninn restarts.
  features.security.stig.profiles.test-host.enable = true;
  # /etc is the upstream overlay, with the host's stateful files carried in and out (GH-185;
  # gate: etc-overlay-live-switch-muninn). Rollback: lib.mkForce false copies the state back out.
  features.nixos.etc-overlay.enable = true;
}
