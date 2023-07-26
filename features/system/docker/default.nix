{...}: {
  virtualisation.docker.enable = true;

  # TODO: Split this out into it's own feature
  # TODO: Check if it's possible to make features able to define system and home-manager code.
  virtualisation.oci-containers.containers = {
    mytabbycontainer = {
      image = "tabbyml/tabby";
      autoStart = true;
      cmd = ["serve" "--model" "TabbyML/SantaCoder-1B"];
      ports = ["4001:8080"];
      volumes = [
        "/home/tom/.tabby:/data"
      ];
    };
  };
}
