let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "sound_test";
    actual = feature.sound.enable;
    expected = false;
  }
  {
    name = "sound_test";
    actual = feature.hardware.pulseaudio.enable;
    expected = false;
  }
  {
    name = "sound_test";
    actual = feature.security.rtkit.enable;
    expected = true;
  }
  {
    name = "sound_test";
    actual = feature.services.pipewire.enable;
    expected = true;
  }
  {
    name = "sound_test";
    actual = feature.services.pipewire.alsa.enable;
    expected = true;
  }
  {
    name = "sound_test";
    actual = feature.services.pipewire.alsa.support32Bit;
    expected = true;
  }
  {
    name = "sound_test";
    actual = feature.services.pipewire.pulse.enable;
    expected = true;
  }
]
