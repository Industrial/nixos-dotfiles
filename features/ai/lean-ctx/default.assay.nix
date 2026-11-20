# Colocated suite for features/ai/lean-ctx/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "lean-ctx") null cfg.environment.systemPackages;
  added = lib.subtractLists (nixos.packageNames nixos.baseline) (nixos.packageNames cfg);
  svc = cfg.systemd.user.services.lean-ctx-hook-binary;
  hookBinary = "/run/current-system/sw/bin/lean-ctx";
in
  assay.suite "lean-ctx" {
    installsLeanCtx = assay.eq (nixos.hasPackage cfg "lean-ctx") true;
    addsOnlyLeanCtx = assay.eq added ["lean-ctx"];
    installsColocatedPackage = assay.eq (lib.getVersion pkg) "3.9.18";
    enablesCompression = assay.eq cfg.environment.variables.LEAN_CTX_COMPRESS "1";

    # Every lean-ctx build must write the same hook path into the shared
    # ~/.claude, or concurrent repos flip it to their own store path. The system
    # profile always exists and always follows this feature's package.
    pinsHookBinaryEnv = assay.eq cfg.environment.variables.LEAN_CTX_HOOK_BINARY hookBinary;

    # MCP servers spawned under systemd never see environment.variables, so the same
    # value is also written into ~/.lean-ctx/config.toml by a user oneshot at login.
    setsConfigViaUserOneshot = assay.eq svc.serviceConfig.Type "oneshot";
    oneshotRunsAtLogin = assay.eq svc.wantedBy ["default.target"];
    oneshotWritesSameHookBinary =
      assay.eq svc.serviceConfig.ExecStart
      "${pkg}/bin/lean-ctx config set hook_binary ${hookBinary}";
  }
