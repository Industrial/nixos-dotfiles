# Eval helper for co-located feature suites.
#
# Typed options cover merge-sensitive devenv surfaces (mkOverride / mkBefore).
# freeformType accepts any other top-level attr so this file is not an inventory
# of every feature's config keys.
{
  pkgs ? import <nixpkgs> {},
  lib ? pkgs.lib,
}: let
  anything = lib.types.attrsOf lib.types.unspecified;

  stubs = {lib, ...}: {
    freeformType = lib.types.attrsOf lib.types.unspecified;

    options = {
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [];
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
      };
      enterShell = lib.mkOption {
        type = lib.types.lines;
        default = "";
      };
      dotenv = lib.mkOption {
        type = anything;
        default = {};
      };
      languages = lib.mkOption {
        type = anything;
        default = {};
      };
      scripts = lib.mkOption {
        type = anything;
        default = {};
      };
      git-hooks = lib.mkOption {
        type = anything;
        default = {};
      };
      # Declared, not freeform: a feature that only ever sets one of these via
      # `mkIf` would otherwise make the freeform type resolve attribute names
      # through `config`, which recurses back into the feature's own `cfg`.
      processes = lib.mkOption {
        type = anything;
        default = {};
      };
      services = lib.mkOption {
        type = anything;
        default = {};
      };
    };
  };

  evalModule = modulePath: settings:
    lib.evalModules {
      modules = [(import modulePath) stubs settings];
      specialArgs = {inherit pkgs lib;};
    };

  packageNames = cfg: map (p: p.pname or p.name) (cfg.packages or []);

  project = cfg: let
    languages = cfg.languages or {};
    js = languages.javascript or {};
    rust = languages.rust or {};
    python = languages.python or {};
    uv = python.uv or {};
    sync = uv.sync or {};
    scripts = cfg.scripts or {};
  in {
    packages = packageNames cfg;
    env = cfg.env or {};
    enterShell = cfg.enterShell or "";
    dotenv = {enable = (cfg.dotenv or {}).enable or false;};
    languages = {
      javascript = {
        enable = js.enable or false;
        bunEnable = (js.bun or {}).enable or false;
      };
      typescriptEnable = (languages.typescript or {}).enable or false;
      rust = {
        enable = rust.enable or false;
        channel = rust.channel or "";
        version = rust.version or "";
        components = rust.components or [];
        targets = rust.targets or [];
      };
      python = {
        enable = python.enable or false;
        version = python.version or "";
        uvEnable = uv.enable or false;
        uvSyncEnable = sync.enable or false;
        uvSyncArguments = sync.arguments or [];
      };
    };
    scripts = builtins.attrNames scripts;
    scriptExec = lib.mapAttrs (_: s: s.exec or "") scripts;
    git-hooks = cfg.git-hooks or {};
  };
in {
  inherit pkgs lib stubs evalModule project packageNames;

  feature = modulePath: settings: project (evalModule modulePath settings).config;

  optionNames = modulePath:
    builtins.attrNames (evalModule modulePath {}).options.local.features;
}
