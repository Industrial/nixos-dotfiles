args @ {...}: let
  feature = import ./default.nix args;
in {
  test_virtualisation_oci-containers_containers_localai_image = {
    expr = feature.virtualisation.oci-containers.containers.localai.image;
    expected = "localai/localai:v2.5.1-ffmpeg-core";
  };
  test_virtualisation_oci-containers_containers_localai_autoStart = {
    expr = feature.virtualisation.oci-containers.containers.localai.autoStart;
    expected = true;
  };
  test_virtualisation_oci-containers_containers_localai_cmd = {
    expr = feature.virtualisation.oci-containers.containers.localai.cmd;
    expected = ["phi-2"];
  };
  test_virtualisation_oci-containers_containers_localai_ports = {
    expr = feature.virtualisation.oci-containers.containers.localai.ports;
    expected = ["8080:8080"];
  };
}
