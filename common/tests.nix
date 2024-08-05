{
  inputs,
  pkgs,
  ...
}: let
  settings = {
    hostname = "testhostname";
    stateVersion = "24.05";
    system = "x86_64-linux";
    hostPlatform = {
      system = "x86_64-linux";
    };
    userdir = "/Users/test";
    useremail = "test@test.com";
    userfullname = "Chadster McChaddington";
    username = "test";
  };
in {
  features = import ../features/tests.nix {
    inherit inputs settings pkgs;
  };
}
