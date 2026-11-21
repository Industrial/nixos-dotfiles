# Colocated suite for lib/vfiles.nix — the vfiles option surface and what it hands the
# linker.
#
# Evaluated against the real NixOS option tree. The spec is read back as JSON, so claims
# are about what `vfiles` is run with: sources resolved to store paths (Nix paths, text
# and packages) or kept as given (out-of-store strings), and the legacy scripts mapped to
# activation scripts only while vfiles is off.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  inherit (nixos) lib;

  files = {pkgs, ...}: {
    imports = [./vfiles.nix];
    vfiles.files = {
      "/home/alice/a.conf" = {
        text = "a\n";
        user = "alice";
      };
      "/home/alice/b.conf" = {
        source = ./vfiles.nix;
        mode = "copy";
        perms = "0600";
        user = "alice";
      };
      "/home/alice/c.conf" = {
        source = "/home/alice/checkout/c.conf";
        fallback = pkgs.writeText "c-fallback.conf" "c\n";
        user = "alice";
        group = "wheel";
      };
    };
    vfiles.legacy.oldScript.text = "true";
  };

  evalWith = extra: nixos.evalSystem {modules = [files] ++ extra;};
  on = (evalWith [{vfiles.enable = true;}]).config;
  off = (evalWith []).config;

  spec = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile on.vfiles.spec));
  byPath = lib.listToAttrs (map (f: lib.nameValuePair f.path f) spec.files);
  inStore = s: lib.hasPrefix "/nix/store/" s;

  # Both a source and a text: the module refuses it with an assertion.
  conflicted =
    (evalWith [
      {
        vfiles.enable = true;
        vfiles.files."/home/alice/d.conf" = {
          text = "d";
          source = ./vfiles.nix;
          user = "alice";
        };
      }
    ]).config;
  failedAssertions = map (a: a.message) (lib.filter (a: !a.assertion) conflicted.assertions);
in
  assay.suite "vfiles-module" {
    textBecomesAStoreFile = assay.eq [(inStore byPath."/home/alice/a.conf".source) (lib.hasSuffix "-a.conf" byPath."/home/alice/a.conf".source)] [true true];
    nixPathIsCopiedToTheStore = assay.eq (inStore byPath."/home/alice/b.conf".source) true;
    outOfStoreSourceStaysAsGiven = assay.eq byPath."/home/alice/c.conf".source "/home/alice/checkout/c.conf";
    packageFallbackIsItsOutPath = assay.eq (lib.hasSuffix "-c-fallback.conf" byPath."/home/alice/c.conf".fallback) true;
    fieldsPassThrough = assay.eq [byPath."/home/alice/b.conf".mode byPath."/home/alice/b.conf".perms byPath."/home/alice/c.conf".group] ["copy" "0600" "wheel"];

    legacyRunsWhileOff = assay.eq [(off.system.activationScripts ? oldScript) (off.system.activationScripts ? vfiles)] [true false];
    legacyGoneWhileOn = assay.eq [(on.system.activationScripts ? oldScript) (on.system.activationScripts ? vfiles)] [false true];

    sourceAndTextIsRefused =
      assay.eq failedAssertions [''vfiles.files."/home/alice/d.conf": set exactly one of source and text (neither, for mode absent).''];
    noAssertionFailsForAValidSet = assay.eq (lib.filter (a: !a.assertion) on.assertions) [];
  }
