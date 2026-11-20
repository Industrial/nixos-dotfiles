# Assay: V-268147 -- Bluetooth disabled.
#
# Claims read the evaluated hardware.bluetooth option, for the control alone, for the
# Bluetooth feature alone, and for the two together.
let
  assay = import ../../../../common/assay/default.nix;
  nixos = import ../../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./V-268147.nix];};
  bluetoothFeature = ../../../nixos/bluetooth/default.nix;
  withFeature = nixos.eval {modules = [bluetoothFeature];};
in
  assay.suite "stig-V-268147" {
    bluetoothDisabled = assay.eq cfg.hardware.bluetooth.enable false;
    # No Bluetooth service, so no bluetoothd is left listening for pairings.
    noBluetoothService = assay.eq (cfg.systemd.services ? bluetooth) false;

    # Unlike V-268146 this is a genuine change: features/nixos/bluetooth enables Bluetooth and
    # profiles/base.nix imports it, so applying this control takes Bluetooth audio and
    # peripherals away. That direct conflict is why it is `full` and not base-safe.
    theBluetoothFeatureEnablesIt = assay.eq withFeature.hardware.bluetooth.enable true;
    # Imported side by side at equal priority the two cannot both win: the module system
    # refuses the pair outright rather than silently picking one.
    conflictsWithTheBluetoothFeature =
      assay.throws
      "((import ${toString ../../../../common/assay/nixos.nix}).eval {modules = [${toString ./V-268147.nix} ${toString bluetoothFeature}];}).hardware.bluetooth.enable"
      "conflicting definition values";
  }
