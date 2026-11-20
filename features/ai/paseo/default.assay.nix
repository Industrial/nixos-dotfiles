# Colocated suite for features/ai/paseo
#
# The claims that matter are the security posture (loopback bind) and the
# user-service shape, same as features/ai/cloudcli — both are easy to regress
# into something that looks fine and publishes a shell to the LAN, or that runs
# as a daemon with no agent credentials.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  system = nixos.evalSystem {modules = [./default.nix];};
  cfg = system.config;
  inherit (system) pkgs;
  inherit (nixos.defaultSettings) username userdir;
  svc = cfg.systemd.user.services.paseo;
  onPath = entry: builtins.elem "${entry}" (map (p: "${p}") svc.path);
in
  assay.suite "paseo" {
    # Straight from nixpkgs — no vendored tarball, lockfile or hash to go stale,
    # which is the main reason this feature is shorter than cloudcli's.
    usesNixpkgsPackage = assay.eq (builtins.elem pkgs.paseo.outPath (map (p: "${p}") cfg.environment.systemPackages)) true;
    hasNoVendoredLockfile = assay.eq (builtins.pathExists ./package-lock.json) false;
    hasNoLocalDerivation = assay.eq (builtins.pathExists ./package.nix) false;

    # A user service, so the spawned agent CLI inherits the operator's
    # ~/.claude/.credentials.json and can write the trees under $HOME.
    isUserService = assay.eq (cfg.systemd.user.services ? paseo) true;
    notASystemService = assay.eq (cfg.systemd.services ? paseo) false;
    lingerEnabled = assay.eq cfg.users.users.${username}.linger true;
    serviceWantedBy = assay.eq svc.wantedBy ["default.target"];
    serviceType = assay.eq svc.serviceConfig.Type "simple";
    restartsOnFailure = assay.eq svc.serviceConfig.Restart "on-failure";
    worksInHome = assay.eq svc.serviceConfig.WorkingDirectory userdir;

    # Runs the daemon supervisor, which is also what serves the web UI — not the
    # `paseo` CLI, which would exit immediately.
    execRunsServerNotCli = assay.eq svc.serviceConfig.ExecStart "${pkgs.paseo}/bin/paseo-server";

    # THE security claim. 127.0.0.1 happens to be upstream's default here, but it
    # is set explicitly so a changed default cannot quietly publish a
    # shell-capable browser to the LAN. Reach it over `ssh -L`, never the firewall.
    bindsLoopbackOnly = assay.eq svc.environment.PASEO_HOST "127.0.0.1";
    pinsPort = assay.eq svc.environment.PASEO_PORT "6767";
    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);

    # The web UI is the point of this feature, so it is requested rather than
    # inherited — the daemon is perfectly happy to run headless.
    webUiEnabled = assay.eq svc.environment.PASEO_WEB_UI_ENABLED "true";

    # State in $HOME, never the store.
    stateInHome = assay.eq svc.environment.PASEO_HOME "${userdir}/.paseo";
    homeIsSet = assay.eq svc.environment.HOME userdir;

    # The agent child resolves its tooling through PATH; a missing shell breaks
    # the built-in terminal and a missing openssh breaks push.
    pathHasShell = assay.eq (onPath pkgs.bashInteractive) true;
    pathHasGit = assay.eq (onPath pkgs.git) true;
    pathHasOpenssh = assay.eq (onPath pkgs.openssh) true;
    # Paseo drives agent CLIs, it does not contain one, so claude-code is a hard
    # dependency rather than an alternative.
    pathHasClaudeCode = assay.eq (onPath pkgs.claude-code) true;

    # THE REGRESSION CLAIM, and the most valuable one in this file. procps
    # supplies `ps`, which the daemon uses to enumerate its own children; the
    # ENOENT when it is missing ("spawn ps ENOENT") is unhandled and crashes the
    # process. Observed as the web UI dropping its connection every couple of
    # minutes while systemd still reported the unit active with NRestarts=0,
    # because the supervisor was respawning the child rather than the unit
    # restarting. Nothing about a missing entry here fails at build or activation
    # time, so this claim is the only thing standing between a tidy-up of the path
    # list and a crash loop that looks healthy from the outside.
    pathHasProcps = assay.eq (onPath pkgs.procps) true;
    # tar extracts the speech model; without it the download retries and logs a
    # level-50 error on a loop.
    pathHasGnutar = assay.eq (onPath pkgs.gnutar) true;
    # which is how paseo probes for the optional agent CLIs.
    pathHasWhich = assay.eq (onPath pkgs.which) true;
    # The system and per-user profiles, so the spawned CLI's MCP servers and
    # hooks (lean-ctx, roam, maestro, uvx, jq, ...) resolve the same way they do
    # from a login shell. Without these, ~/.claude loads but its servers ENOENT.
    pathHasSystemProfile = assay.eq (onPath "/run/current-system/sw") true;
    pathHasUserProfile = assay.eq (onPath "/etc/profiles/per-user/${username}") true;
    # And the unit's generated PATH really carries them, after the explicit floor.
    unitPathReachesSystemProfile = assay.eq (nixos.lib.hasInfix ":/run/current-system/sw/bin:" svc.environment.PATH) true;
  }
