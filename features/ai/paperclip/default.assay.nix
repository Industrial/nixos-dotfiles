# Colocated suite for features/ai/paperclip
#
# Paperclip runs as a lingering user service and its embedded Postgres is an unpatched
# Linux binary, so nix-ld is load-bearing — and a linger boot has no login session, so
# the unit has to carry the nix-ld variables itself.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;
  # Substring test over generated text; store-path context is irrelevant to the match.
  contains = needle: s: lib.hasInfix (builtins.unsafeDiscardStringContext needle) (builtins.unsafeDiscardStringContext s);
  system = nixos.evalSystem {modules = [./default.nix];};
  cfg = system.config;
  pkgs = system.pkgs;
  inherit (nixos.defaultSettings) username userdir;
  paperclipai = lib.findFirst (p: lib.getName p == "paperclipai") null cfg.environment.systemPackages;
  svc = cfg.systemd.user.services.paperclipai;
  outPaths = map (p: "${p}");
in
  assay.suite "paperclip" {
    installsPaperclipai = assay.eq (nixos.hasPackage cfg "paperclipai") true;
    installsNode22 = assay.eq (builtins.elem pkgs.nodejs_22.outPath (outPaths cfg.environment.systemPackages)) true;
    # The installed CLI is the colocated npx wrapper at its pinned version.
    installsPinnedWrapper = assay.eq (contains "npx --yes paperclipai@2026.817.0" paperclipai.text) true;

    # Unpatched @embedded-postgres binaries need a dynamic linker + libstdc++.
    nixLdEnabled = assay.eq cfg.programs.nix-ld.enable true;
    nixLdHasLibstdcxx = assay.eq (builtins.elem pkgs.stdenv.cc.cc.outPath (outPaths cfg.programs.nix-ld.libraries)) true;

    # A user service that survives logout and starts at boot.
    isUserService = assay.eq (cfg.systemd.user.services ? paperclipai) true;
    notASystemService = assay.eq (cfg.systemd.services ? paperclipai) false;
    lingerEnabled = assay.eq cfg.users.users.${username}.linger true;
    serviceDescription = assay.eq svc.description "Paperclip AI control plane";
    serviceWantedBy = assay.eq svc.wantedBy ["default.target"];
    serviceType = assay.eq svc.serviceConfig.Type "simple";
    servicePathHasBash = assay.eq (builtins.elem pkgs.bashInteractive.outPath (outPaths svc.path)) true;
    serviceExecUsesRun = assay.eq svc.serviceConfig.ExecStart "${paperclipai}/bin/paperclipai run --instance default --no-repair";
    worksInHome = assay.eq svc.serviceConfig.WorkingDirectory userdir;
    instanceHomeInHome = assay.eq svc.environment.PAPERCLIP_HOME "${userdir}/.paperclip";

    # A linger boot has no login session, so the unit must carry nix-ld's own values;
    # an empty one means embedded Postgres cannot load.
    serviceCarriesNixLd = assay.eq svc.environment.NIX_LD cfg.environment.variables.NIX_LD;
    serviceCarriesNixLdLibraryPath = assay.eq svc.environment.NIX_LD_LIBRARY_PATH cfg.environment.variables.NIX_LD_LIBRARY_PATH;
    nixLdIsSet = assay.eq (svc.environment.NIX_LD != "") true;

    # `paperclipai service install` leaves a unit in ~/.config that would shadow ours.
    # Read from the generated per-user activation script, which is what actually runs.
    removesImperativeUnit =
      assay.eq
      (contains "rm -f \"$HOME/.config/systemd/user/paperclipai.service\"" cfg.systemd.user.services.nixos-activation.script)
      true;
  }
