{...}: {
  virtualisation.docker.enable = true;

  # TODO: Split this out into it's own feature
  # TODO: Check if it's possible to make features able to define system and home-manager code.
  virtualisation.oci-containers.containers = {
    # mytabbycontainer = {
    #   image = "tabbyml/tabby";
    #   autoStart = true;
    #   cmd = ["serve" "--model" "TabbyML/SantaCoder-1B"];
    #   ports = ["4001:8080"];
    #   volumes = [
    #     "/home/tom/.tabby:/data"
    #   ];
    # };
    # cryptpad = {
    #   image = "promasu/cryptpad";
    #   autoStart = true;
    #   # cmd = ["serve" "--model" "TabbyML/SantaCoder-1B"];
    #   ports = [
    #     "4001:3000"
    #     "4002:3001"
    #   ];
    #   # volumes = [
    #   #   "/home/tom/.tabby:/data"
    #   # ];
    # };
    # etherpad = {
    #   image = "elestio/etherpad";
    #   autoStart = true;
    #   ports = [
    #     "4001:3000"
    #     "4002:3001"
    #   ];
    #   # volumes = [
    #   #   "/home/tom/.tabby:/data"
    #   # ];
    # };
    octobot = {
      image = "drakkarsoftware/octobot";
      autoStart = true;
      ports = [
        "5001:5001"
      ];
      volumes = [
        "/home/tom/.dotfiles/features/home/lab/crypto/octobot/logs:/octobot/logs"
        "/home/tom/.dotfiles/features/home/lab/crypto/octobot/tentacles:/octobot/tentacles"
        "/home/tom/.dotfiles/features/home/lab/crypto/octobot/users:/octobot/users"
      ];
    };
    graphhopper = {
      image = "israelhikingmap/graphhopper";
      autoStart = true;
      ports = [
        "5002:8989"
        "5003:8990"
      ];
      volumes = [
        "/home/tom/.dotfiles/features/home/lab/maps/graphhopper/data:/data"
      ];
    };
  };
}
