# Colocated suite for features/ai/cloudcli/default.nix.
# The claims that matter here are the security posture (loopback bind) and the
# user-service shape — both are easy to regress into something that looks fine and
# publishes a shell to the LAN, or that runs as a daemon with no agent credentials.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  system = nixos.evalSystem {modules = [./default.nix];};
  cfg = system.config;
  inherit (system) pkgs;
  inherit (nixos.defaultSettings) username userdir;
  cloudcli = lib.findFirst (p: lib.getName p == "cloudcli") null cfg.environment.systemPackages;
  svc = cfg.systemd.user.services.cloudcli;
  onPath = p: builtins.elem p.outPath (map (x: "${x}") svc.path);
in
  assay.suite "cloudcli" {
    installsPackage = assay.eq (nixos.hasPackage cfg "cloudcli") true;
    buildsFromColocatedPackage = assay.eq (lib.getVersion cloudcli) "1.37.9";

    # A user service, so the spawned agent CLI inherits the operator's
    # ~/.claude/.credentials.json and can write the working trees under $HOME.
    isUserService = assay.eq (cfg.systemd.user.services ? cloudcli) true;
    notASystemService = assay.eq (cfg.systemd.services ? cloudcli) false;
    lingerEnabled = assay.eq cfg.users.users.${username}.linger true;

    serviceWantedBy = assay.eq svc.wantedBy ["default.target"];
    serviceType = assay.eq svc.serviceConfig.Type "simple";
    restartsOnFailure = assay.eq svc.serviceConfig.Restart "on-failure";
    execUsesWrappedBinary = assay.eq svc.serviceConfig.ExecStart "${cloudcli}/bin/cloudcli";
    worksInHome = assay.eq svc.serviceConfig.WorkingDirectory userdir;

    # THE security claim. Upstream defaults HOST to 0.0.0.0; this unit must not.
    bindsLoopbackOnly = assay.eq svc.environment.HOST "127.0.0.1";
    pinsPort = assay.eq svc.environment.SERVER_PORT "3001";
    # Loopback only means nothing on the firewall either: reach it over `ssh -L`.
    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);

    # State in $HOME, never the store.
    databaseInHome = assay.eq svc.environment.DATABASE_PATH "${userdir}/.cloudcli/auth.db";
    workspacesRootInHome = assay.eq svc.environment.WORKSPACES_ROOT userdir;
    homeIsSet = assay.eq svc.environment.HOME userdir;

    # The agent child resolves its tooling through PATH; a missing shell breaks the
    # built-in terminal and a missing openssh breaks push.
    pathHasShell = assay.eq (onPath pkgs.bashInteractive) true;
    pathHasGit = assay.eq (onPath pkgs.git) true;
    pathHasOpenssh = assay.eq (onPath pkgs.openssh) true;
    pathHasClaudeCode = assay.eq (onPath pkgs.claude-code) true;
  }
