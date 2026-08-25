# FlexGet automates downloading from RSS/torznab sources. Port = 5050 (web UI).
#
# Uses the native services.flexget module; the YAML below is embedded into
# the Nix store at eval time and installed by the unit's ExecStartPre, so
# the repo stays the single source of truth with no host-clone dependency.
{pkgs, lib, ...}: let
  directoryPath = "/data/services/flexget";
  # nixpkgs' flexget omits the 'cryptography' dependency that upstream's
  # utils/waf module imports during daemon startup (crashes with
  # ModuleNotFoundError before serving). Add it via an override.
  flexgetFixed = pkgs.flexget.overridePythonAttrs (old: let
    py = pkgs.python3;
    webui = pkgs.callPackage ./webui.nix {};
  in {
    dependencies = (old.dependencies or []) ++ [pkgs.python3Packages.cryptography];
    # nixpkgs builds from the GitHub tarball where ui/v2/dist is only a
    # "build it yourself" stub page; the PyPI wheel ships the prebuilt
    # bundle. Replace the stub with the real UI.
    postInstall = (old.postInstall or "") + ''
      rm -rf "$out/${py.sitePackages}/flexget/ui/v2"
      cp -r "${webui}/share/webui" "$out/${py.sitePackages}/flexget/ui/v2"
    '';
  });
in {
  services.flexget = {
    enable = true;
    user = "flexget";
    homeDir = directoryPath;
    # Schedules live in the YAML (web_server + schedules sections).
    systemScheduler = false;
    config = builtins.readFile ./config/config.yml;
    package = flexgetFixed;
  };

  # FlexGet refuses to start on a stale lock ("Another process (PID ...) is
  # running"), e.g. after an unclean stop or a crash-loop. Clear it before
  # the daemon starts; the "+" prefix runs as root regardless of User=.
  systemd.services.flexget.serviceConfig.ExecStartPre = [
    "+${pkgs.coreutils}/bin/rm -f ${directoryPath}/.flexget-lock"
  ];

  # The module's ExecStop ('flexget daemon stop') spawns a second Python
  # process that recreates the lockfile while the unit is being restarted,
  # racing the new daemon's own boot ("Another process (PID ...) is
  # running"). SIGTERM alone stops the daemon cleanly -- drop ExecStop.
  systemd.services.flexget.serviceConfig.ExecStop = lib.mkForce "";

  # Quiesce before the switch restarts units: the previous generation may
  # be mid crash-loop (Restart=always), and its auto-restart racing the
  # new daemon's boot leaves a fresh lock -> "Another process is running"
  # -> failed activation -> rollback. Runs as root on every activation.
  system.activationScripts.flexgetQuiesce = {
    text = ''
      ${pkgs.systemd}/bin/systemctl stop flexget.service 2>/dev/null || true
      ${pkgs.coreutils}/bin/rm -f ${directoryPath}/.flexget-lock
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${directoryPath} 0770 flexget data - -"
  ];

  users.users.flexget = {
    isSystemUser = true;
    home = "/home/flexget";
    createHome = true;
    group = "flexget";
    extraGroups = ["data"];
  };
  users.groups.flexget = {};
}
