# Colocated suite: docker enable + user in docker group.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      settings = { hostname = "h"; username = "alice"; };
      pkgs = { docker = "docker"; };
    })
  '';
in
  assay.suite "docker" {
    enabled = assay.eq "${mod}.virtualisation.docker.enable" "true";
  }
