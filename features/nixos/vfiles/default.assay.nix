# Assay: vfiles takes over the declared files from the features' activation scripts, and
# switching it off brings those scripts back (the rollback).
#
# Evaluated against the real NixOS option tree, with a stand-in feature that declares one
# file and keeps its old script as `vfiles.legacy`: the same shape every migrated feature
# has. The spec is read back as JSON, so the claims are about what vfiles is run with.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  standIn = {pkgs, ...}: {
    imports = [../../../lib/vfiles.nix];
    vfiles.files."/home/alice/.config/x/x.toml" = {
      source = pkgs.writeText "x.toml" "x = 1\n";
      user = "alice";
    };
    vfiles.files."/home/alice/.config/gone.toml" = {
      mode = "absent";
      user = "alice";
    };
    vfiles.legacy.linkX.text = "ln -sfn /nix/store/x /home/alice/.config/x/x.toml";
  };

  on = nixos.eval {modules = [standIn ./default.nix];};
  off = nixos.eval {modules = [standIn ./default.nix {vfiles.enable = lib.mkForce false;}];};
  without = nixos.eval {modules = [standIn];};

  spec = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile on.vfiles.spec));
  byPath = lib.listToAttrs (map (f: lib.nameValuePair f.path f) spec.files);
  x = byPath."/home/alice/.config/x/x.toml";
  script = on.system.activationScripts.vfiles;
in
  assay.suite "vfiles-feature" {
    takesOver = assay.eq [(on.system.activationScripts ? vfiles) (on.system.activationScripts ? linkX)] [true false];
    rollbackBringsTheLegacyScriptsBack =
      assay.eq [(off.system.activationScripts ? vfiles) off.system.activationScripts.linkX.text] [false "ln -sfn /nix/store/x /home/alice/.config/x/x.toml"];
    offByDefault = assay.eq [without.vfiles.enable (without.system.activationScripts ? linkX) (without.system.activationScripts ? vfiles)] [false true false];

    runsAfterUsersAndGroups = assay.eq script.deps ["users" "groups"];
    runsTheSpecIntoTheStateDir =
      assay.eq (lib.hasInfix (builtins.unsafeDiscardStringContext "/bin/vfiles --spec ${on.vfiles.spec} --state-dir /var/lib/vfiles") (builtins.unsafeDiscardStringContext script.text)) true;
    specInEtcForTheProbe = assay.eq "${on.environment.etc."vfiles/spec.json".source}" "${on.vfiles.spec}";
    installsThePackage = assay.eq (builtins.any (p: (p.pname or "") == "vfiles") on.environment.systemPackages) true;

    specCarriesEveryField =
      assay.eq (builtins.attrNames x) ["fallback" "force" "group" "immutable" "mode" "path" "perms" "source" "user"];
    specDefaults = assay.eq [x.mode x.group x.perms x.immutable x.force x.fallback] ["link" "users" "0644" false false null];
    specSourceIsAStorePath = assay.eq (lib.hasPrefix "/nix/store/" x.source && lib.hasSuffix "-x.toml" x.source) true;
    absentHasNoSource = assay.eq byPath."/home/alice/.config/gone.toml".source null;
    specSortedByPath = assay.eq (map (f: f.path) spec.files) (lib.sort lib.lessThan (map (f: f.path) spec.files));
  }
