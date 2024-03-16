let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "local-ai_test";
    actual = feature.virtualisation.oci-containers.containers.localai.image;
    expected = "localai/localai:v2.5.1-ffmpeg-core";
  }
  {
    name = "local-ai_test";
    actual = feature.virtualisation.oci-containers.containers.localai.autoStart;
    expected = true;
  }
  {
    name = "local-ai_test";
    actual = feature.virtualisation.oci-containers.containers.localai.cmd;
    expected = ["phi-2"];
  }
  {
    name = "local-ai_test";
    actual = feature.virtualisation.oci-containers.containers.localai.ports;
    expected = ["8080:8080"];
  }
]
