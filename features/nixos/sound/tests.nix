args @ {...}: let
  feature = import ./default.nix args;
in {
  test_sound_enable = {
    expr = feature.sound.enable;
    expected = false;
  };
  test_hardware_pulseaudio_enable = {
    expr = feature.hardware.pulseaudio.enable;
    expected = false;
  };
  test_security_rtkit_enable = {
    expr = feature.security.rtkit.enable;
    expected = true;
  };
  test_services_pipewire_enable = {
    expr = feature.services.pipewire.enable;
    expected = true;
  };
  test_services_pipewire_alsa_enable = {
    expr = feature.services.pipewire.alsa.enable;
    expected = true;
  };
  test_services_pipewire_alsa_support32Bit = {
    expr = feature.services.pipewire.alsa.support32Bit;
    expected = true;
  };
  test_services_pipewire_pulse_enable = {
    expr = feature.services.pipewire.pulse.enable;
    expected = true;
  };
}
