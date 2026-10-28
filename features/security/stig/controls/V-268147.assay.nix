# Colocated suite: V-268147 — Bluetooth disabled.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268147.nix {};
in
  assay.suite "stig-V-268147" {
    bluetoothDisabled = assay.eq mod.hardware.bluetooth.enable false;

    # Unlike V-268146 this is a genuine change: features/nixos/bluetooth enables Bluetooth and
    # profiles/base.nix imports it, so applying this control takes Bluetooth audio and
    # peripherals away. That direct conflict is why it is `full` and not base-safe.
    conflictsWithTheBluetoothFeature =
      assay.eq (builtins.match ".*enable = true.*" (builtins.readFile ./../../../nixos/bluetooth/default.nix) != null) true;
  }
