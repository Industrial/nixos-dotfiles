{
  system ? "x86_64-linux",
  hostname,
  username ? "tom",
  version ? "24.11",
}: let
  assertions = import ./assert.nix;

  # Apply validations
  validSystem = assertions.assertSupportedSystem system;
  validHostname = assertions.assertNonEmptyString hostname;
  validUsername = assertions.assertNonEmptyString username;
  validVersion = assertions.assertMatches "[0-9]+\\.[0-9]+" version;
in {
  inherit system username;
  settings = {
    system = validSystem;
    hostname = validHostname;
    username = validUsername;
    stateVersion = validVersion;
    hostPlatform = {
      system = validSystem;
    };
    userdir = "/home/${validUsername}";
    useremail = "${validUsername}@${validSystem}.local";
    userfullname = validUsername;
  };
}
