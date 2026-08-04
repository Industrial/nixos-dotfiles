# Colocated suite: primary user from settings.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      settings = { hostname = "h"; username = "alice"; };
    })
  '';
in
  assay.suite "users" {
    username = assay.eq "${mod}.users.users.alice.isNormalUser" "true";
  }
