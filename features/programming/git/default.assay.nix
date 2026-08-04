# Colocated suite: git package + config file wiring.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      settings = {
        hostname = "h"; username = "alice"; useremail = "a@b.c";
        userdir = "/home/alice";
      };
      pkgs = {
        git = "git";
        writeText = name: text: name;
      };
    })
  '';
in
  assay.suite "git" {
    packages = assay.eq "${mod}.environment.systemPackages" ''[ "git" ]'';
  }
