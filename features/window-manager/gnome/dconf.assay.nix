# Assay: the GNOME dconf database.
#
# Claims read the evaluated programs.dconf.profiles.user.databases. GVariant-typed values
# (mkInt32, mkEmptyArray) are compared through their `.value`, so the claim is about the
# number or list GNOME reads, whatever helper produced it.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./dconf.nix];};
  dbs = cfg.programs.dconf.profiles.user.databases;
  db = builtins.head dbs;
  s = db.settings;
  v = x:
    if builtins.isAttrs x && x ? value
    then x.value
    else x;
  autoMove = s."org/gnome/shell/extensions/auto-move-windows".application-list;
in
  assay.suite "dconf" {
    oneUserDatabase = assay.eq (builtins.length dbs) 1;
    # Every key is locked: the database is policy, not a default the user can drift from.
    locksAllKeys = assay.eq db.lockAll true;

    # Security-relevant desktop settings.
    screenLockEnabled = assay.eq s."org/gnome/desktop/screensaver".lock-enabled true;
    doesNotRememberMountPasswords = assay.eq s."org/gnome/shell".remember-mount-password false;
    purgesOldTempAndTrash =
      assay.eq (with s."org/gnome/desktop/privacy"; [remove-old-temp-files remove-old-trash-files (v old-files-age)]) [true true 30];
    # Shell extensions may be installed and are not all disabled at once.
    userExtensionsAllowed =
      assay.eq (with s."org/gnome/shell"; [allow-extension-installation disable-user-extensions]) [true false];

    # A desktop on AC never sleeps on idle; on battery after 20 minutes.
    neverSleepsOnAc =
      assay.eq (with s."org/gnome/settings-daemon/plugins/power"; [(v sleep-inactive-ac-timeout) sleep-inactive-ac-type]) [0 "nothing"];
    sleepsOnBatteryAfter20Min =
      assay.eq (v s."org/gnome/settings-daemon/plugins/power".sleep-inactive-battery-timeout) 1200;

    # Ten named workspaces, which auto-move-windows indexes from 0.
    tenWorkspaces = assay.eq (v s."org/gnome/desktop/wm/preferences".num-workspaces) 10;
    workspaceNames =
      assay.eq s."org/gnome/desktop/wm/preferences".workspace-names
      ["www" "dev" "cmd" "git" "doc" "mda" "gtd" "net" "oth" "rnd"];
    superDigitSwitchesWorkspace =
      assay.eq (map (n: s."org/gnome/desktop/wm/keybindings"."switch-to-workspace-${toString n}") [1 2 10])
      [["<Super>1"] ["<Super>2"] ["<Super>0"]];
    autoMoveRulesTargetExistingWorkspaces =
      assay.eq (builtins.all (r: let
        m = builtins.match "[[]'[^']+', ([0-9]+)[]]" r;
      in
        m != null && lib.toInt (builtins.head m) < 10)
      autoMove)
      true;

    # GNOME reads its own key, not fontconfig's alias, so the stylix family is named again.
    monospaceFontIsTheStylixFamily =
      assay.eq s."org/gnome/desktop/interface".monospace-font-name "IosevkaTerm Nerd Font Mono 11";
    prefersDark = assay.eq s."org/gnome/desktop/interface".color-scheme "prefer-dark";
    ghosttyIsAFavourite =
      assay.eq (builtins.elem "com.mitchellh.ghostty.desktop" s."org/gnome/shell".favorite-apps) true;
  }
