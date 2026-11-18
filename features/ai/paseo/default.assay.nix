# Colocated suite for features/ai/paseo
#
# The claims that matter are the security posture (loopback bind) and the
# user-service shape, same as features/ai/cloudcli — both are easy to regress
# into something that looks fine and publishes a shell to the LAN, or that runs
# as a daemon with no agent credentials.
let
  assay = import ./../../../common/assay/default.nix;
  lib = (import <nixpkgs> {}).lib;
  src = builtins.readFile ./default.nix;
  hasText = needle: lib.hasInfix needle src;
  mod = import ./default.nix {
    settings = {
      username = "tom";
      userdir = "/home/tom";
    };
    pkgs = {
      paseo = "paseo";
      bashInteractive = "bashInteractive";
      coreutils = "coreutils";
      git = "git";
      gnutar = "gnutar";
      openssh = "openssh";
      procps = "procps";
      ripgrep = "ripgrep";
      which = "which";
      nodejs_22 = "nodejs_22";
      claude-code = "claude-code";
    };
  };
  svc = mod.systemd.user.services.paseo;
in
  assay.suite "paseo" {
    # Straight from nixpkgs — no vendored tarball, lockfile or hash to go stale,
    # which is the main reason this feature is shorter than cloudcli's.
    usesNixpkgsPackage = assay.eq (builtins.elem "paseo" mod.environment.systemPackages) true;
    hasNoVendoredLockfile = assay.eq (builtins.pathExists ./package-lock.json) false;
    hasNoLocalDerivation = assay.eq (builtins.pathExists ./package.nix) false;

    # A user service, so the spawned agent CLI inherits the operator's
    # ~/.claude/.credentials.json and can write the trees under $HOME.
    isUserService = assay.eq (builtins.hasAttr "paseo" mod.systemd.user.services) true;
    lingerEnabled = assay.eq mod.users.users.tom.linger true;
    serviceWantedBy = assay.eq svc.wantedBy ["default.target"];
    serviceType = assay.eq svc.serviceConfig.Type "simple";
    restartsOnFailure = assay.eq svc.serviceConfig.Restart "on-failure";
    worksInHome = assay.eq svc.serviceConfig.WorkingDirectory "/home/tom";

    # Runs the daemon supervisor, which is also what serves the web UI — not the
    # `paseo` CLI, which would exit immediately.
    execRunsServerNotCli = assay.eq svc.serviceConfig.ExecStart "paseo/bin/paseo-server";

    # THE security claim. 127.0.0.1 happens to be upstream's default here, but it
    # is set explicitly so a changed default cannot quietly publish a
    # shell-capable browser to the LAN.
    bindsLoopbackOnly = assay.eq svc.environment.PASEO_HOST "127.0.0.1";
    pinsPort = assay.eq svc.environment.PASEO_PORT "6767";

    # The web UI is the point of this feature, so it is requested rather than
    # inherited — the daemon is perfectly happy to run headless.
    webUiEnabled = assay.eq svc.environment.PASEO_WEB_UI_ENABLED "true";

    # State in $HOME, never the store.
    stateInHome = assay.eq svc.environment.PASEO_HOME "/home/tom/.paseo";
    homeIsSet = assay.eq svc.environment.HOME "/home/tom";

    # The agent child resolves its tooling through PATH; a missing shell breaks
    # the built-in terminal and a missing openssh breaks push.
    pathHasShell = assay.eq (builtins.elem "bashInteractive" svc.path) true;
    pathHasGit = assay.eq (builtins.elem "git" svc.path) true;
    pathHasOpenssh = assay.eq (builtins.elem "openssh" svc.path) true;
    pathHasClaudeCode = assay.eq (builtins.elem "claude-code" svc.path) true;

    # THE REGRESSION CLAIM, and the most valuable one in this file. procps
    # supplies `ps`, which the daemon uses to enumerate its own children; the
    # ENOENT when it is missing is unhandled and crashes the process. Observed as
    # the web UI dropping its connection every couple of minutes while systemd
    # still reported the unit active with NRestarts=0, because the supervisor was
    # respawning the child rather than the unit restarting. Nothing about a
    # missing entry here fails at build or activation time, so this claim is the
    # only thing standing between a tidy-up of the path list and a crash loop that
    # looks healthy from the outside.
    pathHasProcps = assay.eq (builtins.elem "procps" svc.path) true;
    # tar extracts the speech model; without it the download retries and logs a
    # level-50 error on a loop.
    pathHasGnutar = assay.eq (builtins.elem "gnutar" svc.path) true;
    # which is how paseo probes for the optional agent CLIs.
    pathHasWhich = assay.eq (builtins.elem "which" svc.path) true;
    # The system and per-user profiles, so the spawned CLI's MCP servers and
    # hooks (lean-ctx, roam, maestro, uvx, jq, ...) resolve the same way they do
    # from a login shell. Without these, ~/.claude loads but its servers ENOENT.
    pathHasSystemProfile = assay.eq (builtins.elem "/run/current-system/sw" svc.path) true;
    pathHasUserProfile = assay.eq (builtins.elem "/etc/profiles/per-user/tom" svc.path) true;
    # And the finding itself, so a future reader does not have to rediscover why
    # the list is longer than cloudcli's.
    documentsTheCrashLoop = assay.eq (hasText "spawn ps ENOENT") true;

    # Paseo drives agent CLIs, it does not contain one, so claude-code is a hard
    # dependency rather than an alternative. Recording it here stops a future
    # tidy-up from dropping features/ai/claude-code as "superseded".
    documentsClaudeCodeDependency = assay.eq (hasText "does not contain one") true;

    # The SSH-forward instruction is the documented remote path; if the bind
    # address ever changes, this comment is what should have been read first.
    documentsSshForward = assay.eq (hasText "ssh -N -L 6767:127.0.0.1:6767") true;
  }
