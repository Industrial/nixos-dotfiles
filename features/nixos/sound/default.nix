{
  settings,
  pkgs,
  ...
}: {
  # https://nixos.wiki/wiki/PipeWire
  sound.enable = false;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire.enable = true;
  services.pipewire.alsa.enable = true;
  services.pipewire.alsa.support32Bit = true;
  services.pipewire.pulse.enable = true;

  environment.systemPackages = with pkgs; [
    pavucontrol
    pulsemixer
  ];
}
