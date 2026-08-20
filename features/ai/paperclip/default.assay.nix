# Colocated suite for features/ai/paperclip
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  pkg = builtins.readFile ./package.nix;
  lib = (import <nixpkgs> {}).lib;
  mod = import ./default.nix {
    inherit lib;
    config = {
      environment.variables = {
        NIX_LD = "/run/current-system/sw/share/nix-ld/lib/ld.so";
        NIX_LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib";
      };
    };
    settings = {
      username = "tom";
      userdir = "/home/tom";
    };
    pkgs = {
      nodejs_22 = "nodejs_22";
      bashInteractive = "bashInteractive";
      coreutils = "coreutils";
      callPackage = _: _: "paperclipai-pkg";
      stdenv.cc.cc = "stdenv.cc.cc";
      zlib = "zlib";
      openssl = "openssl";
      curl = "curl";
      icu = "icu";
      libuuid = "libuuid";
    };
  };
in
  assay.suite "paperclip" {
    hasPaperclipaiNet = assay.eq (builtins.match ".*paperclipai\\.net.*" src != null) true;
    hasNodejs22 = assay.eq (builtins.elem "nodejs_22" mod.environment.systemPackages) true;
    hasCallPackage = assay.eq (builtins.match ".*callPackage.*package\\.nix.*" src != null) true;
    hasWrapperName = assay.eq (builtins.match ".*name = \"paperclipai\".*" pkg != null) true;
    pinsNpmVersion = assay.eq (builtins.match ".*paperclipai@2026\\.817\\.0.*" pkg != null) true;
    nixLdEnabled = assay.eq mod.programs.nix-ld.enable true;
    serviceDescription = assay.eq mod.systemd.user.services.paperclipai.description "Paperclip AI control plane";
    serviceWantedBy = assay.eq mod.systemd.user.services.paperclipai.wantedBy ["default.target"];
    serviceType = assay.eq mod.systemd.user.services.paperclipai.serviceConfig.Type "simple";
    servicePathHasBash = assay.eq (builtins.elem "bashInteractive" mod.systemd.user.services.paperclipai.path) true;
    serviceExecUsesRun = assay.eq (builtins.match ".* run --instance default --no-repair.*" mod.systemd.user.services.paperclipai.serviceConfig.ExecStart != null) true;
    lingerEnabled = assay.eq mod.users.users.tom.linger true;
    removesImperativeUnit = assay.eq (builtins.match ".*paperclipai\\.service.*" mod.system.userActivationScripts.paperclipRemoveImperativeUnit.text != null) true;
  }
