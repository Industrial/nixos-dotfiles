# Paperclip — https://paperclipai.net/
# Open-source control plane for AI agents (org charts, goals, budgets, heartbeats).
# Docs: https://docs.paperclip.ing/guides/getting-started/installation/
#
# Requires Node.js 20+. Do not run as root (embedded Postgres refuses admin users).
# Embedded Postgres is an unpatched Linux binary → enable nix-ld.
# Declarative systemd --user unit replaces `paperclipai service install`.
{
  config,
  pkgs,
  settings,
  lib,
  ...
}: let
  paperclipai = pkgs.callPackage ./package.nix {};
  home = settings.userdir;
  instanceHome = "${home}/.paperclip";
in {
  environment.systemPackages = [
    pkgs.nodejs_22
    paperclipai
  ];

  # Unpatched @embedded-postgres binaries need a dynamic linker + libstdc++.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      curl
      icu
      libuuid
    ];
  };

  # Start at boot / survive logout (user systemd).
  users.users.${settings.username}.linger = true;

  # Drop imperative onboard unit so /etc/systemd/user wins cleanly.
  system.userActivationScripts.paperclipRemoveImperativeUnit = {
    text = ''
      rm -f "$HOME/.config/systemd/user/paperclipai.service"
    '';
  };

  systemd.user.services.paperclipai = {
    description = "Paperclip AI control plane";
    wantedBy = ["default.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    # npx/npm spawn `sh`; postgres scripts need a normal user PATH.
    path = with pkgs; [
      bashInteractive
      coreutils
      nodejs_22
      paperclipai
    ];

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = home;
      ExecStart = "${paperclipai}/bin/paperclipai run --instance default --no-repair";
      Restart = "on-failure";
      RestartSec = "10s";
      TimeoutStopSec = "300";
    };

    environment = {
      HOME = home;
      PAPERCLIP_HOME = instanceHome;
      PAPERCLIP_INSTANCE_ID = "default";
      PAPERCLIP_SERVICE_MANAGED = "1";
      # Linger boot has no login session vars — reuse nix-ld module outputs.
      NIX_LD = config.environment.variables.NIX_LD or "";
      NIX_LD_LIBRARY_PATH = config.environment.variables.NIX_LD_LIBRARY_PATH or "";
    };
  };
}
