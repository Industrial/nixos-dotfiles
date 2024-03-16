let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.sound.enable;
    expected = false;
  }
  {
    actual = feature.hardware.pulseaudio.enable;
    expected = false;
  }
  {
    actual = feature.security.rtkit.enable;
    expected = true;
  }
  {
    actual = feature.services.pipewire.enable;
    expected = true;
  }
  {
    actual = feature.services.pipewire.alsa.enable;
    expected = true;
  }
  {
    actual = feature.services.pipewire.alsa.support32Bit;
    expected = true;
  }
  {
    actual = feature.services.pipewire.pulse.enable;
    expected = true;
  }
]
