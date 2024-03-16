let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem "localai/localai:v2.5.1-ffmpeg-core" feature.virtualisation.oci-containers.containers.localai.image;
    expected = true;
  }
  {
    actual = feature.virtualisation.oci-containers.containers.localai.autoStart;
    expected = true;
  }
  {
    actual = builtins.elem "phi-2" feature.virtualisation.oci-containers.containers.localai.cmd;
    expected = true;
  }
  {
    actual = builtins.elem "8080:8080" feature.virtualisation.oci-containers.containers.localai.ports;
    expected = true;
  }
]
