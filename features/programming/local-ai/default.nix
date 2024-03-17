{
  settings,
  pkgs,
  ...
}: {
  # docker run -ti -p 8080:8080 localai/localai:v2.5.1-ffmpeg-core phi-2
  virtualisation.oci-containers.containers = {
    localai = {
      image = "localai/localai:v2.5.1-ffmpeg-core";
      autoStart = true;
      cmd = ["phi-2"];
      ports = ["8080:8080"];
      # volumes = [
      #   "${settings.userdir}/.tabby:/data"
      # ];
    };
  };
}
