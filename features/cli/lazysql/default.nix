# Lazysql browses SQL databases. It's a TUI client for MySQL, PostgreSQL and SQLite.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lazysql
  ];
}
