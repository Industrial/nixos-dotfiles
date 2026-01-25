# pgAdmin is a PostgreSQL administration and development platform.
{
  settings,
  pkgs,
  lib,
  ...
}: let
  # Create a wrapper script that sets SQLITE_PATH to a user-writable directory
  pgadmin4-wrapped = pkgs.writeShellScriptBin "pgadmin4" ''
    export SQLITE_PATH="$HOME/.local/share/pgadmin/pgadmin4.db"
    export PGADMIN_CONFIG_DIR="$HOME/.config/pgadmin"
    export PGADMIN_DATA_DIR="$HOME/.local/share/pgadmin"

    # Create directories if they don't exist
    mkdir -p "$HOME/.config/pgadmin"
    mkdir -p "$HOME/.local/share/pgadmin"

    # Run pgadmin4 with the configured paths
    exec ${pkgs.pgadmin4}/bin/pgadmin4 "$@"
  '';
in {
  environment = {
    systemPackages = with pkgs; [
      # pgadmin4-wrapped
      pgadmin4-desktopmode
    ];
  };
}
