# Colocated suite: WoW Classic configuration
let
  assay = import ./../../../common/assay/default.nix;
  lib = {
    mkIf = cond: val:
      if cond
      then val
      else null;
  };
  settings = {
    hostname = "h";
    username = "alice";
  };
  config = {
    home.homeDirectory = "/home/alice";
    lib.file.mkOutOfStoreSymlink = path: path;
  };
  mod = import ./default.nix {inherit config lib settings;};
in
  assay.suite "wow-classic" {
    has-wtf-symlink = assay.eq (builtins.hasAttr ''/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/WTF'' mod.home.file) true;
  }
