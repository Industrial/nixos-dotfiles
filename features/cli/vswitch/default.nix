# vswitch is the local rebuild (rust/tools/vswitch, GH-241): it replaces nixos-rebuild and
# nh in cli-core, and bin/update/system switches through it. Binary: vswitch.
#
#   vswitch switch [--flake DIR] [--host NAME]   build (through vmon), vdiff against the
#                                                 running system, then vdeploy's apply:
#                                                 switch-to-configuration test, vhealth on
#                                                 the new generation's probes, keep (boot
#                                                 default) or roll back
#   vswitch boot | test | build | dry            nixos-rebuild's other verbs
#
# The activation runs elevated (sudo) in vdeploy's own transient unit, `vdeploy-apply`, so
# a local switch and the vdeploy agent never switch at once, and it shares vdeploy's ledger
# (/var/lib/vdeploy: bad marks, inflight.json, deploys.jsonl). A generation vswitch rolled
# back is refused by vdeploy too, and the other way round. On a host where vdeploy deploys,
# the next commit on main is still switched to by vdeploy: vswitch is for this host's
# experiments and console recovery, not a second deployer.
#
# The wrapper hands vswitch this host's absolute tool paths (sudo resets PATH, and the
# transient unit has systemd's), vmon when cli-core has it, and the probes user when
# vhealth is on (`vhealth`, as vdeploy's apply uses: restricted Nix daemons refuse
# `nobody`).
#
# Take-over rollback: `features.cli.vswitch.enable = lib.mkForce false;` on a host brings nh
# back (profiles/cli-core.nix), and bin/update/system falls back to nixos-rebuild.
{
  config,
  lib,
  pkgs,
  ...
}: let
  vswitch = pkgs.callPackage ../../../rust/tools/vswitch/default.nix {};
  vmon = pkgs.callPackage ../../../rust/tools/vmon/default.nix {};
  systemd = config.systemd.package;
  nix = config.nix.package;
  vmonOn = config.features.cli.vmon.enable or false;
  # features/nix/vhealth's static user: present exactly when the generations carry probes.
  vhealthOn = config.users.users ? vhealth;
  window = config.features.nix.vdeploy.healthWindow or "2m";
  flags =
    [
      "--nix"
      "${nix}/bin/nix"
      "--nix-env"
      "${nix}/bin/nix-env"
      "--nix-store"
      "${nix}/bin/nix-store"
      "--systemd-run"
      "${systemd}/bin/systemd-run"
      "--systemctl"
      "${systemd}/bin/systemctl"
      "--setpriv"
      "${pkgs.util-linux}/bin/setpriv"
      "--elevate"
      "/run/wrappers/bin/sudo"
      "--health-window"
      window
    ]
    ++ lib.optionals vmonOn ["--vmon" "${vmon}/bin/vmon"]
    ++ lib.optionals vhealthOn ["--health-as" "vhealth"];
  wrapped = pkgs.writeShellScriptBin "vswitch" ''
    exec ${vswitch}/bin/vswitch ${lib.escapeShellArgs flags} "$@"
  '';
in {
  environment.systemPackages = [wrapped];
}
