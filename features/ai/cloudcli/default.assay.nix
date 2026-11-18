# Colocated suite for features/ai/cloudcli/default.nix.
# The claims that matter here are the security posture (loopback bind) and the
# user-service shape — both are easy to regress into something that looks fine and
# publishes a shell to the LAN, or that runs as a daemon with no agent credentials.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  lib = (import <nixpkgs> {}).lib;
  mod = import ./default.nix {
    inherit lib;
    settings = {
      username = "tom";
      userdir = "/home/tom";
    };
    pkgs = {
      callPackage = _: _: "cloudcli-pkg";
      bashInteractive = "bashInteractive";
      coreutils = "coreutils";
      git = "git";
      openssh = "openssh";
      ripgrep = "ripgrep";
      nodejs_22 = "nodejs_22";
      claude-code = "claude-code";
    };
  };
  svc = mod.systemd.user.services.cloudcli;
in
  assay.suite "cloudcli" {
    buildsFromColocatedPackage = assay.eq (builtins.match ".*callPackage \\./package\\.nix.*" src != null) true;
    installsPackage = assay.eq (builtins.elem "cloudcli-pkg" mod.environment.systemPackages) true;

    # A user service, so the spawned agent CLI inherits the operator's
    # ~/.claude/.credentials.json and can write the working trees under $HOME.
    isUserService = assay.eq (builtins.hasAttr "cloudcli" mod.systemd.user.services) true;
    notASystemService = assay.eq (builtins.hasAttr "systemd" mod && builtins.hasAttr "services" (mod.systemd or {})) false;
    lingerEnabled = assay.eq mod.users.users.tom.linger true;

    serviceWantedBy = assay.eq svc.wantedBy ["default.target"];
    serviceType = assay.eq svc.serviceConfig.Type "simple";
    restartsOnFailure = assay.eq svc.serviceConfig.Restart "on-failure";
    execUsesWrappedBinary = assay.eq svc.serviceConfig.ExecStart "cloudcli-pkg/bin/cloudcli";
    worksInHome = assay.eq svc.serviceConfig.WorkingDirectory "/home/tom";

    # THE security claim. Upstream defaults HOST to 0.0.0.0; this unit must not.
    bindsLoopbackOnly = assay.eq svc.environment.HOST "127.0.0.1";
    pinsPort = assay.eq svc.environment.SERVER_PORT "3001";

    # State in $HOME, never the store.
    databaseInHome = assay.eq svc.environment.DATABASE_PATH "/home/tom/.cloudcli/auth.db";
    workspacesRootInHome = assay.eq svc.environment.WORKSPACES_ROOT "/home/tom";
    homeIsSet = assay.eq svc.environment.HOME "/home/tom";

    # The agent child resolves its tooling through PATH; a missing shell breaks the
    # built-in terminal and a missing openssh breaks push.
    pathHasShell = assay.eq (builtins.elem "bashInteractive" svc.path) true;
    pathHasGit = assay.eq (builtins.elem "git" svc.path) true;
    pathHasOpenssh = assay.eq (builtins.elem "openssh" svc.path) true;
    pathHasClaudeCode = assay.eq (builtins.elem "claude-code" svc.path) true;

    # The SSH-forward instruction is the documented remote path; if the bind address
    # ever changes, this comment is the thing that should have been read first.
    documentsSshForward = assay.eq (builtins.match ".*ssh -N -L 3001:127\\.0\\.0\\.1:3001.*" src != null) true;
  }
