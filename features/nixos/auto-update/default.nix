{
  config,
  lib,
  pkgs,
  settings,
  ...
}: let
  # Disabled: root cannot update a user-owned flake (libgit2 "repository path is not
  # owned by current user"). Nightly switch also fights interactive sessions / RAM.
  # Prefer features/cli/nixos-update-notifier (user timer + package list) and manual
  # `bin/update/host` when ready.
  enableAutoUpdate = false;

  dotfilesDir = "${settings.userdir}/.dotfiles";
  hostFlakeDir = "${dotfilesDir}/hosts/${settings.hostname}";
  logFile = "${dotfilesDir}/logs/nixos-auto-update";

  updateScript = pkgs.writeShellScript "nixos-auto-update" ''
    set -euo pipefail

    exec >> ${logFile} 2>&1

    echo "[$(date -Is)] Starting NixOS automatic update..."

    if [ ! -d ${hostFlakeDir} ]; then
      echo "[$(date -Is)] Host flake directory not found: ${hostFlakeDir}"
      exit 1
    fi

    cd ${hostFlakeDir}

    echo "[$(date -Is)] Updating flake inputs..."
    ${pkgs.nix}/bin/nix --experimental-features "nix-command flakes" flake update

    echo "[$(date -Is)] Rebuilding and switching system..."
    ${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch \
      --flake ".#${settings.hostname}" \
      --show-trace \
      --option eval-cache false

    echo "[$(date -Is)] NixOS automatic update completed successfully."
  '';
in {
  systemd.services.nixos-auto-update = lib.mkIf enableAutoUpdate {
    description = "Nightly NixOS flake update and switch";
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${dotfilesDir}/logs";
      ExecStart = updateScript;
    };
  };

  systemd.timers.nixos-auto-update = lib.mkIf enableAutoUpdate {
    description = "Run NixOS automatic update daily at 04:00";
    wantedBy = ["timers.target"];

    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };
  };
}
